defmodule SmartKioskCore.Repo.Migrations.AddDeliveryFeaturesLite do
  use Ecto.Migration

  def change do
    # 1. Add fields to riders
    alter table(:riders) do
      add :license_url, :string
      add :national_id_url, :string
      add :verification_status, :string, default: "pending"
    end

    # 2. No changes needed to delivery_zones.boundary as it is already JSONB

    # 3. No changes needed to shops/deliveries lat/lng as they are already floats
  end
end
