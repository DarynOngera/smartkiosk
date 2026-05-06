defmodule SmartKiosk.Repo do
  use Ecto.Repo,
    otp_app: :smart_kiosk,
    adapter: Ecto.Adapters.Postgres
end
