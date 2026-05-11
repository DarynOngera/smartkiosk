defmodule SmartKioskCore.Bootstrap do
  @moduledoc """
  Seed helpers for system RBAC records.

  Keeping these definitions in code lets seeds and tests share the same
  source of truth for roles, permissions, and default role migration.
  """

  alias SmartKioskCore.Repo
  alias SmartKioskCore.Schemas.{Permission, Role, RolePermission, User, UserRole}

  @system_roles [
    %{
      name: "Platform Admin",
      slug: "platform_admin",
      scope: "platform",
      description: "SmartKiosk operations team — full platform access",
      is_system: true
    },
    %{
      name: "Customer",
      slug: "customer",
      scope: "platform",
      description: "Regular customer account with no elevated permissions",
      is_system: true
    },
    %{
      name: "Owner",
      slug: "owner",
      scope: "shop",
      description: "Shop owner with full control of their shop",
      is_system: true
    },
    %{
      name: "Manager",
      slug: "manager",
      scope: "shop",
      description: "Delegated shop management, all operational permissions",
      is_system: true
    },
    %{
      name: "Staff",
      slug: "staff",
      scope: "shop",
      description: "Cashier / stock clerk with limited access",
      is_system: true
    },
    %{
      name: "Rider",
      slug: "rider",
      scope: "shop",
      description: "Delivery rider — delivery task access only",
      is_system: true
    }
  ]

  @permissions [
    %{resource: "platform", action: "read", description: "View platform-level data"},
    %{
      resource: "platform",
      action: "manage_shops",
      description: "Create, suspend, and delete shops"
    },
    %{
      resource: "platform",
      action: "manage_users",
      description: "Manage platform-level user accounts"
    },
    %{
      resource: "shop",
      action: "manage_settings",
      description: "Edit shop profile, plan, and config"
    },
    %{
      resource: "shop",
      action: "manage_staff",
      description: "Invite, edit, and remove shop staff"
    },
    %{resource: "orders", action: "read", description: "View orders"},
    %{resource: "orders", action: "write", description: "Create and update orders"},
    %{resource: "orders", action: "cancel", description: "Cancel orders"},
    %{resource: "inventory", action: "read", description: "View products and stock levels"},
    %{resource: "inventory", action: "write", description: "Add, edit, and adjust stock"},
    %{resource: "customers", action: "read", description: "View customer records"},
    %{resource: "customers", action: "write", description: "Add and edit customer records"},
    %{resource: "pos", action: "use", description: "Operate the point-of-sale terminal"},
    %{resource: "analytics", action: "read", description: "View shop analytics and reports"},
    %{resource: "campaigns", action: "read", description: "View advertising campaigns"},
    %{resource: "campaigns", action: "write", description: "Create and edit campaigns"},
    %{resource: "deliveries", action: "read", description: "View delivery tasks"},
    %{
      resource: "deliveries",
      action: "manage",
      description: "Assign riders and update delivery status"
    },
    %{resource: "transactions", action: "read", description: "View financial transactions"}
  ]

  @role_permissions_matrix %{
    "platform_admin" => ~w(
      platform:read platform:manage_shops platform:manage_users
    ),
    "customer" => [],
    "owner" => ~w(
      shop:manage_settings shop:manage_staff
      orders:read orders:write orders:cancel
      inventory:read inventory:write
      customers:read customers:write
      pos:use analytics:read
      campaigns:read campaigns:write
      deliveries:read deliveries:manage
      transactions:read
    ),
    "manager" => ~w(
      shop:manage_staff
      orders:read orders:write orders:cancel
      inventory:read inventory:write
      customers:read customers:write
      pos:use analytics:read
      campaigns:read campaigns:write
      deliveries:read deliveries:manage
      transactions:read
    ),
    "staff" => ~w(
      orders:read orders:write
      inventory:read
      customers:read
      pos:use
      deliveries:read
    ),
    "rider" => ~w(
      deliveries:read deliveries:manage
    )
  }

  @doc "Seeds system roles, permissions, and role-permission assignments."
  def seed_rbac! do
    roles_by_slug =
      Map.new(@system_roles, fn attrs ->
        role = Repo.get_by(Role, slug: attrs.slug) || insert_role!(attrs)
        {attrs.slug, role}
      end)

    permissions_by_slug =
      Map.new(@permissions, fn attrs ->
        permission =
          Repo.get_by(Permission, resource: attrs.resource, action: attrs.action) ||
            insert_permission!(attrs)

        {"#{attrs.resource}:#{attrs.action}", permission}
      end)

    Enum.each(@role_permissions_matrix, fn {role_slug, permission_slugs} ->
      role = Map.fetch!(roles_by_slug, role_slug)

      Enum.each(permission_slugs, fn permission_slug ->
        permission = Map.fetch!(permissions_by_slug, permission_slug)

        unless Repo.get_by(RolePermission, role_id: role.id, permission_id: permission.id) do
          %RolePermission{}
          |> RolePermission.changeset(%{role_id: role.id, permission_id: permission.id})
          |> Repo.insert!()
        end
      end)
    end)

    %{roles_by_slug: roles_by_slug, permissions_by_slug: permissions_by_slug}
  end

  @doc "Creates missing user_role rows from each user's enum role."
  def migrate_existing_user_roles!(roles_by_slug \\ nil) do
    roles_by_slug = roles_by_slug || load_roles_by_slug()

    Repo.all(User)
    |> Enum.each(fn user ->
      case Map.get(roles_by_slug, to_string(user.role)) do
        nil ->
          :ok

        role ->
          %UserRole{}
          |> UserRole.changeset(%{user_id: user.id, role_id: role.id, shop_id: user.shop_id})
          |> Repo.insert!(on_conflict: :nothing)
      end
    end)

    :ok
  end

  defp load_roles_by_slug do
    Repo.all(Role)
    |> Map.new(&{&1.slug, &1})
  end

  defp insert_role!(attrs) do
    %Role{}
    |> Role.changeset(attrs)
    |> Repo.insert!()
  end

  defp insert_permission!(attrs) do
    %Permission{}
    |> Permission.changeset(attrs)
    |> Repo.insert!()
  end
end
