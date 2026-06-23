defmodule SmartKioskCore.Repo.Migrations.CreateReports do
  use Ecto.Migration


def change do
  create table(:reports) do
    add :shop_id, references(:shops, on_delete: :delete_all, type: :binary_id), null: false
    add :period, :string, null: false          # "daily", "weekly", "monthly"
    add :starts_at, :utc_datetime, null: false
    add :ends_at, :utc_datetime, null: false
    add :total_orders, :integer, null: false
    add :total_revenue, :decimal, null: false
    add :total_items, :integer, null: false
    add :online_orders, :integer
    add :pos_orders, :integer
    add :status, :string, default: "pending"   # "pending", "generating", "ready", "failed"
    add :file_path, :string                     # path to PDF if generated
    add :metadata, :map, default: %{}
    timestamps()
  end

  create index(:reports, [:shop_id])
end
end
