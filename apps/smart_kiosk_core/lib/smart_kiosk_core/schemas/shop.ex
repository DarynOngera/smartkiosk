defmodule SmartKioskCore.Schemas.Shop do
  @moduledoc """
  The top-level tenant. One shop = one account.

  `plan` drives feature gating: :basic | :pro | :enterprise
  `status` lifecycle:  :pending_review | :active | :suspended | :closed
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  # include legacy plan atoms so existing DB rows can be loaded
  @plans ~w(basic pro enterprise kiosk duka biashara)a
  @statuses ~w(pending_review active suspended closed)a
  @categories ~w(
    electronics general_shop vegetables fruits groceries
    hardware garage furniture services textiles cosmetics
    bakery butcher pharmacy restaurant cafe beverages
    books stationery mobile_money tailoring cleaning
  )a

  schema "shops" do
    field(:name, :string)
    field(:slug, :string)
    field(:phone, :string)
    field(:email, :string)
    field(:address, :string)
    field(:city, :string)
    field(:country, :string, default: "KE")
    field(:lat, :float)
    field(:lng, :float)
    field(:plan, Ecto.Enum, values: @plans, default: :basic)
    field(:status, Ecto.Enum, values: @statuses, default: :pending_review)
    field(:category, Ecto.Enum, values: @categories, default: :general_shop)
    # field(:business_type, :string, default: "general")
    field(:logo_url, :string)
    field(:description, :string)
    field(:owner_id, :binary_id)
    field(:settings, :map, default: %{})
    # GeoJSON polygon (JSONB). When PostGIS is enabled, can be upgraded to geometry.
    field(:delivery_zone, :map)
    field(:type, :any, virtual: true, default: :shop)

    has_many(:users, SmartKioskCore.Schemas.User)
    has_many(:products, SmartKioskCore.Schemas.Product)
    has_many(:orders, SmartKioskCore.Schemas.Order)
    has_many(:customers, SmartKioskCore.Schemas.Customer)
    has_many(:transactions, SmartKioskCore.Schemas.Transaction)
    has_many(:delivery_zones, SmartKioskCore.Schemas.DeliveryZone)
    has_many(:campaigns, SmartKioskCore.Schemas.Campaign)
    has_many(:invoices, SmartKioskCore.Schemas.Invoice)
    has_one(:subscription, SmartKioskCore.Schemas.Subscription)

    timestamps(type: :utc_datetime)
  end

  @required ~w(name phone)a
  @optional ~w(slug email address city country lat lng plan status category logo_url description settings delivery_zone)a

  def changeset(shop, attrs) do
    attrs = normalize_attrs(attrs)

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

  defp normalize_attrs(attrs) when is_map(attrs) do
    plan_val = Map.get(attrs, "plan") || Map.get(attrs, :plan)

    if plan_val do
      Map.put(attrs, "plan", canonical_plan(plan_val))
    else
      attrs
    end
  end

  defp normalize_attrs(other), do: other

  @doc """
  Convert legacy plan strings/atoms to canonical atoms.

  Examples:
    canonical_plan("kiosk") => :basic
    canonical_plan(:duka) => :pro
    canonical_plan("biashara") => :enterprise
  """
  def canonical_plan(plan) when is_atom(plan), do: canonical_plan(Atom.to_string(plan))

  def canonical_plan(plan) when is_binary(plan) do
    case String.downcase(plan) do
      "kiosk" ->
        :basic

      "duka" ->
        :pro

      "biashara" ->
        :enterprise

      "basic" ->
        :basic

      "pro" ->
        :pro

      "enterprise" ->
        :enterprise

      other ->
        try do
          String.to_existing_atom(other)
        rescue
          _ -> :basic
        end
    end
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
