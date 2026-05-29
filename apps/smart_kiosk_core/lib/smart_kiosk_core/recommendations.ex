defmodule SmartKioskCore.Recommendations do
  @moduledoc """
  The Recommendations context.

  Manages precomputed recommendation scores for shops and products,
  refreshed periodically by an Oban worker.

  Personalized recommendations re-rank the global base scores using
  a 90-day user activity window (orders + carts). Guests and cold-start
  users fall back to the global trending list.
  """

  import Ecto.Query

  require Logger

  alias SmartKioskCore.Repo

  alias SmartKioskCore.Schemas.{
    Recommendation,
    Shop,
    Product,
    CartItem,
    OrderItem,
    Order,
    User,
    Customer
  }

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

  # Personalization tuning
  @affinity_boost_max 0.30
  @category_boost_max 0.10
  @shop_boost_for_product_max 0.15

  @order_weight 3.0
  @cart_weight 1.0
  @history_days 90

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
  Lists top recommended shops personalized for a user.
  Falls back to global popularity for guests and cold-start users.
  """
  def list_recommended_shops_for_user(user, limit \\ 8)
  def list_recommended_shops_for_user(nil, limit), do: list_recommended_shops(limit)

  def list_recommended_shops_for_user(%User{} = user, limit) do
    since = history_cutoff()
    profile = build_user_shop_profile(user.id, since)

    Logger.info(
      "Shop recommendations for user #{user.id} — profile empty?: #{profile.empty?}, shop_affinity: #{map_size(profile.shop_affinity)}, cat_affinity: #{map_size(profile.category_affinity)}"
    )

    if profile.empty? do
      Logger.info("Falling back to global shop recommendations for user #{user.id}")
      list_recommended_shops(limit)
    else
      from(r in Recommendation,
        where: r.type == :shop,
        preload: :shop
      )
      |> Repo.all()
      |> apply_personalized_ranking(&compute_shop_boost/2, profile)
      |> Enum.take(limit)
    end
  end

  @doc """
  Lists top recommended products personalized for a user.
  Falls back to global popularity for guests and cold-start users.
  """
  def list_recommended_products_for_user(user, limit \\ 10)
  def list_recommended_products_for_user(nil, limit), do: list_recommended_products(limit)

  def list_recommended_products_for_user(%User{} = user, limit) do
    since = history_cutoff()
    profile = build_user_product_profile(user.id, since)

    Logger.info(
      "Product recommendations for user #{user.id} — profile empty?: #{profile.empty?}, product_affinity: #{map_size(profile.product_affinity)}, shop_affinity: #{map_size(profile.shop_affinity)}, cat_affinity: #{map_size(profile.category_affinity)}"
    )

    if profile.empty? do
      Logger.info("Falling back to global product recommendations for user #{user.id}")
      list_recommended_products(limit)
    else
      from(r in Recommendation,
        where: r.type == :product,
        preload: [product: [:images, :shop]]
      )
      |> Repo.all()
      |> apply_personalized_ranking(&compute_product_boost/2, profile)
      |> Enum.take(limit)
    end
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

  # ── Personalization ────────────────────────────────────────────────────────────

  defp history_cutoff do
    DateTime.utc_now()
    |> DateTime.add(-@history_days * 24 * 60 * 60, :second)
    |> DateTime.truncate(:second)
  end

  defp build_user_shop_profile(user_id, since) do
    shop_affinity = fetch_shop_affinity(user_id, since)
    category_affinity = fetch_shop_category_affinity(user_id, since)

    %{
      shop_affinity: shop_affinity,
      category_affinity: category_affinity,
      empty?: map_size(shop_affinity) == 0 and map_size(category_affinity) == 0
    }
  end

  defp build_user_product_profile(user_id, since) do
    product_affinity = fetch_product_affinity(user_id, since)
    shop_affinity = fetch_shop_affinity(user_id, since)
    category_affinity = fetch_product_category_affinity(user_id, since)

    %{
      product_affinity: product_affinity,
      shop_affinity: shop_affinity,
      category_affinity: category_affinity,
      empty?:
        map_size(product_affinity) == 0 and
          map_size(shop_affinity) == 0 and
          map_size(category_affinity) == 0
    }
  end

  defp apply_personalized_ranking(recommendations, boost_fn, profile) do
    recommendations
    |> Enum.map(fn rec -> %{rec | score: rec.score + boost_fn.(rec, profile)} end)
    |> Enum.sort_by(fn rec -> rec.score end, :desc)
    |> Enum.with_index(1)
    |> Enum.map(fn {rec, rank} -> %{rec | rank: rank} end)
  end

  defp compute_shop_boost(%Recommendation{shop: %Shop{} = shop}, profile) do
    shop_score = Map.get(profile.shop_affinity, shop.id, 0)
    cat_score = Map.get(profile.category_affinity, shop.category, 0)

    max_shop = max(max_map_value(profile.shop_affinity), 1)
    max_cat = max(max_map_value(profile.category_affinity), 1)

    shop_boost = min(shop_score / max_shop, 1.0) * @affinity_boost_max
    cat_boost = min(cat_score / max_cat, 1.0) * @category_boost_max

    boost = shop_boost + cat_boost

    Logger.debug(
      "Shop boost for #{shop.id}: shop_score=#{shop_score}, cat_score=#{cat_score}, boost=#{boost}"
    )

    boost
  end

  defp compute_shop_boost(_, _), do: 0.0

  defp compute_product_boost(%Recommendation{product: %Product{} = product}, profile) do
    product_score = Map.get(profile.product_affinity, product.id, 0)
    shop_score = Map.get(profile.shop_affinity, product.shop_id, 0)
    cat_score = Map.get(profile.category_affinity, product.category_id, 0)

    max_product = max(max_map_value(profile.product_affinity), 1)
    max_shop = max(max_map_value(profile.shop_affinity), 1)
    max_cat = max(max_map_value(profile.category_affinity), 1)

    product_boost = min(product_score / max_product, 1.0) * @affinity_boost_max
    shop_boost = min(shop_score / max_shop, 1.0) * @shop_boost_for_product_max
    cat_boost = min(cat_score / max_cat, 1.0) * @category_boost_max

    boost = product_boost + shop_boost + cat_boost

    Logger.debug(
      "Product boost for #{product.id}: product_score=#{product_score}, shop_score=#{shop_score}, cat_score=#{cat_score}, boost=#{boost}"
    )

    boost
  end

  defp compute_product_boost(_, _), do: 0.0

  defp max_map_value(map) when map_size(map) == 0, do: 0
  defp max_map_value(map), do: map |> Map.values() |> Enum.max()

  # ── Affinity queries ─────────────────────────────────────────────────────────────

  defp fetch_shop_affinity(user_id, since) do
    order_counts =
      from(c in Customer,
        join: o in Order,
        on: o.customer_id == c.id,
        where:
          c.user_id == ^user_id and o.inserted_at >= ^since and
            o.status != :cancelled,
        group_by: o.shop_id,
        select: {o.shop_id, count(o.id)}
      )
      |> Repo.all()
      |> Enum.into(%{}, fn {shop_id, count} -> {shop_id, count * @order_weight} end)

    cart_counts =
      from(ci in CartItem,
        where: ci.user_id == ^user_id and ci.inserted_at >= ^since,
        group_by: ci.shop_id,
        select: {ci.shop_id, count(ci.id)}
      )
      |> Repo.all()
      |> Enum.into(%{}, fn {shop_id, count} -> {shop_id, count * @cart_weight} end)

    merge_affinities(order_counts, cart_counts)
  end

  defp fetch_product_affinity(user_id, since) do
    order_counts =
      from(c in Customer,
        join: o in Order,
        on: o.customer_id == c.id,
        join: oi in OrderItem,
        on: oi.order_id == o.id,
        where:
          c.user_id == ^user_id and o.inserted_at >= ^since and
            o.status != :cancelled,
        group_by: oi.product_id,
        select: {oi.product_id, sum(oi.quantity)}
      )
      |> Repo.all()
      |> Enum.into(%{}, fn {product_id, qty} ->
        {product_id, (qty || 0) * @order_weight}
      end)

    cart_counts =
      from(ci in CartItem,
        where: ci.user_id == ^user_id and ci.inserted_at >= ^since,
        group_by: ci.product_id,
        select: {ci.product_id, sum(ci.quantity)}
      )
      |> Repo.all()
      |> Enum.into(%{}, fn {product_id, qty} ->
        {product_id, (qty || 0) * @cart_weight}
      end)

    merge_affinities(order_counts, cart_counts)
  end

  defp fetch_shop_category_affinity(user_id, since) do
    from(c in Customer,
      join: o in Order,
      on: o.customer_id == c.id,
      join: s in Shop,
      on: s.id == o.shop_id,
      where:
        c.user_id == ^user_id and o.inserted_at >= ^since and
          o.status != :cancelled,
      group_by: s.category,
      select: {s.category, count(o.id)}
    )
    |> Repo.all()
    |> Enum.into(%{}, fn {cat, count} -> {cat, count * @order_weight} end)
  end

  defp fetch_product_category_affinity(user_id, since) do
    order_cats =
      from(c in Customer,
        join: o in Order,
        on: o.customer_id == c.id,
        join: oi in OrderItem,
        on: oi.order_id == o.id,
        join: p in Product,
        on: p.id == oi.product_id,
        where:
          c.user_id == ^user_id and o.inserted_at >= ^since and
            o.status != :cancelled,
        group_by: p.category_id,
        select: {p.category_id, count(oi.id)}
      )
      |> Repo.all()
      |> Enum.into(%{}, fn {cat_id, count} -> {cat_id, count * @order_weight} end)

    cart_cats =
      from(ci in CartItem,
        join: p in Product,
        on: p.id == ci.product_id,
        where: ci.user_id == ^user_id and ci.inserted_at >= ^since,
        group_by: p.category_id,
        select: {p.category_id, count(ci.id)}
      )
      |> Repo.all()
      |> Enum.into(%{}, fn {cat_id, count} -> {cat_id, count * @cart_weight} end)

    merge_affinities(order_cats, cart_cats)
  end

  defp merge_affinities(map1, map2) do
    Map.merge(map1, map2, fn _k, v1, v2 -> v1 + v2 end)
  end

  # ── Data fetching ──────────────────────────────────────────────────────────────

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
