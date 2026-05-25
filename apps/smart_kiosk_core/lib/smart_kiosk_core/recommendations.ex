defmodule SmartKioskCore.Recommendations do
  @moduledoc """
  The Recommendations context.

  Manages precomputed recommendation scores for shops and products,
  refreshed periodically by an Oban worker.
  """

  import Ecto.Query

  alias SmartKioskCore.Repo
  alias SmartKioskCore.Schemas.{Recommendation, Shop, Product, CartItem, OrderItem, Order}

  @shop_weights %{
    plan: 0.30,
    cart_additions: 0.30,
    order_history: 0.20,
    recency: 0.10,
    featured: 0.10
  }

  @product_weights %{
    plan: 0.30,
    cart_additions: 0.30,
    order_history: 0.20,
    recency: 0.10,
    featured: 0.10
  }

  @plan_scores %{basic: 0.33, pro: 0.66, enterprise: 1.0}

  # ── Public API ────────────────────────────────────────────────────────────────

  @doc "Lists top recommended shops, preloaded."
  def list_recommended_shops(limit \\ 8) do
    from(r in Recommendation,
      where: r.type == :shop,
      order_by: [asc: r.rank],
      limit: ^limit,
      preload: :shop
    )
    |> Repo.all()
  end

  @doc "Lists top recommended products, preloaded."
  def list_recommended_products(limit \\ 10) do
    from(r in Recommendation,
      where: r.type == :product,
      order_by: [asc: r.rank],
      limit: ^limit,
      preload: [product: [:images, :shop]]
    )
    |> Repo.all()
  end

  @doc """
  Atomically refreshes all recommendation scores.

  1. Deletes existing recommendations.
  2. Computes scores for all active shops and in-stock products.
  3. Inserts new ranked recommendations in a transaction.
  """
  def refresh_recommendations do
    active_shops = fetch_active_shops()
    active_products = fetch_active_products()

    cart_counts = fetch_cart_counts()
    order_counts = fetch_order_counts()

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    shop_recs =
      active_shops
      |> Enum.map(fn shop ->
        cart_count = Map.get(cart_counts, {:shop, shop.id}, 0)
        order_count = Map.get(order_counts, {:shop, shop.id}, 0)
        score = compute_shop_score(shop, cart_count, order_count, now)
        {shop, score}
      end)
      |> Enum.sort_by(fn {_shop, score} -> score end, :desc)
      |> Enum.with_index(1)
      |> Enum.map(fn {{shop, score}, rank} ->
        %{
          id: Ecto.UUID.generate(),
          type: :shop,
          shop_id: shop.id,
          score: score,
          rank: rank,
          metadata: %{},
          inserted_at: now,
          updated_at: now
        }
      end)

    product_recs =
      active_products
      |> Enum.map(fn product ->
        cart_count = Map.get(cart_counts, {:product, product.id}, 0)
        order_count = Map.get(order_counts, {:product, product.id}, 0)
        score = compute_product_score(product, cart_count, order_count, now)
        {product, score}
      end)
      |> Enum.sort_by(fn {_product, score} -> score end, :desc)
      |> Enum.with_index(1)
      |> Enum.map(fn {{product, score}, rank} ->
        %{
          id: Ecto.UUID.generate(),
          type: :product,
          shop_id: product.shop_id,
          product_id: product.id,
          score: score,
          rank: rank,
          metadata: %{},
          inserted_at: now,
          updated_at: now
        }
      end)

    Repo.transaction(fn ->
      Repo.delete_all(Recommendation)

      if shop_recs != [] do
        Repo.insert_all(Recommendation, shop_recs)
      end

      if product_recs != [] do
        Repo.insert_all(Recommendation, product_recs)
      end
    end)
  end

  # ── Score computation ──────────────────────────────────────────────────────────

  defp compute_shop_score(%Shop{} = shop, cart_count, order_count, now) do
    plan = Shop.canonical_plan(shop.plan)
    plan_score = Map.get(@plan_scores, plan, 0.33)

    max_cart = max(cart_count, 1)
    max_orders = max(order_count, 1)
    norm_cart = min(cart_count / (max_cart * 2), 1.0)
    norm_orders = min(order_count / (max_orders * 2), 1.0)

    days_since = days_since(shop.inserted_at, now)
    recency_score = max(0.0, 1.0 - days_since / 90.0)

    featured_score = if shop.plan in [:pro, :enterprise], do: 1.0, else: 0.5

    plan_score * @shop_weights.plan +
      norm_cart * @shop_weights.cart_additions +
      norm_orders * @shop_weights.order_history +
      recency_score * @shop_weights.recency +
      featured_score * @shop_weights.featured
  end

  defp compute_product_score(%Product{} = product, cart_count, order_count, now) do
    plan =
      if Ecto.assoc_loaded?(product.shop) do
        Shop.canonical_plan(product.shop.plan)
      else
        :basic
      end

    plan_score = Map.get(@plan_scores, plan, 0.33)

    max_cart = max(cart_count, 1)
    max_orders = max(order_count, 1)
    norm_cart = min(cart_count / (max_cart * 2), 1.0)
    norm_orders = min(order_count / (max_orders * 2), 1.0)

    days_since = days_since(product.inserted_at, now)
    recency_score = max(0.0, 1.0 - days_since / 90.0)

    featured_score = if product.is_featured, do: 1.0, else: 0.5

    plan_score * @product_weights.plan +
      norm_cart * @product_weights.cart_additions +
      norm_orders * @product_weights.order_history +
      recency_score * @product_weights.recency +
      featured_score * @product_weights.featured
  end

  defp days_since(%DateTime{} = inserted_at, %DateTime{} = now) do
    DateTime.diff(now, inserted_at, :day)
  end

  defp days_since(_inserted_at, _now), do: 0

  # ── Data fetching ────────────────────────────────────────────────────────────

  defp fetch_active_shops do
    from(s in Shop, where: s.status == :active)
    |> Repo.all()
  end

  defp fetch_active_products do
    from(p in Product,
      join: s in Shop,
      on: p.shop_id == s.id,
      where: p.status == :active and p.stock_qty > 0 and s.status == :active,
      preload: [:shop]
    )
    |> Repo.all()
  end

  defp fetch_cart_counts do
    shop_counts =
      from(c in CartItem, group_by: c.shop_id, select: {c.shop_id, count(c.id)})
      |> Repo.all()
      |> Enum.into(%{}, fn {shop_id, count} -> {{:shop, shop_id}, count} end)

    product_counts =
      from(c in CartItem, group_by: c.product_id, select: {c.product_id, count(c.id)})
      |> Repo.all()
      |> Enum.into(%{}, fn {product_id, count} -> {{:product, product_id}, count} end)

    Map.merge(shop_counts, product_counts)
  end

  defp fetch_order_counts do
    shop_counts =
      from(oi in OrderItem,
        join: o in Order,
        on: oi.order_id == o.id,
        where: o.status not in [:pending, :cancelled],
        group_by: o.shop_id,
        select: {o.shop_id, count(oi.id)}
      )
      |> Repo.all()
      |> Enum.into(%{}, fn {shop_id, count} -> {{:shop, shop_id}, count} end)

    product_counts =
      from(oi in OrderItem,
        join: o in Order,
        on: oi.order_id == o.id,
        where: o.status not in [:pending, :cancelled],
        group_by: oi.product_id,
        select: {oi.product_id, count(oi.id)}
      )
      |> Repo.all()
      |> Enum.into(%{}, fn {product_id, count} -> {{:product, product_id}, count} end)

    Map.merge(shop_counts, product_counts)
  end
end
