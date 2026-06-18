# lib/smart_kiosk_core/schemas/report.ex
defmodule SmartKioskCore.Schemas.Report do
  use Ecto.Schema
  import Ecto.Changeset

  schema "reports" do
    field :period, :string
    field :starts_at, :utc_datetime
    field :ends_at, :utc_datetime
    field :total_orders, :integer
    field :total_revenue, :decimal
    field :total_items, :integer
    field :online_orders, :integer
    field :pos_orders, :integer
    field :status, :string, default: "pending"
    field :file_path, :string
    field :metadata, :map, default: %{}

    belongs_to :shop, SmartKioskCore.Schemas.Shop, type: :binary_id

    timestamps()
  end

  def changeset(report, attrs) do
    report
    |> cast(attrs, [
      :shop_id, :period, :starts_at, :ends_at,
      :total_orders, :total_revenue, :total_items,
      :online_orders, :pos_orders, :status, :file_path, :metadata
    ])
    |> validate_required([:shop_id, :period, :starts_at, :ends_at, :total_orders, :total_revenue])
  end
end
