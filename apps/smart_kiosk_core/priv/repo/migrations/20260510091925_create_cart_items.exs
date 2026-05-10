defmodule SmartKioskCore.Repo.Migrations.CreateCartItems do
  use Ecto.Migration

  def change do
    create table(:cart_items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :quantity, :integer, null: false, default: 1
      add :unit_price, :decimal, null: false
      add :line_total, :decimal, null: false
      add :product_name, :string, null: false
      add :session_id, :string
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id)
      add :shop_id, references(:shops, on_delete: :delete_all, type: :binary_id), null: false
      add :product_id, references(:products, on_delete: :delete_all, type: :binary_id), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:cart_items, [:user_id])
    create index(:cart_items, [:session_id])
    create index(:cart_items, [:shop_id])
    create index(:cart_items, [:product_id])
    create index(:cart_items, [:user_id, :session_id])
  end
end
