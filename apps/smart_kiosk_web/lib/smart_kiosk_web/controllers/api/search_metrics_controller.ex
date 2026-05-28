defmodule SmartKioskWeb.Api.SearchMetricsController do
  @moduledoc """
  Public API endpoint for search performance metrics.

  Returns JSON with query latency percentiles, index health, and
  search relevance statistics. No authentication required.

  ## Endpoint

      GET /api/search/metrics

  ## Response Format

      {
        "query_latency": {
          "p50_ms": 12.4,
          "p95_ms": 45.2,
          "p99_ms": 120.8,
          "min_ms": 2.1,
          "max_ms": 340.5,
          "count_1m": 342,
          "count_5m": 1240
        },
        "index": {
          "document_count": 150101,
          "memory_bytes": 25165824,
          "last_rebuild_at": "2026-05-28T09:32:53Z",
          "freshness_seconds": 1847,
          "build_duration_ms": 15420
        },
        "relevance": {
          "avg_results_per_query": 8.3,
          "zero_result_rate": 0.02,
          "total_queries": 5240
        }
      }
  """

  use SmartKioskWeb, :controller

  alias SmartKioskCore.Search.MetricsAggregator

  @doc """
  Returns current search metrics as JSON.
  """
  def index(conn, _params) do
    stats = MetricsAggregator.stats()
    json(conn, stats)
  end
end
