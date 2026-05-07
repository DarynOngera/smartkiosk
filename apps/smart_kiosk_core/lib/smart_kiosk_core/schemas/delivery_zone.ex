defmodule SmartKioskCore.Schemas.DeliveryZone do
  @moduledoc """
  Geographic delivery zone. The boundary is a PostGIS geometry stored
  as a GeoJSON-compatible map in JSONB for now (Phase 1 simplification).
  Phase 3 will promote this to a proper PostGIS geometry column.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "delivery_zones" do
    field :name,      :string
    field :boundary,  :map    # GeoJSON Polygon
    field :base_fee,  :decimal
    field :active,    :boolean, default: true

    has_many :deliveries, SmartKioskCore.Schemas.Delivery

    timestamps(type: :utc_datetime)
  end

  def changeset(zone, attrs) do
    zone
    |> cast(attrs, [:name, :boundary, :base_fee, :active])
    |> validate_required([:name, :base_fee])
    |> validate_number(:base_fee, greater_than_or_equal_to: 0)
  end
end
