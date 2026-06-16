alias SmartKioskCore.Repo
import Ecto.Query
alias SmartKioskCore.Schemas.{Category, User, Shop, Subscription, Order}
alias SmartKioskCore.Schemas.{Role, Permission, RolePermission, UserRole, CartItem}

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
      %{
        "key" => "weight_volume",
        "label" => "Weight / Volume",
        "type" => "text",
        "required" => false
      },
      %{
        "key" => "unit",
        "label" => "Unit",
        "type" => "select",
        "required" => true,
        "options" => ["piece", "kg", "g", "litre", "ml", "dozen", "pack"]
      },
      %{"key" => "expiry_date", "label" => "Expiry Date", "type" => "date", "required" => false},
      %{
        "key" => "country_of_origin",
        "label" => "Country of Origin",
        "type" => "text",
        "required" => false
      }
    ]
  },
  %{
    name: "Pharmacy & Health",
    slug: "pharmacy-health",
    icon: "ti-pill",
    position: 2,
    attribute_templates: [
      %{
        "key" => "generic_name",
        "label" => "Generic Name",
        "type" => "text",
        "required" => false
      },
      %{
        "key" => "dosage_form",
        "label" => "Dosage Form",
        "type" => "select",
        "required" => true,
        "options" => ["tablet", "capsule", "syrup", "injection", "cream", "drops", "inhaler"]
      },
      %{"key" => "strength", "label" => "Strength / Dose", "type" => "text", "required" => false},
      %{"key" => "pack_size", "label" => "Pack Size", "type" => "text", "required" => false},
      %{
        "key" => "prescription_required",
        "label" => "Prescription Required",
        "type" => "boolean",
        "required" => true
      },
      %{"key" => "expiry_date", "label" => "Expiry Date", "type" => "date", "required" => true},
      %{
        "key" => "manufacturer",
        "label" => "Manufacturer",
        "type" => "text",
        "required" => false
      },
      %{
        "key" => "controlled_substance",
        "label" => "Controlled Substance",
        "type" => "boolean",
        "required" => true
      }
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
      %{
        "key" => "unit",
        "label" => "Unit",
        "type" => "select",
        "required" => true,
        "options" => ["piece", "pack", "kg", "metre", "roll", "bag", "sheet"]
      }
    ]
  },
  %{
    name: "Fashion & Apparel",
    slug: "fashion-apparel",
    icon: "ti-shirt",
    position: 4,
    attribute_templates: [
      %{
        "key" => "size",
        "label" => "Size",
        "type" => "select",
        "required" => false,
        "options" => ["XS", "S", "M", "L", "XL", "XXL", "XXXL", "free size"]
      },
      %{"key" => "colour", "label" => "Colour", "type" => "text", "required" => false},
      %{"key" => "material", "label" => "Material", "type" => "text", "required" => false},
      %{
        "key" => "gender",
        "label" => "Gender",
        "type" => "select",
        "required" => false,
        "options" => ["unisex", "men", "women", "boys", "girls", "baby"]
      }
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
      %{
        "key" => "warranty_months",
        "label" => "Warranty (months)",
        "type" => "number",
        "required" => false
      },
      %{
        "key" => "condition",
        "label" => "Condition",
        "type" => "select",
        "required" => true,
        "options" => ["new", "refurbished", "second_hand"]
      }
    ]
  },
  %{
    name: "Food & Beverages",
    slug: "food-beverages",
    icon: "ti-bowl",
    position: 6,
    attribute_templates: [
      %{"key" => "cuisine", "label" => "Cuisine Type", "type" => "text", "required" => false},
      %{
        "key" => "serves",
        "label" => "Serves (persons)",
        "type" => "number",
        "required" => false
      },
      %{"key" => "allergens", "label" => "Allergens", "type" => "text", "required" => false},
      %{
        "key" => "is_halal",
        "label" => "Halal Certified",
        "type" => "boolean",
        "required" => false
      }
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
  |> User.registration_changeset(
    %{
      email: "admin@smartkiosk.co.ke",
      password: "AdminPassword123!",
      full_name: "Platform Admin",
      role: "platform_admin",
      shop_id: nil
    },
    hash_password: true,
    validate_email: false
  )
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
        plan: :basic,
        status: :active
      })
      |> Repo.insert()

    %Subscription{}
    |> Subscription.changeset(%{shop_id: shop.id, plan: :basic, status: :active})
    |> Repo.insert!()

    %User{}
    |> User.registration_changeset(
      %{
        email: "grace@example.com",
        password: "DemoPassword123!",
        full_name: "Grace Wanjiku",
        role: "owner",
        shop_id: shop.id,
        phone: "+254700000001"
      },
      hash_password: true,
      validate_email: false
    )
    |> Repo.insert!()

    IO.puts("  Created demo shop: Mama Grace Shop")
    IO.puts("  Demo login: grace@example.com / DemoPassword123!")
  end
