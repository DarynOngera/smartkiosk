defmodule SmartKioskCore.Schemas.OrderItem do
  @moduledoc """
  A line item on an order. Prices are snapshotted from the product at the
  time the order is placed — never joined back to the live product price.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "order_items" do
    field :quantity,    :integer
    field :unit_price,  :decimal
    field :line_total,  :decimal

    # product_name snapshot — survives product rename/deletion
    field :product_name, :string

    belongs_to :order,   SmartKioskCore.Schemas.Order
    belongs_to :product, SmartKioskCore.Schemas.Product

    timestamps(type: :utc_datetime)
  end

  @required ~w(order_id product_id quantity unit_price product_name)a

  def changeset(item, attrs) do
    item
    |> cast(attrs, @required)
    |> validate_required(@required)
    |> validate_number(:quantity, greater_than: 0)
    |> validate_number(:unit_price, greater_than_or_equal_to: 0)
    |> compute_line_total()
    |> foreign_key_constraint(:order_id)
    |> foreign_key_constraint(:product_id)
  end

  defp compute_line_total(cs) do
    qty   = get_change(cs, :quantity)
    price = get_change(cs, :unit_price)

    if qty && price do
      put_change(cs, :line_total, Decimal.mult(Decimal.new(qty), price))
    else
      cs
    end
  end
end

