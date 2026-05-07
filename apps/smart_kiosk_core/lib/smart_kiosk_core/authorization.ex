defmodule SmartKioskCore.Authorization do
  @moduledoc """
  RBAC authorization context.

  Roles are assigned to users via the `user_roles` join table, optionally
  scoped to a shop. Permissions are assigned to roles via `role_permissions`.

  ## Typical usage

  At LiveView mount (in ShopAuth):

      permissions = Authorization.list_permissions(user, shop)
      assign(socket, :permissions, permissions)

  In a LiveView or template:

      MapSet.member?(assigns.permissions, "orders:write")

  In a plug (Conn-based):

      Authorization.can?(user, "platform:manage_shops")
  """

  import Ecto.Query

  alias SmartKioskCore.Repo
  alias SmartKioskCore.Schemas.{Role, Permission, RolePermission, UserRole}
  alias SmartKioskCore.Schemas.{User, Shop}

  # ---------------------------------------------------------------------------
  # Permission checks
  # ---------------------------------------------------------------------------

  @doc """
  Returns true if the user holds a platform-wide role that grants the given
  permission slug (format: `"resource:action"`).
  """
  @spec can?(User.t(), String.t()) :: boolean()
  def can?(%User{id: user_id}, permission_slug) when is_binary(permission_slug) do
    {resource, action} = split_slug(permission_slug)

    from(ur in UserRole,
      join: rp in RolePermission, on: rp.role_id == ur.role_id,
      join: p in Permission, on: p.id == rp.permission_id,
      where: ur.user_id == ^user_id,
      where: is_nil(ur.shop_id),
      where: p.resource == ^resource and p.action == ^action,
      select: count(p.id)
    )
    |> Repo.one()
    |> Kernel.>(0)
  end

  @doc """
  Returns true if the user holds a role (shop-scoped or platform-wide) that
  grants the given permission slug within the given shop.
  """
  @spec can?(User.t(), String.t(), Shop.t()) :: boolean()
  def can?(%User{id: user_id}, permission_slug, %Shop{id: shop_id}) when is_binary(permission_slug) do
    {resource, action} = split_slug(permission_slug)

    from(ur in UserRole,
      join: rp in RolePermission, on: rp.role_id == ur.role_id,
      join: p in Permission, on: p.id == rp.permission_id,
      where: ur.user_id == ^user_id,
      where: ur.shop_id == ^shop_id or is_nil(ur.shop_id),
      where: p.resource == ^resource and p.action == ^action,
      select: count(p.id)
    )
    |> Repo.one()
    |> Kernel.>(0)
  end

  # ---------------------------------------------------------------------------
  # Bulk permission loading (for socket assigns)
  # ---------------------------------------------------------------------------

  @doc """
  Returns a `MapSet` of all `"resource:action"` strings the user has within
  the given shop (including any platform-wide roles they hold). Pass `nil` for
  the shop to get platform-only permissions.

  Call once at mount and store on socket assigns to avoid per-action DB hits.
  """
  @spec list_permissions(User.t(), Shop.t() | nil) :: MapSet.t(String.t())
  def list_permissions(%User{id: user_id}, %Shop{id: shop_id}) do
    from(ur in UserRole,
      join: rp in RolePermission, on: rp.role_id == ur.role_id,
      join: p in Permission, on: p.id == rp.permission_id,
      where: ur.user_id == ^user_id,
      where: ur.shop_id == ^shop_id or is_nil(ur.shop_id),
      select: {p.resource, p.action}
    )
    |> Repo.all()
    |> to_mapset()
  end

  def list_permissions(%User{id: user_id}, nil) do
    from(ur in UserRole,
      join: rp in RolePermission, on: rp.role_id == ur.role_id,
      join: p in Permission, on: p.id == rp.permission_id,
      where: ur.user_id == ^user_id,
      where: is_nil(ur.shop_id),
      select: {p.resource, p.action}
    )
    |> Repo.all()
    |> to_mapset()
  end

  # ---------------------------------------------------------------------------
  # Role management
  # ---------------------------------------------------------------------------

  @doc "Assigns a role to a user, optionally scoped to a shop."
  @spec assign_role(User.t(), Role.t(), Shop.t() | nil) ::
          {:ok, UserRole.t()} | {:error, Ecto.Changeset.t()}
  def assign_role(%User{id: user_id}, %Role{id: role_id}, nil) do
    %UserRole{}
    |> UserRole.changeset(%{user_id: user_id, role_id: role_id, shop_id: nil})
    |> Repo.insert()
  end

  def assign_role(%User{id: user_id}, %Role{id: role_id}, %Shop{id: shop_id}) do
    %UserRole{}
    |> UserRole.changeset(%{user_id: user_id, role_id: role_id, shop_id: shop_id})
    |> Repo.insert()
  end

  @doc "Revokes a role from a user."
  @spec revoke_role(User.t(), Role.t(), Shop.t() | nil) :: :ok | {:error, :not_found}
  def revoke_role(%User{id: user_id}, %Role{id: role_id}, nil) do
    case Repo.get_by(UserRole, user_id: user_id, role_id: role_id, shop_id: nil) do
      nil -> {:error, :not_found}
      ur -> Repo.delete!(ur) && :ok
    end
  end

  def revoke_role(%User{id: user_id}, %Role{id: role_id}, %Shop{id: shop_id}) do
    case Repo.get_by(UserRole, user_id: user_id, role_id: role_id, shop_id: shop_id) do
      nil -> {:error, :not_found}
      ur -> Repo.delete!(ur) && :ok
    end
  end

  # ---------------------------------------------------------------------------
  # Queries
  # ---------------------------------------------------------------------------

  @doc "Lists all roles for a given scope (:shop or :platform)."
  @spec list_roles(scope: :shop | :platform) :: [Role.t()]
  def list_roles(scope: :shop),
    do: from(r in Role, where: r.scope == "shop", order_by: r.name) |> Repo.all()

  def list_roles(scope: :platform),
    do: from(r in Role, where: r.scope == "platform", order_by: r.name) |> Repo.all()

  def list_roles(_), do: from(r in Role, order_by: r.name) |> Repo.all()

  @doc "Fetches a role by slug, raising if not found."
  @spec get_role_by_slug!(String.t()) :: Role.t()
  def get_role_by_slug!(slug), do: Repo.get_by!(Role, slug: slug)

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp split_slug(slug) do
    case String.split(slug, ":", parts: 2) do
      [resource, action] -> {resource, action}
      _ -> raise ArgumentError, "invalid permission slug: #{inspect(slug)}"
    end
  end

  defp to_mapset(pairs) do
    pairs
    |> Enum.map(fn {resource, action} -> "#{resource}:#{action}" end)
    |> MapSet.new()
  end
end
