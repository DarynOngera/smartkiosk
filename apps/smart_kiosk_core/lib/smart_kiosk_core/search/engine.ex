defmodule SmartKioskCore.Search.Engine do
  @moduledoc """
  Core fuzzy search engine implementing a Trie (prefix tree) data structure
  with Levenshtein distance calculation for typo tolerance.

  This module provides pure functions for building and querying the search index.
  State management (ETS/DETS) is handled by IndexServer.
  """

  @typedoc "A node in the Trie containing document IDs and child branches"
  @type trie_node :: %{
          optional(:ids) => MapSet.t(),
          optional(:terminal) => boolean(),
          optional(:field_weights) => map(),
          optional(integer()) => trie_node()
        }

  @typedoc "The root of the Trie structure"
  @type trie :: trie_node()

  @typedoc "A document to be indexed"
  @type document :: %{
          required(:id) => term(),
          required(:text) => String.t(),
          optional(:field) => atom(),
          optional(:weight) => float()
        }

  # ── Public API ──────────────────────────────────────────────────────────────

  @doc """
  Builds a search index from a list of documents.

  ## Examples

      iex> docs = [%{id: 1, text: "iPhone 15", field: :name, weight: 1.0}]
      iex> SmartKioskCore.Search.Engine.build_index(docs)
      %{...}
  """
  @spec build_index([document()]) :: trie()
  def build_index(documents) do
    Enum.reduce(documents, %{}, fn doc, tree ->
      doc.text
      |> tokenize()
      |> Enum.reduce(tree, fn token, acc_tree ->
        insert_token_with_prefixes(
          acc_tree,
          token,
          doc.id,
          doc[:field] || :name,
          doc[:weight] || 1.0
        )
      end)
    end)
  end

  @doc """
  Inserts a single document into an existing Trie.

  ## Examples

      iex> tree = SmartKioskCore.Search.Engine.insert(%{}, "iphone", 1, :name, 1.0)
      iex> tree[?i][?p][?h][?o][?n][?e][:terminal]
      true
  """
  @spec insert(trie(), String.t(), term(), atom(), float()) :: trie()
  def insert(tree, text, doc_id, field \\ :name, weight \\ 1.0) do
    text
    |> tokenize()
    |> Enum.reduce(tree, fn token, acc_tree ->
      insert_token_with_prefixes(acc_tree, token, doc_id, field, weight)
    end)
  end

  @doc """
  Removes a document from the Trie by ID.
  """
  @spec remove(trie(), term()) :: trie()
  def remove(tree, doc_id) do
    remove_doc_id(tree, doc_id)
  end

  @typedoc "Search result with distance and field information"
  @type search_result :: {doc_id :: term(), distance :: non_neg_integer(), field :: atom()}

  @doc """
  Searches the Trie with fuzzy matching.

  Returns a list of {doc_id, distance, field} tuples sorted by distance.

  ## Options

    * `:max_typos` - Override default typo budget calculation

  ## Examples

      iex> tree = SmartKioskCore.Search.Engine.build_index([%{id: 1, text: "iPhone", field: :name}])
      iex> SmartKioskCore.Search.Engine.search(tree, "iphoen")
      [{1, 1, :name}]
  """
  @spec search(trie(), String.t(), keyword()) :: [search_result()]
  def search(tree, query, opts \\ []) do
    query_tokens = tokenize(query)
    max_typos = opts[:max_typos] || calculate_typo_budget(query)

    # fuzzy_search_trie now returns %{doc_id => {distance, field}}
    results =
      Enum.reduce(query_tokens, %{}, fn token, acc ->
        matches = fuzzy_search_trie(tree, token, max_typos)

        # matches is now %{doc_id => {distance, field}}
        Enum.reduce(matches, acc, fn {doc_id, {distance, field}}, inner_acc ->
          Map.update(inner_acc, doc_id, {distance, field}, fn {existing_dist, existing_field} ->
            if distance < existing_dist do
              {distance, field}
            else
              {existing_dist, existing_field}
            end
          end)
        end)
      end)

    results
    |> Enum.sort_by(fn {_doc_id, {distance, _field}} -> distance end)
    |> Enum.map(fn {doc_id, {distance, field}} -> {doc_id, distance, field} end)
  end

  @doc """
  Returns all document IDs in the Trie.
  """
  @spec all_doc_ids(trie()) :: MapSet.t()
  def all_doc_ids(tree) do
    collect_all_ids(tree, MapSet.new())
  end

  @doc """
  Calculates the typo budget based on word length.

  ## Rules

    * < 4 characters: 0 typos
    * 4-8 characters: 1 typo
    * > 8 characters: 2 typos
  """
  @spec calculate_typo_budget(String.t()) :: non_neg_integer()
  def calculate_typo_budget(text) do
    len = String.length(text)

    cond do
      len < 4 -> 0
      len <= 8 -> 1
      true -> 2
    end
  end

  @doc """
  Normalizes and tokenizes text into searchable terms.

  ## Examples

      iex> SmartKioskCore.Search.Engine.tokenize("iPhone 15 Pro Max!")
      ["iphone", "15", "pro", "max"]
  """
  @spec tokenize(String.t()) :: [String.t()]
  def tokenize(text) when is_binary(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^\p{L}\p{N}\s]/u, " ")
    |> String.split(~r/\s+/, trim: true)
    |> Enum.reject(&(&1 == ""))
  end

  def tokenize(_), do: []

  # ── Private Functions ───────────────────────────────────────────────────────

  # Insert a token with all its prefixes into the Trie
  # This enables prefix matching (e.g., "iph" matches "iphone")
  defp insert_token_with_prefixes(tree, token, doc_id, field, weight) do
    token_length = String.length(token)

    # Generate all prefixes from length 1 to full token length
    # e.g., "iphone" -> ["i", "ip", "iph", "ipho", "iphon", "iphone"]
    prefixes =
      1..token_length
      |> Enum.map(&String.slice(token, 0, &1))

    # Insert each prefix into the tree
    Enum.reduce(prefixes, tree, fn prefix, acc_tree ->
      insert_token(acc_tree, prefix, doc_id, field, weight)
    end)
  end

  # Recursively insert a token into the Trie
  defp insert_token(tree, "", doc_id, field, weight) do
    tree
    |> Map.update(:ids, MapSet.new([doc_id]), &MapSet.put(&1, doc_id))
    |> Map.put(:terminal, true)
    |> Map.update(:field_weights, %{doc_id => %{field => weight}}, fn existing ->
      Map.update(existing, doc_id, %{field => weight}, &Map.put(&1, field, weight))
    end)
  end

  defp insert_token(tree, <<char::utf8, rest::binary>>, doc_id, field, weight) do
    tree = Map.update(tree, :ids, MapSet.new([doc_id]), &MapSet.put(&1, doc_id))

    subtree = Map.get(tree, char, %{})
    updated_subtree = insert_token(subtree, rest, doc_id, field, weight)

    Map.put(tree, char, updated_subtree)
  end

  # Remove a doc_id from the entire tree
  defp remove_doc_id(tree, doc_id) do
    tree
    |> Map.update(:ids, MapSet.new(), &MapSet.delete(&1, doc_id))
    |> maybe_remove_terminal(doc_id)
    |> remove_from_children(doc_id)
    |> prune_empty_branches()
  end

  defp maybe_remove_terminal(tree, doc_id) do
    case tree[:field_weights] do
      %{^doc_id => _} ->
        new_weights = Map.delete(tree[:field_weights], doc_id)

        if map_size(new_weights) == 0 do
          Map.delete(tree, :terminal)
        else
          Map.put(tree, :field_weights, new_weights)
        end

      _ ->
        tree
    end
  end

  defp remove_from_children(tree, doc_id) do
    Enum.reduce(tree, tree, fn
      {:ids, _}, acc ->
        acc

      {:terminal, _}, acc ->
        acc

      {:field_weights, _}, acc ->
        acc

      {char, subtree}, acc ->
        updated = remove_doc_id(subtree, doc_id)
        Map.put(acc, char, updated)
    end)
  end

  defp prune_empty_branches(tree) do
    pruned =
      Enum.reduce(tree, tree, fn
        {:ids, _}, acc ->
          acc

        {:terminal, _}, acc ->
          acc

        {:field_weights, _}, acc ->
          acc

        {char, subtree}, acc ->
          if empty_branch?(subtree) do
            Map.delete(acc, char)
          else
            acc
          end
      end)

    if empty_branch?(pruned) do
      %{}
    else
      pruned
    end
  end

  defp empty_branch?(tree) do
    keys = Map.keys(tree) -- [:ids, :terminal, :field_weights]
    map_size(tree) == 0 or (keys == [] and MapSet.size(tree[:ids] || MapSet.new()) == 0)
  end

  # Collect all unique doc_ids from the tree
  defp collect_all_ids(tree, acc) do
    acc = MapSet.union(acc, tree[:ids] || MapSet.new())

    Enum.reduce(tree, acc, fn
      {:ids, _}, acc -> acc
      {:terminal, _}, acc -> acc
      {:field_weights, _}, acc -> acc
      {_char, subtree}, acc -> collect_all_ids(subtree, acc)
    end)
  end

  # Initialize fuzzy search on the Trie
  # Using tuple for O(1) row access instead of list
  defp fuzzy_search_trie(tree, target_word, max_typos) do
    target_len = String.length(target_word)
    # Convert to tuple for O(1) access via elem/2
    initial_row = List.to_tuple(Enum.to_list(0..target_len))

    traverse_trie(tree, "", initial_row, target_word, max_typos, %{}, 0)
  end

  # DFS traversal with Levenshtein distance calculation and pruning
  # Returns a map of doc_id => {distance, field}
  # previous_row is now a tuple for O(1) access
  # depth tracks how many characters we've traversed in the trie
  defp traverse_trie(node, _current_prefix, previous_row, target, max_typos, matches, depth)
       when is_map(node) do
    target_len = tuple_size(previous_row) - 1

    # For prefix matching: we want the query to match the BEGINNING of the trie path.
    # 
    # In Levenshtein terms: we look at row[target_len], which represents the cost
    # to match the entire query against the current trie path.
    #
    # For "kili" matching "kilimani":
    #   - row[4] (at column matching "kili") should be 0 for a perfect prefix match
    #   - row[4] would be > 0 if "kili" doesn't match the start of the word
    #
    # Additionally, we require that the trie path is at least as long as the query
    # (depth >= target_len), otherwise it can't be a valid prefix match.
    standard_distance = elem(previous_row, target_len)

    # For prefix matching: when depth >= target_len, check if query matches prefix
    # by looking at the cell where the full query would align with the trie path
    # The trie path is long enough - check exact alignment at target_len
    prefix_distance =
      elem(previous_row, target_len)

    # Use the better distance, but with a penalty for non-prefix matches
    current_distance = min(standard_distance, prefix_distance)

    matches =
      if node[:terminal] == true and current_distance <= max_typos do
        ids = node[:ids] || MapSet.new()
        field_weights = node[:field_weights] || %{}

        Enum.reduce(ids, matches, fn doc_id, acc ->
          # Get the primary field for this doc_id from field_weights
          field = get_primary_field_from_weights(field_weights, doc_id)

          Map.update(acc, doc_id, {current_distance, field}, fn {existing_dist, existing_field} ->
            if current_distance < existing_dist do
              {current_distance, field}
            else
              {existing_dist, existing_field}
            end
          end)
        end)
      else
        matches
      end

    Enum.reduce(node, matches, fn
      {:ids, _}, acc ->
        acc

      {:terminal, _}, acc ->
        acc

      {:field_weights, _}, acc ->
        acc

      {char_code, sub_node}, acc when is_integer(char_code) ->
        char_str = <<char_code::utf8>>
        next_row = compute_next_levenshtein_row(previous_row, char_str, target)

        # next_row is a tuple, use tuple_size and elem to find min
        if min_in_tuple(next_row) <= max_typos do
          traverse_trie(sub_node, "", next_row, target, max_typos, acc, depth + 1)
        else
          acc
        end
    end)
  end

  # Catch-all for non-map nodes (nil, empty, etc.)
  defp traverse_trie(_node, _current_prefix, _previous_row, _target, _max_typos, matches, _depth) do
    matches
  end

  # Extract primary field from field_weights map for a given doc_id
  defp get_primary_field_from_weights(field_weights, doc_id) do
    case Map.get(field_weights, doc_id) do
      nil ->
        :name

      weights when is_map(weights) ->
        weights |> Map.keys() |> List.first() || :name

      _ ->
        :name
    end
  end

  # Find minimum value in a tuple (helper for pruning check)
  defp min_in_tuple(tuple) do
    size = tuple_size(tuple)
    do_min_in_tuple(tuple, size - 1, elem(tuple, 0))
  end

  defp do_min_in_tuple(_tuple, -1, min_val), do: min_val

  defp do_min_in_tuple(tuple, index, min_val) do
    val = elem(tuple, index)
    new_min = if val < min_val, do: val, else: min_val
    do_min_in_tuple(tuple, index - 1, new_min)
  end

  # Compute next row in Levenshtein matrix (space-optimized)
  # previous_row is a tuple for O(1) access via elem/2
  defp compute_next_levenshtein_row(previous_row, char, target) do
    target_chars = String.graphemes(target)
    # previous_row is a tuple, first element is at index 0
    first_cell = elem(previous_row, 0) + 1

    {_, new_row_list} =
      target_chars
      |> Enum.with_index()
      |> Enum.reduce({first_cell, [first_cell]}, fn {target_char, index}, {prev_cell, row_acc} ->
        substitution_cost = if char == target_char, do: 0, else: 1

        # Use elem/2 for O(1) tuple access instead of Enum.at on list
        deletion = elem(previous_row, index + 1) + 1
        insertion = prev_cell + 1
        substitution = elem(previous_row, index) + substitution_cost

        current_cell = Enum.min([deletion, insertion, substitution])
        {current_cell, [current_cell | row_acc]}
      end)

    # Reverse to maintain correct order and convert to tuple
    new_row_list |> Enum.reverse() |> List.to_tuple()
  end
end
