defmodule SmartKioskWeb.StorefrontLive.Index do
  use SmartKioskWeb, :live_view

  alias SmartKioskCore.Catalogue
  alias SmartKioskCore.Cart
  alias SmartKioskCore.Repo
  alias SmartKioskCore.Schemas.Product
  alias SmartKioskCore.Shops

  def mount(%{"slug" => slug}, session, socket) do
    shop = Shops.get_shop_by_slug(slug)
    session_id = session["session_id"] || (get_connect_params(socket) || %{})["session_id"]

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
    product = Repo.get!(Product, product_id)

    with {:ok, opts} <- cart_opts(socket),
         {:ok, _item} <- Cart.add_to_cart(product, 1, opts) do
      {:noreply,
       socket
       |> assign(:cart_count, cart_count(socket))
       |> put_flash(:info, "Added #{product.name} to cart!")}
    else
      {:error, :missing_cart_owner} ->
        {:noreply,
         put_flash(socket, :error, "Could not start your cart. Please refresh and try again.")}

      {:error, changeset} ->
        {:noreply,
         put_flash(socket, :error, "Could not add to cart: #{inspect(changeset.errors)}")}
    end
  end

  defp cart_opts(socket) do
    current_user = socket.assigns[:current_user]
    session_id = socket.assigns[:session_id]

    cond do
      current_user -> {:ok, [user_id: current_user.id]}
      session_id -> {:ok, [session_id: session_id]}
      true -> {:error, :missing_cart_owner}
    end
  end

  defp cart_count(socket) do
    current_user = socket.assigns[:current_user]
    session_id = socket.assigns[:session_id]

    cond do
      current_user -> Cart.get_user_cart_count(current_user)
      session_id -> Cart.get_session_cart_count(session_id)
      true -> 0
    end
  end
end
