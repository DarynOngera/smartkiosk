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

  @typedoc "Search result with distance score"
  @type search_result :: {doc_id :: term(), distance :: non_neg_integer()}

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
        insert_token(acc_tree, token, doc.id, doc[:field] || :name, doc[:weight] || 1.0)
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
      insert_token(acc_tree, token, doc_id, field, weight)
    end)
  end

  @doc """
  Removes a document from the Trie by ID.
  """
  @spec remove(trie(), term()) :: trie()
  def remove(tree, doc_id) do
    remove_doc_id(tree, doc_id)
  end

  @doc """
  Searches the Trie with fuzzy matching.

  Returns a list of {doc_id, distance} tuples sorted by distance.

  ## Options

    * `:max_typos` - Maximum edit distance allowed (default: calculated from query length)
    * `:field_weights` - Map of field names to weight multipliers

  ## Examples

      iex> tree = SmartKioskCore.Search.Engine.build_index([%{id: 1, text: "iPhone"}])
      iex> SmartKioskCore.Search.Engine.search(tree, "iphoen")
      [{1, 1}]
  """
  @spec search(trie(), String.t(), keyword()) :: [search_result()]
  def search(tree, query, opts \\ []) do
    query_tokens = tokenize(query)
    max_typos = opts[:max_typos] || calculate_typo_budget(query)

    results =
      Enum.reduce(query_tokens, %{}, fn token, acc ->
        matches = fuzzy_search_trie(tree, token, max_typos)

        Enum.reduce(matches, acc, fn {doc_id, distance}, inner_acc ->
          Map.update(inner_acc, doc_id, distance, &min(&1, distance))
        end)
      end)

    results
    |> Enum.sort_by(fn {_doc_id, distance} -> distance end)
    |> Enum.map(fn {doc_id, distance} -> {doc_id, distance} end)
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
    |> String.replace(~r/[^\w\s]/u, " ")
    |> String.split(~r/\s+/, trim: true)
    |> Enum.reject(&(&1 == ""))
  end

  def tokenize(_), do: []

  # ── Private Functions ───────────────────────────────────────────────────────

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
  defp fuzzy_search_trie(tree, target_word, max_typos) do
    target_len = String.length(target_word)
    initial_row = Enum.to_list(0..target_len)

    traverse_trie(tree, "", initial_row, target_word, max_typos, %{})
  end

  # DFS traversal with Levenshtein distance calculation and pruning
  defp traverse_trie(node, _current_prefix, previous_row, target, max_typos, matches)
       when is_map(node) do
    current_distance = List.last(previous_row)

    matches =
      if node[:terminal] == true and current_distance <= max_typos do
        ids = node[:ids] || MapSet.new()

        Enum.reduce(ids, matches, fn doc_id, acc ->
          Map.update(acc, doc_id, current_distance, &min(&1, current_distance))
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

        if Enum.min(next_row) <= max_typos do
          traverse_trie(sub_node, "", next_row, target, max_typos, acc)
        else
          acc
        end
    end)
  end

  # Catch-all for non-map nodes (nil, empty, etc.)
  defp traverse_trie(_node, _current_prefix, _previous_row, _target, _max_typos, matches) do
    matches
  end

  # Compute next row in Levenshtein matrix (space-optimized)
  defp compute_next_levenshtein_row(previous_row, char, target) do
    target_chars = String.graphemes(target)
    first_cell = hd(previous_row) + 1

    {_, new_row} =
      target_chars
      |> Enum.with_index()
      |> Enum.reduce({first_cell, [first_cell]}, fn {target_char, index}, {prev_cell, row_acc} ->
        substitution_cost = if char == target_char, do: 0, else: 1

        deletion = Enum.at(previous_row, index + 1, 0) + 1
        insertion = prev_cell + 1
        substitution = Enum.at(previous_row, index, 0) + substitution_cost

        current_cell = Enum.min([deletion, insertion, substitution])
        {current_cell, row_acc ++ [current_cell]}
      end)

    new_row
  end
end
