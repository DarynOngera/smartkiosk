defmodule SmartKiosk.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SmartKiosk.Repo,
      {DNSCluster, query: Application.get_env(:smart_kiosk, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: SmartKiosk.PubSub}
      # Start a worker by calling: SmartKiosk.Worker.start_link(arg)
      # {SmartKiosk.Worker, arg}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: SmartKiosk.Supervisor)
  end
end
