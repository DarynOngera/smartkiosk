defmodule SmartKioskWeb.StorefrontLive.Show do
  use SmartKioskWeb, :live_view

  alias SmartKioskCore.Catalogue
  alias SmartKioskCore.Schemas.Shop
  alias SmartKioskCore.Repo
  alias SmartKioskCore.Cart

  def mount(%{"slug" => slug, "id" => product_id}, _session, socket) do
    shop = Repo.get_by!(Shop, slug: slug)
    product = Catalogue.get_product!(shop, product_id)
    {:ok, socket |> assign(:page_title, product.name) |> assign(:shop, shop) |> assign(:product, product)}
  end

  def handle_event("add_to_cart", _params, socket) do
    current_user = socket.assigns[:current_user]
    session_id = get_connect_params(socket)["session_id"]

    product = socket.assigns.product

    opts =
      cond do
        current_user -> [user_id: current_user.id]
        session_id -> [session_id: session_id]
        true -> []
      end

    Cart.add_to_cart(product, 1, opts)

    {:noreply, put_flash(socket, :info, "Added #{product.name} to cart!")}
  end
end
