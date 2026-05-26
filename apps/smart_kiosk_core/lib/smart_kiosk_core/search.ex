defmodule SmartKioskCore.Search do
  @moduledoc """
  Public interface for the fuzzy search engine.

  This module provides a clean API for searching products and shops
  using the native Elixir fuzzy search implementation with typo tolerance.

  ## Features

  - Fuzzy matching with configurable typo tolerance
  - Prefix search for autocomplete
  - Multi-field ranking (title, description, etc.)
  - Async index updates via batch processing
  - Disk persistence with corruption detection

  ## Usage

      # Search for products and shops
      SmartKioskCore.Search.query_products("iphone")
      # => [{:product, 1}, {:shop, 2}, ...]

      # Prefix search for autocomplete
      SmartKioskCore.Search.prefix_search("iph")
      # => [{:product, 1}, ...]

  ## Architecture

  The search system consists of:

  1. **Engine** (`Search.Engine`) - Core Trie + Levenshtein algorithm
  2. **IndexServer** (`Search.IndexServer`) - GenServer managing ETS/DETS
  3. **BatchQueue** (`Search.BatchQueue`) - Accumulates changes for batch processing
  4. **Query** (`Search.Query`) - Search execution and ranking
  5. **Persistence** (`Search.Persistence`) - DETS snapshot management
  6. **Workers** - Oban jobs for batch processing and rebuilding

  """

  require Logger

  alias SmartKioskCore.Search.IndexServer
  alias SmartKioskCore.{Catalogue, Shops}

  # ── Public API ──────────────────────────────────────────────────────────────

  @doc """
  Queries products and shops using fuzzy search.

  Returns a list of tuples indicating the type and ID of matching items:
  - `{:product, id}` for products
  - `{:shop, id}` for shops

  ## Options

    * `:limit` - Maximum results to return (default: 20)
    * `:max_typos` - Override default typo budget

  ## Examples

      iex> SmartKioskCore.Search.query_products("iphone")
      [{:product, 1}, {:shop, 2}, {:product, 5}]

      iex> SmartKioskCore.Search.query_products("iphoen", limit: 10)
      [{:product, 1}]  # Fuzzy match with 1 typo
  """
  @spec query_products(String.t(), keyword()) ::
          [{:product | :shop, term()}]
  def query_products(query, opts \\ []) do
    if IndexServer.ready?() do
      do_fuzzy_search(query, opts)
    else
      Logger.warning("Search: Index not ready, returning empty results")
      []
    end
  end

  @doc """
  Performs a prefix search for autocomplete suggestions.

  Only returns exact prefix matches (no typos allowed).

  ## Examples

      iex> SmartKioskCore.Search.prefix_search("iph")
      [{:product, 1, "iPhone 15"}, {:product, 2, "iPhone 14"}]
  """
  @spec prefix_search(String.t(), keyword()) ::
          [{:product | :shop, term(), String.t()}]
  def prefix_search(query, opts \\ []) do
    if IndexServer.ready?() do
      limit = opts[:limit] || 10

      query
      |> IndexServer.prefix_search(limit: limit)
      |> hydrate_results()
    else
      []
    end
  end

  @doc """
  Indexes a product into the search engine.

  This is an async operation - the change will be applied in the next batch.

  Called automatically when products are created or updated.
  """
  @spec index_product(map()) :: :ok
  def index_product(product) do
    doc = product_to_doc(product)
    IndexServer.insert(doc)
    :ok
  end

  @doc """
  Indexes a shop into the search engine.

  This is an async operation - the change will be applied in the next batch.

  Called automatically when shops are created or updated.
  """
  @spec index_shop(map()) :: :ok
  def index_shop(shop) do
    doc = shop_to_doc(shop)
    IndexServer.insert(doc)
    :ok
  end

  @doc """
  Removes a product from the search index.

  Called automatically when products are deleted.
  """
  @spec remove_product(term()) :: :ok
  def remove_product(product_id) do
    IndexServer.delete({:product, product_id})
    :ok
  end

  @doc """
  Removes a shop from the search index.

  Called automatically when shops are deleted.
  """
  @spec remove_shop(term()) :: :ok
  def remove_shop(shop_id) do
    IndexServer.delete({:shop, shop_id})
    :ok
  end

  @doc """
  Checks if the search index is ready for queries.
  """
  @spec ready?() :: boolean()
  def ready? do
    IndexServer.ready?()
  end

  @doc """
  Returns the number of documents in the search index.
  """
  @spec document_count() :: non_neg_integer()
  def document_count do
    stats = IndexServer.stats()
    stats[:documents_in_index] || 0
  end

  @doc """
  Returns statistics about the search index.
  """
  @spec stats() :: map()
  def stats do
    IndexServer.stats()
  end

  @doc """
  Returns diagnostic information about the search system.
  """
  @spec diagnose() :: map()
  def diagnose do
    %{
      ready: ready?(),
      document_count: document_count(),
      stats: stats(),
      queue_size: SmartKioskCore.Search.BatchQueue.size()
    }
  end

  @doc """
  Triggers a full index rebuild from the database.

  This is useful after:
  - Data corruption is detected
  - Bulk imports
  - Schema changes
  """
  @spec rebuild() :: :ok
  def rebuild do
    %{}
    |> SmartKioskCore.Workers.SearchRebuildWorker.new()
    |> Oban.insert()

    :ok
  end

  # ── Private Functions ───────────────────────────────────────────────────────

  defp do_fuzzy_search(query, opts) do
    limit = opts[:limit] || 20
    max_typos = opts[:max_typos]

    search_opts =
      [limit: limit] ++
        if max_typos, do: [max_typos: max_typos], else: []

    results = IndexServer.search(query, search_opts)

    results
    |> Enum.map(fn {doc_id, _score, _meta} -> doc_id end)
    |> hydrate_results()
  end

  defp hydrate_results(results) do
    {product_ids, shop_ids} =
      Enum.reduce(results, {[], []}, fn
        {:product, id}, {products, shops} ->
          {[id | products], shops}

        {:shop, id}, {products, shops} ->
          {products, [id | shops]}

        _, acc ->
          acc
      end)

    # Batch load products and shops
    products_map =
      if product_ids != [] do
        product_ids
        |> Catalogue.list_products_by_ids()
        |> Map.new(fn p -> {p.id, p} end)
      else
        %{}
      end

    shops_map =
      if shop_ids != [] do
        shop_ids
        |> Shops.list_shops_by_ids()
        |> Map.new(fn s -> {s.id, s} end)
      else
        %{}
      end

    # Build hydrated results maintaining order
    Enum.reduce(results, [], fn result, acc ->
      case result do
        {:product, id} ->
          case Map.get(products_map, id) do
            nil -> acc
            product -> [Map.put(product, :type, :product) | acc]
          end

        {:shop, id} ->
          case Map.get(shops_map, id) do
            nil -> acc
            shop -> [Map.put(shop, :type, :shop) | acc]
          end

        _ ->
          acc
      end
    end)
    |> Enum.reverse()
  end

  defp product_to_doc(product) do
    shop_name = if product.shop, do: product.shop.name, else: ""

    %{
      id: {:product, product.id},
      text: "#{product.name} #{shop_name}",
      field: :product_name,
      weight: 1.0
    }
  end

  defp shop_to_doc(shop) do
    %{
      id: {:shop, shop.id},
      text: shop.name,
      field: :shop_name,
      weight: 1.0
    }
  end
end
