defmodule SmartKioskCore.Schemas.Permission do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "permissions" do
    field(:resource, :string)
    field(:action, :string)
    field(:description, :string)

    has_many(:role_permissions, SmartKioskCore.Schemas.RolePermission)

    timestamps(type: :utc_datetime)
  end

  @required ~w(resource action)a

  def changeset(permission, attrs) do
    permission
    |> cast(attrs, @required ++ [:description])
    |> validate_required(@required)
    |> unique_constraint([:resource, :action])
  end

  @doc "Returns the canonical slug string for a permission."
  def slug(%__MODULE__{resource: r, action: a}), do: "#{r}:#{a}"
end
