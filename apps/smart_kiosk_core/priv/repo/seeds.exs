alias SmartKioskCore.Repo
alias SmartKioskCore.Schemas.{Category, User, Shop, Subscription}
alias SmartKioskCore.Schemas.{Role, Permission, RolePermission, UserRole}

IO.puts("Seeding SmartKiosk...")

# ── Categories ────────────────────────────────────────────────────────────────

categories = [
  %{
    name: "Groceries & FMCG",
    slug: "groceries-fmcg",
    icon: "ti-shopping-cart",
    position: 1,
    attribute_templates: [
      %{"key" => "brand", "label" => "Brand", "type" => "text", "required" => false},
      %{"key" => "weight_volume", "label" => "Weight / Volume", "type" => "text", "required" => false},
      %{"key" => "unit", "label" => "Unit", "type" => "select", "required" => true,
        "options" => ["piece", "kg", "g", "litre", "ml", "dozen", "pack"]},
      %{"key" => "expiry_date", "label" => "Expiry Date", "type" => "date", "required" => false},
      %{"key" => "country_of_origin", "label" => "Country of Origin", "type" => "text", "required" => false}
    ]
  },
  %{
    name: "Pharmacy & Health",
    slug: "pharmacy-health",
    icon: "ti-pill",
    position: 2,
    attribute_templates: [
      %{"key" => "generic_name", "label" => "Generic Name", "type" => "text", "required" => false},
      %{"key" => "dosage_form", "label" => "Dosage Form", "type" => "select", "required" => true,
        "options" => ["tablet", "capsule", "syrup", "injection", "cream", "drops", "inhaler"]},
      %{"key" => "strength", "label" => "Strength / Dose", "type" => "text", "required" => false},
      %{"key" => "pack_size", "label" => "Pack Size", "type" => "text", "required" => false},
      %{"key" => "prescription_required", "label" => "Prescription Required", "type" => "boolean", "required" => true},
      %{"key" => "expiry_date", "label" => "Expiry Date", "type" => "date", "required" => true},
      %{"key" => "manufacturer", "label" => "Manufacturer", "type" => "text", "required" => false},
      %{"key" => "controlled_substance", "label" => "Controlled Substance", "type" => "boolean", "required" => true}
    ]
  },
  %{
    name: "Hardware & Building",
    slug: "hardware-building",
    icon: "ti-tool",
    position: 3,
    attribute_templates: [
      %{"key" => "material", "label" => "Material", "type" => "text", "required" => false},
      %{"key" => "dimensions", "label" => "Dimensions", "type" => "text", "required" => false},
      %{"key" => "brand", "label" => "Brand", "type" => "text", "required" => false},
      %{"key" => "unit", "label" => "Unit", "type" => "select", "required" => true,
        "options" => ["piece", "pack", "kg", "metre", "roll", "bag", "sheet"]}
    ]
  },
  %{
    name: "Fashion & Apparel",
    slug: "fashion-apparel",
    icon: "ti-shirt",
    position: 4,
    attribute_templates: [
      %{"key" => "size", "label" => "Size", "type" => "select", "required" => false,
        "options" => ["XS", "S", "M", "L", "XL", "XXL", "XXXL", "free size"]},
      %{"key" => "colour", "label" => "Colour", "type" => "text", "required" => false},
      %{"key" => "material", "label" => "Material", "type" => "text", "required" => false},
      %{"key" => "gender", "label" => "Gender", "type" => "select", "required" => false,
        "options" => ["unisex", "men", "women", "boys", "girls", "baby"]}
    ]
  },
  %{
    name: "Electronics",
    slug: "electronics",
    icon: "ti-device-mobile",
    position: 5,
    attribute_templates: [
      %{"key" => "brand", "label" => "Brand", "type" => "text", "required" => false},
      %{"key" => "model", "label" => "Model", "type" => "text", "required" => false},
      %{"key" => "warranty_months", "label" => "Warranty (months)", "type" => "number", "required" => false},
      %{"key" => "condition", "label" => "Condition", "type" => "select", "required" => true,
        "options" => ["new", "refurbished", "second_hand"]}
    ]
  },
  %{
    name: "Food & Beverages",
    slug: "food-beverages",
    icon: "ti-bowl",
    position: 6,
    attribute_templates: [
      %{"key" => "cuisine", "label" => "Cuisine Type", "type" => "text", "required" => false},
      %{"key" => "serves", "label" => "Serves (persons)", "type" => "number", "required" => false},
      %{"key" => "allergens", "label" => "Allergens", "type" => "text", "required" => false},
      %{"key" => "is_halal", "label" => "Halal Certified", "type" => "boolean", "required" => false}
    ]
  }
]

