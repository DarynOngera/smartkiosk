defmodule SmartKioskWeb.CartLive do
  @moduledoc """
  Shopping cart page.

  Groups cart items by shop, then calls Orders.create_order/3 once per shop
  group on checkout. Cart items are only removed after ALL orders succeed.
  If any order fails (out-of-stock, invalid product) the user sees a specific
  error and the cart is left intact so they can correct it.
  """
  use SmartKioskWeb, :live_view

  alias SmartKioskCore.{Cart, Deliveries, Orders}
  alias SmartKioskCore.Repo
  import SmartKioskWeb.Navbar

  @impl true
  def mount(_params, session, socket) do
    current_user = socket.assigns[:current_user]
    session_id = session["session_id"] || (get_connect_params(socket) || %{})["session_id"]

    # Get cart items
    cart_items = load_cart(current_user, session_id)
    cart_total = Cart.calculate_cart_total(cart_items)
    delivery_zones_by_shop = load_delivery_zones(cart_items)

    # Pre-fill checkout form if user is logged in
    initial_checkout_params = %{
      "full_name" => (current_user && current_user.full_name) || "",
      "phone_number" => (current_user && current_user.phone) || ""
    }

    {:ok,
     socket
     |> assign(:page_title, "Shopping Cart · SmartKiosk")
     |> assign(:cart_items, cart_items)
     |> assign(:cart_total, cart_total)
     |> assign(:cart_count, length(cart_items))
     |> assign(:delivery_zones_by_shop, delivery_zones_by_shop)
     |> assign(:session_id, session_id)
     |> assign(:checkout_form, to_form(initial_checkout_params))
     |> assign(:checking_out, false)
     |> assign(:show_receipt, false)
     |> assign(:order, nil)
     |> assign(:created_orders, [])
     |> assign(:payment_started, false)
     |> assign(:show_payment_selection, false)
     |> assign(:checkout_params, nil)
     |> assign(:mpesa_modal_open, false)
     |> assign(:mpesa_pending, false)
     |> assign(:mpesa_phone, nil)
     |> assign(:mpesa_result, nil)
     |> assign(:card_modal_open, false)
     |> assign(:card_pending, false)
     |> assign(:card_result, nil)
     |> assign(:rider_location, nil)}
  end

  # ── Events ──────────────────────────────────────────────────────────────────

  @impl true
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

  @impl true
  def handle_event("remove_item", %{"id" => id}, socket) do
    id |> Cart.get_cart_item!() |> Cart.remove_cart_item()

    {:noreply, reload_cart(socket)}
  end

  @impl true
  def handle_event("checkout", params, socket) do
    cart_items = socket.assigns.cart_items

    if cart_items == [] do
      {:noreply, socket |> put_flash(:error, "Cart is empty")}
    else
      name = Map.get(params, "full_name", "")
      phone = Map.get(params, "phone_number", "")
      shop_delivery = Map.get(params, "shop_delivery", %{})

      # Store checkout params for later use after payment
      # Also update the checkout_form to preserve form values
      {:noreply,
       socket
       |> assign(:checkout_params, %{name: name, phone: phone, shop_delivery: shop_delivery})
       |> assign(:show_payment_selection, true)
       |> assign(:checkout_form, to_form(%{"full_name" => name, "phone_number" => phone}))}
    end
  end

  @impl true
  def handle_event("print_receipt", %{"order-id" => _order_id}, socket) do
    push_event(socket, "print_receipt", %{})
    {:noreply, socket}
  end

  @impl true
  def handle_event("share_receipt", _params, socket) do
    order = socket.assigns[:order]
    text = build_text_receipt(order)
    push_event(socket, "share", %{text: text})
    {:noreply, socket}
  end

  @impl true
  def handle_event("new_order", _params, socket) do
    # reset cart view and return the shopper to the home page
    {:noreply,
     socket
     |> assign(:cart_items, [])
     |> assign(:cart_total, Decimal.new("0"))
     |> assign(:cart_count, 0)
     |> assign(:show_receipt, false)
     |> push_navigate(to: ~p"/")}
  end

  @impl true
  def handle_event("start_payment", %{"method" => method}, socket) do
    # Open the appropriate modal (M-Pesa or Card). The modal handlers will
    # initiate the gateway flow (simulated) and mark transactions pending.
    case method do
      "mpesa" ->
        phone = socket.assigns[:current_user] && socket.assigns.current_user.phone

        {:noreply,
         socket
         |> assign(:show_payment_selection, false)
         |> assign(mpesa_modal_open: true, mpesa_phone: phone, mpesa_pending: false)}

      "card" ->
        {:noreply,
         socket
         |> assign(:show_payment_selection, false)
         |> assign(card_modal_open: true, card_pending: false)}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("show_mpesa_modal", _params, socket) do
    {:noreply, assign(socket, :mpesa_modal_open, true)}
  end

  @impl true
  def handle_event("close_mpesa_modal", _params, socket) do
    {:noreply, assign(socket, mpesa_modal_open: false, mpesa_pending: false, mpesa_phone: nil)}
  end

  @impl true
  def handle_event("submit_mpesa", %{"mpesa" => %{"phone" => phone}}, socket) do
    # simulate an STK push for the created orders
    created_orders = socket.assigns[:created_orders] || []

    total =
      created_orders
      |> Enum.reduce(Decimal.new("0"), fn o, acc ->
        acc
        |> Decimal.add(
          Decimal.add(o.subtotal || Decimal.new("0"), o.delivery_fee || Decimal.new("0"))
        )
      end)

    ref = :erlang.unique_integer([:positive])
    Process.send_after(self(), {:mpesa_stk_result, ref, phone, total}, 2_000)

    {:noreply,
     socket
     |> put_flash(:info, "Simulated STK Push sent to #{phone}. Waiting for confirmation...")
     |> assign(mpesa_modal_open: true, mpesa_pending: true, mpesa_phone: phone, mpesa_result: nil)}
  end

  @impl true
  def handle_event("show_card_modal", _params, socket) do
    {:noreply, assign(socket, :card_modal_open, true)}
  end

  @impl true
  def handle_event("close_card_modal", _params, socket) do
    {:noreply, assign(socket, card_modal_open: false, card_pending: false, card_result: nil)}
  end

  @impl true
  def handle_event("submit_card", %{"card" => card_params}, socket) do
    created_orders = socket.assigns[:created_orders] || []

    total =
      created_orders
      |> Enum.reduce(Decimal.new("0"), fn o, acc ->
        acc
        |> Decimal.add(
          Decimal.add(o.subtotal || Decimal.new("0"), o.delivery_fee || Decimal.new("0"))
        )
      end)

    card_number = Map.get(card_params, "number", "") |> String.trim()

    if card_number == "" do
      {:noreply, socket |> put_flash(:error, "Card number required")}
    else
      ref = :erlang.unique_integer([:positive])
      Process.send_after(self(), {:card_result, ref, card_number, total}, 1_500)

      {:noreply,
       socket
       |> put_flash(:info, "Processing card payment...")
       |> assign(card_modal_open: true, card_pending: true, card_result: nil)}
    end
  end

  @impl true
  def handle_event("confirm_payment", _params, socket) do
    created_orders = socket.assigns[:created_orders] || []

    case List.first(created_orders) do
      nil ->
        {:noreply, put_flash(socket, :error, "No created orders to confirm.")}

      order ->
        order = Repo.preload(order, [:shop, items: :product, transactions: []])

        # Clear the cart now that payment is confirmed
        socket.assigns.cart_items |> Enum.each(&Cart.remove_cart_item/1)

        {:noreply,
         socket
         |> assign(:cart_items, [])
         |> assign(:cart_total, Decimal.new("0"))
         |> assign(:cart_count, 0)
         |> assign(:order, order)
         |> assign(:show_receipt, true)
         |> assign(:created_orders, [])}
    end
  end

  # ── Internal Helpers ─────────────────────────────────────────────────────────

  # Group items by shop, create one order per group, clear cart only on
  # full success. Returns {:noreply, socket}.
  defp do_checkout(socket, cart_items, name, phone, shop_delivery) do
    current_user = socket.assigns[:current_user]

    # Group cart items by shop struct (items are preloaded with product: :shop)
    items_by_shop = Enum.group_by(cart_items, fn item -> item.product.shop end)

    results =
      Enum.map(items_by_shop, fn {shop, items} ->
        # Resolve or create a customer record for this shop
        customer_attrs = %{
          name: name,
          phone: phone,
          user_id: current_user && current_user.id
        }

        customer_id =
          case Orders.find_or_create_customer(shop, customer_attrs) do
            {:ok, customer} -> customer.id
            _ -> nil
          end

        # Build the {product, qty} pairs Orders.create_order/3 expects
        order_items = Enum.map(items, fn item -> {item.product, item.quantity} end)

        delivery =
          (Map.get(shop_delivery, shop.id) ||
             Map.get(shop_delivery, to_string(shop.id), %{}))
          |> normalize_delivery_params()

        opts = [
          customer_id: customer_id,
          channel: :online,
          user_id: current_user && current_user.id,
          delivery: delivery
        ]

        case Orders.create_order(shop, order_items, opts) do
          {:ok, order} ->
            {:ok, shop, order}

          {:error, :invalid_cart} ->
            {:error, shop, "Your cart is invalid."}

          {:error, :missing_delivery_zone} ->
            {:error, shop, "Please choose a delivery zone for #{shop.name}."}

          {:error, :missing_delivery_point} ->
            {:error, shop, "Please choose a delivery point before checking out."}

          {:error, :delivery_point_outside_zone} ->
            {:error, shop, "Your delivery point must be inside #{shop.name}'s delivery zone."}

          {:error, :unresolved_delivery_point} ->
            {:error, shop,
             "We could not locate that delivery point. Please add a clearer building or landmark."}

          {:error, :missing_pickup_location} ->
            {:error, shop, "This shop has no pickup location set yet."}

          {:error, :no_available_rider} ->
            {:error, shop, "No verified riders are currently available for #{shop.name}."}

          {:error, {:insufficient_stock, _id}} ->
            {:error, shop, "Sorry, one or more items in your #{shop.name} cart are out of stock."}

          {:error, {:invalid_product, _id}} ->
            {:error, shop, "A product from #{shop.name} is no longer available."}

          {:error, _} ->
            {:error, shop, "Something went wrong placing your #{shop.name} order."}
        end
      end)

    errors = Enum.filter(results, fn {status, _, _} -> status == :error end)
    success = Enum.filter(results, fn {status, _, _} -> status == :ok end)

    socket = assign(socket, :checking_out, false)

    cond do
      # All orders failed — leave cart intact, show errors
      errors != [] && success == [] ->
        error_msg =
          errors
          |> Enum.map(fn {:error, _shop, msg} -> msg end)
          |> Enum.join(" ")

        {:noreply, put_flash(socket, :error, error_msg)}

      # Partial failure — some shops failed. Do not clear the cart or show
      # the receipt until payment is completed. Keep created orders in the
      # socket and surface the errors so the user can proceed to payment or
      # correct the issues.
      errors != [] ->
        error_msg =
          errors
          |> Enum.map(fn {:error, _shop, msg} -> msg end)
          |> Enum.join(" ")

        created_orders = success |> Enum.map(fn {:ok, _shop, order} -> order end)

        {:noreply,
         socket
         |> assign(:created_orders, created_orders)
         |> assign(:checking_out, false)
         |> put_flash(:info, "Some orders were created. Proceed to payment to complete them.")
         |> put_flash(:error, error_msg)}

      # All succeeded — create orders but do not clear the cart or show the
      # receipt until payment is processed. Store created orders on the
      # socket and prompt the user to proceed to payment.
      true ->
        created_orders = success |> Enum.map(fn {:ok, _shop, order} -> order end)

        order_numbers =
          created_orders
          |> Enum.map(fn order -> "##{String.slice(order.id, 0, 8)}" end)
          |> Enum.join(", ")

        {:noreply,
         socket
         |> assign(:created_orders, created_orders)
         |> assign(:checking_out, false)
         |> put_flash(
           :info,
           "Orders created. Proceed to payment to complete your purchase: #{order_numbers}"
         )}
    end
  end

  defp normalize_delivery_params(delivery_params) when is_map(delivery_params) do
    %{
      delivery_type:
        Map.get(delivery_params, "delivery_type") ||
          Map.get(delivery_params, :delivery_type) || "delivery",
      delivery_zone_id:
        Map.get(delivery_params, "delivery_zone_id") ||
          Map.get(delivery_params, :delivery_zone_id),
      delivery_address:
        Map.get(delivery_params, "delivery_address") ||
          Map.get(delivery_params, :delivery_address)
    }
  end

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
    delivery_zones_by_shop = load_delivery_zones(cart_items)

    socket
    |> assign(:cart_items, cart_items)
    |> assign(:cart_total, cart_total)
    |> assign(:cart_count, length(cart_items))
    |> assign(:delivery_zones_by_shop, delivery_zones_by_shop)
  end

  defp load_delivery_zones(cart_items) do
    cart_items
    |> Enum.group_by(fn item -> item.product.shop end)
    |> Enum.into(%{}, fn {shop, _items} ->
      {shop.id, Deliveries.list_delivery_zones(shop, active_only: true)}
    end)
  end

  defp build_text_receipt(nil), do: ""

  defp build_text_receipt(order) do
    lines =
      []
      |> then(fn l ->
        [
          "Shop: #{order.shop.name}",
          "Date: #{DateTime.utc_now() |> DateTime.to_string()}",
          "Order: #{String.slice(order.id, 0, 8)}",
          "",
          "Items:"
        ] ++
          l
      end)

    item_lines =
      Enum.map(order.items || [], fn it ->
        "#{it.product_name} x#{it.quantity}  KES #{it.line_total}"
      end)

    total = "\nTotal: KES #{order.total}"

    Enum.join(lines ++ item_lines, "\n") <> total <> "\n\nThank you for your purchase!"
  end

  defp subscribe_to_rider_location(%{delivery: %{rider_id: rider_id}})
       when not is_nil(rider_id) do
    Phoenix.PubSub.subscribe(SmartKiosk.PubSub, "rider:#{rider_id}:location")
  end

  defp subscribe_to_rider_location(_), do: :ok

  @impl true
  def handle_info({:mpesa_stk_result, _ref, phone, amount}, socket) do
    # Simulate success/failure (80% success)
    success = :rand.uniform() <= 0.8

    if success do
      # Payment successful - now create the orders
      checkout_params = socket.assigns[:checkout_params]
      cart_items = socket.assigns.cart_items

      if checkout_params && cart_items do
        {:noreply, socket} =
          do_checkout(
            socket,
            cart_items,
            checkout_params.name,
            checkout_params.phone,
            checkout_params.shop_delivery
          )

        # Get the created orders from the socket
        created_orders = socket.assigns[:created_orders] || []
        first_order = List.first(created_orders)

        if first_order do
          subscribe_to_rider_location(first_order)

          receipt_ref = "MPESA#{:erlang.unique_integer([:positive])}"

          # Clear cart and show receipt
          socket.assigns.cart_items |> Enum.each(&Cart.remove_cart_item/1)

          {:noreply,
           socket
           |> put_flash(
             :info,
             "STK Push confirmed for #{phone}. Ref: #{receipt_ref}. Amount: KES #{amount}"
           )
           |> assign(
             mpesa_pending: false,
             mpesa_modal_open: false,
             mpesa_phone: nil,
             mpesa_result: %{status: :success, ref: receipt_ref, amount: amount},
             cart_items: [],
             cart_total: Decimal.new("0"),
             cart_count: 0,
             order: first_order,
             show_receipt: true,
             created_orders: [],
             rider_location: nil
           )}
        else
          {:noreply,
           socket
           |> put_flash(:error, "Payment successful but order creation failed.")
           |> assign(
             mpesa_pending: false,
             mpesa_modal_open: false,
             mpesa_phone: nil
           )}
        end
      else
        {:noreply,
         socket
         |> put_flash(:error, "Payment successful but checkout data missing.")
         |> assign(
           mpesa_pending: false,
           mpesa_modal_open: false,
           mpesa_phone: nil
         )}
      end
    else
      {:noreply,
       socket
       |> put_flash(:error, "STK Push failed for #{phone}. Please try again.")
       |> assign(
         mpesa_pending: false,
         mpesa_modal_open: true,
         mpesa_result: %{status: :failed, amount: amount}
       )}
    end
  end

  @impl true
  def handle_info({:card_result, _ref, _card_number, amount}, socket) do
    success = :rand.uniform() <= 0.9

    if success do
      # Payment successful - now create the orders
      checkout_params = socket.assigns[:checkout_params]
      cart_items = socket.assigns.cart_items

      if checkout_params && cart_items do
        {:noreply, socket} =
          do_checkout(
            socket,
            cart_items,
            checkout_params.name,
            checkout_params.phone,
            checkout_params.shop_delivery
          )

        # Get the created orders from the socket
        created_orders = socket.assigns[:created_orders] || []
        first_order = List.first(created_orders)

        if first_order do
          subscribe_to_rider_location(first_order)

          socket.assigns.cart_items |> Enum.each(&Cart.remove_cart_item/1)

          {:noreply,
           socket
           |> put_flash(:info, "Card payment processed. Amount: KES #{amount}")
           |> assign(
             card_modal_open: false,
             card_pending: false,
             card_result: %{status: :success, amount: amount},
             cart_items: [],
             cart_total: Decimal.new("0"),
             cart_count: 0,
             order: first_order,
             show_receipt: true,
             created_orders: [],
             rider_location: nil
           )}
        else
          {:noreply,
           socket
           |> put_flash(:error, "Payment successful but order creation failed.")
           |> assign(
             card_pending: false,
             card_modal_open: false
           )}
        end
      else
        {:noreply,
         socket
         |> put_flash(:error, "Payment successful but checkout data missing.")
         |> assign(
           card_pending: false,
           card_modal_open: false
         )}
      end
    else
      {:noreply,
       socket
       |> put_flash(:error, "Card processing failed. Please try again.")
       |> assign(card_pending: false, card_modal_open: true, card_result: %{status: :failed})}
    end
  end

  @impl true
  def handle_info({:location_update, rider_location}, socket) do
    {:noreply, assign(socket, :rider_location, rider_location)}
  end
end
