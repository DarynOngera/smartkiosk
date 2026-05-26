defmodule SmartKioskCore.Search.IndexServer do
  @moduledoc """
  GenServer managing the in-memory search index with ETS and DETS backing.

  This is the central coordinator for:
  - In-memory Trie storage (ETS table for concurrent reads)
  - Disk persistence (DETS for recovery)
  - Change batching and processing
  - Snapshot management

  ## Architecture

  ```
  [Web Requests] → [ETS Table] → (fast concurrent reads)
                      ↓
              [GenServer] → (single-writer for updates)
                      ↓
              [DETS File] → (disk persistence)
  ```

  ## Configuration

      config :smart_kiosk_core, SmartKioskCore.Search.IndexServer,
        dets_path: "priv/search_index.dets",
        snapshot_interval_ms: 300_000,  # 5 minutes
        max_memory_mb: 512
  """

  use GenServer

  require Logger

  alias SmartKioskCore.Search.{BatchQueue, Engine, Persistence}

  @typedoc "Index server state"
  @type state :: %{
          ets_table: :ets.table(),
          dets_path: String.t(),
          snapshot_timer: reference() | nil,
          last_snapshot: DateTime.t() | nil,
          stats: map()
        }

  @ets_table :search_index

  # ── Public API ──────────────────────────────────────────────────────────────

  @doc """
  Starts the IndexServer.

  ## Options

    * `:dets_path` - Path to DETS file (default: priv/search_index.dets)
    * `:snapshot_interval_ms` - Auto-save interval (default: 5 minutes)
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = opts[:name] || __MODULE__
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Searches the index with the given query.

  ## Examples

      iex> SmartKioskCore.Search.IndexServer.search("iphone")
      [{1, 0.0, %{distance: 0, field: :name}}, ...]
  """
  @spec search(String.t(), keyword()) :: [Query.ranked_result()]
  def search(query, opts \\ []) do
    case lookup_trie() do
      nil ->
        Logger.warning("IndexServer: Search attempted but index not loaded")
        []

      trie ->
        SmartKioskCore.Search.Query.execute(trie, query, opts)
    end
  end

  @doc """
  Performs a prefix search (exact match only, no typos).

  Ideal for autocomplete/suggestions.
  """
  @spec prefix_search(String.t(), keyword()) :: [Query.ranked_result()]
  def prefix_search(query, opts \\ []) do
    case lookup_trie() do
      nil -> []
      trie -> SmartKioskCore.Search.Query.prefix_search(trie, query, opts)
    end
  end

  @doc """
  Inserts a document into the index.

  This is an async operation - the change is queued and applied in batch.
  """
  @spec insert(Engine.document()) :: :ok
  def insert(doc) do
    BatchQueue.insert(doc)
  end

  @doc """
  Updates a document in the index.

  Equivalent to delete + insert.
  """
  @spec update(Engine.document()) :: :ok
  def update(doc) do
    BatchQueue.update(doc)
  end

  @doc """
  Removes a document from the index.

  This is an async operation.
  """
  @spec delete(term()) :: :ok
  def delete(doc_id) do
    BatchQueue.delete(doc_id)
  end

  @doc """
  Rebuilds the entire index from the given documents.

  This is a synchronous operation that replaces the current index.
  """
  @spec rebuild([Engine.document()]) :: :ok | {:error, term()}
  def rebuild(documents) do
    GenServer.call(__MODULE__, {:rebuild, documents}, :infinity)
  end

  @doc """
  Triggers a manual snapshot to disk.
  """
  @spec snapshot() :: :ok | {:error, term()}
  def snapshot do
    GenServer.call(__MODULE__, :snapshot)
  end

  @doc """
  Returns current index statistics.
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  @doc """
  Checks if the index is ready for queries.
  """
  @spec ready?() :: boolean()
  def ready? do
    lookup_trie() != nil
  end

  # ── GenServer Callbacks ─────────────────────────────────────────────────────

  @impl true
  def init(opts) do
    dets_path = opts[:dets_path] || default_dets_path()
    snapshot_interval = opts[:snapshot_interval_ms] || 300_000

    # Create ETS table for concurrent reads
    ets_table =
      :ets.new(@ets_table, [
        :set,
        :protected,
        :named_table,
        read_concurrency: true
      ])

    state = %{
      ets_table: ets_table,
      dets_path: dets_path,
      snapshot_timer: nil,
      last_snapshot: nil,
      stats: %{documents: 0, last_rebuild: nil}
    }

    # Try to load from disk, otherwise trigger async rebuild
    state =
      case Persistence.load(dets_path) do
        {:ok, trie} ->
          :ets.insert(ets_table, {:trie, trie})
          update_stats(state, trie)

        {:error, reason} ->
          Logger.warning("IndexServer: Could not load index (#{reason}), scheduling rebuild")
          # Schedule a rebuild in 5 seconds to allow system to fully boot
          Process.send_after(self(), :trigger_rebuild, 5_000)
          state
      end

    # Schedule periodic snapshots
    timer = Process.send_after(self(), :scheduled_snapshot, snapshot_interval)
    state = %{state | snapshot_timer: timer}

    Logger.info("IndexServer: Initialized with DETS at #{dets_path}")
    {:ok, state}
  end

  @impl true
  def handle_call({:rebuild, documents}, _from, state) do
    start_time = System.monotonic_time(:millisecond)

    # Build new trie
    trie = Engine.build_index(documents)

    # Update ETS
    :ets.insert(state.ets_table, {:trie, trie})

    # Save to disk
    Persistence.save(trie, state.dets_path)

    duration = System.monotonic_time(:millisecond) - start_time

    new_stats = %{
      documents: length(documents),
      last_rebuild: DateTime.utc_now(),
      rebuild_duration_ms: duration
    }

    Logger.info("IndexServer: Rebuilt index with #{length(documents)} documents in #{duration}ms")

    :telemetry.execute(
      [:smart_kiosk, :search, :index, :rebuild],
      %{duration_ms: duration, documents: length(documents)},
      %{}
    )

    {:reply, :ok, %{state | stats: new_stats, last_snapshot: DateTime.utc_now()}}
  end

  @impl true
  def handle_call(:snapshot, _from, state) do
    result =
      case lookup_trie() do
        nil ->
          {:error, :no_index}

        trie ->
          Persistence.save(trie, state.dets_path)
      end

    new_state =
      case result do
        :ok -> %{state | last_snapshot: DateTime.utc_now()}
        _ -> state
      end

    {:reply, result, new_state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats =
      case lookup_trie() do
        nil ->
          state.stats

        trie ->
          doc_count =
            trie
            |> Engine.all_doc_ids()
            |> MapSet.size()

          Map.merge(state.stats, %{
            documents_in_index: doc_count,
            memory_estimate_bytes: estimate_memory(trie),
            ready: true
          })
      end

    {:reply, stats, state}
  end

  @impl true
  def handle_info(:scheduled_snapshot, state) do
    # Cancel existing timer
    if state.snapshot_timer do
      Process.cancel_timer(state.snapshot_timer)
    end

    # Perform snapshot
    case lookup_trie() do
      nil ->
        :ok

      trie ->
        Task.start(fn ->
          Persistence.save(trie, state.dets_path)
        end)
    end

    # Schedule next snapshot
    interval = 300_000
    timer = Process.send_after(self(), :scheduled_snapshot, interval)

    {:noreply, %{state | snapshot_timer: timer, last_snapshot: DateTime.utc_now()}}
  end

  @impl true
  def handle_info(:trigger_rebuild, state) do
    Logger.info("IndexServer: Triggering async index rebuild")

    # Enqueue the rebuild worker
    %{}
    |> SmartKioskCore.Workers.SearchRebuildWorker.new()
    |> Oban.insert()

    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    # Final snapshot on shutdown
    case lookup_trie() do
      nil -> :ok
      trie -> Persistence.save(trie, state.dets_path)
    end

    :ok
  end

  # ── Private Functions ───────────────────────────────────────────────────────

  defp lookup_trie do
    case :ets.lookup(@ets_table, :trie) do
      [{:trie, trie}] -> trie
      [] -> nil
    end
  end

  defp update_stats(state, trie) do
    doc_count =
      trie
      |> Engine.all_doc_ids()
      |> MapSet.size()

    %{state | stats: %{documents: doc_count, last_rebuild: DateTime.utc_now()}}
  end

  defp estimate_memory(trie) do
    # Rough estimate based on term size
    :erlang.external_size(trie)
  end

  defp default_dets_path do
    :code.priv_dir(:smart_kiosk_core)
    |> to_string()
    |> Path.join("search_index.dets")
  end
end
