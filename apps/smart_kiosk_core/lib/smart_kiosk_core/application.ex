defmodule SmartKioskCore.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SmartKioskCore.Repo,
      {Phoenix.PubSub, name: SmartKiosk.PubSub},
      {Oban, Application.fetch_env!(:smart_kiosk_core, Oban)},
      # Search engine processes
      SmartKioskCore.Search.BatchQueue,
      SmartKioskCore.Search.IndexServer,
      SmartKioskCore.Search.MetricsAggregator
    ]

    # Attach search telemetry handlers
    SmartKioskCore.Search.Metrics.attach_handlers()

    opts = [strategy: :one_for_one, name: SmartKioskCore.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
