# Seeds: bakery products bulk insert
# Run with:
#   mix run apps/smart_kiosk_core/priv/repo/seeds/bakery_products.exs

alias SmartKioskCore.{Repo, Shops, Catalogue}
alias SmartKioskCore.Schemas.{Category}
import Ecto.Query

shop = Shops.get_shop_by_name("Kazuto Kirigaya's Shop")
if is_nil(shop) do
  IO.puts("Shop not found: Kazuto Kirigaya's Shop. Please create it first.")
  System.halt(1)
end

# Try to find a reasonable category for bakery products
category = Repo.get_by(Category, slug: "food-beverages") || Repo.one(from c in Category, limit: 1)
if is_nil(category) do
  IO.puts("No category found to assign products to. Please create a category first.")
  System.halt(1)
end

templates = [
  "Chocolate Cookie",
  "Butter Cookie",
  "Oatmeal Cookie",
  "Chocolate Cake",
  "Vanilla Cake",
  "Red Velvet Cake",
  "Cupcake",
  "Donut",
  "Brownie",
  "Macaron",
  "Scone",
  "Croissant",
  "Muffin",
  "Candy",
  "Cheesecake",
  "Bundt Cake",
  "Eclair",
  "Tart",
  "Puff Pastry",
  "Danish"
]

# Helper to slugify names for SKUs
slugify = fn name ->
  name
  |> String.downcase()
  |> String.replace(~r/[^a-z0-9]+/, "-")
  |> String.replace(~r/-+/, "-")
  |> String.trim("-")
end

count = String.to_integer(System.get_env("BATCH") || "1000")

1..count
|> Enum.each(fn i ->
  base = Enum.at(templates, rem(i, length(templates)))
  name = "#{base} #{i}"
  sku = "#{slugify.(name)}-#{i}"

  price_cents = Enum.random(80..3000) # in cents
  price = Decimal.new(price_cents) |> Decimal.div(100)
  cost_cents = max(10, price_cents - Enum.random(10..200))
  cost_price = Decimal.new(cost_cents) |> Decimal.div(100)

  attrs = %{
    "name" => name,
    "description" => "Freshly baked #{base} — delicious and made to order.",
    "sku" => sku,
    "price" => price,
    "cost_price" => cost_price,
    "stock_qty" => Enum.random(20..200),
    "low_stock_threshold" => 20,
    "status" => "active",
    "is_featured" => false,
    "category_id" => category.id
  }

  case Catalogue.create_product(shop, attrs) do
    {:ok, _product} ->
      if rem(i, 100) == 0 do
        IO.puts("Inserted #{i} products")
      end

    {:error, changeset} ->
      IO.puts("Failed inserting product #{name}: #{inspect(changeset.errors)}")
  end
end)

IO.puts("Done inserting #{count} bakery products for shop #{shop.name}")
