defmodule SmartKioskWeb.UI.POSLive.Index do
  use SmartKioskWeb, :live_view

  alias SmartKioskCore.Catalogue
  import SmartKioskWeb.Navbar

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    shop = socket.assigns.current_shop

    products = if shop, do: Catalogue.list_products(shop, status: :active), else: []

    {:ok,
     socket
     |> assign(:page_title, "POS")
     |> assign(:user, user)
     |> assign(:shop, shop)
     |> assign(:products, products)
     |> assign(:cart, [])
     |> assign(:cart_total, 0.0)
     |> assign(:search_query, "")
     |> assign(:show_payment, false)
     |> assign(:payment_method, "mpesa")
     |> assign(:payment_amount, nil)
     |> assign(:active_tab, "products")
     |> assign(:mobile_menu_open, false)
     |> assign(:mobile_cart_open, false)}
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
    {:noreply, assign(socket, cart: [], cart_total: 0.0, show_payment: false)}
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
  def handle_event("select_payment_method", %{"method" => method}, socket) do
    {:noreply, assign(socket, :payment_method, method)}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, socket |> assign(:active_tab, tab) |> assign(:mobile_menu_open, false)}
  end

  @impl true
  def handle_event("toggle_mobile_menu", _params, socket) do
    {:noreply, update(socket, :mobile_menu_open, &(!&1))}
  end

  @impl true
  def handle_event("toggle_mobile_cart", _params, socket) do
    {:noreply, update(socket, :mobile_cart_open, &(!&1))}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    products = Catalogue.list_products(socket.assigns.shop, status: :active, search: query)
    {:noreply, socket |> assign(:products, products) |> assign(:search_query, query)}
  end

  defp calculate_total(cart) do
    cart
    |> Enum.reduce(0.0, fn item, acc ->
      acc + (Decimal.to_float(item.product.price) * item.quantity)
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#0B0F1A] text-white">
      <.navbar current_user={@user} user_shop={@shop} cart_count={length(@cart)} />

      <div class="flex h-[calc(100vh-64px)] overflow-hidden relative">
        <%!-- Mobile Menu Overlay --%>
        <%= if @mobile_menu_open do %>
          <div
            phx-click="toggle_mobile_menu"
            class="fixed inset-0 bg-black/50 z-40 lg:hidden"
          ></div>
        <% end %>

        <%!-- Mobile Cart Overlay --%>
        <%= if @mobile_cart_open do %>
          <div
            phx-click="toggle_mobile_cart"
            class="fixed inset-0 bg-black/50 z-50 lg:hidden"
          ></div>
        <% end %>

        <%!-- Left Sidebar Navigation --%>
        <aside class={[
          "fixed lg:relative z-50 lg:z-auto h-full transition-transform duration-300 ease-in-out lg:translate-x-0",
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
            <h2 class="hidden lg:block text-sm font-semibold text-slate-400 uppercase tracking-wider mb-4">Menu</h2>
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
                phx-value-tab="inventory"
                class={[
                  "w-full flex items-center gap-3 px-4 py-3 rounded-xl transition-all",
                  @active_tab == "inventory" && "bg-violet-500 text-white",
                  @active_tab != "inventory" && "text-slate-400 hover:bg-white/5 hover:text-white"
                ]}
              >
                <.icon name="hero-cube" class="w-5 h-5" />
                <span class="font-medium">Inventory</span>
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
                <.icon name="hero-receipt" class="w-5 h-5" />
                <span class="font-medium">Orders</span>
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
                phx-value-tab="reports"
                class={[
                  "w-full flex items-center gap-3 px-4 py-3 rounded-xl transition-all",
                  @active_tab == "reports" && "bg-violet-500 text-white",
                  @active_tab != "reports" && "text-slate-400 hover:bg-white/5 hover:text-white"
                ]}
              >
                <.icon name="hero-chart-bar" class="w-5 h-5" />
                <span class="font-medium">Reports</span>
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
        </aside>

        <%!-- Main Content Area --%>
        <main class="flex-1 flex flex-col overflow-hidden">
          <header class="p-6 border-b border-white/10 flex items-center justify-between">
            <div class="flex items-center gap-3">
              <button phx-click="toggle_mobile_menu" class="lg:hidden p-2 text-slate-400 hover:text-white">
                <.icon name="hero-bars-3" class="w-6 h-6" />
              </button>
              <h1 class="text-xl font-bold"><%= if @active_tab == "products", do: "Point of Sale", else: String.capitalize(@active_tab) %></h1>
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
                <button class="btn btn-outline border-white/10 text-white hidden sm:block">Scan Barcode</button>
              <% end %>
              <button phx-click="toggle_mobile_cart" class="lg:hidden p-2 text-slate-400 hover:text-white relative">
                <.icon name="hero-shopping-cart" class="w-6 h-6" />
                <%= if length(@cart) > 0 do %>
                  <span class="absolute -top-1 -right-1 w-5 h-5 bg-violet-500 rounded-full text-xs font-bold flex items-center justify-center">
                    <%= length(@cart) %>
                  </span>
                <% end %>
              </button>
            </div>
          </header>

          <%= if @active_tab == "products" do %>
            <div class="p-6 flex-1 overflow-y-auto">
              <div class="grid grid-cols-2 lg:grid-cols-4 gap-4">
                <%= for product <- @products do %>
                  <button
                    type="button"
                    phx-click="add_to_cart"
                    phx-value-product_id={product.id}
                    class="bg-white/5 border border-white/10 rounded-2xl p-4 hover:border-violet-500/30 transition-all text-left"
                  >
                    <div class="w-full h-32 bg-slate-800 rounded-lg mb-3 flex items-center justify-center overflow-hidden">
                      <img :if={Enum.any?(product.images)} src={List.first(product.images).url} class="w-full h-full object-cover" />
                      <.icon :if={Enum.empty?(product.images)} name="hero-shopping-bag" class="w-10 h-10 text-slate-600" />
                    </div>
                    <h3 class="font-semibold text-sm truncate"><%= product.name %></h3>
                    <p class="text-violet-400 font-bold">KES <%= product.price %></p>
                  </button>
                <% end %>
              </div>
            </div>
          <% else %>
            <div class="flex-1 flex items-center justify-center">
              <div class="text-center">
                <.icon name="hero-cube" class="w-16 h-16 text-slate-600 mx-auto mb-4" />
                <h2 class="text-xl font-semibold text-slate-400"><%= String.capitalize(@active_tab) %></h2>
                <p class="text-slate-500 mt-2">Coming soon</p>
              </div>
            </div>
          <% end %>
        </main>

        <%!-- Cart Sidebar (Desktop) / Modal (Mobile) --%>
        <section class={[
          "fixed lg:relative z-50 lg:z-auto h-full transition-transform duration-300 ease-in-out lg:translate-x-0",
          "w-96 border-l border-white/10 bg-[#0B0F1A] flex flex-col",
          @mobile_cart_open && "translate-x-0",
          !@mobile_cart_open && "translate-x-full lg:translate-x-0"
        ]}>
          <%!-- Mobile Close Button --%>
          <button
            phx-click="toggle_mobile_cart"
            class="lg:hidden absolute top-4 right-4 text-slate-400 hover:text-white z-10"
          >
            <.icon name="hero-x-mark" class="w-6 h-6" />
          </button>

          <%= if @show_payment do %>
            <%!-- Payment Panel --%>
            <div class="p-6 border-b border-white/10 flex items-center gap-3">
              <button phx-click="hide_payment" class="text-slate-400 hover:text-white">
                <.icon name="hero-arrow-left" class="w-5 h-5" />
              </button>
              <h2 class="text-xl font-bold">Payment</h2>
            </div>

            <div class="flex-1 overflow-y-auto p-6 space-y-6">
              <%!-- Payment Methods --%>
              <div>
                <label class="text-sm text-slate-400 mb-3 block">Payment Method</label>
                <div class="grid grid-cols-2 gap-3">
                  <button
                    type="button"
                    phx-click="select_payment_method"
                    phx-value-method="mpesa"
                    class={[
                      "p-4 border rounded-xl flex flex-col items-center gap-2 transition-all",
                      @payment_method == "mpesa" && "border-violet-500 bg-violet-500/10",
                      @payment_method != "mpesa" && "border-white/10 hover:border-violet-500/30"
                    ]}
                  >
                    <.icon name="hero-device-phone-mobile" class="w-8 h-8" />
                    <span class="text-sm font-semibold">M-Pesa</span>
                  </button>
                  <button
                    type="button"
                    phx-click="select_payment_method"
                    phx-value-method="card"
                    class={[
                      "p-4 border rounded-xl flex flex-col items-center gap-2 transition-all",
                      @payment_method == "card" && "border-violet-500 bg-violet-500/10",
                      @payment_method != "card" && "border-white/10 hover:border-violet-500/30"
                    ]}
                  >
                    <.icon name="hero-credit-card" class="w-8 h-8" />
                    <span class="text-sm font-semibold">Card</span>
                  </button>
                  <button
                    type="button"
                    phx-click="select_payment_method"
                    phx-value-method="cash"
                    class={[
                      "p-4 border rounded-xl flex flex-col items-center gap-2 transition-all",
                      @payment_method == "cash" && "border-violet-500 bg-violet-500/10",
                      @payment_method != "cash" && "border-white/10 hover:border-violet-500/30"
                    ]}
                  >
                    <.icon name="hero-banknotes" class="w-8 h-8" />
                    <span class="text-sm font-semibold">Cash</span>
                  </button>
                  <button
                    type="button"
                    phx-click="select_payment_method"
                    phx-value-method="transfer"
                    class={[
                      "p-4 border rounded-xl flex flex-col items-center gap-2 transition-all",
                      @payment_method == "transfer" && "border-violet-500 bg-violet-500/10",
                      @payment_method != "transfer" && "border-white/10 hover:border-violet-500/30"
                    ]}
                  >
                    <.icon name="hero-arrows-right-left" class="w-8 h-8" />
                    <span class="text-sm font-semibold">Transfer</span>
                  </button>
                </div>
              </div>

              <%!-- Payment Details --%>
              <div>
                <label class="text-sm text-slate-400 mb-3 block">Amount Due</label>
                <div class="bg-white/5 border border-white/10 rounded-xl p-4">
                  <p class="text-3xl font-bold text-violet-400">KES <%= :erlang.float_to_binary(@cart_total, decimals: 2) %></p>
                </div>
              </div>

              <%!-- Order Summary --%>
              <div class="bg-white/5 border border-white/10 rounded-xl p-4 space-y-2">
                <h3 class="font-semibold mb-3">Order Summary</h3>
                <%= for item <- @cart do %>
                  <div class="flex justify-between text-sm">
                    <span class="text-slate-400"><%= item.product.name %> x<%= item.quantity %></span>
                    <span>KES <%= :erlang.float_to_binary(Decimal.to_float(item.product.price) * item.quantity, decimals: 2) %></span>
                  </div>
                <% end %>
              </div>
            </div>

            <div class="p-6 border-t border-white/10 space-y-4">
              <button class="w-full py-4 bg-violet-600 rounded-xl font-bold hover:bg-violet-500 flex items-center justify-center gap-2">
                <.icon name="hero-check" class="w-5 h-5" /> Complete Payment
              </button>
            </div>
          <% else %>
            <%!-- Cart View --%>
            <div class="p-6 border-b border-white/10 flex justify-between items-center">
              <h2 class="text-xl font-bold">Cart (<%= length(@cart) %>)</h2>
              <button phx-click="clear_cart" class="text-red-400 text-sm hover:text-red-300">Clear</button>
            </div>

            <div class="flex-1 overflow-y-auto p-6 space-y-4">
              <%= for item <- @cart do %>
                <div class="bg-white/5 border border-white/10 rounded-xl p-4 flex items-center gap-4">
                  <div class="flex-1 min-w-0">
                    <p class="font-semibold truncate"><%= item.product.name %></p>
                    <p class="text-slate-400 text-sm">KES <%= item.product.price %></p>
                  </div>
                  <div class="flex items-center gap-2">
                    <button phx-click="update_quantity" phx-value-product_id={item.product.id} phx-value-delta="-1" class="w-8 h-8 bg-slate-800 rounded-lg">-</button>
                    <span class="w-8 text-center"><%= item.quantity %></span>
                    <button phx-click="update_quantity" phx-value-product_id={item.product.id} phx-value-delta="1" class="w-8 h-8 bg-violet-600 rounded-lg">+</button>
                  </div>
                </div>
              <% end %>
            </div>

            <div class="p-6 border-t border-white/10 space-y-4">
              <div class="flex justify-between font-bold text-lg"><span>Total</span><span>KES <%= :erlang.float_to_binary(@cart_total, decimals: 2) %></span></div>
              <button phx-click="show_payment" class="w-full py-4 bg-violet-600 rounded-xl font-bold hover:bg-violet-500">Proceed to Payment</button>
            </div>
          <% end %>
        </section>
      </div>
    </div>
    """
  end
end
