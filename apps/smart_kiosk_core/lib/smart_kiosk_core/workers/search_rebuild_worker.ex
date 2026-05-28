defmodule SmartKioskCore.Workers.SearchRebuildWorker do
  @moduledoc """
  Rebuilds the entire search index from the database in batches.

  Products are fetched in batches of 5,000 to keep memory flat and the
  system responsive. Between batches the worker sleeps briefly to yield
  CPU time to other processes.

  Triggered:
  1. On application startup (if stale / empty index detected)
  2. When corruption is detected in the persisted index
  3. Manually via `SmartKioskCore.Search.rebuild/0`
  """

  use Oban.Worker,
    queue: :search_index,
    max_attempts: 1,
    unique: [period: 60]

  require Logger

  alias SmartKioskCore.Search.{IndexServer, Engine}
  alias SmartKioskCore.Repo
  alias SmartKioskCore.Schemas.{Product, Shop}

  import Ecto.Query

  @batch_size 5_000
  @yield_ms 10

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    force = args["force"] || false

    db_count = db_document_count()
    index_count = IndexServer.stats()[:documents_in_index] || 0

    if force or index_count != db_count do
      do_rebuild()
    else
      Logger.info("SearchRebuildWorker: Index up-to-date (#{index_count} docs), skipping")

      :ok
    end
  end

  # ── Rebuild Orchestration ────────────────────────────────────────────────────

  defp do_rebuild do
    Logger.info("SearchRebuildWorker: Starting full index rebuild")
    start_time = System.monotonic_time(:millisecond)

    # Start with an empty index and accumulate batches
    index = Engine.empty_index()
    index = build_products(index)
    index = build_shops(index)

    # Compute vocabulary and IDF after all inserts
    index = Engine.finalize_index(index)

    # Atomic swap — fast, never blocks GenServer for more than a few µs
    doc_count = count_in_index(index)
    :ok = IndexServer.swap_index(index, doc_count)

    # Persist the rebuilt index (safe now with inverted index, ~8MB)
    case IndexServer.snapshot() do
      :ok ->
        Logger.info("SearchRebuildWorker: Index persisted to disk")

      {:error, reason} ->
        Logger.warning("SearchRebuildWorker: Persist failed: #{inspect(reason)}")
    end

    duration = System.monotonic_time(:millisecond) - start_time

    Logger.info("SearchRebuildWorker: Rebuilt index with #{doc_count} documents in #{duration}ms")

    :ok
  end

  # ── Product Batching ─────────────────────────────────────────────────────────

  defp build_products(trie) do
    total =
      from(p in Product,
        join: s in assoc(p, :shop),
        where: p.status == :active and p.stock_qty > 0 and s.status == :active,
        select: count(p.id)
      )
      |> Repo.one()

    Logger.info("SearchRebuildWorker: Indexing #{total} products in batches of #{@batch_size}")

    total
    |> batches()
    |> Enum.reduce(trie, fn offset, acc_trie ->
      docs = fetch_product_batch(offset)
      trie = Enum.reduce(docs, acc_trie, &insert_doc/2)

      # Yield CPU so the web interface stays responsive
      Process.sleep(@yield_ms)
      trie
    end)
  end

  defp fetch_product_batch(offset) do
    products =
      from(p in Product,
        join: s in assoc(p, :shop),
        where: p.status == :active and p.stock_qty > 0 and s.status == :active,
        order_by: p.id,
        limit: ^@batch_size,
        offset: ^offset,
        preload: [:shop]
      )
      |> Repo.all()

    Enum.map(products, fn product ->
      shop_name = if product.shop, do: product.shop.name, else: ""

      %{
        id: {:product, product.id},
        text: "#{product.name} #{shop_name}",
        field: :product_name,
        weight: 1.0
      }
    end)
  end

  # ── Shops ────────────────────────────────────────────────────────────────────

  defp build_shops(trie) do
    shops =
      from(s in Shop, where: s.status == :active)
      |> Repo.all()

    docs =
      Enum.map(shops, fn shop ->
        %{
          id: {:shop, shop.id},
          text: shop.name,
          field: :shop_name,
          weight: 1.0
        }
      end)

    Enum.reduce(docs, trie, &insert_doc/2)
  end

  # ── Helpers ──────────────────────────────────────────────────────────────────

  defp insert_doc(doc, trie) do
    Engine.insert(trie, doc.text, doc.id, doc.field, doc.weight)
  end

  defp db_document_count do
    product_count =
      from(p in Product,
        join: s in assoc(p, :shop),
        where: p.status == :active and p.stock_qty > 0 and s.status == :active,
        select: count(p.id)
      )
      |> Repo.one()

    shop_count =
      from(s in Shop, where: s.status == :active, select: count(s.id))
      |> Repo.one()

    product_count + shop_count
  end

  defp batches(total) when total <= 0, do: []

  defp batches(total) do
    0..(total - 1)//@batch_size
  end

  defp count_in_index(index) do
    map_size(index.docs)
  end
end
