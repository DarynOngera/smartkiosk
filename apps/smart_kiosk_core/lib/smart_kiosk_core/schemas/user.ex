defmodule SmartKioskCore.Schemas.User do
  @moduledoc """
  Platform user. Roles are global (not per-shop).

  Roles:
    :platform_admin  — SmartKiosk ops team. shop_id is nil.
    :customer        — Regular platform user (buyer). shop_id is nil.
    :owner           — Shop owner. Full control of their shop.
    :manager         — Delegated shop management.
    :staff           — Cashier / stock clerk. Limited access.
    :rider           — Delivery rider. No shop access; has a Rider profile.

  phx.gen.auth generates the token tables and confirmation plumbing
  alongside this schema. The hashed_password field lives here.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @roles ~w(platform_admin customer owner manager staff rider)a

  schema "users" do
    field(:email, :string)
    field(:hashed_password, :string, redact: true)
    field(:full_name, :string)
    field(:phone, :string)
    field(:role, Ecto.Enum, values: @roles, default: :customer)
    field(:confirmed_at, :utc_datetime)
    field(:avatar_url, :string)

    # Virtual field for accepting plain-text passwords in changesets
    field(:password, :string, virtual: true)

    # Nullable for platform_admin/customer/rider
    belongs_to(:shop, SmartKioskCore.Schemas.Shop)

    has_many(:owned_shops, SmartKioskCore.Schemas.Shop, foreign_key: :owner_id)

    # Optional rider profile
    has_one(:rider_profile, SmartKioskCore.Schemas.Rider)

    # phx.gen.auth token table (generated separately)
    has_many(:tokens, SmartKioskCore.Schemas.UserToken)

    # Customer profiles — one per shop the user has ordered from
    has_many(:customer_profiles, SmartKioskCore.Schemas.Customer)

    # Dynamic RBAC — roles assigned via associative table
    has_many(:user_roles, SmartKioskCore.Schemas.UserRole)
    has_many(:roles, through: [:user_roles, :role])

    timestamps(type: :utc_datetime)
  end

  @doc "Registration changeset — used on initial sign-up."
  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email, :password, :full_name, :phone])
    |> validate_email(opts)
    |> validate_password(opts)
    |> validate_required([:full_name])
    |> validate_role_shop_consistency()
  end

  @doc """
  Internal bootstrap changeset for seeds and trusted admin flows.
  """
  def bootstrap_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email, :password, :full_name, :phone, :role, :shop_id, :avatar_url])
    |> validate_email(opts)
    |> validate_password(opts)
    |> validate_required([:full_name, :role])
    |> validate_role_shop_consistency()
  end

  @doc """
  Assigns a user to a shop and updates their role.

  This is used when an existing platform user creates a shop and becomes the owner,
  or when promoting/demoting users within a shop.
  """
  def assign_to_shop_changeset(%__MODULE__{} = user, %SmartKioskCore.Schemas.Shop{} = shop, role)
      when role in [:owner, :manager, :staff] do
    user
    |> change(shop_id: shop.id, role: role)
    |> validate_role_shop_consistency()
  end

  @doc "Update changeset — profile edits (no password change)."
  def profile_changeset(user, attrs) do
    user
    |> cast(attrs, [:full_name, :phone, :avatar_url])
    |> validate_required([:full_name])
    |> validate_format(:phone, ~r/^\+?[\d\s\-]{9,15}$/)
  end

  @doc "Password change changeset."
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  @doc "Email confirmation changeset."
  def confirm_changeset(user) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    change(user, confirmed_at: now)
  end

  # ── Private helpers ──────────────────────────────────────────────────────────

  defp validate_email(changeset, opts) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> maybe_validate_unique_email(opts)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 12, max: 72)
    |> maybe_hash_password(opts)
  end

  defp maybe_validate_unique_email(changeset, opts) do
    if Keyword.get(opts, :validate_email, true) do
      changeset
      |> unsafe_validate_unique(:email, SmartKioskCore.Repo)
      |> unique_constraint(:email)
    else
      changeset
    end
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      |> validate_length(:password, max: 72, count: :bytes)
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  @doc "Verifies the password. Returns true if valid."
  def valid_password?(%__MODULE__{hashed_password: hashed}, password)
      when is_binary(hashed) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed)
  end

  def valid_password?(_, _), do: Bcrypt.no_user_verify() && false

  defp validate_role_shop_consistency(changeset) do
    role = get_field(changeset, :role)
    shop_id = get_field(changeset, :shop_id)

    cond do
      role in [:platform_admin, :customer, :rider] && shop_id != nil ->
        add_error(changeset, :shop_id, "this user role must not belong to a shop")

      role in [:owner, :manager, :staff] && shop_id == nil ->
        add_error(changeset, :shop_id, "this user role must belong to a shop")

      true ->
        changeset
    end
  end
end
