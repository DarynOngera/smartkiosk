defmodule SmartKioskCore.Workers.SearchRebuildWorker do
  @moduledoc """
  Rebuilds the entire search index from the database.

  This worker is triggered:
  1. On application startup (if no valid DETS snapshot exists)
  2. When corruption is detected in the persisted index
  3. Manually via the admin panel

  The rebuild process:
  1. Fetches all active products and shops from the database
  2. Builds a new Trie from scratch
  3. Replaces the in-memory index atomically
  4. Saves the new index to DETS
  """

  use Oban.Worker,
    queue: :search_index,
    max_attempts: 1,
    unique: [period: 60]

  require Logger

  alias SmartKioskCore.Search.IndexServer
  alias SmartKioskCore.Repo

  import Ecto.Query

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    force = args["force"] || false

    # Check if we really need to rebuild
    # Rebuild if force=true OR if index has no documents
    stats = IndexServer.stats()
    doc_count = stats[:documents_in_index] || 0

    if force or doc_count == 0 do
      do_rebuild()
    else
      Logger.info(
        "SearchRebuildWorker: Index already has #{doc_count} documents, skipping rebuild (use force=true to override)"
      )

      :ok
    end
  end

  defp do_rebuild do
    Logger.info("SearchRebuildWorker: Starting full index rebuild")

    start_time = System.monotonic_time(:millisecond)

    # Build documents list
    documents =
      []
      |> add_products()
      |> add_shops()

    # Rebuild the index
    case IndexServer.rebuild(documents) do
      :ok ->
        duration = System.monotonic_time(:millisecond) - start_time

        Logger.info(
          "SearchRebuildWorker: Rebuilt index with #{length(documents)} documents " <>
            "in #{duration}ms"
        )

        :ok

      {:error, reason} ->
        Logger.error("SearchRebuildWorker: Rebuild failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # ── Private Functions ───────────────────────────────────────────────────────

  defp add_products(documents) do
    # Fetch all active products with their shops
    products =
      from(p in SmartKioskCore.Schemas.Product,
        join: s in assoc(p, :shop),
        where: p.status == :active and p.stock_qty > 0 and s.status == :active,
        preload: [:shop]
      )
      |> Repo.all()

    product_docs =
      Enum.map(products, fn product ->
        shop_name = if product.shop, do: product.shop.name, else: ""

        %{
          id: {:product, product.id},
          text: "#{product.name} #{shop_name}",
          field: :product_name,
          weight: 1.0
        }
      end)

    documents ++ product_docs
  end

  defp add_shops(documents) do
    # Fetch all active shops
    shops =
      from(s in SmartKioskCore.Schemas.Shop,
        where: s.status == :active
      )
      |> Repo.all()

    shop_docs =
      Enum.map(shops, fn shop ->
        %{
          id: {:shop, shop.id},
          text: shop.name,
          field: :shop_name,
          weight: 1.0
        }
      end)

    documents ++ shop_docs
  end
end
