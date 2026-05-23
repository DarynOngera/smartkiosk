defmodule SmartKioskCore.Schemas.Delivery do
  @moduledoc """
  A delivery task linked to an order. Assigned to a rider within a zone.

  Status: :pending_pickup | :picked_up | :in_transit | :delivered | :failed
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(pending_pickup picked_up in_transit delivered failed)a

  schema "deliveries" do
    field(:status, Ecto.Enum, values: @statuses, default: :pending_pickup)
    field(:pickup_lat, :float)
    field(:pickup_lng, :float)
    field(:dropoff_lat, :float)
    field(:dropoff_lng, :float)
    field(:distance_km, :decimal)
    field(:notes, :string)
    field(:picked_up_at, :utc_datetime)
    field(:delivered_at, :utc_datetime)

    belongs_to(:order, SmartKioskCore.Schemas.Order)
    belongs_to(:rider, SmartKioskCore.Schemas.Rider)
    belongs_to(:delivery_zone, SmartKioskCore.Schemas.DeliveryZone)

    timestamps(type: :utc_datetime)
  end

  @required ~w(order_id pickup_lat pickup_lng dropoff_lat dropoff_lng)a
  @optional ~w(rider_id delivery_zone_id status distance_km notes picked_up_at delivered_at)a

  def changeset(delivery, attrs) do
    delivery
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> foreign_key_constraint(:order_id)
    |> foreign_key_constraint(:rider_id)
    |> foreign_key_constraint(:delivery_zone_id)
  end

  def status_changeset(delivery, :picked_up) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    change(delivery, status: :picked_up, picked_up_at: now)
  end

  def status_changeset(delivery, :delivered) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    change(delivery, status: :delivered, delivered_at: now)
  end

  def status_changeset(delivery, new_status) do
    change(delivery, status: new_status)
  end
end
