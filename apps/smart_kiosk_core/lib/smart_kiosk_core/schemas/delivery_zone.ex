defmodule SmartKioskCore.Schemas.DeliveryZone do
  @moduledoc """
  Geographic delivery zone.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "delivery_zones" do
    field(:name, :string)
    # GeoJSON Polygon
    field(:boundary, :map)
    field(:base_fee, :decimal)
    field(:active, :boolean, default: true)

    has_many(:deliveries, SmartKioskCore.Schemas.Delivery)

    timestamps(type: :utc_datetime)
  end

  def changeset(zone, attrs) do
    zone
    |> cast(attrs, [:name, :boundary, :base_fee, :active])
    |> validate_required([:name, :base_fee])
    |> validate_number(:base_fee, greater_than_or_equal_to: 0)
  end
end
