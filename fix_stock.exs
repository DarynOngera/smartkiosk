# Script to update stock quantities for existing products
alias SmartKioskCore.Repo
alias SmartKioskCore.Schemas.{Shop, Product}

products_by_shop = %{
  "Mama Grace Shop" => [
    %{sku: "RICE-5KG", stock_qty: 100},
    %{sku: "SUGAR-2KG", stock_qty: 80},
    %{sku: "OIL-1L", stock_qty: 50},
    %{sku: "BREAD-400G", stock_qty: 30},
    %{sku: "MILK-500ML", stock_qty: 40},
    %{sku: "FLOUR-2KG", stock_qty: 60},
    %{sku: "OMO-1KG", stock_qty: 25},
    %{sku: "COLGATE", stock_qty: 20},
    %{sku: "TEA-100G", stock_qty: 50},
    %{sku: "SALT-1KG", stock_qty: 100}
  ],
  "Test Owner's Shop" => [
    %{sku: "CHARGER-TC", stock_qty: 15},
    %{sku: "USB-1M", stock_qty: 30},
    %{sku: "POWERBANK-10K", stock_qty: 10},
    %{sku: "EARPHONES", stock_qty: 25},
    %{sku: "SCREEN-GUARD", stock_qty: 50},
    %{sku: "SD-64GB", stock_qty: 20},
    %{sku: "CASE-GENERIC", stock_qty: 40},
    %{sku: "HDMI-2M", stock_qty: 15},
    %{sku: "MOUSE", stock_qty: 20},
    %{sku: "KEYBOARD", stock_qty: 12}
  ],
  "Test2 Owner's Shop" => [
    %{sku: "UGALI", stock_qty: 100},
    %{sku: "CHAPATI", stock_qty: 150},
    %{sku: "PILAU", stock_qty: 80},
    %{sku: "BEEF-STEW", stock_qty: 50},
    %{sku: "CHICKEN-QUARTER", stock_qty: 40},
    %{sku: "SODA-500ML", stock_qty: 60},
    %{sku: "WATER-500ML", stock_qty: 100},
    %{sku: "MANDAZI", stock_qty: 200},
    %{sku: "SAMOSA", stock_qty: 80},
    %{sku: "CHAI", stock_qty: 100}
  ]
}

Enum.each(products_by_shop, fn {shop_name, products} ->
  case Repo.get_by(Shop, name: shop_name) do
    nil ->
      IO.puts("Shop not found: #{shop_name}")
    shop ->
      Enum.each(products, fn %{sku: sku, stock_qty: qty} ->
        case Repo.get_by(Product, shop_id: shop.id, sku: sku) do
          nil ->
            IO.puts("  Product not found: #{sku}")
          product ->
            product
            |> Product.changeset(%{stock_qty: qty})
            |> Repo.update!()
            IO.puts("  Updated #{product.name}: stock_qty = #{qty}")
        end
      end)
  end
end)

IO.puts("Stock quantities updated!")
