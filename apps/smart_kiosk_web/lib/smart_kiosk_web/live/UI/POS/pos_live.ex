defmodule SmartKioskWeb.UI.POSLive.Index do
  use SmartKioskWeb, :live_view

  alias SmartKioskCore.Catalogue
  alias SmartKioskCore.Orders
  import SmartKioskWeb.Navbar

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    shop = socket.assigns.current_shop

    products = if shop, do: Catalogue.list_products(shop, status: :active), else: []

    if connected?(socket) and shop do
      Phoenix.PubSub.subscribe(SmartKiosk.PubSub, "shop:#{shop.id}:orders")
    end

    {:ok,
     socket
     |> assign(:page_title, "POS")
     |> assign(:user, user)
     |> assign(:shop, shop)
     |> assign(:products, products)
     |> assign(:cart, [])
     |> assign(:cart_total, 0.0)
     |> assign(:search_query, "")
     |> assign(:cart_open, false)
     |> assign(:active_tab, "products")
     |> assign(:mobile_menu_open, false)
     |> assign(:mobile_cart_open, false)
     |> assign(:show_payment, false)
     |> assign(:show_receipt, false)
     |> assign(:receipt, nil)
     |> assign(:cash_received, 0.0)
     |> assign(:cash_change, 0.0)
     |> assign(:card_modal_open, false)
     |> assign(:card_pending, false)
     |> assign(:card_result, nil)
     |> assign(:mpesa_modal_open, false)
     |> assign(:mpesa_pending, false)
     |> assign(:mpesa_phone, nil)
     |> assign(:mpesa_result, nil)
     |> assign_revenue_stats()}
  end

  # ── Events ──────────────────────────────────────────────────────────────────

  @impl true
  def handle_event("toggle_cart", _params, socket) do
    {:noreply, assign(socket, :cart_open, !socket.assigns.cart_open)}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, socket |> assign(:active_tab, tab) |> assign(:mobile_menu_open, false)}
  end

  @impl true
  def handle_event("toggle_mobile_menu", _params, socket) do
    {:noreply, assign(socket, :mobile_menu_open, !socket.assigns.mobile_menu_open)}
  end

  @impl true
  def handle_event("toggle_mobile_cart", _params, socket) do
    {:noreply, assign(socket, :mobile_cart_open, !socket.assigns.mobile_cart_open)}
  end

  @impl true
  def handle_event("add_to_cart", %{"product_id" => product_id}, socket) do
    product = Enum.find(socket.assigns.products, fn p -> p.id == product_id end)
    cart = socket.assigns.cart

    new_cart =
      case Enum.find_index(cart, fn item -> item.product.id == product_id end) do
        nil -> [%{product: product, quantity: 1} | cart]
        index -> List.update_at(cart, index, fn item -> %{item | quantity: item.quantity + 1} end)
      end

    {:noreply, assign(socket, cart: new_cart, cart_total: calculate_total(new_cart))}
  end

  @impl true
  def handle_event("update_quantity", %{"product_id" => product_id, "delta" => delta}, socket) do
    cart = socket.assigns.cart
    delta_int = String.to_integer(delta)

    new_cart =
      Enum.map(cart, fn item ->
        if item.product.id == product_id do
          new_qty = item.quantity + delta_int
          if new_qty > 0, do: %{item | quantity: new_qty}, else: item
        else
          item
        end
      end)
      |> Enum.reject(fn item -> item.quantity <= 0 end)

    {:noreply, assign(socket, cart: new_cart, cart_total: calculate_total(new_cart))}
  end

  @impl true
  def handle_event("clear_cart", _params, socket) do
    {:noreply, assign(socket, cart: [], cart_total: 0.0)}
  end

  @impl true
  def handle_event("show_payment", _params, socket) do
    {:noreply, assign(socket, :show_payment, true)}
  end

  @impl true
  def handle_event("hide_payment", _params, socket) do
    {:noreply, assign(socket, :show_payment, false)}
  end

  @impl true
  def handle_event("complete_payment", %{"method" => method}, socket) do
    cart = socket.assigns.cart || []
    total = socket.assigns.cart_total || 0.0

    if cart == [] or total == 0.0 do
      {:noreply, put_flash(socket, :error, "Cart is empty. Add items before completing payment.")}
    else
      case method do
        "cash" ->
          received = socket.assigns.cash_received || total
          change = received - total
          persist_result = persist_pos_sale(socket, :cash, total)

          case persist_result do
            {:ok, %{order: order}} ->
              receipt = build_receipt(order, socket.assigns.shop, socket.assigns.cart, total, "cash", received, change)

              {:noreply,
               socket
               |> put_flash(
                 :info,
                 "Cash payment recorded. Received: KES #{:erlang.float_to_binary(received, decimals: 2)}#{if change > 0, do: ", Change: KES #{:erlang.float_to_binary(change, decimals: 2)}", else: ""}"
               )
               |> assign(
                 cart: [],
                 cart_total: 0.0,
                 show_payment: false,
                 mobile_cart_open: false,
                 cart_open: false,
                 mpesa_modal_open: false,
                 cash_received: 0.0,
                 cash_change: 0.0,
                 receipt: receipt,
                 show_receipt: true
               )
               |> assign_revenue_stats()}

            {:error, reason} ->
              {:noreply, put_flash(socket, :error, "Payment failed to save: #{inspect(reason)}")}
          end

        "mpesa" ->
          # M-PESA is handled async via the STK modal — show the modal instead
          {:noreply, assign(socket, :mpesa_modal_open, true)}

        "card" ->
          # Card is handled async via the card modal
          {:noreply, assign(socket, :card_modal_open, true)}

        _ ->
          persist_result = persist_pos_sale(socket, :cash, total)

          case persist_result do
            {:ok, %{order: order}} ->
              receipt = build_receipt(order, socket.assigns.shop, socket.assigns.cart, total, method, total, 0.0)

              {:noreply,
               socket
               |> put_flash(:info, "Payment completed. Amount: KES #{:erlang.float_to_binary(total, decimals: 2)}")
               |> assign(
                 cart: [],
                 cart_total: 0.0,
                 show_payment: false,
                 mobile_cart_open: false,
                 cart_open: false,
                 mpesa_modal_open: false,
                 receipt: receipt,
                 show_receipt: true
               )
               |> assign_revenue_stats()}

            {:error, reason} ->
              {:noreply, put_flash(socket, :error, "Payment failed to save: #{inspect(reason)}")}
          end
      end
    end
  end

  @impl true
  def handle_event("update_cash", %{"cash_received" => val}, socket) do
    # parse float safely
    val = String.trim(val || "")

    received =
      case Float.parse(String.replace(val, ",", "")) do
        {f, _} -> f
        :error -> 0.0
      end

    total = socket.assigns.cart_total || 0.0
    change = received - total

    {:noreply, assign(socket, cash_received: received, cash_change: change)}
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
    # simulate an STK push; in production you'd call an API here
    total = socket.assigns.cart_total || 0.0

    # mark pending and store phone, then simulate async callback
    ref = :erlang.unique_integer([:positive])
    Process.send_after(self(), {:mpesa_stk_result, ref, phone, total}, 2_000)

    {:noreply,
     socket
     |> put_flash(:info, "Simulated STK Push sent to #{phone}. Waiting for confirmation...")
     |> assign(mpesa_modal_open: true, mpesa_pending: true, mpesa_phone: phone, mpesa_result: nil)}
  end

  @impl true
  def handle_event("show_card_modal", _params, socket) do
    {:noreply, assign(socket, card_modal_open: true)}
  end

  @impl true
  def handle_event("close_card_modal", _params, socket) do
    {:noreply, assign(socket, card_modal_open: false, card_pending: false, card_result: nil)}
  end

  @impl true
  def handle_event("submit_card", %{"card" => card_params}, socket) do
    # Simulate card processing delay and random success
    total = socket.assigns.cart_total || 0.0

    # very small validation: card number present
    card_number = Map.get(card_params, "number", "") |> String.trim()

    if card_number == "" do
      {:noreply, socket |> put_flash(:error, "Card number required")}
    else
      # simulate async processing
      ref = :erlang.unique_integer([:positive])
      Process.send_after(self(), {:card_result, ref, card_number, total}, 1_500)

      {:noreply,
       socket
       |> put_flash(:info, "Processing card payment...")
       |> assign(card_modal_open: true, card_pending: true, card_result: nil)}
    end
  end

  @impl true
  def handle_event("print_receipt", %{"order-id" => _order_id}, socket) do
    push_event(socket, "print_receipt", %{})
    {:noreply, socket}
  end

  @impl true
  def handle_event("share_receipt", _params, socket) do
    receipt = socket.assigns[:receipt]
    text = build_text_receipt(receipt)
    push_event(socket, "share", %{text: text})
    {:noreply, socket}
  end

  @impl true
  def handle_event("new_order", _params, socket) do
    {:noreply,
     socket
     |> assign(cart: [], cart_total: 0.0, show_receipt: false, receipt: nil)
     |> push_navigate(to: ~p"/pos")}
  end

  @impl true
  def handle_event("view_order_receipt", %{"order_id" => order_id}, socket) do
    shop = socket.assigns.shop

    try do
      order = Orders.get_order!(shop, order_id)
      transaction = List.first(order.transactions)
      method = if transaction, do: to_string(transaction.type), else: "cash"

      cart =
        Enum.map(order.items, fn item ->
          %{product: item.product, quantity: item.quantity}
        end)

      total_float = Decimal.to_float(order.total)

      receipt = %{
        id: "POS-#{String.slice(order.id, 0, 8) |> String.upcase()}",
        shop: shop,
        items: cart,
        total: total_float,
        method: method,
        received: total_float,
        change: 0.0,
        inserted_at: order.inserted_at
      }

      {:noreply,
       socket
       |> assign(receipt: receipt, show_receipt: true, cart_open: false, mobile_cart_open: false)}
    rescue
      _ -> {:noreply, put_flash(socket, :error, "Order receipt not found")}
    end
  end

  @impl true
  def handle_event("set_quantity", %{"product_id" => product_id, "quantity" => quantity_str}, socket) do
    qty =
      case Integer.parse(quantity_str || "") do
        {q, _} when q > 0 -> q
        _ -> 1
      end

    cart = socket.assigns.cart

    new_cart =
      case Enum.find_index(cart, fn item -> item.product.id == product_id end) do
        nil -> cart
        index -> List.update_at(cart, index, fn item -> %{item | quantity: qty} end)
      end

    {:noreply, assign(socket, cart: new_cart, cart_total: calculate_total(new_cart))}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    products = Catalogue.list_products(socket.assigns.shop, status: :active, search: query)

    # Quick Add logic: if query matches exactly one product's SKU, add it to cart
    case Enum.find(products, fn p -> p.sku == String.trim(query) end) do
      %{} = product when query != "" ->
        handle_event(
          "add_to_cart",
          %{"product_id" => product.id},
          assign(socket, search_query: "")
        )

      _ ->
        {:noreply, assign(socket, products: products, search_query: query)}
    end
  end

  # ── Internal Helpers ─────────────────────────────────────────────────────────

  defp calculate_total(cart) do
    cart
    |> Enum.reduce(0.0, fn item, acc ->
      acc + Decimal.to_float(item.product.price) * item.quantity
    end)
  end

  defp assign_revenue_stats(socket) do
    shop = socket.assigns.shop
    user = socket.assigns.user

    if shop do
      pos_revenue_today = Orders.get_pos_sales_today(shop)
      pos_orders_today = Orders.list_pos_orders_today(shop, limit: 15)
      pos_cashier_sales_today = Orders.get_pos_sales_today_by_cashier(shop)
      my_stats_today = Orders.get_cashier_pos_stats_today(shop, user.id)

      socket
      |> assign(:pos_revenue_today, pos_revenue_today)
      |> assign(:pos_orders_today, pos_orders_today)
      |> assign(:pos_cashier_sales_today, pos_cashier_sales_today)
      |> assign(:my_stats_today, my_stats_today)
    else
      socket
      |> assign(:pos_revenue_today, Decimal.new("0"))
      |> assign(:pos_orders_today, [])
      |> assign(:pos_cashier_sales_today, [])
      |> assign(:my_stats_today, %{total: Decimal.new("0"), count: 0})
    end
  end

  # Persists a POS sale to the database via Orders.process_pos_payment/4.
  # Returns {:ok, order} or {:error, reason}.
  defp persist_pos_sale(socket, payment_method, amount) do
    shop = socket.assigns.shop
    user = socket.assigns.user
    cart = socket.assigns.cart

    # Convert cart items to the {product, qty} format expected by the orders context
    items = Enum.map(cart, fn %{product: product, quantity: qty} -> {product, qty} end)

    payment_attrs = %{
      payment_method: payment_method,
      amount: Decimal.from_float(amount),
      user_id: user.id
    }

    Orders.process_pos_payment(shop, items, payment_attrs)
  end

  # Builds the in-memory receipt map shown on the receipt screen.
  defp build_receipt(order, shop, cart, total, method, received, change) do
    %{
      id: "POS-#{String.slice(order.id, 0, 8) |> String.upcase()}",
      shop: shop,
      items: cart,
      total: total,
      method: method,
      received: received,
      change: change,
      inserted_at: order.inserted_at
    }
  end

  defp build_text_receipt(nil), do: ""

  defp build_text_receipt(receipt) do
    header = [
      "Shop: #{receipt.shop.name}",
      "Date: #{DateTime.utc_now() |> DateTime.to_string()}",
      "Order: #{receipt.id}",
      "",
      "Items:"
    ]

    item_lines =
      Enum.map(receipt.items || [], fn it ->
        "#{it.product.name} x#{it.quantity}  KES #{:erlang.float_to_binary(Decimal.to_float(it.product.price) * it.quantity, decimals: 2)}"
      end)

    total = "\nTotal: KES #{:erlang.float_to_binary(receipt.total, decimals: 2)}"

    payment_details =
      if receipt.method == "cash" do
        "\nReceived: KES #{:erlang.float_to_binary(receipt.received, decimals: 2)}\nChange: KES #{:erlang.float_to_binary(receipt.change, decimals: 2)}"
      else
        ""
      end

    Enum.join(header ++ item_lines, "\n") <>
      total <> payment_details <> "\n\nThank you for your purchase!"
  end

  # ── Info ────────────────────────────────────────────────────────────────────

  @impl true
  def handle_info({:mpesa_stk_result, _ref, phone, amount}, socket) do
    # Simulate success/failure (80% success)
    success = :rand.uniform() <= 0.8

    if success do
      receipt_ref = "MPESA#{:erlang.unique_integer([:positive])}"

      case persist_pos_sale(socket, :mpesa_stk, amount) do
        {:ok, %{order: order}} ->
          receipt = build_receipt(order, socket.assigns.shop, socket.assigns.cart, amount, "mpesa", amount, 0.0)

          {:noreply,
           socket
           |> put_flash(
             :info,
             "STK Push confirmed for #{phone}. Ref: #{receipt_ref}. Amount: KES #{:erlang.float_to_binary(amount, decimals: 2)}"
           )
           |> assign(
             mpesa_pending: false,
             mpesa_modal_open: false,
             mpesa_phone: nil,
             mpesa_result: %{status: :success, ref: receipt_ref, amount: amount},
             cart: [],
             cart_total: 0.0,
             show_payment: false,
             mobile_cart_open: false,
             cart_open: false,
             receipt: receipt,
             show_receipt: true
           )
           |> assign_revenue_stats()}

        {:error, reason} ->
          {:noreply,
           socket
           |> put_flash(:error, "M-PESA confirmed but failed to save order: #{inspect(reason)}")
           |> assign(mpesa_pending: false, mpesa_modal_open: false)}
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
    # simulate 90% success
    success = :rand.uniform() <= 0.9

    if success do
      case persist_pos_sale(socket, :card, amount) do
        {:ok, %{order: order}} ->
          receipt = build_receipt(order, socket.assigns.shop, socket.assigns.cart, amount, "card", amount, 0.0)

          {:noreply,
           socket
           |> put_flash(
             :info,
             "Card payment processed. Amount: KES #{:erlang.float_to_binary(amount, decimals: 2)}"
           )
           |> assign(
             cart: [],
             cart_total: 0.0,
             show_payment: false,
             mobile_cart_open: false,
             cart_open: false,
             mpesa_modal_open: false,
             card_modal_open: false,
             card_pending: false,
             card_result: %{status: :success, amount: amount},
             receipt: receipt,
             show_receipt: true
           )
           |> assign_revenue_stats()}

        {:error, reason} ->
          {:noreply,
           socket
           |> put_flash(:error, "Card approved but failed to save order: #{inspect(reason)}")
           |> assign(card_pending: false, card_modal_open: false)}
      end
    else
      {:noreply,
       socket
       |> put_flash(:error, "Card processing failed. Please try again.")
       |> assign(card_pending: false, card_modal_open: true, card_result: %{status: :failed})}
    end
  end

  @impl true
  def handle_info({:new_order, _order}, socket) do
    {:noreply, assign_revenue_stats(socket)}
  end

  # ── Render ──────────────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#0B0F1A] text-white">
      <.navbar current_user={@user} user_shop={@shop} cart_count={length(@cart)} />

      <div class="flex h-[calc(100vh-64px)] overflow-hidden relative">
        <%!-- Mobile Menu Backdrop --%>
        <%= if @mobile_menu_open do %>
          <div phx-click="toggle_mobile_menu" class="fixed inset-0 bg-black/50 z-40 lg:hidden"></div>
        <% end %>

        <%!-- Mobile Cart Overlay --%>
        <%= if @mobile_cart_open do %>
          <div phx-click="toggle_mobile_cart" class="fixed inset-0 bg-black/50 z-50 lg:hidden"></div>
        <% end %>

        <%!-- Left Sidebar Navigation --%>
        <aside class={[
          "fixed lg:relative z-50 lg:z-auto h-full transition-transform duration-300 ease-in-out",
          "w-64 border-r border-white/10 bg-[#0B0F1A] flex flex-col",
          @mobile_menu_open && "translate-x-0",
          !@mobile_menu_open && "-translate-x-full lg:translate-x-0"
        ]}>
          <div class="p-4">
            <div class="flex items-center justify-between mb-4 lg:hidden">
              <h2 class="text-sm font-semibold text-slate-400 uppercase tracking-wider">Menu</h2>
              <button phx-click="toggle_mobile_menu" class="text-slate-400 hover:text-white">
                <.icon name="hero-x-mark" class="w-6 h-6" />
              </button>
            </div>
            <h2 class="hidden lg:block text-sm font-semibold text-slate-400 uppercase tracking-wider mb-4">
              Menu
            </h2>
            <nav class="space-y-1">
              <button
                type="button"
                phx-click="switch_tab"
                phx-value-tab="products"
                class={[
                  "w-full flex items-center gap-3 px-4 py-3 rounded-xl transition-all",
                  @active_tab == "products" && "bg-violet-500 text-white",
                  @active_tab != "products" && "text-slate-400 hover:bg-white/5 hover:text-white"
                ]}
              >
                <.icon name="hero-shopping-bag" class="w-5 h-5" />
                <span class="font-medium">Products</span>
              </button>
              <button
                type="button"
                phx-click="switch_tab"
                phx-value-tab="expenses"
                class={[
                  "w-full flex items-center gap-3 px-4 py-3 rounded-xl transition-all",
                  @active_tab == "expenses" && "bg-violet-500 text-white",
                  @active_tab != "expenses" && "text-slate-400 hover:bg-white/5 hover:text-white"
                ]}
              >
                <.icon name="hero-banknotes" class="w-5 h-5" />
                <span class="font-medium">Expenses</span>
              </button>
              <button
                type="button"
                phx-click="switch_tab"
                phx-value-tab="customers"
                class={[
                  "w-full flex items-center gap-3 px-4 py-3 rounded-xl transition-all",
                  @active_tab == "customers" && "bg-violet-500 text-white",
                  @active_tab != "customers" && "text-slate-400 hover:bg-white/5 hover:text-white"
                ]}
              >
                <.icon name="hero-users" class="w-5 h-5" />
                <span class="font-medium">Customers</span>
              </button>
              <button
                type="button"
                phx-click="switch_tab"
                phx-value-tab="orders"
                class={[
                  "w-full flex items-center gap-3 px-4 py-3 rounded-xl transition-all",
                  @active_tab == "orders" && "bg-violet-500 text-white",
                  @active_tab != "orders" && "text-slate-400 hover:bg-white/5 hover:text-white"
                ]}
              >
                <.icon name="hero-book-open" class="w-5 h-5" />
                <span class="font-medium">Orders</span>
              </button>
              <button
                type="button"
                phx-click="switch_tab"
                phx-value-tab="revenue"
                class={[
                  "w-full flex items-center gap-3 px-4 py-3 rounded-xl transition-all",
                  @active_tab == "revenue" && "bg-violet-500 text-white",
                  @active_tab != "revenue" && "text-slate-400 hover:bg-white/5 hover:text-white"
                ]}
              >
                <.icon name="hero-currency-dollar" class="w-5 h-5" />
                <span class="font-medium">Revenue</span>
              </button>
              <button
                type="button"
                phx-click="switch_tab"
                phx-value-tab="sales"
                class={[
                  "w-full flex items-center gap-3 px-4 py-3 rounded-xl transition-all",
                  @active_tab == "sales" && "bg-violet-500 text-white",
                  @active_tab != "sales" && "text-slate-400 hover:bg-white/5 hover:text-white"
                ]}
              >
                <.icon name="hero-chart-bar" class="w-5 h-5" />
                <span class="font-medium">Sales</span>
              </button>
              <button
                type="button"
                phx-click="switch_tab"
                phx-value-tab="settings"
                class={[
                  "w-full flex items-center gap-3 px-4 py-3 rounded-xl transition-all",
                  @active_tab == "settings" && "bg-violet-500 text-white",
                  @active_tab != "settings" && "text-slate-400 hover:bg-white/5 hover:text-white"
                ]}
              >
                <.icon name="hero-cog-6-tooth" class="w-5 h-5" />
                <span class="font-medium">Settings</span>
              </button>
            </nav>
          </div>

          <%!-- ── Active Cashier Card ── --%>
          <div class="mx-4 mt-4 p-4 bg-violet-500/10 border border-violet-500/20 rounded-2xl">
            <div class="flex items-center gap-3 mb-3">
              <div class="w-8 h-8 bg-violet-500/30 rounded-full flex items-center justify-center flex-shrink-0">
                <.icon name="hero-user-circle" class="w-5 h-5 text-violet-300" />
              </div>
              <div class="min-w-0">
                <p class="text-xs font-semibold text-violet-300 uppercase tracking-wider">Active Cashier</p>
                <p class="text-sm font-bold text-white truncate"><%= @user.full_name || @user.email %></p>
              </div>
            </div>
            <div class="flex items-center gap-2 text-xs text-slate-400">
              <span class="w-2 h-2 bg-emerald-400 rounded-full animate-pulse flex-shrink-0"></span>
              <span class="truncate"><%= @user.email %></span>
            </div>
            <div class="mt-3 pt-3 border-t border-violet-500/20">
              <p class="text-xs text-slate-500 uppercase tracking-wider font-medium mb-1">POS Revenue Today</p>
              <p class="text-lg font-bold text-emerald-400">
                KES <%= Decimal.to_string(@pos_revenue_today, :normal) %>
              </p>
            </div>
          </div>
        </aside>

        <%!-- Main Content Area --%>
        <main class="flex-1 flex flex-col overflow-hidden">
          <header class="p-6 border-b border-white/10 flex items-center justify-between">
            <div class="flex items-center gap-3">
              <button
                phx-click="toggle_mobile_menu"
                class="lg:hidden p-2 text-slate-400 hover:text-white"
              >
                <.icon name="hero-bars-3" class="w-6 h-6" />
              </button>
              <h1 class="text-xl font-bold">
                Point of Sale
              </h1>
            </div>
            <div class="flex items-center gap-3">
              <%= if @active_tab == "products" do %>
                <.form for={%{}} as={:search} phx-change="search" class="relative hidden sm:block">
                  <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                    <.icon name="hero-magnifying-glass" class="w-5 h-5 text-slate-500" />
                  </div>
                  <input
                    type="text"
                    name="query"
                    value={@search_query}
                    placeholder="Search products..."
                    class="bg-slate-900/50 border border-white/10 rounded-xl py-2 pl-10 pr-4 text-white placeholder:text-slate-600 focus:outline-none focus:ring-2 focus:ring-violet-500/50 focus:border-violet-500 transition-all w-48 md:w-64"
                  />
                </.form>
                <button class="btn btn-outline border-white/10 text-white hidden sm:block">
                  Scan Barcode
                </button>
              <% end %>
              <button
                phx-click="toggle_mobile_cart"
                class="lg:hidden p-2 text-slate-400 hover:text-white relative"
              >
                <.icon name="hero-shopping-cart" class="w-6 h-6" />
                <%= if length(@cart) > 0 do %>
                  <span class="absolute -top-1 -right-1 w-5 h-5 bg-violet-500 rounded-full text-xs font-bold flex items-center justify-center">
                    <%= length(@cart) %>
                  </span>
                <% end %>
              </button>
            </div>
          </header>

          <%= cond do %>
            <% @active_tab == "products" -> %>
              <div class="p-6 flex-1 overflow-y-auto">
                <div class="grid grid-cols-2 lg:grid-cols-4 gap-4">
                  <%= for product <- @products do %>
                    <button
                      type="button"
                      phx-click="add_to_cart"
                      phx-value-product_id={product.id}
                      class="bg-white/5 border border-white/10 rounded-2xl p-4 hover:border-violet-500/30 transition-all text-left group"
                    >
                      <div class="w-full h-32 bg-slate-800 rounded-lg mb-3 flex items-center justify-center overflow-hidden relative">
                        <img
                          :if={Enum.any?(product.images)}
                          src={List.first(product.images).url}
                          class="w-full h-full object-cover group-hover:scale-110 transition-transform duration-500"
                        />
                        <.icon
                          :if={Enum.empty?(product.images)}
                          name="hero-shopping-bag"
                          class="w-10 h-10 text-slate-600"
                        />
                        <div class="absolute top-2 right-2 px-2 py-1 bg-black/60 backdrop-blur-md rounded text-[10px] font-mono text-slate-300 border border-white/5">
                          <%= product.sku || "NO-SKU" %>
                        </div>
                      </div>
                      <h3 class="font-semibold text-sm truncate text-slate-200"><%= product.name %></h3>
                      <div class="flex items-center justify-between mt-1">
                        <p class="text-violet-400 font-bold">KES <%= product.price %></p>
                        <span class="text-[10px] text-slate-500 uppercase tracking-wider">
                          <%= product.stock_qty %> left
                        </span>
                      </div>
                    </button>
                  <% end %>
                </div>
              </div>

            <% @active_tab == "sales" -> %>
              <div class="p-6 flex-1 overflow-y-auto space-y-6">
                <%!-- 1. Stats Cards Grid --%>
                <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
                  <%!-- Today's POS Revenue --%>
                  <div class="bg-white/5 border border-white/10 rounded-3xl p-6 backdrop-blur-xl relative overflow-hidden group">
                    <div class="absolute top-0 right-0 w-32 h-32 bg-emerald-500/10 rounded-full blur-3xl -mr-8 -mt-8 group-hover:bg-emerald-500/20 transition-all duration-500"></div>
                    <div class="flex items-center gap-4">
                      <div class="w-12 h-12 bg-emerald-500/20 rounded-2xl flex items-center justify-center">
                        <.icon name="hero-banknotes" class="w-6 h-6 text-emerald-400" />
                      </div>
                      <div>
                        <p class="text-slate-500 text-sm font-medium">POS Revenue Today</p>
                        <p class="text-3xl font-black text-white mt-1">
                          KES <%= Decimal.to_string(@pos_revenue_today, :normal) %>
                        </p>
                      </div>
                    </div>
                  </div>

                  <%!-- Personal Cashier Contribution --%>
                  <div class="bg-white/5 border border-white/10 rounded-3xl p-6 backdrop-blur-xl relative overflow-hidden group">
                    <div class="absolute top-0 right-0 w-32 h-32 bg-violet-500/10 rounded-full blur-3xl -mr-8 -mt-8 group-hover:bg-violet-500/20 transition-all duration-500"></div>
                    <div class="flex items-center gap-4">
                      <div class="w-12 h-12 bg-violet-500/20 rounded-2xl flex items-center justify-center">
                        <.icon name="hero-user" class="w-6 h-6 text-violet-400" />
                      </div>
                      <div>
                        <p class="text-slate-500 text-sm font-medium">My Sales Contribution</p>
                        <p class="text-3xl font-black text-white mt-1">
                          KES <%= Decimal.to_string(@my_stats_today.total, :normal) %>
                        </p>
                        <p class="text-xs text-slate-400 mt-1">
                          <%= @my_stats_today.count %> transactions completed
                        </p>
                      </div>
                    </div>
                  </div>

                  <%!-- Total POS Orders today --%>
                  <div class="bg-white/5 border border-white/10 rounded-3xl p-6 backdrop-blur-xl relative overflow-hidden group">
                    <div class="absolute top-0 right-0 w-32 h-32 bg-blue-500/10 rounded-full blur-3xl -mr-8 -mt-8 group-hover:bg-blue-500/20 transition-all duration-500"></div>
                    <div class="flex items-center gap-4">
                      <div class="w-12 h-12 bg-blue-500/20 rounded-2xl flex items-center justify-center">
                        <.icon name="hero-shopping-bag" class="w-6 h-6 text-blue-400" />
                      </div>
                      <div>
                        <p class="text-slate-500 text-sm font-medium">POS Transactions Count</p>
                        <p class="text-3xl font-black text-white mt-1">
                          <%= length(@pos_orders_today) %>
                        </p>
                        <p class="text-xs text-slate-400 mt-1">Across all active cashiers</p>
                      </div>
                    </div>
                  </div>
                </div>

                <%!-- 2. Detail Columns --%>
                <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
                  <%!-- Cashier Performance --%>
                  <div class="bg-white/5 border border-white/10 rounded-3xl p-6 backdrop-blur-xl">
                    <div class="flex items-center justify-between mb-6">
                      <h2 class="text-xl font-bold text-white flex items-center gap-2">
                        <.icon name="hero-users" class="w-5 h-5 text-violet-400" /> Cashier Performance
                      </h2>
                    </div>

                    <div class="overflow-x-auto">
                      <table class="w-full text-left border-collapse">
                        <thead>
                          <tr class="border-b border-white/10 text-xs text-slate-500 uppercase tracking-wider font-semibold">
                            <th class="py-3">Cashier</th>
                            <th class="py-3 text-center">Sales count</th>
                            <th class="py-3 text-right">Total Revenue</th>
                          </tr>
                        </thead>
                        <tbody class="divide-y divide-white/5">
                          <%= if @pos_cashier_sales_today == [] do %>
                            <tr>
                              <td colspan="3" class="py-6 text-center text-slate-500 text-sm">
                                No sales data recorded today.
                              </td>
                            </tr>
                          <% else %>
                            <%= for c <- @pos_cashier_sales_today do %>
                              <tr class={[
                                "text-sm",
                                c.user_id == @user.id && "bg-violet-500/5 font-semibold text-white"
                              ]}>
                                <td class="py-4">
                                  <div class="flex items-center gap-2">
                                    <div class={[
                                      "w-2 h-2 rounded-full",
                                      if(c.user_id == @user.id, do: "bg-emerald-400 animate-pulse", else: "bg-slate-500")
                                    ]}></div>
                                    <div>
                                      <p class={if(c.user_id == @user.id, do: "text-violet-300 font-bold", else: "text-slate-200")}>
                                        <%= c.full_name || c.email %>
                                      </p>
                                      <p class="text-xs text-slate-500"><%= c.email %></p>
                                    </div>
                                    <span :if={c.user_id == @user.id} class="text-[10px] px-2 py-0.5 bg-violet-500/20 text-violet-300 border border-violet-500/30 rounded-full font-normal">
                                      You
                                    </span>
                                  </div>
                                </td>
                                <td class="py-4 text-center font-mono text-slate-300">
                                  <%= c.count %>
                                </td>
                                <td class="py-4 text-right font-mono font-bold text-emerald-400">
                                  KES <%= Decimal.to_string(c.total, :normal) %>
                                </td>
                              </tr>
                            <% end %>
                          <% end %>
                        </tbody>
                      </table>
                    </div>
                  </div>

                  <%!-- Today's POS Sales History --%>
                  <div class="bg-white/5 border border-white/10 rounded-3xl p-6 backdrop-blur-xl">
                    <div class="flex items-center justify-between mb-6">
                      <h2 class="text-xl font-bold text-white flex items-center gap-2">
                        <.icon name="hero-list-bullet" class="w-5 h-5 text-blue-400" /> Today's POS Sales
                      </h2>
                    </div>

                    <div class="space-y-4 max-h-[450px] overflow-y-auto pr-2">
                      <%= if @pos_orders_today == [] do %>
                        <div class="h-40 flex flex-col items-center justify-center text-slate-500 opacity-50 border-2 border-dashed border-white/10 rounded-2xl">
                          <.icon name="hero-shopping-bag" class="w-8 h-8 mb-2" />
                          <p>No POS sales completed today.</p>
                        </div>
                      <% else %>
                        <%= for order <- @pos_orders_today do %>
                          <div class="flex items-center justify-between p-4 bg-white/5 border border-white/10 rounded-2xl hover:border-violet-500/30 transition-all">
                            <div class="min-w-0">
                              <div class="flex items-center gap-2">
                                <span class="font-mono text-sm font-bold text-white">
                                  POS-<%= String.slice(order.id, 0, 8) |> String.upcase() %>
                                </span>
                                <%
                                  transaction = List.first(order.transactions)
                                  method_str = if transaction, do: to_string(transaction.type), else: "cash"
                                  {badge_bg, badge_text, method_label} = case method_str do
                                    "mpesa" -> {"bg-yellow-500/10 border-yellow-500/20", "text-yellow-400", "M-PESA"}
                                    "mpesa_stk" -> {"bg-yellow-500/10 border-yellow-500/20", "text-yellow-400", "M-PESA"}
                                    "card" -> {"bg-blue-500/10 border-blue-500/20", "text-blue-400", "Card"}
                                    _ -> {"bg-green-500/10 border-green-500/20", "text-green-400", "Cash"}
                                  end
                                %>
                                <span class={["text-[10px] px-2 py-0.5 border rounded-full font-medium", badge_bg, badge_text]}>
                                  <%= method_label %>
                                </span>
                              </div>
                              <div class="flex items-center gap-2 mt-1">
                                <p class="text-xs text-slate-500">
                                  <%= Calendar.strftime(order.inserted_at, "%I:%M %p") %>
                                </p>
                                <span class="text-slate-600 text-xs">•</span>
                                <p class="text-xs text-slate-400 truncate">
                                  Cashier: <%= if transaction && transaction.user_id do %>
                                    <%= if transaction.user_id == @user.id do %>
                                      You
                                    <% else %>
                                      <%= Enum.find(@pos_cashier_sales_today, fn c -> c.user_id == transaction.user_id end) |> then(fn c -> if c, do: c.full_name || c.email, else: "Other" end) %>
                                    <% end %>
                                  <% else %>
                                    System
                                  <% end %>
                                </p>
                              </div>
                            </div>
                            <div class="flex items-center gap-3">
                              <span class="font-mono font-bold text-white">
                                KES <%= Decimal.to_string(order.total, :normal) %>
                              </span>
                              <button
                                type="button"
                                phx-click="view_order_receipt"
                                phx-value-order_id={order.id}
                                class="p-2 bg-white/5 hover:bg-violet-500/20 border border-white/10 rounded-xl text-slate-400 hover:text-white transition-all"
                                title="View Receipt"
                              >
                                <.icon name="hero-receipt-percent" class="w-4 h-4" />
                              </button>
                            </div>
                          </div>
                        <% end %>
                      <% end %>
                    </div>
                  </div>
                </div>
              </div>

            <% true -> %>
              <div class="flex-1 flex items-center justify-center">
                <div class="text-center">
                  <.icon name="hero-cube" class="w-16 h-16 text-slate-600 mx-auto mb-4" />
                  <h2 class="text-xl font-semibold text-slate-400">
                    <%= String.capitalize(@active_tab) %>
                  </h2>
                  <p class="text-slate-500 mt-2">Coming soon</p>
                </div>
              </div>
          <% end %>
        </main>

        <%!-- 2. Cart Sidebar (Responsive) --%>
        <section class={[
          "fixed inset-0 z-50 lg:relative lg:block lg:w-96 border-l border-white/10 bg-[#0B0F1A] flex flex-col transition-transform duration-300",
          !@mobile_cart_open && "hidden lg:block",
          @mobile_cart_open && "translate-x-0",
          !@mobile_cart_open && "translate-x-full lg:translate-x-0"
        ]}>
          <div class="p-6 border-b border-white/10 flex justify-between items-center">
            <h2 class="text-xl font-bold">Cart (<%= length(@cart) %>)</h2>
            <div class="flex items-center gap-3">
              <button phx-click="toggle_mobile_cart" class="lg:hidden text-slate-400">Close</button>
              <button phx-click="clear_cart" class="text-red-400 text-sm hover:text-red-300">
                Clear
              </button>
            </div>
          </div>

          <%= if @receipt do %>
            <div
              id="receipt-container"
              phx-hook="PrintReceipt"
              class="digital-receipt bg-white text-black rounded-lg p-4 max-w-sm mx-auto font-mono mb-6"
            >
              <div class="text-sm mb-2">
                <div class="font-semibold"><%= @receipt.shop.name %></div>
                <div><%= @receipt.inserted_at |> DateTime.to_string() %></div>
                <div>Order: <%= @receipt.id %></div>
                <div>Payment: <%= String.upcase(@receipt.method) %></div>
              </div>

              <div class="divide-y">
                <%= for item <- @receipt.items do %>
                  <div class="flex justify-between text-sm py-1">
                    <span><%= item.product.name %> x<%= item.quantity %></span>
                    <span>
                      KES <%= :erlang.float_to_binary(
                        Decimal.to_float(item.product.price) * item.quantity,
                        decimals: 2
                      ) %>
                    </span>
                  </div>
                <% end %>
              </div>

              <div class="flex justify-between font-bold mt-4">
                <span>Total</span>
                <span>KES <%= :erlang.float_to_binary(@receipt.total, decimals: 2) %></span>
              </div>

              <%= if @receipt.method == "cash" do %>
                <div class="flex justify-between text-sm mt-1 text-slate-600">
                  <span>Received</span>
                  <span>KES <%= :erlang.float_to_binary(@receipt.received, decimals: 2) %></span>
                </div>
                <div class="flex justify-between text-sm font-semibold mt-1">
                  <span>Change</span>
                  <span>KES <%= :erlang.float_to_binary(@receipt.change, decimals: 2) %></span>
                </div>
              <% end %>

              <div class="text-sm mt-3">Thank you for your purchase!</div>

              <div class="flex gap-2 mt-4">
                <button
                  phx-click="print_receipt"
                  phx-value-order-id={@receipt.id}
                  class="btn no-print"
                >
                  Print Receipt
                </button>
                <button phx-click="share_receipt" class="btn no-print">Share Receipt</button>
                <button phx-click="new_order" class="btn no-print">New Order</button>
              </div>
            </div>
          <% else %>
            <%= if @show_payment do %>
              <%!-- Payment selection --%>
              <div class="p-6 flex-1 overflow-y-auto">
                <div class="mb-6">
                  <button
                    phx-click="hide_payment"
                    class="text-violet-400 text-sm font-semibold flex items-center gap-1"
                  >
                    <.icon name="hero-arrow-left" class="w-4 h-4" /> Back to Cart
                  </button>
                </div>

                <label class="text-sm text-slate-400 mb-3 block text-center">Amount Due</label>
                <div class="bg-white/5 border border-white/10 rounded-2xl p-6 text-center mb-8">
                  <p class="text-4xl font-bold text-violet-400 tabular-nums">
                    KES <%= :erlang.float_to_binary(@cart_total, decimals: 2) %>
                  </p>
                </div>

                <div class="space-y-4">
                  <%!-- Cash Option --%>
                  <div class="bg-white/5 border border-white/10 rounded-2xl p-4">
                    <div class="flex items-center justify-between mb-4">
                      <div class="flex items-center gap-3">
                        <div class="w-10 h-10 bg-green-500/20 rounded-xl flex items-center justify-center">
                          <.icon name="hero-banknotes" class="w-6 h-6 text-green-500" />
                        </div>
                        <span class="font-bold">Cash Payment</span>
                      </div>
                    </div>

                    <form phx-change="update_cash" class="space-y-3">
                      <label class="text-xs text-slate-500 uppercase tracking-wider font-bold">
                        Amount Received
                      </label>
                      <input
                        name="cash_received"
                        type="text"
                        inputmode="numeric"
                        value={
                          if @cash_received > 0,
                            do: :erlang.float_to_binary(@cash_received, decimals: 2),
                            else: ""
                        }
                        placeholder="0.00"
                        class="w-full bg-slate-900 border border-white/10 rounded-xl py-3 px-4 text-white text-xl font-mono focus:ring-2 focus:ring-violet-500/50 outline-none"
                      />
                    </form>

                    <div class="flex justify-between items-center mt-4 pt-4 border-t border-white/5">
                      <span class="text-slate-400">Change Due</span>
                      <span class="text-xl font-bold text-white font-mono">
                        KES <%= :erlang.float_to_binary(@cash_change, decimals: 2) %>
                      </span>
                    </div>

                    <button
                      phx-click="complete_payment"
                      phx-value-method="cash"
                      disabled={@cash_received < @cart_total}
                      class="w-full mt-4 py-3 bg-green-600 hover:bg-green-500 disabled:bg-slate-800 disabled:text-slate-600 rounded-xl font-bold transition-all"
                    >
                      Complete Cash Sale
                    </button>
                  </div>

                  <%!-- M-PESA Option --%>
                  <button
                    phx-click="show_mpesa_modal"
                    class="w-full p-4 bg-white/5 border border-white/10 hover:border-yellow-500/50 rounded-2xl flex items-center justify-between transition-all group"
                  >
                    <div class="flex items-center gap-3">
                      <div class="w-10 h-10 bg-yellow-500/20 rounded-xl flex items-center justify-center">
                        <.icon name="hero-phone" class="w-6 h-6 text-yellow-500" />
                      </div>
                      <span class="font-bold">M-PESA STK Push</span>
                    </div>
                    <.icon
                      name="hero-chevron-right"
                      class="w-5 h-5 text-slate-600 group-hover:text-yellow-500"
                    />
                  </button>

                  <%!-- Card Option --%>
                  <button
                    phx-click="show_card_modal"
                    class="w-full p-4 bg-white/5 border border-white/10 hover:border-blue-500/50 rounded-2xl flex items-center justify-between transition-all group"
                  >
                    <div class="flex items-center gap-3">
                      <div class="w-10 h-10 bg-blue-500/20 rounded-xl flex items-center justify-center">
                        <.icon name="hero-credit-card" class="w-6 h-6 text-blue-500" />
                      </div>
                      <span class="font-bold">Credit/Debit Card</span>
                    </div>
                    <.icon
                      name="hero-chevron-right"
                      class="w-5 h-5 text-slate-600 group-hover:text-blue-500"
                    />
                  </button>
                </div>
              </div>
            <% else %>
              <%!-- Cart View --%>
              <div class="flex-1 overflow-y-auto p-6 space-y-4">
                <%= if @cart == [] do %>
                  <div class="h-full flex flex-col items-center justify-center text-slate-500 opacity-50">
                    <.icon name="hero-shopping-cart" class="w-12 h-12 mb-2" />
                    <p>Cart is empty</p>
                  </div>
                <% else %>
                  <%= for item <- @cart do %>
                    <div class="bg-white/5 border border-white/10 rounded-xl p-3 flex items-center gap-3">
                      <div class="flex-1 min-w-0">
                        <p class="font-semibold truncate text-sm"><%= item.product.name %></p>
                        <p class="text-slate-400 text-xs">
                          KES <%= item.product.price %> &times; <%= item.quantity %> =
                          <span class="text-violet-300 font-semibold">
                            KES <%= :erlang.float_to_binary(Decimal.to_float(item.product.price) * item.quantity, decimals: 2) %>
                          </span>
                        </p>
                      </div>
                      <div class="flex items-center gap-1.5">
                        <button
                          phx-click="update_quantity"
                          phx-value-product_id={item.product.id}
                          phx-value-delta="-1"
                          class="w-7 h-7 bg-slate-800 hover:bg-slate-700 rounded-lg flex items-center justify-center transition-colors"
                        >
                          <.icon name="hero-minus" class="w-3.5 h-3.5" />
                        </button>
                        <input
                          id={"qty-input-#{item.product.id}"}
                          type="number"
                          min="1"
                          value={item.quantity}
                          phx-blur="set_quantity"
                          phx-value-product_id={item.product.id}
                          name="quantity"
                          class="w-12 h-7 bg-slate-900 border border-white/10 rounded-lg text-center text-sm font-mono font-bold text-white focus:outline-none focus:ring-1 focus:ring-violet-500 focus:border-violet-500 [appearance:textfield] [&::-webkit-inner-spin-button]:appearance-none [&::-webkit-outer-spin-button]:appearance-none"
                        />
                        <button
                          phx-click="update_quantity"
                          phx-value-product_id={item.product.id}
                          phx-value-delta="1"
                          class="w-7 h-7 bg-violet-600 hover:bg-violet-500 rounded-lg flex items-center justify-center transition-colors"
                        >
                          <.icon name="hero-plus" class="w-3.5 h-3.5" />
                        </button>
                      </div>
                    </div>
                  <% end %>
                <% end %>
              </div>

              <div class="p-6 border-t border-white/10 space-y-4">
                <div class="flex justify-between font-bold text-lg">
                  <span>Total</span>
                  <span class="tabular-nums">
                    KES <%= :erlang.float_to_binary(@cart_total, decimals: 2) %>
                  </span>
                </div>
                <button
                  phx-click="show_payment"
                  disabled={@cart == []}
                  class="w-full py-4 bg-violet-600 disabled:bg-slate-800 disabled:text-slate-600 rounded-xl font-bold hover:bg-violet-500 transition-all active:scale-[0.98]"
                >
                  Proceed to Payment
                </button>
              </div>
            <% end %>
          <% end %>
        </section>

        <%= if @mpesa_modal_open do %>
          <div class="fixed inset-0 z-[60] flex items-center justify-center">
            <div phx-click="close_mpesa_modal" class="absolute inset-0 bg-black/60 backdrop-blur-sm">
            </div>

            <div class="relative bg-[#0B0F1A] p-8 rounded-2xl w-full max-w-md border border-white/10 shadow-2xl">
              <h3 class="text-xl font-bold mb-6 flex items-center gap-2">
                <.icon name="hero-phone" class="w-6 h-6 text-yellow-500" /> M-PESA STK Push
              </h3>

              <%= if @mpesa_pending do %>
                <div class="space-y-6 text-center py-4">
                  <div class="w-16 h-16 border-4 border-yellow-500/20 border-t-yellow-500 rounded-full animate-spin mx-auto">
                  </div>
                  <div>
                    <p class="text-lg font-semibold">Waiting for Confirmation</p>
                    <p class="text-sm text-slate-400 mt-1">
                      An STK Push has been sent to <strong><%= @mpesa_phone %></strong>
                    </p>
                  </div>
                  <button
                    phx-click="close_mpesa_modal"
                    class="px-6 py-2 bg-white/5 hover:bg-white/10 rounded-xl text-sm font-medium transition-all"
                  >
                    Cancel
                  </button>
                </div>
              <% else %>
                <%= if @mpesa_result && @mpesa_result.status == :failed do %>
                  <div class="bg-red-500/10 border border-red-500/20 rounded-xl p-4 mb-6">
                    <p class="text-sm text-red-400 text-center font-medium">
                      STK Push failed or timed out. Please try again.
                    </p>
                  </div>
                <% end %>

                <form phx-submit="submit_mpesa" class="space-y-6">
                  <div>
                    <label class="text-sm text-slate-400 block mb-2 font-medium">
                      Customer Phone Number
                    </label>
                    <input
                      name="mpesa[phone]"
                      type="tel"
                      required
                      placeholder="07XXXXXXXX"
                      class="w-full bg-slate-900 border border-white/10 rounded-xl py-3 px-4 text-white text-lg focus:ring-2 focus:ring-yellow-500/50 outline-none"
                    />
                  </div>
                  <div class="flex items-center gap-3 justify-end">
                    <button
                      type="button"
                      phx-click="close_mpesa_modal"
                      class="px-6 py-3 bg-white/5 hover:bg-white/10 rounded-xl text-sm font-semibold transition-all"
                    >
                      Cancel
                    </button>
                    <button
                      type="submit"
                      class="px-8 py-3 bg-yellow-500 hover:bg-yellow-400 text-black rounded-xl font-bold shadow-lg shadow-yellow-500/20 transition-all"
                    >
                      Send STK Push
                    </button>
                  </div>
                </form>
              <% end %>
            </div>
          </div>
        <% end %>

        <%= if @card_modal_open do %>
          <div class="fixed inset-0 z-[60] flex items-center justify-center">
            <div phx-click="close_card_modal" class="absolute inset-0 bg-black/60 backdrop-blur-sm">
            </div>

            <div class="relative bg-[#0B0F1A] p-8 rounded-2xl w-full max-w-md border border-white/10 shadow-2xl">
              <h3 class="text-xl font-bold mb-6 flex items-center gap-2">
                <.icon name="hero-credit-card" class="w-6 h-6 text-blue-500" /> Card Payment
              </h3>

              <%= if @card_pending do %>
                <div class="space-y-6 text-center py-4">
                  <div class="w-16 h-16 border-4 border-blue-500/20 border-t-blue-500 rounded-full animate-spin mx-auto">
                  </div>
                  <div>
                    <p class="text-lg font-semibold">Processing Card</p>
                    <p class="text-sm text-slate-400 mt-1">Contacting payment gateway…</p>
                  </div>
                  <button
                    phx-click="close_card_modal"
                    class="px-6 py-2 bg-white/5 hover:bg-white/10 rounded-xl text-sm font-medium transition-all"
                  >
                    Cancel
                  </button>
                </div>
              <% else %>
                <%= if @card_result && @card_result.status == :failed do %>
                  <div class="bg-red-500/10 border border-red-500/20 rounded-xl p-4 mb-6">
                    <p class="text-sm text-red-400 text-center font-medium">
                      Transaction declined. Please check details or try another card.
                    </p>
                  </div>
                <% end %>

                <form phx-submit="submit_card" class="space-y-6">
                  <div>
                    <label class="text-sm text-slate-400 block mb-2 font-medium">Card Number</label>
                    <div class="relative">
                      <div class="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none">
                        <.icon name="hero-credit-card" class="w-5 h-5 text-slate-600" />
                      </div>
                      <input
                        name="card[number]"
                        type="text"
                        required
                        placeholder="4242 4242 4242 4242"
                        class="w-full bg-slate-900 border border-white/10 rounded-xl py-3 pl-12 pr-4 text-white font-mono focus:ring-2 focus:ring-blue-500/50 outline-none"
                      />
                    </div>
                  </div>
                  <div class="grid grid-cols-2 gap-4">
                    <div>
                      <label class="text-sm text-slate-400 block mb-2 font-medium">
                        Expiry (MM/YY)
                      </label>
                      <input
                        name="card[expiry]"
                        type="text"
                        required
                        placeholder="12/26"
                        class="w-full bg-slate-900 border border-white/10 rounded-xl py-3 px-4 text-white font-mono focus:ring-2 focus:ring-blue-500/50 outline-none"
                      />
                    </div>
                    <div>
                      <label class="text-sm text-slate-400 block mb-2 font-medium">CVV</label>
                      <input
                        name="card[cvv]"
                        type="text"
                        required
                        placeholder="123"
                        class="w-full bg-slate-900 border border-white/10 rounded-xl py-3 px-4 text-white font-mono focus:ring-2 focus:ring-blue-500/50 outline-none"
                      />
                    </div>
                  </div>
                  <div>
                    <label class="text-sm text-slate-400 block mb-2 font-medium">
                      Cardholder Name
                    </label>
                    <input
                      name="card[name]"
                      type="text"
                      required
                      placeholder="Jane Mwangi"
                      class="w-full bg-slate-900 border border-white/10 rounded-xl py-3 px-4 text-white focus:ring-2 focus:ring-blue-500/50 outline-none"
                    />
                  </div>
                  <div class="flex items-center gap-3 justify-end pt-4">
                    <button
                      type="button"
                      phx-click="close_card_modal"
                      class="px-6 py-3 bg-white/5 hover:bg-white/10 rounded-xl text-sm font-semibold transition-all"
                    >
                      Cancel
                    </button>
                    <button
                      type="submit"
                      class="px-8 py-3 bg-blue-600 hover:bg-blue-500 text-white rounded-xl font-bold shadow-lg shadow-blue-500/20 transition-all"
                    >
                      Process Payment
                    </button>
                  </div>
                </form>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
