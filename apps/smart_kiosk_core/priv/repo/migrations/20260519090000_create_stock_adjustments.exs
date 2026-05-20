defmodule SmartKioskCore.Repo.Migrations.CreateStockAdjustments do
  use Ecto.Migration

  def change do
    create table(:stock_adjustments, primary_key: false) do
      add(:id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()"))

      add(:shop_id, references(:shops, type: :uuid, on_delete: :delete_all), null: false)
      add(:product_id, references(:products, type: :uuid, on_delete: :delete_all), null: false)
      add(:user_id, references(:users, type: :uuid, on_delete: :nilify_all))

      add(:qty_delta, :integer, null: false)
      add(:reason, :string, null: false)
      add(:notes, :text)

      timestamps(type: :utc_datetime)
    end

    create(index(:stock_adjustments, [:shop_id]))
    create(index(:stock_adjustments, [:product_id]))
    create(index(:stock_adjustments, [:user_id]))
    create(index(:stock_adjustments, [:inserted_at]))
  end
end
