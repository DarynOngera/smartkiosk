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
    belongs_to :user,   SmartKioskCore.Schemas.User
    has_many   :orders, SmartKioskCore.Schemas.Order

    timestamps(type: :utc_datetime)
  end

  @required ~w(shop_id)a
  @optional ~w(name phone email notes user_id)a

  def changeset(customer, attrs) do
    customer
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/)
    |> validate_format(:phone, ~r/^\+?[\d\s\-]{9,15}$/)
    |> unique_constraint([:shop_id, :phone], message: "phone already registered for this shop")
    |> foreign_key_constraint(:shop_id)
    |> foreign_key_constraint(:user_id)
  end
end


