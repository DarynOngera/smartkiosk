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
     |> assign(:cart_open, false)
     |> assign(:active_tab, "products")
     |> assign(:mobile_menu_open, false)}
  end

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
  def handle_event("search", %{"search" => search}, socket) do
    products = Catalogue.list_products(socket.assigns.shop, status: :active, search: search)
    {:noreply, assign(socket, :products, products)}
  end

  defp calculate_total(cart) do
    cart
    |> Enum.reduce(0.0, fn item, acc ->
      acc + Decimal.to_float(item.product.price) * item.quantity
    end)
  end

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

        <%!-- Mobile Cart Backdrop --%>
        <%= if @cart_open do %>
          <div phx-click="toggle_cart" class="fixed inset-0 bg-black/50 z-50 lg:hidden"></div>
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
                <%= if @active_tab == "products",
                  do: "Point of Sale",
                  else: String.capitalize(@active_tab) %>
              </h1>
            </div>
            <div class="flex items-center gap-4">
              <button class="btn btn-outline border-white/10 text-white hidden sm:block">
                Scan Barcode
              </button>
              <button phx-click="toggle_cart" class="lg:hidden p-3 bg-violet-600 rounded-xl relative">
                <.icon name="hero-shopping-cart" class="w-5 h-5" />
                <span class="absolute -top-1 -right-1 bg-red-500 text-[10px] w-5 h-5 flex items-center justify-center rounded-full font-bold">
                  <%= length(@cart) %>
                </span>
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
                      <img
                        :if={Enum.any?(product.images)}
                        src={List.first(product.images).url}
                        class="w-full h-full object-cover"
                      />
                      <.icon
                        :if={Enum.empty?(product.images)}
                        name="hero-shopping-bag"
                        class="w-10 h-10 text-slate-600"
                      />
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
          !@cart_open && "hidden lg:block translate-x-full lg:translate-x-0"
        ]}>
          <div class="p-6 border-b border-white/10 flex justify-between items-center">
            <h2 class="text-xl font-bold">Cart (<%= length(@cart) %>)</h2>
            <div class="flex items-center gap-3">
              <button phx-click="toggle_cart" class="lg:hidden text-slate-400">Close</button>
              <button phx-click="clear_cart" class="text-red-400 text-sm hover:text-red-300">
                Clear
              </button>
            </div>
          </div>

          <div class="flex-1 overflow-y-auto p-6 space-y-4">
            <%= for item <- @cart do %>
              <div class="bg-white/5 border border-white/10 rounded-xl p-4 flex items-center gap-4">
                <div class="flex-1 min-w-0">
                  <p class="font-semibold truncate"><%= item.product.name %></p>
                  <p class="text-slate-400 text-sm">KES <%= item.product.price %></p>
                </div>
                <div class="flex items-center gap-2">
                  <button
                    phx-click="update_quantity"
                    phx-value-product_id={item.product.id}
                    phx-value-delta="-1"
                    class="w-8 h-8 bg-slate-800 rounded-lg"
                  >
                    -
                  </button>
                  <span class="w-8 text-center"><%= item.quantity %></span>
                  <button
                    phx-click="update_quantity"
                    phx-value-product_id={item.product.id}
                    phx-value-delta="1"
                    class="w-8 h-8 bg-violet-600 rounded-lg"
                  >
                    +
                  </button>
                </div>
              </div>
            <% end %>
          </div>

          <div class="p-6 border-t border-white/10 space-y-4">
            <div class="flex justify-between font-bold text-lg">
              <span>Total</span><span>KES <%= :erlang.float_to_binary(@cart_total, decimals: 2) %></span>
            </div>
            <button class="w-full py-4 bg-violet-600 rounded-xl font-bold hover:bg-violet-500">
              Proceed to Payment
            </button>
          </div>
        </section>
      </div>
    </div>
    """
  end
end
