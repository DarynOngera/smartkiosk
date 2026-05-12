defmodule SmartKioskCore.Catalogue do
  @moduledoc """
  The Catalogue context.

  Manages products, categories, and inventory levels for a given shop.
  All queries are scoped to a shop via SmartKioskCore.Tenant.scope/2.
  """

  import Ecto.Query
  import SmartKioskCore.Tenant

  alias SmartKioskCore.Repo
  alias SmartKioskCore.Schemas.{Category, Product, ProductImage, Shop}

  # ── Categories ───────────────────────────────────────────────────────────────

  @doc "Lists all top-level categories with their children preloaded."
  def list_categories do
    from(c in Category,
      where: is_nil(c.parent_id),
      order_by: [asc: c.position, asc: c.name],
      preload: :children
    )
    |> Repo.all()
  end

  @doc "Gets a category by id. Raises if not found."
  def get_category!(id), do: Repo.get!(Category, id)

  @doc "Gets the attribute templates for a category (merges parent templates first)."
  def get_attribute_templates(%Category{parent_id: nil} = cat), do: cat.attribute_templates

  def get_attribute_templates(%Category{} = cat) do
    parent = Repo.get(Category, cat.parent_id)
    ((parent && parent.attribute_templates) || []) ++ cat.attribute_templates
  end

  @doc "Creates a category. Platform admin only."
  def create_category(attrs) do
    %Category{}
    |> Category.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Updates a category."
  def update_category(%Category{} = cat, attrs) do
    cat
    |> Category.changeset(attrs)
    |> Repo.update()
  end

  # ── Products ─────────────────────────────────────────────────────────────────

  @doc """
  Lists products for a shop with optional filters.

  Options:
    - status: atom or nil
    - category_id: uuid or nil
    - search: string or nil (matches name/sku/barcode)
    - low_stock: boolean
    - limit: integer (default 50)
    - offset: integer (default 0)
  """
  def list_products(%Shop{} = shop, opts \\ []) do
    Product
    |> scope(shop)
    |> filter_by_status(opts[:status])
    |> filter_by_category(opts[:category_id])
    |> filter_by_search(opts[:search])
    |> filter_low_stock(opts[:low_stock])
    |> order_by([p], asc: p.name)
    |> limit(^Keyword.get(opts, :limit, 50))
    |> offset(^Keyword.get(opts, :offset, 0))
    |> preload([:category, :images])
    |> Repo.all()
  end

  @doc "Counts products for a shop (respects same filters as list_products)."
  def count_products(%Shop{} = shop, opts \\ []) do
    Product
    |> scope(shop)
    |> filter_by_status(opts[:status])
    |> filter_by_category(opts[:category_id])
    |> filter_by_search(opts[:search])
    |> filter_low_stock(opts[:low_stock])
    |> Repo.aggregate(:count, :id)
  end

  @doc "Gets a product by id, scoped to a shop."
  def get_product!(%Shop{} = shop, id) do
    Product
    |> scope(shop)
    |> preload([:category, :images])
    |> Repo.get!(id)
  end

  @doc "Creates a product for a shop."
  def create_product(%Shop{} = shop, attrs) do
    %Product{}
    |> Product.changeset(Map.put(attrs, :shop_id, shop.id))
    |> Repo.insert()
  end

  #remove a product from inventory
  @doc "removes the product from the shop"
  def remove_product(%Product{} = product) do
    product
    |> Product.changeset(%{status: :archived})
    |> Repo.update()
  end

  @doc "Updates a product."
  def update_product(%Product{} = product, attrs) do
    product
    |> Product.changeset(attrs)
    |> Repo.update()
  end

  @doc "Archives a product (soft delete)."
  def archive_product(%Product{} = product) do
    product
    |> Product.changeset(%{status: :archived})
    |> Repo.update()
  end

  # ── Inventory ─────────────────────────────────────────────────────────────────

  @doc """
  Adjusts stock for a product by a delta (positive = restock, negative = sale).
  Returns {:error, changeset} if the result would be negative.
  Broadcasts a PubSub event if stock drops below the low_stock_threshold.
  """
  def adjust_stock(%Product{} = product, qty_delta) do
    product
    |> Product.stock_changeset(qty_delta)
    |> Repo.update()
    |> tap(&maybe_broadcast_low_stock/1)
  end

  @doc """
  Adjusts stock for multiple products atomically (used after an order is confirmed).
  Rolls back the entire transaction if any product would go negative.
  """
  def adjust_stock_bulk(items) do
    Repo.transaction(fn ->
      Enum.each(items, fn {product, qty_delta} ->
        case adjust_stock(product, qty_delta) do
          {:ok, _} -> :ok
          {:error, cs} -> Repo.rollback(cs)
        end
      end)
    end)
  end

  @doc "Lists products below their low_stock_threshold."
  def list_low_stock_products(%Shop{} = shop) do
    Product
    |> scope(shop)
    |> where([p], p.stock_qty <= p.low_stock_threshold and p.status == :active)
    |> order_by([p], asc: p.stock_qty)
    |> Repo.all()
  end

  # ── Product images ────────────────────────────────────────────────────────────

  @doc "Adds an image to a product."
  def add_product_image(%Product{} = product, attrs) do
    %ProductImage{}
    |> ProductImage.changeset(Map.put(attrs, :product_id, product.id))
    |> Repo.insert()
  end

  @spec remove_product_image(%SmartKioskCore.Schemas.ProductImage{}) :: {:ok, %SmartKioskCore.Schemas.ProductImage{}} | {:error, Ecto.Changeset.t()}
  @doc "Removes a product image."
  def remove_product_image(%ProductImage{} = image), do: Repo.delete(image)

  @doc "Reorders product images by position."
  def reorder_images(image_ids) when is_list(image_ids) do
    image_ids
    |> Enum.with_index(0)
    |> Enum.each(fn {id, pos} ->
      from(i in ProductImage, where: i.id == ^id)
      |> Repo.update_all(set: [position: pos])
    end)

    :ok
  end

  # ── Private filters ────────────────────────────────────────────────────────────

  defp filter_by_status(query, nil), do: query
  defp filter_by_status(query, status), do: where(query, [p], p.status == ^status)

  defp filter_by_category(query, nil), do: query
  defp filter_by_category(query, cat_id), do: where(query, [p], p.category_id == ^cat_id)

  defp filter_by_search(query, nil), do: query
  defp filter_by_search(query, ""), do: query

  defp filter_by_search(query, search) do
    term = "%#{search}%"
    where(query, [p], ilike(p.name, ^term) or ilike(p.sku, ^term) or ilike(p.barcode, ^term))
  end

  defp filter_low_stock(query, true) do
    where(query, [p], p.stock_qty <= p.low_stock_threshold)
  end

  defp filter_low_stock(query, _), do: query

  defp maybe_broadcast_low_stock({:ok, %Product{} = product}) do
    if product.stock_qty <= product.low_stock_threshold do
      Phoenix.PubSub.broadcast(
        SmartKiosk.PubSub,
        "shop:#{product.shop_id}:inventory",
        {:low_stock, product}
      )
    end
  end

  defp maybe_broadcast_low_stock(_), do: :ok
end
