defmodule SmartKioskCore.Repo do
  use Ecto.Repo,
    otp_app: :smart_kiosk_core,
    adapter: Ecto.Adapters.Postgres
end
