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
