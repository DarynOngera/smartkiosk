defmodule SmartKioskWeb.HomeLive do
  @moduledoc """
  Homepage with navbar, category filters sidebar, and product display.
  """
  use SmartKioskWeb, :live_view

  alias SmartKioskCore.Schemas.{Shop, Product}
  alias SmartKioskCore.Repo
  alias SmartKioskCore.Shops
  alias SmartKioskCore.Cart
  alias SmartKioskCore.Recommendations
  import SmartKioskWeb.Sidebar
  import SmartKioskWeb.SearchBar
  import Ecto.Query

  @featured_categories [
    {:electronics, "Electronics"},
    {:groceries, "Groceries"},
    {:fruits, "Fruits"},
    {:vegetables, "Vegetables"},
    {:bakery, "Bakery"},
    {:restaurant, "Restaurants"},
    {:pharmacy, "Pharmacy"},
    {:cosmetics, "Cosmetics"},
    {:hardware, "Hardware"},
    {:furniture, "Furniture"},
    {:services, "Services"},
    {:textiles, "Textiles"},
    {:garage, "Garage"}
  ]

  def mount(_params, session, socket) do
    current_user = socket.assigns[:current_user]
    session_id = session["session_id"] || (get_connect_params(socket) || %{})["session_id"]

    # Fetch user's shop if they have one assigned
    user_shop =
      if current_user do
        Shops.get_shop_for_user(current_user)
      else
        nil
      end

    # Get all shop categories for filtering
    shop_categories = Shop.category_labels()

    # Get products grouped by featured categories
    _products_by_category = fetch_products_by_categories()

    # Get precomputed recommendations
    recommended_shops = Recommendations.list_recommended_shops()
    recommended_products = Recommendations.list_recommended_products()

    # Get cart count
    cart_count =
      cond do
        current_user -> Cart.get_user_cart_count(current_user)
        session_id -> Cart.get_session_cart_count(session_id)
        true -> 0
      end

    {:ok,
     socket
     |> assign(:page_title, "SmartKiosk · Local Commerce")
     |> assign(:shop_categories, shop_categories)
     |> assign(:selected_category, nil)
     |> assign(:products_by_category, [])
     |> assign(:filtered_shops, nil)
     |> assign(:recommended_shops, recommended_shops)
     |> assign(:recommended_products, recommended_products)
     |> assign(:user_shop, user_shop)
     |> assign(:cart_count, cart_count)
     |> assign(:session_id, session_id)
     |> assign(:search_query, "")
     |> assign(:search_results, [])
     |> assign(:search_loading, false)
     |> assign(:page, 1)
     |> assign(:has_more, false)}
  end

  def handle_params(params, _uri, socket) do
    category = params["category"]
    page = String.to_integer(params["page"] || "1")
    limit = 12

    socket = assign(socket, page: page)

    if category && category != "" do
      # Filter mode: show shops in this category
      category_atom = safe_category_atom(category)

      if is_nil(category_atom) do
        {:noreply,
         socket
         |> assign(:selected_category, nil)
         |> assign(:filtered_shops, nil)
         |> assign(:search_query, "")}
      else
        filtered_shops = fetch_shops_by_category(category_atom)

        {:noreply,
         socket
         |> assign(:selected_category, category_atom)
         |> assign(:filtered_shops, filtered_shops)
         |> assign(:search_query, "")}
      end
    else
      # Home mode: show products by category with pagination
      products_by_category = fetch_products_by_categories(page: page, limit: limit)
      # Simplified check
      has_more = length(products_by_category) == limit

      {:noreply,
       socket
       |> assign(:selected_category, nil)
       |> assign(:filtered_shops, nil)
       |> assign(:products_by_category, products_by_category)
       |> assign(:has_more, has_more)
       |> assign(:search_query, "")}
    end
  end

  def handle_event("load-more", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/?page=#{socket.assigns.page + 1}")}
  end

  def handle_event("search", %{"query" => query}, socket) do
    if String.length(query) >= 2 do
      results = SmartKioskCore.Search.query_products(query)
      {:noreply, assign(socket, search_query: query, search_results: results)}
    else
      {:noreply, assign(socket, search_query: query, search_results: [])}
    end
  end

  def handle_event("search_submit", %{"query" => query}, socket) do
    case SmartKioskCore.Search.query_products(query) do
      [%{type: :product, shop: %{slug: shop_slug}} = first_result | _] ->
        path = ~p"/shop/#{shop_slug}/product/#{first_result.id}"
        {:noreply, push_navigate(socket, to: path)}

      [%{type: :shop, slug: slug} | _] ->
        path = ~p"/shop/#{slug}"
        {:noreply, push_navigate(socket, to: path)}

      [] ->
        {:noreply, socket}
    end
  end

  def handle_event("filter_category", %{"category" => category}, socket) do
    {:noreply, push_patch(socket, to: ~p"/?category=#{category}")}
  end

  def handle_event("add_to_cart", %{"product_id" => product_id}, socket) do
    current_user = socket.assigns[:current_user]
    session_id = socket.assigns[:session_id]

    product = Repo.get!(Product, product_id)

    opts =
      cond do
        current_user -> [user_id: current_user.id]
        session_id -> [session_id: session_id]
        true -> []
      end

    Cart.add_to_cart(product, 1, opts)

    cart_count =
      cond do
        current_user -> Cart.get_user_cart_count(current_user)
        session_id -> Cart.get_session_cart_count(session_id)
        true -> 0
      end

    {:noreply,
     socket
     |> assign(:cart_count, cart_count)
     |> put_flash(:info, "Added #{product.name} to cart")}
  end

  def handle_event("clear_filter", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/")}
  end

  # Helper functions

  defp format_category_name(atom) do
    atom
    |> to_string()
    |> String.split("_")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp selected_category_label(categories, category) do
    categories[category] || format_category_name(category)
  end

  defp safe_category_atom(category) when is_binary(category) do
    Shop.category_labels()
    |> Map.keys()
    |> Enum.find(fn key -> to_string(key) == category end)
  end

  defp safe_category_atom(_), do: nil

  defp fetch_products_by_categories(opts \\ []) do
    page = opts[:page] || 1
    limit = opts[:limit] || 12
    offset = (page - 1) * limit

    Enum.map(@featured_categories, fn {cat_slug, _label} ->
      products =
        Product
        |> join(:inner, [p], s in Shop, on: s.id == p.shop_id)
        |> where([p, s], s.category == ^cat_slug)
        |> where([p, s], p.status == :active)
        |> where([p, s], p.stock_qty > 0)
        |> order_by([p, s], desc: p.inserted_at)
        |> limit(^limit)
        |> offset(^offset)
        |> preload([:images, :shop])
        |> Repo.all()

      {cat_slug, products}
    end)
    |> Enum.reject(fn {_cat, products} -> Enum.empty?(products) end)
  end

  defp fetch_shops_by_category(category) when is_atom(category) do
    from(s in Shop,
      where: s.category == ^category,
      where: s.status == :active,
      order_by: [desc: s.inserted_at],
      limit: 20
    )
    |> Repo.all()
  end
end
