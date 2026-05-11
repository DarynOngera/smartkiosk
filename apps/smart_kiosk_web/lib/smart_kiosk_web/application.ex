defmodule SmartKioskWeb.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SmartKioskWeb.Telemetry,
      {Finch, name: SmartKiosk.Finch},
      SmartKioskWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: SmartKioskWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    SmartKioskWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
