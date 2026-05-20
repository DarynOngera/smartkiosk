defmodule SmartKioskCore.Schemas.StockAdjustment do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "stock_adjustments" do
    field(:qty_delta, :integer)
    field(:reason, :string)
    field(:notes, :string)

    belongs_to(:shop, SmartKioskCore.Schemas.Shop)
    belongs_to(:product, SmartKioskCore.Schemas.Product)
    belongs_to(:user, SmartKioskCore.Schemas.User)

    timestamps(type: :utc_datetime)
  end

  @required ~w(shop_id product_id qty_delta reason)a
  @optional ~w(user_id notes)a

  def changeset(adjustment, attrs) do
    adjustment
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_number(:qty_delta, not_equal_to: 0)
    |> validate_length(:reason, min: 2, max: 80)
    |> validate_length(:notes, max: 500)
    |> foreign_key_constraint(:shop_id)
    |> foreign_key_constraint(:product_id)
    |> foreign_key_constraint(:user_id)
  end
end
