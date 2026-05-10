defmodule SmartKioskCore.Schemas.ProductImage do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "product_images" do
    field(:url, :string)
    field(:alt_text, :string)
    field(:position, :integer, default: 0)

    belongs_to(:product, SmartKioskCore.Schemas.Product)

    timestamps(type: :utc_datetime)
  end

  def changeset(image, attrs) do
    image
    |> cast(attrs, [:url, :alt_text, :position, :product_id])
    |> validate_required([:url, :product_id])
    |> foreign_key_constraint(:product_id)
  end
end
