defmodule SmartKioskWeb.StorefrontLive.Index do
  use SmartKioskWeb, :live_view

  alias SmartKioskCore.Catalogue
  alias SmartKioskCore.Accounts
  alias SmartKioskCore.Shops

  def mount(%{"slug" => slug}, _session, socket) do
    shop = Shops.get_shop_by_slug(slug)
    session_id = get_connect_params(socket)["session_id"]

    if shop do
      products =
        Catalogue.list_products(shop, status: :active)
        |> SmartKioskCore.Repo.preload(:images)

      {:ok,
       assign(socket,
         shop: shop,
         products: products,
         page_title: shop.name,
         session_id: session_id
       )}
    else
      {:ok, push_navigate(socket, to: ~p"/")}
    end
  end

  def handle_event("add_to_cart", %{"product_id" => product_id}, socket) do
    # Reuse existing cart logic
    product = SmartKioskCore.Repo.get!(SmartKioskCore.Schemas.Product, product_id)
    session_id = socket.assigns[:session_id]
    SmartKioskCore.Cart.add_to_cart(product, 1, session_id: session_id)

    {:noreply, put_flash(socket, :info, "Added #{product.name} to cart!")}
  end
end