end

# ── System Roles ──────────────────────────────────────────────────────────────
IO.puts("Seeding roles...")

system_roles = [
  %{
    name: "Platform Admin",
    slug: "platform_admin",
    scope: "platform",
    description: "SmartKiosk operations team — full platform access",
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
  # Shop
  %{
    resource: "shop",
    action: "manage_settings",
    description: "Edit shop profile, plan, and config"
  },
  %{resource: "shop", action: "manage_staff", description: "Invite, edit, and remove shop staff"},
  # Orders
  %{resource: "orders", action: "read", description: "View orders"},
  %{resource: "orders", action: "write", description: "Create and update orders"},
  %{resource: "orders", action: "cancel", description: "Cancel orders"},
  # Inventory
  %{resource: "inventory", action: "read", description: "View products and stock levels"},
  %{resource: "inventory", action: "write", description: "Add, edit, and adjust stock"},
  # Customers
  %{resource: "customers", action: "read", description: "View customer records"},
  %{resource: "customers", action: "write", description: "Add and edit customer records"},
  # POS
  %{resource: "pos", action: "use", description: "Operate the point-of-sale terminal"},
  # Analytics
  %{resource: "analytics", action: "read", description: "View shop analytics and reports"},
  # Campaigns
  %{resource: "campaigns", action: "read", description: "View advertising campaigns"},
  %{resource: "campaigns", action: "write", description: "Create and edit campaigns"},
  # Deliveries
  %{resource: "deliveries", action: "read", description: "View delivery tasks"},
  %{
    resource: "deliveries",
    action: "manage",
    description: "Assign riders and update delivery status"
  },
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

# ── Update existing shop categories ───────────────────────────────────────────
IO.puts("Updating shop categories...")

alias SmartKioskCore.Catalogue
alias SmartKioskCore.Schemas.Product

shop_categories = %{
  "Mama Grace Shop" => "general_shop",
  "Test Owner's Shop" => "electronics",
  "Test2 Owner's Shop" => "restaurant"
}

Enum.each(shop_categories, fn {shop_name, category} ->
  case Repo.get_by(Shop, name: shop_name) do
    nil ->
      IO.puts("  Shop not found: #{shop_name}")

    shop ->
      shop
      |> Shop.changeset(%{category: category})
      |> Repo.update!()

      IO.puts("  Updated #{shop_name} → #{category}")
  end
end)

# ── Seed products for existing shops ───────────────────────────────────────────
IO.puts("Seeding products for existing shops...")

products_by_shop = %{
  "Mama Grace Shop" => [
    %{name: "Rice (5kg)", sku: "RICE-5KG", price: 350, stock_qty: 100},
    %{name: "Sugar (2kg)", sku: "SUGAR-2KG", price: 240, stock_qty: 80},
    %{name: "Cooking Oil (1L)", sku: "OIL-1L", price: 180, stock_qty: 50},
    %{name: "Bread (400g)", sku: "BREAD-400G", price: 55, stock_qty: 30},
    %{name: "Milk (500ml)", sku: "MILK-500ML", price: 60, stock_qty: 40},
    %{name: "Wheat Flour (2kg)", sku: "FLOUR-2KG", price: 150, stock_qty: 60},
    %{name: "Soap (Omo 1kg)", sku: "OMO-1KG", price: 120, stock_qty: 25},
    %{name: "Toothpaste (Colgate)", sku: "COLGATE", price: 85, stock_qty: 20},
    %{name: "Tea Leaves (100g)", sku: "TEA-100G", price: 45, stock_qty: 50},
    %{name: "Salt (1kg)", sku: "SALT-1KG", price: 25, stock_qty: 100}
  ],
  "Test Owner's Shop" => [
    %{name: "Phone Charger (Type-C)", sku: "CHARGER-TC", price: 450, stock_qty: 15},
    %{name: "USB Cable (1m)", sku: "USB-1M", price: 150, stock_qty: 30},
    %{name: "Power Bank (10000mAh)", sku: "POWERBANK-10K", price: 1200, stock_qty: 10},
    %{name: "Earphones (Wired)", sku: "EARPHONES", price: 200, stock_qty: 25},
    %{name: "Screen Protector (Universal)", sku: "SCREEN-GUARD", price: 100, stock_qty: 50},
    %{name: "Memory Card (64GB)", sku: "SD-64GB", price: 600, stock_qty: 20},
    %{name: "Phone Case (Generic)", sku: "CASE-GENERIC", price: 250, stock_qty: 40},
    %{name: "HDMI Cable (2m)", sku: "HDMI-2M", price: 350, stock_qty: 15},
    %{name: "Mouse (Wired)", sku: "MOUSE", price: 300, stock_qty: 20},
    %{name: "Keyboard (USB)", sku: "KEYBOARD", price: 800, stock_qty: 12}
  ],
  "Test2 Owner's Shop" => [
    %{name: "Ugali (Served)", sku: "UGALI", price: 80, stock_qty: 100},
    %{name: "Chapati", sku: "CHAPATI", price: 30, stock_qty: 150},
    %{name: "Pilau Rice", sku: "PILAU", price: 150, stock_qty: 80},
    %{name: "Beef Stew", sku: "BEEF-STEW", price: 180, stock_qty: 50},
    %{name: "Chicken (1/4)", sku: "CHICKEN-QUARTER", price: 250, stock_qty: 40},
    %{name: "Soda (500ml)", sku: "SODA-500ML", price: 60, stock_qty: 60},
    %{name: "Water (500ml)", sku: "WATER-500ML", price: 30, stock_qty: 100},
    %{name: "Mandazi", sku: "MANDAZI", price: 20, stock_qty: 200},
    %{name: "Samosa", sku: "SAMOSA", price: 50, stock_qty: 80},
    %{name: "Tea (Chai)", sku: "CHAI", price: 40, stock_qty: 100}
  ]
}

Enum.each(products_by_shop, fn {shop_name, products} ->
  case Repo.get_by(Shop, name: shop_name) do
    nil ->
      IO.puts("  Shop not found: #{shop_name}")

    shop ->
      # Get a default category for products (Groceries & FMCG)
      default_category =
        Repo.get_by(Category, slug: "groceries-fmcg") ||
          Repo.one(from(c in Category, limit: 1))

      if is_nil(default_category) do
        IO.puts("  No category found for #{shop_name}, skipping products")
      else
        Enum.each(products, fn product_attrs ->
          attrs =
            Map.merge(product_attrs, %{
              shop_id: shop.id,
              category_id: default_category.id,
              status: :active,
              tax_rate: Decimal.new("16.00")
            })

          case Repo.get_by(Product, shop_id: shop.id, sku: attrs.sku) do
            nil ->
              case %Product{}
                   |> Product.changeset(attrs)
                   |> Repo.insert() do
                {:ok, product} ->
                  IO.puts("  Created #{product.name} in #{shop_name}")

                {:error, changeset} ->
                  IO.puts("  Error creating #{attrs.name}: #{inspect(changeset.errors)}")
              end

            existing ->
              IO.puts("  Product exists: #{existing.name} in #{shop_name}")
          end
        end)
      end
  end
end)

IO.puts("Product seeding complete.")

# ── Seed additional shops ─────────────────────────────────────────────────────
IO.puts("Seeding additional shops...")

additional_shops = [
  %{
    "name" => "Nairobi Electronics Hub",
    "phone" => "+254700000002",
    "email" => "nairobi.electronics@example.com",
    "address" => "Moi Avenue, Nairobi",
    "city" => "Nairobi",
    "plan" => "pro",
    "status" => "active",
    "category" => "electronics",
    "lat" => -1.2863,
    "lng" => 36.8172
  },
  %{
    "name" => "Kilimani Fresh Mart",
    "phone" => "+254700000003",
    "email" => "kilimani.fresh@example.com",
    "address" => "Kilimani Road, Nairobi",
    "city" => "Nairobi",
    "plan" => "enterprise",
    "status" => "active",
    "category" => "groceries",
    "lat" => -1.2897,
    "lng" => 36.7703
  },
  %{
    "name" => "Westlands Pharmacy",
    "phone" => "+254700000004",
    "email" => "westlands.pharma@example.com",
    "address" => "Westlands Road, Nairobi",
    "city" => "Nairobi",
    "plan" => "basic",
    "status" => "active",
    "category" => "pharmacy",
    "lat" => -1.2675,
    "lng" => 36.8067
  },
  %{
    "name" => "Kikwetu Bakery",
    "phone" => "+254700000005",
    "email" => "kikwetu.bakery@example.com",
    "address" => "Ngong Road, Nairobi",
    "city" => "Nairobi",
    "plan" => "basic",
    "status" => "active",
    "category" => "bakery",
    "lat" => -1.2984,
    "lng" => 36.7864
  },
  %{
    "name" => "Mombasa Hardware",
    "phone" => "+254700000006",
    "email" => "mombasa.hardware@example.com",
    "address" => "Digo Road, Mombasa",
    "city" => "Mombasa",
    "plan" => "pro",
    "status" => "active",
    "category" => "hardware",
    "lat" => -4.0435,
    "lng" => 39.6682
  },
  %{
    "name" => "Lavington Furniture",
    "phone" => "+254700000007",
    "email" => "lavington.furniture@example.com",
    "address" => "James Gichuru Road, Nairobi",
    "city" => "Nairobi",
    "plan" => "basic",
    "status" => "active",
    "category" => "furniture",
    "lat" => -1.2645,
    "lng" => 36.7536
  },
  %{
    "name" => "Nakuru Garments",
    "phone" => "+254700000008",
    "email" => "nakuru.garments@example.com",
    "address" => "Kenyatta Avenue, Nakuru",
    "city" => "Nakuru",
    "plan" => "basic",
    "status" => "active",
    "category" => "textiles",
    "lat" => -0.3031,
    "lng" => 36.0663
  },
  %{
    "name" => "Tusker Bar & Grill",
    "phone" => "+254700000009",
    "email" => "tusker.bar@example.com",
    "address" => "Langata Road, Nairobi",
    "city" => "Nairobi",
    "plan" => "pro",
    "status" => "active",
    "category" => "restaurant",
    "lat" => -1.3292,
    "lng" => 36.7887
  },
  %{
    "name" => "Glow Beauty Supplies",
    "phone" => "+254700000010",
    "email" => "glow.beauty@example.com",
    "address" => "Kimathi Street, Nairobi",
    "city" => "Nairobi",
    "plan" => "basic",
    "status" => "active",
    "category" => "cosmetics",
    "lat" => -1.2839,
    "lng" => 36.8219
  },
  %{
    "name" => "Karen Auto Garage",
    "phone" => "+254700000011",
    "email" => "karen.garage@example.com",
    "address" => "Karen Road, Nairobi",
    "city" => "Nairobi",
    "plan" => "basic",
    "status" => "active",
    "category" => "garage",
    "lat" => -1.3167,
    "lng" => 36.7167
  }
]

shops_map =
  Map.new(additional_shops, fn attrs ->
    shop =
      case Repo.get_by(Shop, phone: attrs["phone"]) do
        nil ->
          {:ok, shop} =
            %Shop{}
            |> Shop.changeset(attrs)
            |> Repo.insert()

          IO.puts("  Created shop: #{shop.name}")
          shop

        existing ->
          IO.puts("  Shop exists: #{existing.name}")
          existing
      end

    {attrs["name"], shop}
  end)

IO.puts("#{map_size(shops_map)} additional shops ready")

# ── Seed additional products ──────────────────────────────────────────────────
IO.puts("Seeding additional products...")

default_category =
  Repo.get_by(Category, slug: "groceries-fmcg") ||
    Repo.one(from(c in Category, limit: 1))

additional_products = [
  {"Nairobi Electronics Hub",
   [
     %{name: "Samsung Galaxy A54", sku: "SGA54", price: 45000, stock_qty: 8},
     %{name: "iPhone 15 Pro", sku: "IP15P", price: 145_000, stock_qty: 5},
     %{name: "Sony WH-1000XM5", sku: "SONY-XM5", price: 35000, stock_qty: 12},
     %{name: "MacBook Air M2", sku: "MBA-M2", price: 180_000, stock_qty: 3},
     %{name: "iPad Pro 12.9", sku: "IPAD-PRO", price: 120_000, stock_qty: 6},
     %{name: "Samsung 55\" TV", sku: "TV-55", price: 65000, stock_qty: 4},
     %{name: "PlayStation 5", sku: "PS5", price: 75000, stock_qty: 7},
     %{name: "JBL Flip 6 Speaker", sku: "JBL-F6", price: 12000, stock_qty: 15}
   ]},
  {"Kilimani Fresh Mart",
   [
     %{name: "Organic Avocado (1kg)", sku: "AVO-1KG", price: 120, stock_qty: 50},
     %{name: "Fresh Spinach Bunch", sku: "SPINACH", price: 30, stock_qty: 80},
     %{name: "Cherry Tomatoes (500g)", sku: "TOM-500G", price: 90, stock_qty: 40},
     %{name: "Greek Yogurt (1L)", sku: "YOG-1L", price: 350, stock_qty: 25},
     %{name: "Free-Range Eggs (Tray)", sku: "EGGS-TRAY", price: 450, stock_qty: 30},
     %{name: "Artisan Cheese (200g)", sku: "CHEESE-200", price: 650, stock_qty: 15},
     %{name: "Fresh Salmon (500g)", sku: "SALMON-500", price: 850, stock_qty: 10},
     %{name: "Organic Honey (500g)", sku: "HONEY-500", price: 550, stock_qty: 20}
   ]},
  {"Westlands Pharmacy",
   [
     %{name: "Panadol Extra (24 tabs)", sku: "PAN-EXTRA", price: 120, stock_qty: 100},
     %{name: "Amoxicillin 500mg (21 caps)", sku: "AMOX-500", price: 180, stock_qty: 80},
     %{name: "Vitamin C 1000mg (60 tabs)", sku: "VIT-C", price: 250, stock_qty: 60},
     %{name: "Bandage Roll (10cm)", sku: "BAND-10", price: 45, stock_qty: 120},
     %{name: "Thermometer Digital", sku: "THERMO", price: 350, stock_qty: 25},
     %{name: "Face Mask (Pack of 50)", sku: "MASK-50", price: 150, stock_qty: 200},
     %{name: "Hand Sanitizer (500ml)", sku: "SAN-500", price: 200, stock_qty: 75},
     %{name: "Blood Pressure Monitor", sku: "BPM", price: 2800, stock_qty: 8}
   ]},
  {"Kikwetu Bakery",
   [
     %{name: "Birthday Cake (1kg)", sku: "CAKE-1KG", price: 2500, stock_qty: 5},
     %{name: "Croissants (6 pcs)", sku: "CROIS-6", price: 450, stock_qty: 20},
     %{name: "Chocolate Muffins (4 pcs)", sku: "MUFF-4", price: 350, stock_qty: 25},
     %{name: "Sourdough Bread", sku: "SOUR-BREAD", price: 280, stock_qty: 15},
     %{name: "Cinnamon Rolls (4 pcs)", sku: "CINN-4", price: 380, stock_qty: 18},
     %{name: "Red Velvet Cake Slice", sku: "VELVET", price: 350, stock_qty: 12},
     %{name: "Cookies (Pack of 12)", sku: "COOK-12", price: 250, stock_qty: 30},
     %{name: "Donuts (6 pcs)", sku: "DONUT-6", price: 400, stock_qty: 22}
   ]},
  {"Mombasa Hardware",
   [
     %{name: "Cement (50kg bag)", sku: "CEM-50", price: 650, stock_qty: 100},
     %{name: "Steel Rod (12mm, 6m)", sku: "ROD-12", price: 850, stock_qty: 50},
     %{name: "Roofing Sheets (3m)", sku: "ROOF-3", price: 1200, stock_qty: 40},
     %{name: "PVC Pipes (4 inch, 6m)", sku: "PVC-4", price: 450, stock_qty: 60},
     %{name: "Paint (20L, White)", sku: "PAINT-20", price: 2800, stock_qty: 20},
     %{name: "Tile Adhesive (25kg)", sku: "ADH-25", price: 650, stock_qty: 30},
     %{name: "Wire Mesh (1m x 25m)", sku: "MESH", price: 3500, stock_qty: 15},
     %{name: "Drainage Grate", sku: "GRATE", price: 1200, stock_qty: 25}
   ]},
  {"Lavington Furniture",
   [
     %{name: "3-Seater Sofa", sku: "SOFA-3", price: 45000, stock_qty: 5},
     %{name: "Dining Table (6-seater)", sku: "DIN-6", price: 28000, stock_qty: 3},
     %{name: "Queen Bed Frame", sku: "BED-Q", price: 22000, stock_qty: 4},
     %{name: "Wardrobe (3-door)", sku: "WARD-3", price: 18000, stock_qty: 6},
     %{name: "Office Desk", sku: "DESK", price: 12000, stock_qty: 8},
     %{name: "Bookshelf", sku: "SHELF", price: 8500, stock_qty: 10},
     %{name: "Coffee Table", sku: "COFFEE", price: 6500, stock_qty: 7},
     %{name: "Recliner Chair", sku: "RECLINER", price: 25000, stock_qty: 3}
   ]},
  {"Nakuru Garments",
   [
     %{name: "Kitenge Dress", sku: "KIT-DRESS", price: 2800, stock_qty: 20},
     %{name: "Men's Kikoy", sku: "KIKOY", price: 850, stock_qty: 50},
     %{name: "Shuka Blanket", sku: "SHUKA", price: 1200, stock_qty: 30},
     %{name: "Embroidery Kit", sku: "EMB-KIT", price: 1500, stock_qty: 15},
     %{name: "Silk Scarf", sku: "SCARF", price: 950, stock_qty: 25},
     %{name: "Tailoring Thread Set", sku: "THREAD", price: 350, stock_qty: 40},
     %{name: "Beaded Necklace", sku: "BEADS", price: 650, stock_qty: 35},
     %{name: "Leather Sandals", sku: "SANDALS", price: 1800, stock_qty: 20}
   ]},
  {"Tusker Bar & Grill",
   [
     %{name: "Nyama Choma (1kg)", sku: "NYAMA-1", price: 1200, stock_qty: 30},
     %{name: "Tusker Lager (500ml)", sku: "TUSKER", price: 220, stock_qty: 100},
     %{name: "Grilled Tilapia", sku: "TILAPIA", price: 800, stock_qty: 25},
     %{name: "Ugali & Sukuma", sku: "UGALI-SK", price: 250, stock_qty: 50},
     %{name: "Chicken Wings (10 pcs)", sku: "WINGS-10", price: 650, stock_qty: 40},
     %{name: "Beef Burger", sku: "BURGER", price: 550, stock_qty: 35},
     %{name: "Mutura (2 pcs)", sku: "MUTURA", price: 150, stock_qty: 60},
     %{name: "Pilau & Kachumbari", sku: "PILAU-K", price: 450, stock_qty: 45}
   ]},
  {"Glow Beauty Supplies",
   [
     %{name: "Shea Butter (200g)", sku: "SHEA-200", price: 450, stock_qty: 30},
     %{name: "Hair Growth Oil", sku: "HAIR-OIL", price: 650, stock_qty: 25},
     %{name: "Face Mask (Charcoal)", sku: "MASK-CHAR", price: 350, stock_qty: 40},
     %{name: "Lipstick Set (6 colors)", sku: "LIP-SET", price: 1200, stock_qty: 15},
     %{name: "Nail Polish Set", sku: "NAIL-SET", price: 850, stock_qty: 20},
     %{name: "Body Lotion (500ml)", sku: "LOTION", price: 550, stock_qty: 35},
     %{name: "Perfume (50ml)", sku: "PERFUME", price: 2800, stock_qty: 10},
     %{name: "Hair Braids (Pack)", sku: "BRAIDS", price: 450, stock_qty: 50}
   ]},
  {"Karen Auto Garage",
   [
     %{name: "Engine Oil (5L)", sku: "OIL-5L", price: 2500, stock_qty: 20},
     %{name: "Brake Pads (Front)", sku: "BRAKE-F", price: 1800, stock_qty: 15},
     %{name: "Car Battery (75Ah)", sku: "BATT-75", price: 8500, stock_qty: 8},
     %{name: "Air Filter", sku: "AIR-FIL", price: 650, stock_qty: 25},
     %{name: "Spark Plugs (Set of 4)", sku: "SPARK-4", price: 1200, stock_qty: 18},
     %{name: "Tire (205/55 R16)", sku: "TIRE-205", price: 6500, stock_qty: 12},
     %{name: "Alternator", sku: "ALT", price: 12000, stock_qty: 5},
     %{name: "Shock Absorber", sku: "SHOCK", price: 4500, stock_qty: 8}
   ]}
]

Enum.each(additional_products, fn {shop_name, products} ->
  shop = shops_map[shop_name]

  if shop do
    Enum.each(products, fn product_attrs ->
      attrs =
        Map.merge(product_attrs, %{
          shop_id: shop.id,
          category_id: default_category.id,
          status: :active
        })

      case Repo.get_by(Product, shop_id: shop.id, sku: attrs.sku) do
        nil ->
          case %Product{}
               |> Product.changeset(attrs)
               |> Repo.insert() do
            {:ok, product} ->
              IO.puts("  Created #{product.name} in #{shop_name}")

            {:error, changeset} ->
              IO.puts("  Error creating #{attrs.name}: #{inspect(changeset.errors)}")
          end

        existing ->
          IO.puts("  Product exists: #{existing.name} in #{shop_name}")
      end
    end)
  else
    IO.puts("  Shop not found: #{shop_name}")
  end
end)

IO.puts("Additional products seeded")

# ── Seed demo customers ───────────────────────────────────────────────────────
IO.puts("Seeding demo customers...")

customers = [
  %{"name" => "John Kamau", "phone" => "+254711111111"},
  %{"name" => "Mary Wanjiku", "phone" => "+254722222222"},
  %{"name" => "Peter Ochieng", "phone" => "+254733333333"},
  %{"name" => "Sarah Achieng", "phone" => "+254744444444"},
  %{"name" => "David Mutua", "phone" => "+254755555555"}
]

all_shops = Repo.all(Shop)

Enum.each(all_shops, fn shop ->
  Enum.each(customers, fn customer_attrs ->
    unique_phone = "#{customer_attrs["phone"]}#{:rand.uniform(99)}"

    case Repo.get_by(SmartKioskCore.Schemas.Customer, shop_id: shop.id, phone: unique_phone) do
      nil ->
        %SmartKioskCore.Schemas.Customer{}
        |> SmartKioskCore.Schemas.Customer.changeset(
          Map.merge(customer_attrs, %{
            "shop_id" => shop.id,
            "phone" => unique_phone
          })
        )
        |> Repo.insert!()

      _ ->
        :ok
    end
  end)
end)

IO.puts("#{length(all_shops) * 5} customers seeded")

# ── Seed demo orders ──────────────────────────────────────────────────────────
IO.puts("Seeding demo orders...")

order_statuses = [:confirmed, :preparing, :ready, :dispatched, :delivered]

all_shops_with_products =
  Shop
  |> preload(:products)
  |> Repo.all()

Enum.each(all_shops_with_products, fn shop ->
  shop_customers =
    Repo.all(
      from(c in SmartKioskCore.Schemas.Customer,
        where: c.shop_id == ^shop.id,
        limit: 3
      )
    )

  shop_products = shop.products |> Enum.filter(&(&1.status == :active and &1.stock_qty > 0))

  if length(shop_customers) > 0 and length(shop_products) > 0 do
    # Create 3-5 orders per shop
    order_count = :rand.uniform(3) + 2

    Enum.each(1..order_count, fn _i ->
      customer = Enum.random(shop_customers)
      items_count = min(:rand.uniform(3) + 1, length(shop_products))
      selected_products = Enum.take_random(shop_products, items_count)

      order_items =
        Enum.map(selected_products, fn product ->
          qty = :rand.uniform(3)

          %{
            product_id: product.id,
            quantity: qty,
            unit_price: product.price,
            product_name: product.name
          }
        end)

      subtotal =
        Enum.reduce(order_items, Decimal.new("0"), fn item, acc ->
          line_total = Decimal.mult(Decimal.new(item.unit_price), Decimal.new(item.quantity))
          Decimal.add(acc, line_total)
        end)

      order_attrs = %{
        shop_id: shop.id,
        customer_id: customer.id,
        channel: :online,
        status: Enum.random(order_statuses),
        subtotal: subtotal,
        total: subtotal,
        delivery_address: "#{customer.name}'s Home, #{shop.city}",
        notes: "Demo order"
      }

      order =
        %Order{}
        |> Order.changeset(order_attrs)
        |> Repo.insert!()

      # Insert order items
      Enum.each(order_items, fn item_attrs ->
        %SmartKioskCore.Schemas.OrderItem{}
        |> SmartKioskCore.Schemas.OrderItem.changeset(Map.put(item_attrs, :order_id, order.id))
        |> Repo.insert!()
      end)
    end)
  end
end)

IO.puts("Orders seeded")

# ── Seed demo cart items ──────────────────────────────────────────────────────
IO.puts("Seeding demo cart items...")

# Add some items to cart for recommendation signals
Enum.each(all_shops_with_products, fn shop ->
  shop_products = shop.products |> Enum.filter(&(&1.status == :active and &1.stock_qty > 0))

  if length(shop_products) > 0 do
    # Add 2-4 random products to cart per shop
    cart_items_count = min(:rand.uniform(3) + 1, length(shop_products))
    selected_products = Enum.take_random(shop_products, cart_items_count)

    Enum.each(selected_products, fn product ->
      cart_attrs = %{
        product_id: product.id,
        shop_id: shop.id,
        product_name: product.name,
        unit_price: product.price,
        quantity: :rand.uniform(2),
        session_id: "demo-session-#{:rand.uniform(1000)}"
      }

      case Repo.get_by(SmartKioskCore.Schemas.CartItem,
             product_id: product.id,
             session_id: cart_attrs.session_id
           ) do
        nil ->
          %SmartKioskCore.Schemas.CartItem{}
          |> SmartKioskCore.Schemas.CartItem.changeset(cart_attrs)
          |> Repo.insert!()

        _ ->
          :ok
      end
    end)
  end
end)

IO.puts("Cart items seeded")

# ── Refresh recommendations ─────────────────────────────────────────────────────
IO.puts("Refreshing recommendations...")
SmartKioskCore.Recommendations.refresh_recommendations()
IO.puts("Recommendations refreshed")

IO.puts("All seeding complete.")
