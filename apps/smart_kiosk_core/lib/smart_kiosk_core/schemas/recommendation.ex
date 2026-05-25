defmodule SmartKioskCore.Schemas.Recommendation do
  @moduledoc """
  Precomputed recommendation scores for shops and products.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @types ~w(shop product)a

  schema "recommendations" do
    field(:type, Ecto.Enum, values: @types)
    field(:score, :float)
    field(:rank, :integer)
    field(:metadata, :map, default: %{})

    belongs_to(:shop, SmartKioskCore.Schemas.Shop)
    belongs_to(:product, SmartKioskCore.Schemas.Product)

    timestamps(type: :utc_datetime)
  end

  @required ~w(type shop_id score rank)a
  @optional ~w(product_id metadata)a

  def changeset(recommendation, attrs) do
    recommendation
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_number(:score, greater_than_or_equal_to: 0)
    |> validate_number(:rank, greater_than_or_equal_to: 1)
    |> foreign_key_constraint(:shop_id)
    |> foreign_key_constraint(:product_id)
  end
end
