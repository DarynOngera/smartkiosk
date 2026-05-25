defmodule SmartKioskCore.Search.Query do
  @moduledoc """
  Handles search query execution and result ranking.

  This module provides the high-level search interface that:
  1. Tokenizes and normalizes queries
  2. Determines typo budgets based on query length
  3. Executes fuzzy search across the Trie
  4. Ranks results by relevance using multiple factors
  5. Returns sorted document IDs

  Ranking Algorithm:
  1. Edit distance (lower is better)
  2. Prefix match bonus (exact prefix matches rank higher)
  3. Field weight (title matches rank above description)
  """

  require Logger

  alias SmartKioskCore.Search.Engine

  @typedoc "Search options"
  @type options :: [
          max_typos: non_neg_integer(),
          limit: pos_integer(),
          field_weights: map()
        ]

  @typedoc "Ranked search result"
  @type ranked_result :: {
          doc_id :: term(),
          score :: float(),
          metadata :: map()
        }

  @default_limit 50
  @default_field_weights %{
    product_name: 1.0,
    shop_name: 1.0,
    name: 1.0,
    description: 0.3
  }

  # ── Public API ──────────────────────────────────────────────────────────────

  @doc """
  Executes a search query against the Trie and returns ranked results.

  ## Options

    * `:max_typos` - Override default typo budget calculation
    * `:limit` - Maximum number of results (default: 50)
    * `:field_weights` - Custom field weight mapping

  ## Examples

      iex> tree = SmartKioskCore.Search.Engine.build_index([%{id: 1, text: "iPhone"}])
      iex> SmartKioskCore.Search.Query.execute(tree, "iphoen")
      [{1, 0.5, %{distance: 1, field: :name}}]
  """
  @spec execute(Engine.trie(), String.t(), options()) :: [ranked_result()]
  def execute(tree, query, opts \\ []) do
    start_time = System.monotonic_time(:microsecond)

    if query == nil or String.trim(query) == "" do
      log_metrics(0, 0, start_time)
      []
    else
      results = do_execute(tree, query, opts)
      log_metrics(length(results), 1, start_time)
      results
    end
  end

  @doc """
  Executes a multi-token search with AND logic.

  All tokens must match (within typo budget) for a document to be included.

  ## Examples

      iex> tree = SmartKioskCore.Search.Engine.build_index([%{id: 1, text: "iPhone 15"}])
      iex> SmartKioskCore.Search.Query.execute_and(tree, "iphone 15")
      [{1, ...}]
  """
  @spec execute_and(Engine.trie(), String.t(), options()) :: [ranked_result()]
  def execute_and(tree, query, opts \\ []) do
    start_time = System.monotonic_time(:microsecond)

    tokens = Engine.tokenize(query)

    if tokens == [] do
      log_metrics(0, 0, start_time)
      []
    else
      results = do_execute_and(tree, tokens, opts)
      log_metrics(length(results), length(tokens), start_time)
      results
    end
  end

  @doc """
  Filters results to only include exact prefix matches (no typos).

  Useful for "search-as-you-type" instant suggestions.
  """
  @spec prefix_search(Engine.trie(), String.t(), options()) :: [ranked_result()]
  def prefix_search(tree, query, opts \\ []) do
    opts = Keyword.put(opts, :max_typos, 0)
    execute(tree, query, opts)
  end

  @doc """
  Calculates the composite relevance score for a match.

  Lower scores rank higher (0.0 is perfect match).

  ## Scoring Formula

      score = (distance * 0.5) + (prefix_bonus * 0.3) + (field_penalty * 0.2)

  Where:
    * distance: Levenshtein edit distance
    * prefix_bonus: 0.0 for exact prefix, 0.5 for fuzzy
    * field_penalty: (1.0 - field_weight)
  """
  @spec calculate_score(non_neg_integer(), atom(), float()) :: float()
  def calculate_score(distance, _field, field_weight) do
    distance_component = distance * 0.5

    prefix_bonus =
      if distance == 0 do
        0.0
      else
        0.5
      end

    field_penalty = (1.0 - field_weight) * 0.2

    distance_component + prefix_bonus + field_penalty
  end

  # ── Private Functions ───────────────────────────────────────────────────────

  defp do_execute(tree, query, opts) do
    max_typos = opts[:max_typos] || Engine.calculate_typo_budget(query)
    limit = opts[:limit] || @default_limit
    field_weights = opts[:field_weights] || @default_field_weights

    # Engine.search now returns {doc_id, distance, field} tuples
    results = Engine.search(tree, query, max_typos: max_typos)

    results
    |> Enum.map(fn {doc_id, distance, field} -> {doc_id, distance, %{field: field}} end)
    |> rank_results(field_weights)
    |> Enum.take(limit)
  end

  defp do_execute_and(tree, tokens, opts) do
    max_typos = opts[:max_typos]
    limit = opts[:limit] || @default_limit
    field_weights = opts[:field_weights] || @default_field_weights

    # Get results for each token
    # Engine.search returns {doc_id, distance, field} tuples
    token_results =
      Enum.map(tokens, fn token ->
        typos = max_typos || Engine.calculate_typo_budget(token)
        Engine.search(tree, token, max_typos: typos)
      end)

    # Find intersection of all token results
    case token_results do
      [] ->
        []

      [first | rest] ->
        # Convert to map for intersection logic: doc_id => {distance, field}
        first_map = Map.new(first, fn {id, dist, field} -> {id, {dist, field}} end)

        intersection =
          Enum.reduce(rest, first_map, fn results, acc ->
            result_map = Map.new(results, fn {id, dist, field} -> {id, {dist, field}} end)

            Map.filter(acc, fn {id, _} ->
              Map.has_key?(result_map, id)
            end)
          end)

        intersection
        |> Enum.map(fn {doc_id, {distance, field}} ->
          {doc_id, distance, %{field: field}}
        end)
        |> rank_results(field_weights)
        |> Enum.take(limit)
    end
  end

  defp rank_results(results, field_weights) do
    Enum.map(results, fn {doc_id, distance, metadata} ->
      # Field now comes from the search result tuple (extracted from terminal node)
      field = metadata[:field] || :name
      field_weight = Map.get(field_weights, field, 1.0)

      score = calculate_score(distance, field, field_weight)

      metadata =
        Map.merge(metadata, %{
          distance: distance,
          field: field,
          field_weight: field_weight
        })

      {doc_id, score, metadata}
    end)
    |> Enum.sort_by(fn {_id, score, _meta} -> score end)
  end

  defp log_metrics(result_count, token_count, start_time) do
    duration_ms = (System.monotonic_time(:microsecond) - start_time) / 1000

    :telemetry.execute(
      [:smart_kiosk, :search, :query],
      %{duration_ms: duration_ms, results: result_count},
      %{tokens: token_count}
    )

    if duration_ms > 10 do
      Logger.warning("Search.Query: Slow query detected (#{duration_ms}ms)")
    end
  end
end
