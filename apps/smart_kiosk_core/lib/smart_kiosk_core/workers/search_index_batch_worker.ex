defmodule SmartKioskCore.Workers.SearchIndexBatchWorker do
  @moduledoc """
  Processes batched search index changes every 30 seconds.

  This worker dequeues all pending changes from the BatchQueue and applies
  them to the in-memory Trie. It runs on a schedule via Oban Cron.

  ## Change Processing

  - `:insert` - Adds new document to index
  - `:update` - Removes old document, inserts new one
  - `:delete` - Removes document from index

  Changes are applied atomically to ensure consistency.
  """

  use Oban.Worker,
    queue: :search_index,
    max_attempts: 3

  require Logger

  alias SmartKioskCore.Search.{BatchQueue, Engine}

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    changes = BatchQueue.dequeue_all()

    if changes == [] do
      Logger.debug("SearchIndexBatchWorker: No changes to process")
      :ok
    else
      process_changes(changes)
    end
  end

  # ── Private Functions ───────────────────────────────────────────────────────

  defp process_changes(changes) do
    start_time = System.monotonic_time(:millisecond)

    # Get current trie
    current_trie = get_current_trie()

    # Apply all changes
    new_trie =
      Enum.reduce(changes, current_trie, fn
        {:insert, doc}, trie ->
          Engine.insert(trie, doc.text, doc.id, doc[:field] || :name, doc[:weight] || 1.0)

        {:update, doc}, trie ->
          # Delete then re-insert
          trie
          |> Engine.remove(doc.id)
          |> Engine.insert(doc.text, doc.id, doc[:field] || :name, doc[:weight] || 1.0)

        {:delete, doc_id}, trie ->
          Engine.remove(trie, doc_id)
      end)

    # Update the index
    update_index(new_trie)

    duration = System.monotonic_time(:millisecond) - start_time

    Logger.info("SearchIndexBatchWorker: Processed #{length(changes)} changes in #{duration}ms")

    :telemetry.execute(
      [:smart_kiosk, :search, :index, :update],
      %{duration_ms: duration, changes: length(changes)},
      %{}
    )

    :ok
  end

  defp get_current_trie do
    # Access the ETS table directly to get current state
    case :ets.lookup(:search_index, :trie) do
      [{:trie, trie}] -> trie
      [] -> %{}
    end
  end

  defp update_index(trie) do
    :ets.insert(:search_index, {:trie, trie})
  end
end
