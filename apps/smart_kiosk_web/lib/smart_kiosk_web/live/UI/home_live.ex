defmodule SmartKioskWeb.HomeLive do
  @moduledoc """
  Homepage with navbar, category filters sidebar, and product display.
  """
  use SmartKioskWeb, :live_view

  alias SmartKioskCore.Schemas.{Shop, Product}
  alias SmartKioskCore.Repo
  alias SmartKioskCore.Accounts
  alias SmartKioskCore.Cart
  import SmartKioskWeb.Sidebar
  import SmartKioskWeb.SearchBar
  import Ecto.Query

  @featured_categories [
    {:electronics, "Electronics"},
    {:groceries, "Groceries"},
    {:fruits, "Fresh Fruits"},
    {:vegetables, "Vegetables"},
    {:bakery, "Bakery"},
    {:restaurant, "Restaurants"},
    {:pharmacy, "Pharmacy"},
    {:cosmetics, "Cosmetics"}
  ]

  def mount(_params, _session, socket) do
    current_user = socket.assigns[:current_user]
    session_id = get_connect_params(socket)["session_id"]

    # Fetch user's shop if they have one assigned
    user_shop =
      if current_user do
        Accounts.get_shop_for_user(current_user)
      else
        nil
      end

    # Get all shop categories for filtering
    shop_categories = Shop.category_labels()

    # Get products grouped by featured categories
    products_by_category = fetch_products_by_categories()

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
     |> assign(:products_by_category, products_by_category)
     |> assign(:filtered_shops, nil)
     |> assign(:user_shop, user_shop)
     |> assign(:cart_count, cart_count)
     |> assign(:session_id, session_id)
     |> assign(:search_query, "")
     |> assign(:search_results, [])
     |> assign(:search_loading, false)}
  end

  def handle_params(params, _uri, socket) do
    category = params["category"]
    search_query = params["search"]

    cond do
      search_query && search_query != "" ->
        # Search mode: show search results
        decoded_query = URI.decode(search_query)
        search_results = perform_search(decoded_query)

        {:noreply,
         socket
         |> assign(:selected_category, nil)
         |> assign(:filtered_shops, nil)
         |> assign(:products_by_category, nil)
         |> assign(:search_query, decoded_query)
         |> assign(:search_results, search_results)
         |> assign(:search_loading, false)}

      category && category != "" ->
        # Filter mode: show shops in this category
        filtered_shops = fetch_shops_by_category(category)

        {:noreply,
         socket
         |> assign(:selected_category, category)
         |> assign(:filtered_shops, filtered_shops)
         |> assign(:products_by_category, nil)
         |> assign(:search_results, [])}

      true ->
        # Default mode: show products by category
        products_by_category = fetch_products_by_categories()

        {:noreply,
         socket
         |> assign(:selected_category, nil)
         |> assign(:filtered_shops, nil)
         |> assign(:products_by_category, products_by_category)
         |> assign(:search_results, [])}
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
     assign(socket, :cart_count, cart_count) |> put_flash(:info, "Added #{product.name} to cart")}
  end

  def handle_event("clear_filter", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/")}
  end

  def handle_event("search", %{"query" => query}, socket) do
    if String.trim(query) == "" do
      {:noreply,
        socket
        |> assign(:search_query, "")
        |> assign(:search_results, [])
        |> assign(:search_loading, false)}
    else
      {:noreply,
        socket
        |> assign(:search_query, query)
        |> assign(:search_loading, true)
        |> push_patch(to: ~p"/?search=#{URI.encode(query)}")}
    end
  end

  def handle_event("search_submit", %{"query" => query}, socket) do
    handle_event("search", %{"query" => query}, socket)
  end

  # Helper functions

  defp format_category_name(atom) do
    atom
    |> to_string()
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp selected_category_label(shop_categories, selected_category)
       when is_map(shop_categories) and is_binary(selected_category) do
    Enum.find_value(shop_categories, "Shops", fn {cat_key, label} ->
      if Atom.to_string(cat_key) == selected_category, do: label, else: nil
    end)
  end

  defp selected_category_label(_shop_categories, _selected_category), do: "Shops"

  defp fetch_products_by_categories do
    @featured_categories
    |> Enum.map(fn {category, _label} ->
      products =
        from(p in Product,
          join: s in assoc(p, :shop),
          where: s.category == ^category,
          where: p.status == :active,
          where: p.stock_qty > 0,
          preload: [:shop, :images],
          limit: 5,
          order_by: [desc: p.inserted_at]
        )
        |> Repo.all()

      {category, products}
    end)
    |> Enum.reject(fn {_cat, products} -> products == [] end)
  end

  defp fetch_shops_by_category(category) do
    from(s in Shop,
      where: s.category == ^category,
      where: s.status == :active,
      order_by: [desc: s.inserted_at],
      limit: 20
    )
    |> Repo.all()
  end

  defp perform_search(query) when is_binary(query) do
    search_term = "%#{query}%"

    # Search products
    products =
      from(p in Product,
        join: s in assoc(p, :shop),
        where: ilike(p.name, ^search_term) or ilike(p.description, ^search_term),
        where: p.status == :active,
        where: p.stock_qty > 0,
        where: s.status == :active,
        preload: [:shop, :images],
        limit: 10,
        order_by: [desc: p.inserted_at]
      )
      |> Repo.all()
      |> Enum.map(&Map.put(&1, :type, :product))

    # Search shops
    shops =
      from(s in Shop,
        where: ilike(s.name, ^search_term) or ilike(s.description, ^search_term),
        where: s.status == :active,
        limit: 5,
        order_by: [desc: s.inserted_at]
      )
      |> Repo.all()
      |> Enum.map(&Map.put(&1, :type, :shop))

    # Combine and sort results
    (products ++ shops)
    |> Enum.sort_by(& &1.inserted_at, :desc)
  end

  defp perform_search(_), do: []
end
