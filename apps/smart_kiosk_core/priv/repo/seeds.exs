alias SmartKioskCore.Repo
alias SmartKioskCore.Schemas.{Category, User, Shop, Subscription}

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

IO.puts("Seeding complete.")
