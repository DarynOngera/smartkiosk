defmodule SmartKioskCore.Schemas.UserRole do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_roles" do
    belongs_to(:user, SmartKioskCore.Schemas.User)
    belongs_to(:role, SmartKioskCore.Schemas.Role)
    # nil → platform-wide
    belongs_to(:shop, SmartKioskCore.Schemas.Shop)

    timestamps(type: :utc_datetime)
  end

  def changeset(user_role, attrs) do
    user_role
    |> cast(attrs, [:user_id, :role_id, :shop_id])
    |> validate_required([:user_id, :role_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:role_id)
    |> foreign_key_constraint(:shop_id)
    # Constraint names match partial unique indexes from the migration
    |> unique_constraint([:user_id, :role_id],
      name: :user_roles_platform_unique,
      message: "role already assigned platform-wide"
    )
    |> unique_constraint([:user_id, :role_id, :shop_id],
      name: :user_roles_shop_unique,
      message: "role already assigned for this shop"
    )
  end
end
