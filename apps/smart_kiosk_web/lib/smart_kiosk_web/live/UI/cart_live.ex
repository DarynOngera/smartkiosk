defmodule SmartKioskWeb.CartLive do
  @moduledoc """
  Shopping cart page with item list and checkout form.
  """
  use SmartKioskWeb, :live_view

  alias SmartKioskCore.Cart
  import SmartKioskWeb.Navbar

  def mount(_params, _session, socket) do
    current_user = socket.assigns[:current_user]
    session_id = get_connect_params(socket)["session_id"]

    # Get cart items
    cart_items =
      cond do
        current_user -> Cart.get_user_cart(current_user)
        session_id -> Cart.get_session_cart(session_id)
        true -> []
      end

    # Calculate total
    cart_total = Cart.calculate_cart_total(cart_items)

    # Pre-fill checkout form if user is logged in
    initial_checkout_params =
      if current_user do
        %{
          full_name: current_user.full_name || "",
          phone_number: current_user.phone || ""
        }
      else
        %{
          full_name: "",
          phone_number: ""
        }
      end

    {:ok,
     socket
     |> assign(:page_title, "Shopping Cart · SmartKiosk")
     |> assign(:cart_items, cart_items)
     |> assign(:cart_total, cart_total)
     |> assign(:cart_count, length(cart_items))
     |> assign(:session_id, session_id)
     |> assign(
       :checkout_form,
       to_form(%{
         "full_name" => initial_checkout_params.full_name,
         "phone_number" => initial_checkout_params.phone_number
       })
     )}
  end

  def handle_event("update_quantity", %{"id" => id, "quantity" => quantity}, socket) do
    quantity = String.to_integer(quantity)
    cart_item = Cart.get_cart_item!(id)

    if quantity > 0 do
      {:ok, _updated_item} =
        Cart.update_cart_item(cart_item, %{quantity: quantity, unit_price: cart_item.unit_price})
    else
      Cart.remove_cart_item(cart_item)
    end

    # Reload cart
    current_user = socket.assigns[:current_user]
    session_id = socket.assigns[:session_id]

    cart_items =
      cond do
        current_user -> Cart.get_user_cart(current_user)
        session_id -> Cart.get_session_cart(session_id)
        true -> []
      end

    cart_total = Cart.calculate_cart_total(cart_items)

    {:noreply,
     socket
     |> assign(:cart_items, cart_items)
     |> assign(:cart_total, cart_total)
     |> assign(:cart_count, length(cart_items))}
  end

  def handle_event("remove_item", %{"id" => id}, socket) do
    cart_item = Cart.get_cart_item!(id)
    Cart.remove_cart_item(cart_item)

    # Reload cart
    current_user = socket.assigns[:current_user]
    session_id = socket.assigns[:session_id]

    cart_items =
      cond do
        current_user -> Cart.get_user_cart(current_user)
        session_id -> Cart.get_session_cart(session_id)
        true -> []
      end

    cart_total = Cart.calculate_cart_total(cart_items)

    {:noreply,
     socket
     |> assign(:cart_items, cart_items)
     |> assign(:cart_total, cart_total)
     |> assign(:cart_count, length(cart_items))}
  end

  def handle_event("checkout", %{"full_name" => _name, "phone_number" => _phone}, socket) do
    # Simulate successful checkout by clearing cart
    cart_items = socket.assigns.cart_items
    Enum.each(cart_items, fn item -> Cart.remove_cart_item(item) end)

    {:noreply,
     socket
     |> assign(:cart_items, [])
     |> assign(:cart_total, Decimal.new("0"))
     |> assign(:cart_count, 0)
     |> put_flash(:info, "Order placed successfully! Checkout simulation complete.")
     |> push_navigate(to: ~p"/")}
  end
end
