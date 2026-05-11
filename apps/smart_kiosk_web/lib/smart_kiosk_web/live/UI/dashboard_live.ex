defmodule SmartKioskWeb.UI.DashboardLive do
  @moduledoc """
  Unified dashboard for both Customers and Shop Owners.
  """
  use SmartKioskWeb, :live_view

  alias SmartKioskCore.Catalogue
  import SmartKioskWeb.Navbar
  import SmartKioskWeb.Components.ProductCard

  def mount(_params, _session, socket) do
    _user = socket.assigns.current_user
    shop = socket.assigns.current_shop

    products = if shop, do: Catalogue.list_products(shop, limit: 10), else: []

    # In a real app, you'd fetch stats/data here
    socket =
      if shop do
        # Merchant Stats
        socket
        |> assign(:page_title, "Merchant Dashboard")
        |> assign(:sales_today, "KES 0.00")
        |> assign(:inventory_count, Catalogue.count_products(shop))
        |> assign(:pending_orders, 0)
        |> assign(:products, products)
      else
        # Customer Stats
        socket
        |> assign(:page_title, "Customer Dashboard")
        |> assign(:total_spent, "KES 0.00")
        |> assign(:orders_count, 0)
        |> assign(:loyalty_points, 0)
      end

    {:ok, socket}
  end

  def merchant_view(assigns) do
    ~H"""
    <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-10">
      <%!-- Stats Cards --%>
      <div class="bg-white/5 border border-white/10 rounded-3xl p-6 backdrop-blur-xl">
        <div class="flex items-center gap-4 mb-4">
          <div class="w-12 h-12 bg-emerald-500/20 rounded-2xl flex items-center justify-center">
            <.icon name="hero-banknotes" class="w-6 h-6 text-emerald-400" />
          </div>
          <div>
            <p class="text-slate-500 text-sm font-medium">Sales Today</p>
            <p class="text-2xl font-bold text-white"><%= @sales_today %></p>
          </div>
        </div>
      </div>

      <div class="bg-white/5 border border-white/10 rounded-3xl p-6 backdrop-blur-xl">
        <div class="flex items-center gap-4 mb-4">
          <div class="w-12 h-12 bg-violet-500/20 rounded-2xl flex items-center justify-center">
            <.icon name="hero-cube" class="w-6 h-6 text-violet-400" />
          </div>
          <div>
            <p class="text-slate-500 text-sm font-medium">Inventory</p>
            <p class="text-2xl font-bold text-white"><%= @inventory_count %> Items</p>
          </div>
        </div>
      </div>

      <div class="bg-white/5 border border-white/10 rounded-3xl p-6 backdrop-blur-xl">
        <div class="flex items-center gap-4 mb-4">
          <div class="w-12 h-12 bg-amber-500/20 rounded-2xl flex items-center justify-center">
            <.icon name="hero-clock" class="w-6 h-6 text-amber-400" />
          </div>
          <div>
            <p class="text-slate-500 text-sm font-medium">Pending Orders</p>
            <p class="text-2xl font-bold text-white"><%= @pending_orders %></p>
          </div>
        </div>
      </div>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
      <%!-- Inventory List --%>
      <div class="bg-white/5 border border-white/10 rounded-3xl p-6 backdrop-blur-xl">
        <h2 class="text-xl font-bold text-white mb-6">Recent Inventory</h2>
        <div class="space-y-4">
          <%= for product <- @products do %>
            <.product_card product={product} />
          <% end %>
        </div>
      </div>

      <%!-- Quick Actions --%>
      <div class="space-y-4">
        <h2 class="text-xl font-bold text-white mb-4">Quick Management</h2>
        <div class="grid grid-cols-2 gap-4">
          <.link
            navigate="/inventory"
            class="p-6 bg-white/5 border border-white/10 rounded-2xl hover:bg-white/10 transition-colors group"
          >
            <.icon
              name="hero-plus-circle"
              class="w-8 h-8 text-violet-400 mb-3 group-hover:scale-110 transition-transform"
            />
            <p class="font-bold text-white">Add/Remove Stock</p>
            <p class="text-slate-500 text-xs mt-1">Manage your inventory levels</p>
          </.link>

          <.link
            navigate="/orders"
            class="p-6 bg-white/5 border border-white/10 rounded-2xl hover:bg-white/10 transition-colors group"
          >
            <.icon
              name="hero-truck"
              class="w-8 h-8 text-indigo-400 mb-3 group-hover:scale-110 transition-transform"
            />
            <p class="font-bold text-white">Orders & Deliveries</p>
            <p class="text-slate-500 text-xs mt-1">Track customer shipments</p>
          </.link>
        </div>
      </div>
    </div>
    """
  end

  def customer_view(assigns) do
    ~H"""
    <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-10">
      <%!-- Stats Cards --%>
      <div class="bg-white/5 border border-white/10 rounded-3xl p-6 backdrop-blur-xl">
        <div class="flex items-center gap-4 mb-4">
          <div class="w-12 h-12 bg-indigo-500/20 rounded-2xl flex items-center justify-center">
            <.icon name="hero-shopping-bag" class="w-6 h-6 text-indigo-400" />
          </div>
          <div>
            <p class="text-slate-500 text-sm font-medium">Orders Count</p>
            <p class="text-2xl font-bold text-white"><%= @orders_count %></p>
          </div>
        </div>
      </div>

      <div class="bg-white/5 border border-white/10 rounded-3xl p-6 backdrop-blur-xl">
        <div class="flex items-center gap-4 mb-4">
          <div class="w-12 h-12 bg-emerald-500/20 rounded-2xl flex items-center justify-center">
            <.icon name="hero-currency-dollar" class="w-6 h-6 text-emerald-400" />
          </div>
          <div>
            <p class="text-slate-500 text-sm font-medium">Total Spent</p>
            <p class="text-2xl font-bold text-white"><%= @total_spent %></p>
          </div>
        </div>
      </div>

      <div class="bg-white/5 border border-white/10 rounded-3xl p-6 backdrop-blur-xl">
        <div class="flex items-center gap-4 mb-4">
          <div class="w-12 h-12 bg-rose-500/20 rounded-2xl flex items-center justify-center">
            <.icon name="hero-star" class="w-6 h-6 text-rose-400" />
          </div>
          <div>
            <p class="text-slate-500 text-sm font-medium">Loyalty Points</p>
            <p class="text-2xl font-bold text-white"><%= @loyalty_points %></p>
          </div>
        </div>
      </div>
    </div>

    <div class="bg-white/5 border border-white/10 rounded-3xl overflow-hidden">
      <div class="p-6 border-b border-white/10 flex items-center justify-between">
        <h2 class="text-xl font-bold text-white">Recent Purchases</h2>
        <button class="text-sm text-violet-400 font-semibold hover:text-violet-300">View All</button>
      </div>
      <div class="p-20 flex flex-col items-center justify-center text-center">
        <div class="w-16 h-16 bg-white/5 rounded-full flex items-center justify-center mb-4">
          <.icon name="hero-shopping-cart" class="w-8 h-8 text-slate-700" />
        </div>
        <p class="text-slate-500 font-medium">No purchases yet.</p>
        <p class="text-slate-600 text-sm mt-1">Items you buy will appear here.</p>
      </div>
    </div>
    """
  end
end
