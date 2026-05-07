defmodule SmartKioskCore.Schemas.Role do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "roles" do
    field :name,        :string
    field :slug,        :string
    field :scope,       :string   # "platform" | "shop"
    field :description, :string
    field :is_system,   :boolean, default: false

    has_many :role_permissions, SmartKioskCore.Schemas.RolePermission
    has_many :permissions, through: [:role_permissions, :permission]
    has_many :user_roles,  SmartKioskCore.Schemas.UserRole

    timestamps(type: :utc_datetime)
  end

  @required ~w(name slug scope)a
  @optional ~w(description is_system)a

  def changeset(role, attrs) do
    role
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_inclusion(:scope, ["platform", "shop"])
    |> unique_constraint(:slug)
  end
end
