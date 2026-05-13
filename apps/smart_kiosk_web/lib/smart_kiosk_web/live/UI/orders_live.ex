defmodule SmartKioskWeb.UI.OrdersLive.Index do
  use SmartKioskWeb, :live_view
  alias SmartKioskCore.Orders

  @statuses ~w(pending confirmed preparing ready dispatched delivered cancelled)a

  def mount(_params, _session, socket) do
    shop = socket.assigns.current_shop
    orders = Orders.list_orders(shop)

    {:ok,
     socket
     |> assign(:orders, orders)
     |> assign(:page_title, "Orders")
     |> assign(:status_filter, nil)
      |> assign(:statuses, @statuses)
    }
  end

  def handle_params(params, _url, socket) do
    status = params["status"]
    shop = socket.assigns.current_shop

    orders =
      if status && status in Enum.map(@statuses, &to_string/1) do
        Orders.list_orders(shop, status: String.to_atom(status))
      else
        Orders.list_orders(shop)
      end

    {:noreply,
     socket
     |> assign(:orders, orders)
     |> assign(:status_filter, status)}
  end

  @spec render(any()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_shop}>
      <div class="container mx-auto px-4 py-8">
        <div class="flex justify-between items-center mb-6">
          <h1 class="text-3xl font-bold text-gray-900">Orders</h1>
          <div class="flex gap-2">
            <%= for status <- @statuses do %>
              <.link
                patch={~p"/orders?status=#{status}"}
                class={[
                  "px-4 py-2 rounded-lg text-sm font-medium transition-colors",
                  @status_filter == to_string(status) &&
                    "bg-blue-600 text-white",
                  @status_filter != to_string(status) &&
                    "bg-gray-100 text-gray-700 hover:bg-gray-200"
                ]}
              >
                <%= String.capitalize(to_string(status)) %> (<%= count_orders_by_status(
                  @orders,
                  status
                ) %>)
              </.link>
            <% end %>
            <.link
              patch={~p"/orders"}
              class={[
                "px-4 py-2 rounded-lg text-sm font-medium transition-colors",
                is_nil(@status_filter) && "bg-blue-600 text-white",
                !is_nil(@status_filter) && "bg-gray-100 text-gray-700 hover:bg-gray-200"
              ]}
            >
              All (<%= length(@orders) %>)
            </.link>
          </div>
        </div>

        <div class="bg-white rounded-lg shadow overflow-hidden">
          <%= if @orders == [] do %>
            <div class="p-8 text-center text-gray-500">
              <p class="text-lg">No orders found</p>
            </div>
          <% else %>
            <table class="min-w-full divide-y divide-gray-200">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Order ID
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Customer
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Status
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Total
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Date
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Channel
                  </th>
                  <th class="px-6 py-3"></th>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
                <%= for order <- @orders do %>
                  <tr class="hover:bg-gray-50">
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                      <%= String.slice(order.id, 0..7) %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      <%= (order.customer && order.customer.name) || "Guest" %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <span class={[
                        "px-2 inline-flex text-xs leading-5 font-semibold rounded-full",
                        status_bg_class(order.status)
                      ]}>
                        <%= String.capitalize(to_string(order.status)) %>
                      </span>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      <%= format_money(order.total) %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      <%= format_date(order.inserted_at) %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      <%= String.capitalize(to_string(order.channel)) %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                      <.link
                        navigate={~p"/orders/#{order.id}"}
                        class="text-blue-600 hover:text-blue-900"
                      >
                        View
                      </.link>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp count_orders_by_status(orders, status) do
    Enum.count(orders, &(&1.status == status))
  end

  defp status_bg_class(:pending), do: "bg-yellow-100 text-yellow-800"
  defp status_bg_class(:confirmed), do: "bg-blue-100 text-blue-800"
  defp status_bg_class(:preparing), do: "bg-purple-100 text-purple-800"
  defp status_bg_class(:ready), do: "bg-green-100 text-green-800"
  defp status_bg_class(:dispatched), do: "bg-indigo-100 text-indigo-800"
  defp status_bg_class(:delivered), do: "bg-gray-100 text-gray-800"
  defp status_bg_class(:cancelled), do: "bg-red-100 text-red-800"

  defp format_money(decimal) do
    "$#{Decimal.to_string(decimal)}"
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M")
  end
end

