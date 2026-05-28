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

    # Get current index
    current_index = get_current_index()

    # Apply all changes
    new_index =
      Enum.reduce(changes, current_index, fn
        {:insert, doc}, index ->
          Engine.insert(index, doc.text, doc.id, doc[:field] || :name, doc[:weight] || 1.0)

        {:update, doc}, index ->
          # Delete then re-insert
          index
          |> Engine.remove(doc.id)
          |> Engine.insert(doc.text, doc.id, doc[:field] || :name, doc[:weight] || 1.0)

        {:delete, doc_id}, index ->
          Engine.remove(index, doc_id)
      end)

    # Recompute vocabulary and IDF after mutations
    new_index = Engine.finalize_index(new_index)

    # Update the index
    update_index(new_index)

    duration = System.monotonic_time(:millisecond) - start_time

    Logger.info("SearchIndexBatchWorker: Processed #{length(changes)} changes in #{duration}ms")

    :telemetry.execute(
      [:smart_kiosk, :search, :index, :update],
      %{duration_ms: duration, changes: length(changes)},
      %{}
    )

    :ok
  end

  defp get_current_index do
    case :ets.lookup(:search_index, :index) do
      [{:index, index}] -> index
      [] -> Engine.empty_index()
    end
  end

  defp update_index(index) do
    :ets.insert(:search_index, {:index, index})
  end
end
