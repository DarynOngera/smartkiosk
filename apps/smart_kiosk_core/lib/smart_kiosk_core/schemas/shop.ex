defmodule SmartKioskCore.Schemas.Shop do
  @moduledoc """
  The top-level tenant. One shop = one account.

  `plan` drives feature gating: :kiosk | :duka | :biashara | :enterprise
  `status` lifecycle:  :pending_review | :active | :suspended | :closed
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @plans ~w(kiosk duka biashara enterprise)a
  @statuses ~w(pending_review active suspended closed)a
  @categories ~w(
    electronics general_shop vegetables fruits groceries
    hardware garage furniture services textiles cosmetics
    bakery butcher pharmacy restaurant cafe beverages
    books stationery mobile_money tailoring cleaning
  )a

  schema "shops" do
    field :name,           :string
    field :slug,           :string
    field :phone,          :string
    field :email,          :string
    field :address,        :string
    field :city,           :string
    field :country,        :string, default: "KE"
    field :lat,            :float
    field :lng,            :float
    field :plan,           Ecto.Enum, values: @plans, default: :kiosk
    field :status,         Ecto.Enum, values: @statuses, default: :pending_review
    field :category,       Ecto.Enum, values: @categories, default: :general_shop
    field :logo_url,       :string
    field :description,    :string
    field :owner_id,       :binary_id
    field :settings,       :map, default: %{}

    has_many :users,         SmartKioskCore.Schemas.User
    has_many :products,      SmartKioskCore.Schemas.Product
    has_many :orders,        SmartKioskCore.Schemas.Order
    has_many :customers,     SmartKioskCore.Schemas.Customer
    has_many :transactions,  SmartKioskCore.Schemas.Transaction
    has_many :campaigns,     SmartKioskCore.Schemas.Campaign
    has_many :invoices,      SmartKioskCore.Schemas.Invoice
    has_one  :subscription,  SmartKioskCore.Schemas.Subscription

    timestamps(type: :utc_datetime)
  end

  @required ~w(name phone)a
  @optional ~w(slug email address city country lat lng plan status category logo_url description settings)a

  def changeset(shop, attrs) do
    shop
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:name, min: 2, max: 120)
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must be a valid email")
    |> validate_format(:phone, ~r/^\+?[\d\s\-]{9,15}$/, message: "must be a valid phone number")
    |> put_slug()
    |> unique_constraint(:slug)
    |> unique_constraint(:phone)
  end

  @doc "Returns the list of available shop categories."
  def categories, do: @categories

  @doc "Returns a map of category atoms to human-readable labels."
  def category_labels do
    %{
      electronics: "Electronics",
      general_shop: "General Shop",
      vegetables: "Vegetables",
      fruits: "Fruits",
      groceries: "Groceries",
      hardware: "Hardware",
      garage: "Garage",
      furniture: "Furniture",
      services: "Services",
      textiles: "Textiles",
      cosmetics: "Cosmetics",
      bakery: "Bakery",
      butcher: "Butcher",
      pharmacy: "Pharmacy",
      restaurant: "Restaurant",
      cafe: "Cafe",
      beverages: "Beverages",
      books: "Books",
      stationery: "Stationery",
      mobile_money: "Mobile Money",
      tailoring: "Tailoring",
      cleaning: "Cleaning"
    }
  end

  defp put_slug(%Ecto.Changeset{valid?: true, changes: %{name: name}} = changeset) do
    put_change(changeset, :slug, Slug.slugify(name))
  end
  defp put_slug(changeset), do: changeset
end
