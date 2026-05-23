defmodule SmartKioskCore.Search do
  @moduledoc """
  Interface for Meilisearch integration.
  """
  require Logger

  @doc "Indexes a product into Meilisearch."
  def index_product(product) do
    Logger.info("Search: Indexing product '#{product.name}' (#{product.id})")
    # TODO: Implement Meilisearch indexing
    # HTTP.post("http://localhost:7700/indexes/products/documents", body: product_to_doc(product))
    :ok
  end

  @doc "Indexes a shop into Meilisearch."
  def index_shop(shop) do
    Logger.info("Search: Indexing shop '#{shop.name}' (#{shop.id})")
    # TODO: Implement Meilisearch indexing
    :ok
  end

  @doc "Queries products in Meilisearch."
  def query_products(query, opts \\ []) do
    # TODO: Implement Meilisearch search
    # For now, fallback to DB-based search until library is configured
    perform_db_search(query, opts)
  end

  defp perform_db_search(query, _opts) do
    # Centralized search logic (previously in HomeLive)
    products = SmartKioskCore.Catalogue.list_products_centralized(query)
               |> Enum.map(&%{&1 | type: :product})

    shops = SmartKioskCore.Shops.search_shops(query)
            |> Enum.map(&%{&1 | type: :shop})

    (products ++ shops)
    |> Enum.sort_by(& &1.inserted_at, :desc)
  end
end
