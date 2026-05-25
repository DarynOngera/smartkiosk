defmodule SmartKioskCore.Workers.RecommendationWorker do
  use Oban.Worker, queue: :default

  alias SmartKioskCore.Recommendations
  require Logger

  @impl Oban.Worker
  def perform(_job) do
    Logger.info("RecommendationWorker: starting refresh")

    case Recommendations.refresh_recommendations() do
      {:ok, _} ->
        Logger.info("RecommendationWorker: refresh completed successfully")
        :ok

      {:error, reason} ->
        Logger.error("RecommendationWorker: refresh failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
