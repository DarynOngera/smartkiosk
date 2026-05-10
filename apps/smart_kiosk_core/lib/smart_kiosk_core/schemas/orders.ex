defmodule SmartKioskCore.Schemas.Order do
  @moduledoc """
  An order placed either via POS (channel: :pos) or the online storefront
  (channel: :online).

  Status lifecycle:
    :pending → :confirmed → :preparing → :ready → :dispatched → :delivered
    Any status → :cancelled

  Prices are snapshotted at order creation time — product price changes
  do not affect existing orders.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(pending confirmed preparing ready dispatched delivered cancelled)a
  @channels ~w(pos online)a

  schema "orders" do
    field(:status, Ecto.Enum, values: @statuses, default: :pending)
    field(:channel, Ecto.Enum, values: @channels, default: :online)
    field(:subtotal, :decimal)
    field(:delivery_fee, :decimal, default: Decimal.new("0"))
    field(:total, :decimal)
    field(:notes, :string)
    field(:delivery_address, :string)
    field(:delivery_lat, :float)
    field(:delivery_lng, :float)

    belongs_to(:shop, SmartKioskCore.Schemas.Shop)
    belongs_to(:customer, SmartKioskCore.Schemas.Customer)

    has_many(:items, SmartKioskCore.Schemas.OrderItem)
    has_one(:delivery, SmartKioskCore.Schemas.Delivery)
    has_many(:transactions, SmartKioskCore.Schemas.Transaction)

    timestamps(type: :utc_datetime)
  end

  @required ~w(shop_id channel)a
  @optional ~w(customer_id status subtotal delivery_fee total notes delivery_address delivery_lat delivery_lng)a

  def changeset(order, attrs) do
    order
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> foreign_key_constraint(:shop_id)
    |> foreign_key_constraint(:customer_id)
    |> compute_total()
  end

  @doc "Transition the order status."
  def status_changeset(order, new_status) do
    order
    |> change(status: new_status)
    |> validate_inclusion(:status, Ecto.Enum.values(__MODULE__, :status))
  end

  defp compute_total(%Ecto.Changeset{} = cs) do
    subtotal = get_field(cs, :subtotal) || Decimal.new("0")
    delivery_fee = get_field(cs, :delivery_fee) || Decimal.new("0")

    if subtotal do
      put_change(cs, :total, Decimal.add(subtotal, delivery_fee))
    else
      cs
    end
  end
end