defmodule SmartKioskWeb.UI.OrdersLive.Show do
  use SmartKioskWeb, :live_view
  alias SmartKioskCore.Orders

  @valid_transitions %{
    pending: [:confirmed, :cancelled],
    confirmed: [:preparing, :cancelled],
    preparing: [:ready, :cancelled],
    ready: [:dispatched, :delivered],
    dispatched: [:delivered],
    delivered: [],
    cancelled: []
  }

  def mount(%{"id" => id}, _session, socket) do
    shop = socket.assigns.current_shop
    order = Orders.get_order!(shop, id)

    {:ok,
     socket
     |> assign(:order, order)
     |> assign(:page_title, "Order #{String.slice(order.id, 0..7)}")
     |> assign(:allowed_transitions, Map.get(@valid_transitions, order.status, []))}
  end

  def handle_event("transition_status", %{"status" => status}, socket) do
    shop = socket.assigns.current_shop
    order = socket.assigns.order
    new_status = String.to_atom(status)

    case Orders.transition_order(order, new_status) do
      {:ok, updated_order} ->
        {:noreply,
         socket
         |> assign(:order, updated_order)
         |> assign(:allowed_transitions, Map.get(@valid_transitions, new_status, []))
         |> put_flash(:info, "Order status updated to #{String.capitalize(status)}")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to update order: #{reason}")}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_shop}>
      <div class="container mx-auto px-4 py-8">
        <div class="mb-6">
          <.link navigate={~p"/orders"} class="text-blue-600 hover:text-blue-900 mb-4 inline-block">
            ← Back to Orders
          </.link>
          <h1 class="text-3xl font-bold text-gray-900 mt-2">
            Order <%= String.slice(@order.id, 0..7) %>
          </h1>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <!-- Order Details -->
          <div class="lg:col-span-2 space-y-6">
            <!-- Status Card -->
            <div class="bg-white rounded-lg shadow p-6">
              <h2 class="text-lg font-semibold text-gray-900 mb-4">Order Status</h2>
              <div class="flex items-center justify-between">
                <span class={[
                  "px-3 py-1 inline-flex text-sm leading-5 font-semibold rounded-full",
                  status_bg_class(@order.status)
                ]}>
                  <%= String.capitalize(to_string(@order.status)) %>
                </span>
                <div class="flex gap-2">
                  <%= for transition <- @allowed_transitions do %>
                    <button
                      phx-click="transition_status"
                      phx-value-status={transition}
                      class={[
                        "px-4 py-2 rounded-lg text-sm font-medium transition-colors",
                        transition == :cancelled && "bg-red-600 text-white hover:bg-red-700",
                        transition != :cancelled && "bg-blue-600 text-white hover:bg-blue-700"
                      ]}
                    >
                      <%= String.capitalize(to_string(transition)) %>
                    </button>
                  <% end %>
                </div>
              </div>
            </div>
            <!-- Order Items -->
            <div class="bg-white rounded-lg shadow p-6">
              <h2 class="text-lg font-semibold text-gray-900 mb-4">Order Items</h2>
              <table class="min-w-full divide-y divide-gray-200">
                <thead class="bg-gray-50">
                  <tr>
                    <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Product
                    </th>
                    <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Quantity
                    </th>
                    <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Unit Price
                    </th>
                    <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Total
                    </th>
                  </tr>
                </thead>
                <tbody class="bg-white divide-y divide-gray-200">
                  <%= for item <- @order.items do %>
                    <tr>
                      <td class="px-4 py-3 text-sm text-gray-900">
                        <%= item.product_name %>
                      </td>
                      <td class="px-4 py-3 text-sm text-gray-500">
                        <%= item.quantity %>
                      </td>
                      <td class="px-4 py-3 text-sm text-gray-500">
                        <%= format_money(item.unit_price) %>
                      </td>
                      <td class="px-4 py-3 text-sm text-gray-900">
                        <%= format_money(Decimal.mult(item.unit_price, Decimal.new(item.quantity))) %>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
            <!-- Customer Info -->
            <div class="bg-white rounded-lg shadow p-6">
              <h2 class="text-lg font-semibold text-gray-900 mb-4">Customer Information</h2>
              <div class="space-y-2">
                <p class="text-sm text-gray-600">
                  <span class="font-medium">Name:</span>
                  <%= (@order.customer && @order.customer.name) || "Guest" %>
                </p>
                <%= if @order.customer do %>
                  <p class="text-sm text-gray-600">
                    <span class="font-medium">Phone:</span>
                    <%= @order.customer.phone %>
                  </p>
                <% end %>
                <%= if @order.delivery_address do %>
                  <p class="text-sm text-gray-600">
                    <span class="font-medium">Delivery Address:</span>
                    <%= @order.delivery_address %>
                  </p>
                <% end %>
                <%= if @order.notes do %>
                  <p class="text-sm text-gray-600">
                    <span class="font-medium">Notes:</span>
                    <%= @order.notes %>
                  </p>
                <% end %>
              </div>
            </div>
          </div>
          <!-- Order Summary -->
          <div class="lg:col-span-1">
            <div class="bg-white rounded-lg shadow p-6 sticky top-6">
              <h2 class="text-lg font-semibold text-gray-900 mb-4">Order Summary</h2>
              <div class="space-y-3">
                <div class="flex justify-between text-sm">
                  <span class="text-gray-600">Subtotal</span>
                  <span class="text-gray-900"><%= format_money(@order.subtotal) %></span>
                </div>
                <div class="flex justify-between text-sm">
                  <span class="text-gray-600">Delivery Fee</span>
                  <span class="text-gray-900"><%= format_money(@order.delivery_fee) %></span>
                </div>
                <div class="border-t pt-3 flex justify-between">
                  <span class="font-semibold text-gray-900">Total</span>
                  <span class="font-bold text-lg text-gray-900">
                    <%= format_money(@order.total) %>
                  </span>
                </div>
              </div>

              <div class="mt-6 pt-6 border-t">
                <div class="space-y-2 text-sm">
                  <div class="flex justify-between">
                    <span class="text-gray-600">Channel</span>
                    <span class="text-gray-900">
                      <%= String.capitalize(to_string(@order.channel)) %>
                    </span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-gray-600">Order Date</span>
                    <span class="text-gray-900"><%= format_date(@order.inserted_at) %></span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp status_bg_class(:pending), do: "bg-yellow-100 text-yellow-800"
  defp status_bg_class(:confirmed), do: "bg-blue-100 text-blue-800"
  defp status_bg_class(:preparing), do: "bg-purple-100 text-purple-800"
  defp status_bg_class(:ready), do: "bg-green-100 text-green-800"
  defp status_bg_class(:dispatched), do: "bg-indigo-100 text-indigo-800"
  defp status_bg_class(:delivered), do: "bg-gray-100 text-gray-800"
  defp status_bg_class(:cancelled), do: "bg-red-100 text-red-800"

  defp format_money(decimal) do
    "KSH #{Decimal.to_string(decimal)}"
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M")
  end
end
