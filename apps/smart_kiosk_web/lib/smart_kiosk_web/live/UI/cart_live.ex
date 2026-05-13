defmodule SmartKioskWeb.CartLive do
  @moduledoc """
  Shopping cart page.

  Groups cart items by shop, then calls Orders.create_order/3 once per shop
  group on checkout. Cart items are only removed after ALL orders succeed.
  If any order fails (out-of-stock, invalid product) the user sees a specific
  error and the cart is left intact so they can correct it.
  """
  use SmartKioskWeb, :live_view

  alias SmartKioskCore.{Cart, Orders}
  import SmartKioskWeb.Navbar

  def mount(_params, _session, socket) do
    current_user = socket.assigns[:current_user]
    session_id = get_connect_params(socket)["session_id"]

    # Get cart items
    cart_items = load_cart(current_user, session_id)
    cart_total = Cart.calculate_cart_total(cart_items)

    # Pre-fill checkout form if user is logged in
    initial_checkout_params =
      %{
        "full_name" => (current_user && current_user.full_name) || "",
        "phone_number" => (current_user && current_user.phone) || ""
      }

    {:ok,
     socket
     |> assign(:page_title, "Shopping Cart · SmartKiosk")
     |> assign(:cart_items, cart_items)
     |> assign(:cart_total, cart_total)
     |> assign(:cart_count, length(cart_items))
     |> assign(:session_id, session_id)
     |> assign(:checkout_form, to_form(initial_checkout_params))
     |> assign(:checking_out, false)}
  end

  # cart mutations

  def handle_event("update_quantity", %{"id" => id, "quantity" => quantity}, socket) do
    quantity = String.to_integer(quantity)
    cart_item = Cart.get_cart_item!(id)

    if quantity > 0 do
      Cart.update_cart_item(cart_item, %{quantity: quantity, unit_price: cart_item.unit_price})
    else
      Cart.remove_cart_item(cart_item)
    end

    {:noreply, reload_cart(socket)}
  end

  def handle_event("remove_item", %{"id" => id}, socket) do
    id |> Cart.get_cart_item!() |> Cart.remove_cart_item()

    {:noreply, reload_cart(socket)}
  end

  # checkout
  def handle_event("checkout", %{"full_name" => name, "phone" => phone}, socket) do
    cart_items = socket.assigns.cart_items

    if cart_items == [] do
      {:noreply, socket |> put_flash(:error, "Cart is empty")}
    else
      socket = socket |> assign(:checking_out, true)
      do_checkout(socket, cart_items, name, phone)
    end
  end

  # checkout logic
  # Group items by shop, create one order per group, clear cart only on
  # full success. Returns {:noreply, socket}.
  defp do_checkout(socket, cart_items, name, phone) do
    current_user = socket.assigns[:current_user]

    # Group cart items by shop struct (items are preloaded with product: :shop)
    items_by_shop =
      cart_items
      |> Enum.group_by(fn item -> item.product.shop end)

    results =
      Enum.map(items_by_shop, fn {shop, items} ->
        # Resolve or create a customer record for this shop
        customer_id =
          case Orders.find_or_create_customer(shop, %{name: name, phone: phone}) do
            {:ok, customer} -> customer.id
            _               -> nil
          end

        # Build the {product, qty} pairs Orders.create_order/3 expects
        order_items = Enum.map(items, fn item -> {item.product, item.quantity} end)

        opts = [
          customer_id: customer_id,
          channel:     :online,
          user_id:     current_user && current_user.id
        ]

        case Orders.create_order(shop, order_items, opts) do
          {:ok, order}                           -> {:ok, shop, order}
          {:error, :invalid_cart}                -> {:error, shop, "Your cart is invalid."}
          {:error, {:insufficient_stock, _id}}   -> {:error, shop, "Sorry, one or more items in your #{shop.name} cart are out of stock."}
          {:error, {:invalid_product, _id}}      -> {:error, shop, "A product from #{shop.name} is no longer available."}
          {:error, _}                            -> {:error, shop, "Something went wrong placing your #{shop.name} order."}
        end
      end)

    errors  = Enum.filter(results, fn {status, _, _} -> status == :error end)
    success = Enum.filter(results, fn {status, _, _} -> status == :ok    end)

    socket = assign(socket, :checking_out, false)

    cond do
      # All orders failed — leave cart intact, show errors
      errors != [] && success == [] ->
        error_msg =
          errors
          |> Enum.map(fn {:error, _shop, msg} -> msg end)
          |> Enum.join(" ")

        {:noreply, put_flash(socket, :error, error_msg)}

      # Partial failure — remove only the successful shop's items
      errors != [] ->
        successful_shop_ids =
          success
          |> Enum.map(fn {:ok, shop, _order} -> shop.id end)
          |> MapSet.new()

        cart_items
        |> Enum.filter(fn item -> MapSet.member?(successful_shop_ids, item.product.shop.id) end)
        |> Enum.each(fn item -> Cart.remove_cart_item(item) end)

        error_msg =
          errors
          |> Enum.map(fn {:error, _shop, msg} -> msg end)
          |> Enum.join(" ")

        order_numbers =
          success
          |> Enum.map(fn {:ok, _shop, order} -> "##{String.slice(order.id, 0, 8)}" end)
          |> Enum.join(", ")

        {:noreply,
         socket
         |> reload_cart()
         |> put_flash(:info,  "Orders placed: #{order_numbers}.")
         |> put_flash(:error, error_msg)}

      # All succeeded — clear entire cart and redirect
      true ->
        Enum.each(cart_items, fn item -> Cart.remove_cart_item(item) end)

        order_numbers =
          success
          |> Enum.map(fn {:ok, _shop, order} -> "##{String.slice(order.id, 0, 8)}" end)
          |> Enum.join(", ")

        {:noreply,
         socket
         |> assign(:cart_items,    [])
         |> assign(:cart_total,    Decimal.new("0"))
         |> assign(:cart_count,    0)
         |> put_flash(:info, "🎉 Order#{if length(success) > 1, do: "s", else: ""} placed! #{order_numbers}")
         |> push_navigate(to: ~p"/")}
    end
  end


  # helper functions
  defp load_cart(current_user, session_id) do
    cond do
      current_user -> Cart.get_user_cart(current_user)
      session_id -> Cart.get_session_cart(session_id)
      true -> []
    end
  end

  defp reload_cart(socket) do
    current_user = socket.assigns[:current_user]
    session_id = socket.assigns[:session_id]

    cart_items = load_cart(current_user, session_id)
    cart_total = Cart.calculate_cart_total(cart_items)

    socket
    |> assign(:cart_items, cart_items)
    |> assign(:cart_total, cart_total)
    |> assign(:cart_count, length(cart_items))
  end
end
