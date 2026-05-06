defmodule SmartKioskCore.Schemas.Product do
  @moduledoc """
  Flat product (no variants in Phase 1).

  `attributes` is a JSONB map of category-specific fields.
  Its keys are validated against the parent category's attribute_templates
  at the context layer (not here — schema stays thin).

  `status` :  :active | :draft | :archived | :out_of_stock
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(active draft archived out_of_stock)a

  schema "products" do
    field :name,                :string
    field :description,         :string
    field :sku,                 :string
    field :barcode,             :string
    field :price,               :decimal
    field :cost_price,          :decimal
    field :stock_qty,           :integer, default: 0
    field :low_stock_threshold, :integer, default: 5
    field :attributes,          :map, default: %{}
    field :status,              Ecto.Enum, values: @statuses, default: :draft
    field :is_featured,         :boolean, default: false

    belongs_to :shop,     SmartKioskCore.Schemas.Shop
    belongs_to :category, SmartKioskCore.Schemas.Category

    has_many :images,      SmartKioskCore.Schemas.ProductImage
    has_many :order_items, SmartKioskCore.Schemas.OrderItem

    timestamps(type: :utc_datetime)
  end

  @required ~w(name price shop_id category_id)a
  @optional ~w(description sku barcode cost_price stock_qty low_stock_threshold attributes status is_featured)a

  def changeset(product, attrs) do
    product
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:name, min: 2, max: 200)
    |> validate_number(:price, greater_than_or_equal_to: 0)
    |> validate_number(:cost_price, greater_than_or_equal_to: 0)
    |> validate_number(:stock_qty, greater_than_or_equal_to: 0)
    |> validate_number(:low_stock_threshold, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:shop_id)
    |> foreign_key_constraint(:category_id)
    |> unique_constraint([:shop_id, :sku], message: "SKU already exists in this shop")
  end

  @doc "Changeset for adjusting stock (e.g. after a sale or restock)."
  def stock_changeset(product, qty_delta) do
    new_qty = product.stock_qty + qty_delta

    product
    |> change(stock_qty: new_qty)
    |> validate_number(:stock_qty, greater_than_or_equal_to: 0)
  end
end
