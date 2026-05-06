defmodule SmartKioskCore.Schemas.ProductImage do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "product_images" do
    field :url,        :string
    field :alt_text,   :string
    field :position,   :integer, default: 0

    belongs_to :product, SmartKioskCore.Schemas.Product

    timestamps(type: :utc_datetime)
  end

  def changeset(image, attrs) do
    image
    |> cast(attrs, [:url, :alt_text, :position, :product_id])
    |> validate_required([:url, :product_id])
    |> foreign_key_constraint(:product_id)
  end
end

defmodule SmartKioskCore.Schemas.Customer do
  @moduledoc """
  A shop's customer. Per-shop record — the same person buying from two shops
  has two Customer records. No global consumer identity in Phase 1.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "customers" do
    field :name,  :string
    field :phone, :string
    field :email, :string
    field :notes, :string

    belongs_to :shop,   SmartKioskCore.Schemas.Shop
    has_many   :orders, SmartKioskCore.Schemas.Order

    timestamps(type: :utc_datetime)
  end

  @required ~w(shop_id)a
  @optional ~w(name phone email notes)a

  def changeset(customer, attrs) do
    customer
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/)
    |> validate_format(:phone, ~r/^\+?[\d\s\-]{9,15}$/)
    |> unique_constraint([:shop_id, :phone], message: "phone already registered for this shop")
    |> foreign_key_constraint(:shop_id)
  end
end

defmodule SmartKioskCore.Schemas.Rider do
  @moduledoc """
  Rider profile — extends a User with role: :rider.
  Tracks current location and availability status.

  `status`: :offline | :available | :on_delivery
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(offline available on_delivery)a

  schema "riders" do
    field :status,      Ecto.Enum, values: @statuses, default: :offline
    field :current_lat, :float
    field :current_lng, :float
    field :vehicle,     :string   # motorbike | bicycle | foot
    field :rating,      :decimal, default: Decimal.new("5.0")

    belongs_to :user,      SmartKioskCore.Schemas.User
    has_many   :deliveries, SmartKioskCore.Schemas.Delivery

    timestamps(type: :utc_datetime)
  end

  def changeset(rider, attrs) do
    rider
    |> cast(attrs, [:status, :current_lat, :current_lng, :vehicle, :rating, :user_id])
    |> validate_required([:user_id])
    |> foreign_key_constraint(:user_id)
    |> unique_constraint(:user_id, message: "user already has a rider profile")
  end

  @doc "Changeset for location updates from the rider stub/app."
  def location_changeset(rider, attrs) do
    rider
    |> cast(attrs, [:current_lat, :current_lng, :status])
    |> validate_required([:current_lat, :current_lng])
    |> validate_number(:current_lat, greater_than_or_equal_to: -90, less_than_or_equal_to: 90)
    |> validate_number(:current_lng, greater_than_or_equal_to: -180, less_than_or_equal_to: 180)
  end
end

defmodule SmartKioskCore.Schemas.DeliveryZone do
  @moduledoc """
  Geographic delivery zone. The boundary is a PostGIS geometry stored
  as a GeoJSON-compatible map in JSONB for now (Phase 1 simplification).
  Phase 3 will promote this to a proper PostGIS geometry column.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "delivery_zones" do
    field :name,      :string
    field :boundary,  :map    # GeoJSON Polygon
    field :base_fee,  :decimal
    field :active,    :boolean, default: true

    has_many :deliveries, SmartKioskCore.Schemas.Delivery

    timestamps(type: :utc_datetime)
  end

  def changeset(zone, attrs) do
    zone
    |> cast(attrs, [:name, :boundary, :base_fee, :active])
    |> validate_required([:name, :base_fee])
    |> validate_number(:base_fee, greater_than_or_equal_to: 0)
  end
end
