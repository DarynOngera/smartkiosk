defmodule SmartKioskWeb.StorefrontLive.Show do
  use SmartKioskWeb, :live_view

  alias SmartKioskCore.Accounts
  alias SmartKioskCore.Catalogue
  alias SmartKioskCore.Cart

  def mount(%{"slug" => slug, "id" => id}, _session, socket) do
    shop = Accounts.get_shop_by_slug(slug)
    session_id = get_connect_params(socket)["session_id"]

    if shop do
      product = Catalogue.get_product!(shop, id)

      in_stock = product.status == :active && product.stock_qty > 0
      max_qty = if in_stock, do: product.stock_qty, else: 1

      {:ok,
       socket
       |> assign(:shop, shop)
       |> assign(:product, product)
       |> assign(:in_stock, in_stock)
       |> assign(:max_qty, max_qty)
       |> assign(:quantity, 1)
       |> assign(:session_id, session_id)
       |> assign(:page_title, product.name)}
    else
      {:ok, push_navigate(socket, to: ~p"/")}
    end
  end

  def handle_event("add_to_cart", %{"quantity" => quantity}, socket) do
    product = socket.assigns.product
    qty = max(1, String.to_integer(quantity))
    session_id = socket.assigns[:session_id]
    current_user = socket.assigns[:current_user]

    opts =
      if current_user do
        [user_id: current_user.id]
      else
        [session_id: session_id]
      end

    case Cart.add_to_cart(product, qty, opts) do
      {:ok, _item} ->
        {:noreply,
         socket
         |> put_flash(:info, "Added #{qty} × #{product.name} to cart!")
         |> assign(:quantity, 1)}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Could not add to cart: #{inspect(changeset.errors)}")}
    end
  end

  def handle_event("set_quantity", %{"quantity" => quantity}, socket) do
    qty = String.to_integer(quantity)
    max_qty = socket.assigns.max_qty

    {:noreply,
     socket
     |> assign(:quantity, max(1, min(qty, max_qty)))}
  end
end