Enum.each(categories, fn attrs ->
  case Repo.get_by(Category, slug: attrs.slug) do
    nil ->
      %Category{}
      |> Category.changeset(attrs)
      |> Repo.insert!()
      IO.puts("  Created category: #{attrs.name}")
    existing ->
      IO.puts("  Category exists: #{existing.name}")
  end
end)

# ── Platform Admin User ───────────────────────────────────────────────────────
unless Repo.get_by(User, email: "admin@smartkiosk.co.ke") do
  %User{}
  |> User.registration_changeset(%{
    email: "admin@smartkiosk.co.ke",
    password: "AdminPassword123!",
    full_name: "Platform Admin",
    role: "platform_admin",
    shop_id: nil
  }, hash_password: true, validate_email: false)
  |> Repo.insert!()
  IO.puts("  Created platform admin: admin@smartkiosk.co.ke")
end

# ── Demo Shop (dev only) ──────────────────────────────────────────────────────
if Mix.env() == :dev do
  unless Repo.get_by(Shop, slug: "mama-grace-shop") do
    {:ok, shop} =
      %Shop{}
      |> Shop.changeset(%{
        name: "Mama Grace Shop",
        phone: "+254700000001",
        email: "grace@example.com",
        address: "Tom Mboya Street, Nairobi CBD",
        city: "Nairobi",
        lat: -1.2833,
        lng: 36.8172,
        plan: :duka,
        status: :active
      })
      |> Repo.insert()

    %Subscription{}
    |> Subscription.changeset(%{shop_id: shop.id, plan: :duka, status: :active})
    |> Repo.insert!()

    %User{}
    |> User.registration_changeset(%{
      email: "grace@example.com",
      password: "DemoPassword123!",
      full_name: "Grace Wanjiku",
      role: "owner",
      shop_id: shop.id,
      phone: "+254700000001"
    }, hash_password: true, validate_email: false)
    |> Repo.insert!()

    IO.puts("  Created demo shop: Mama Grace Shop")
    IO.puts("  Demo login: grace@example.com / DemoPassword123!")
  end
end

# ── System Roles ──────────────────────────────────────────────────────────────
IO.puts("Seeding roles...")

system_roles = [
  %{name: "Platform Admin", slug: "platform_admin", scope: "platform",
    description: "SmartKiosk operations team — full platform access", is_system: true},
  %{name: "Owner",   slug: "owner",   scope: "shop",
    description: "Shop owner with full control of their shop", is_system: true},
  %{name: "Manager", slug: "manager", scope: "shop",
    description: "Delegated shop management, all operational permissions", is_system: true},
  %{name: "Staff",   slug: "staff",   scope: "shop",
    description: "Cashier / stock clerk with limited access", is_system: true},
  %{name: "Rider",   slug: "rider",   scope: "shop",
    description: "Delivery rider — delivery task access only", is_system: true}
]

roles_by_slug =
  Map.new(system_roles, fn attrs ->
    role =
      case Repo.get_by(Role, slug: attrs.slug) do
        nil ->
          {:ok, r} = %Role{} |> Role.changeset(attrs) |> Repo.insert()
          IO.puts("  Created role: #{r.name}")
          r
        existing ->
          IO.puts("  Role exists: #{existing.name}")
          existing
      end

    {attrs.slug, role}
  end)

