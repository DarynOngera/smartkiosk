defmodule SmartKioskCore.Search.Metrics do
  @moduledoc """
  Telemetry and metrics collection for the search engine.

  This module attaches telemetry handlers to track:
  - Query latency and throughput
  - Index size and memory usage
  - Batch processing statistics
  - Cache hit/miss rates (if applicable)

  Metrics are reported via the `:telemetry` library and can be consumed by
  external monitoring systems (Prometheus, StatsD, etc.).
  """

  require Logger

  # ── Public API ──────────────────────────────────────────────────────────────

  @doc """
  Attaches telemetry handlers for search metrics.

  Call this during application startup.
  """
  @spec attach_handlers() :: :ok
  def attach_handlers do
    events = [
      [:smart_kiosk, :search, :query],
      [:smart_kiosk, :search, :index, :update],
      [:smart_kiosk, :search, :index, :rebuild],
      [:smart_kiosk, :search, :persistence, :save],
      [:smart_kiosk, :search, :persistence, :load]
    ]

    :telemetry.attach_many(
      "search-metrics-handler",
      events,
      &__MODULE__.handle_event/4,
      nil
    )

    Logger.info("Search.Metrics: Telemetry handlers attached")
  end

  @doc """
  Handles telemetry events and logs metrics.

  This function is called automatically by :telemetry.
  """
  @spec handle_event(list(atom()), map(), map(), term()) :: :ok
  def handle_event([:smart_kiosk, :search, :query], measurements, metadata, _config) do
    duration_ms = measurements.duration_ms
    result_count = measurements.results
    token_count = metadata.tokens

    # Log slow queries
    if duration_ms > 10 do
      Logger.warning(
        "Search.Metrics: Slow query - #{duration_ms}ms, " <>
          "#{result_count} results, #{token_count} tokens"
      )
    end

    # Could also report to external metrics system here
    :ok
  end

  def handle_event([:smart_kiosk, :search, :index, :update], measurements, _metadata, _config) do
    Logger.debug(
      "Search.Metrics: Index updated - " <>
        "#{measurements.changes} changes in #{measurements.duration_ms}ms"
    )

    :ok
  end

  def handle_event([:smart_kiosk, :search, :index, :rebuild], measurements, _metadata, _config) do
    Logger.info(
      "Search.Metrics: Index rebuilt - " <>
        "#{measurements.documents} documents in #{measurements.duration_ms}ms"
    )

    :ok
  end

  def handle_event([:smart_kiosk, :search, :persistence, :save], measurements, _metadata, _config) do
    Logger.debug(
      "Search.Metrics: Index saved - " <>
        "#{measurements.bytes} bytes in #{measurements.duration_ms}ms"
    )

    :ok
  end

  def handle_event([:smart_kiosk, :search, :persistence, :load], measurements, metadata, _config) do
    source = metadata[:source] || :unknown

    Logger.info(
      "Search.Metrics: Index loaded from #{source} - " <>
        "#{measurements.bytes} bytes in #{measurements.duration_ms}ms"
    )

    :ok
  end

  @doc """
  Records custom metric.
  """
  @spec record(atom(), map(), map()) :: :ok
  def record(event_name, measurements, metadata \\ %{}) do
    :telemetry.execute(
      [:smart_kiosk, :search | List.wrap(event_name)],
      measurements,
      metadata
    )
  end

  @doc """
  Returns current search statistics.

  ## Examples

      iex> SmartKioskCore.Search.Metrics.stats()
      %{
        query_count: 1234,
        avg_latency_ms: 2.5,
        index_size_bytes: 1024000
      }
  """
  @spec stats() :: map()
  def stats do
    # In a real implementation, this would aggregate from a metrics store
    # For now, return a placeholder structure
    %{
      query_count: nil,
      avg_latency_ms: nil,
      index_size_bytes: nil,
      last_rebuild: nil
    }
  end
end
