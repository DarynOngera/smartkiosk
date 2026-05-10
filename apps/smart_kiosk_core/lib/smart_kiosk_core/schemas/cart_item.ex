defmodule SmartKioskCore.Schemas.CartItem do
  @moduledoc """
  An item in a user's shopping cart. Prices are snapshotted from the product
  at the time the item is added to the cart.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "cart_items" do
    field(:quantity, :integer)
    field(:unit_price, :decimal)
    field(:line_total, :decimal)

    # product_name snapshot — survives product rename/deletion
    field(:product_name, :string)

    # session_id for guest users (when not logged in)
    field(:session_id, :string)

    belongs_to(:user, SmartKioskCore.Schemas.User)
    belongs_to(:shop, SmartKioskCore.Schemas.Shop)
    belongs_to(:product, SmartKioskCore.Schemas.Product)

    timestamps(type: :utc_datetime)
  end

  @required ~w(shop_id product_id quantity unit_price product_name)a
  @optional ~w(user_id session_id)a

  def changeset(item, attrs) do
    item
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_number(:quantity, greater_than: 0)
    |> validate_number(:unit_price, greater_than_or_equal_to: 0)
    |> compute_line_total()
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:shop_id)
    |> foreign_key_constraint(:product_id)
  end

  defp compute_line_total(cs) do
    qty = get_field(cs, :quantity)
    price = get_field(cs, :unit_price)

    if qty && price do
      put_change(cs, :line_total, Decimal.mult(Decimal.new(qty), price))
    else
      cs
    end
  end
end
