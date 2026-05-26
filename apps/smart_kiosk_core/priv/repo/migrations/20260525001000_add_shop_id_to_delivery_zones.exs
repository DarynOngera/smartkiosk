defmodule SmartKioskCore.Repo.Migrations.AddShopIdToDeliveryZones do
  use Ecto.Migration

  def change do
    alter table(:delivery_zones) do
      add :shop_id, references(:shops, type: :uuid, on_delete: :nilify_all)
    end

    create index(:delivery_zones, [:shop_id])
  end
end
