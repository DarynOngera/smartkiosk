defmodule SmartKioskCore.Repo.Migrations.AddDeliveryTypeToOrders do
  use Ecto.Migration

  def change do
    alter table(:orders) do
      add :delivery_type, :string, default: "delivery", null: false
    end
  end
end
