defmodule SmartKioskCore.Search.Persistence do
  @moduledoc """
  Manages disk persistence of the search index using DETS (Disk ETS).

  This module provides functions for:
  - Saving the in-memory Trie to disk
  - Loading the Trie from disk on startup
  - Detecting index corruption via checksums
  - Periodic snapshot maintenance

  DETS is used for persistence because:
  - It's built into Erlang/OTP (no dependencies)
  - Supports large datasets (up to 2GB per table)
  - Provides ACID properties
  """

  require Logger

  alias SmartKioskCore.Search.Engine

  @typedoc "DETS table handle"
  @type table_handle :: :dets.table_name()

  @typedoc "Persistence result"
  @type result :: :ok | {:error, term()}

  @dets_table :search_index
  @checksum_key :__checksum__
  @data_key :__trie_data__

  # ── Public API ──────────────────────────────────────────────────────────────

  @doc """
  Opens the DETS table for reading/writing.

  Creates the file if it doesn't exist.
  """
  @spec open(String.t()) :: {:ok, table_handle()} | {:error, term()}
  def open(dets_path) do
    opts = [
      type: :set,
      file: to_charlist(dets_path),
      access: :read_write
    ]

    case :dets.open_file(@dets_table, opts) do
      {:ok, table} ->
        Logger.info("Search.Persistence: Opened DETS table at #{dets_path}")
        {:ok, table}

      {:error, reason} ->
        Logger.error("Search.Persistence: Failed to open DETS: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Closes the DETS table.
  """
  @spec close(table_handle()) :: :ok | {:error, term()}
  def close(table) do
    :dets.close(table)
  end

  @doc """
  Saves the Trie to disk with a checksum for corruption detection.

  ## Examples

      iex> trie = %{...}
      iex> SmartKioskCore.Search.Persistence.save(trie, "/path/to/index.dets")
      :ok
  """
  @spec save(Engine.trie(), String.t()) :: result()
  def save(trie, dets_path) do
    with {:ok, table} <- open(dets_path),
         serialized = :erlang.term_to_binary(trie),
         checksum = :erlang.md5(serialized),
         :ok <- :dets.insert(table, {@data_key, serialized}),
         :ok <- :dets.insert(table, {@checksum_key, checksum}),
         :ok <- :dets.sync(table),
         :ok <- close(table) do
      Logger.info("Search.Persistence: Saved index to DETS (#{byte_size(serialized)} bytes)")
      :ok
    else
      {:error, reason} ->
        Logger.error("Search.Persistence: Failed to save index: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Loads the Trie from disk and verifies checksum.

  Returns `{:ok, trie}` on success, `{:error, reason}` on failure.

  ## Examples

      iex> SmartKioskCore.Search.Persistence.load("/path/to/index.dets")
      {:ok, %{...}}
  """
  @spec load(String.t()) :: {:ok, Engine.trie()} | {:error, atom()}
  def load(dets_path) do
    with {:ok, table} <- open(dets_path),
         [{@data_key, serialized}] <- :dets.lookup(table, @data_key),
         [{@checksum_key, stored_checksum}] <- :dets.lookup(table, @checksum_key),
         computed_checksum = :erlang.md5(serialized),
         true <- computed_checksum == stored_checksum,
         trie = :erlang.binary_to_term(serialized),
         :ok <- close(table) do
      Logger.info("Search.Persistence: Loaded index from DETS")
      {:ok, trie}
    else
      [] ->
        Logger.warning("Search.Persistence: DETS file empty or missing data")
        {:error, :empty}

      false ->
        Logger.error("Search.Persistence: Checksum mismatch - index corrupted")
        close_dets()
        {:error, :corrupted}

      {:error, reason} ->
        Logger.error("Search.Persistence: Failed to load index: #{inspect(reason)}")
        {:error, reason}

      error ->
        Logger.error("Search.Persistence: Unexpected error: #{inspect(error)}")
        close_dets()
        {:error, :unknown}
    end
  end

  @doc """
  Checks if a valid DETS file exists at the given path.

  Performs a lightweight check without loading the full index.
  """
  @spec exists?(String.t()) :: boolean()
  def exists?(dets_path) do
    File.exists?(dets_path)
  end

  @doc """
  Deletes the DETS file (useful for forcing a rebuild).
  """
  @spec delete(String.t()) :: :ok | {:error, term()}
  def delete(dets_path) do
    close_dets()

    case File.rm(dets_path) do
      :ok ->
        Logger.info("Search.Persistence: Deleted DETS file at #{dets_path}")
        :ok

      {:error, :enoent} ->
        :ok

      {:error, reason} ->
        Logger.error("Search.Persistence: Failed to delete DETS: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Returns statistics about the DETS file.
  """
  @spec stats(String.t()) :: {:ok, map()} | {:error, term()}
  def stats(dets_path) do
    with {:ok, table} <- open(dets_path),
         info = :dets.info(table),
         :ok <- close(table) do
      {:ok, Map.new(info)}
    end
  end

  # ── Private Functions ───────────────────────────────────────────────────────

  defp close_dets do
    try do
      :dets.close(@dets_table)
    catch
      _, _ -> :ok
    end
  end
end