# ── Permissions ────────────────────────────────────────────────────────────────
IO.puts("Seeding permissions...")

all_permissions = [
  # Platform
  %{resource: "platform", action: "read",          description: "View platform-level data"},
  %{resource: "platform", action: "manage_shops",  description: "Create, suspend, and delete shops"},
  %{resource: "platform", action: "manage_users",  description: "Manage platform-level user accounts"},
  # Shop
  %{resource: "shop", action: "manage_settings", description: "Edit shop profile, plan, and config"},
  %{resource: "shop", action: "manage_staff",    description: "Invite, edit, and remove shop staff"},
  # Orders
  %{resource: "orders", action: "read",   description: "View orders"},
  %{resource: "orders", action: "write",  description: "Create and update orders"},
  %{resource: "orders", action: "cancel", description: "Cancel orders"},
  # Inventory
  %{resource: "inventory", action: "read",  description: "View products and stock levels"},
  %{resource: "inventory", action: "write", description: "Add, edit, and adjust stock"},
  # Customers
  %{resource: "customers", action: "read",  description: "View customer records"},
  %{resource: "customers", action: "write", description: "Add and edit customer records"},
  # POS
  %{resource: "pos", action: "use", description: "Operate the point-of-sale terminal"},
  # Analytics
  %{resource: "analytics", action: "read", description: "View shop analytics and reports"},
  # Campaigns
  %{resource: "campaigns", action: "read",  description: "View advertising campaigns"},
  %{resource: "campaigns", action: "write", description: "Create and edit campaigns"},
  # Deliveries
  %{resource: "deliveries", action: "read",   description: "View delivery tasks"},
  %{resource: "deliveries", action: "manage", description: "Assign riders and update delivery status"},
  # Transactions
  %{resource: "transactions", action: "read", description: "View financial transactions"}
]

permissions_by_slug =
  Map.new(all_permissions, fn attrs ->
    perm =
      case Repo.get_by(Permission, resource: attrs.resource, action: attrs.action) do
        nil ->
          {:ok, p} = %Permission{} |> Permission.changeset(attrs) |> Repo.insert()
          p
        existing ->
          existing
      end

    {"#{attrs.resource}:#{attrs.action}", perm}
  end)

IO.puts("  #{map_size(permissions_by_slug)} permissions ready")

# ── Role → Permission Matrix ───────────────────────────────────────────────────
IO.puts("Assigning permissions to roles...")

role_permissions_matrix = %{
  "platform_admin" => ~w(
    platform:read platform:manage_shops platform:manage_users
  ),
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

Enum.each(role_permissions_matrix, fn {role_slug, permission_slugs} ->
  role = roles_by_slug[role_slug]

  Enum.each(permission_slugs, fn perm_slug ->
    permission = permissions_by_slug[perm_slug]

    unless Repo.get_by(RolePermission, role_id: role.id, permission_id: permission.id) do
      %RolePermission{}
      |> RolePermission.changeset(%{role_id: role.id, permission_id: permission.id})
      |> Repo.insert!()
    end
  end)

  IO.puts("  #{role_slug}: #{length(permission_slugs)} permissions assigned")
end)

# ── Migrate existing user.role → user_roles ───────────────────────────────────
IO.puts("Migrating existing users to user_roles...")

Repo.all(User)
|> Enum.each(fn user ->
  role_slug = to_string(user.role)
  role = roles_by_slug[role_slug]

  unless role do
    IO.puts("  WARNING: unknown role #{inspect(role_slug)} for user #{user.email} — skipping")
    nil
  else
    attrs = %{user_id: user.id, role_id: role.id, shop_id: user.shop_id}

    %UserRole{}
    |> UserRole.changeset(attrs)
    |> Repo.insert(on_conflict: :nothing)

    IO.puts("  Migrated #{user.email} → #{role_slug}")
  end
end)

IO.puts("Seeding complete.")
