defmodule SmartKioskWeb.AdminShopsLive do
  # alias SmartKioskCore.Schemas.Shop
  alias SmartKioskCore.Shops
  use SmartKioskWeb, :live_view

  def mount(_params, _session, socket) do
    list_shops = Shops.list_shops()

    socket =
      socket
      |> assign(:shops, list_shops)
      |> assign(:page_title, "Admin - Shops")
      |> assign(:cart_count, 0)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="p-4">
      <h1 class="text-2xl font-bold mb-4 text-black">Shops</h1>
      <table class="min-w-full bg-white border">
        <thead>
          <tr>
            <th class="py-2 px-4 border-b text-black">ID</th>
            <th class="py-2 px-4 border-b text-black">Name</th>
            <th class="py-2 px-4 border-b text-black">Status</th>
            <th class="py-2 px-4 border-b text-black">Plan</th>
            <th class="py-2 px-4 border-b text-black">Actions</th>
          </tr>
        </thead>
        <tbody>
          <%= for shop <- @shops do %>
            <tr>
              <td class="py-2 px-4 border-b text-black"><%= shop.id %></td>
              <td class="py-2 px-4 border-b text-black"><%= shop.name %></td>
              <td class="py-2 px-4 border-b text-black"><%= shop.status %></td>
              <td class="py-2 px-4 border-b text-black"><%= shop.plan %></td>
              <td class="py-2 px-4 border-b text-black">
                <!-- Placeholder for actions like Edit/Delete -->
                <button class="bg-blue-500 text-white px-3 py-1 rounded">Edit</button>
                <button class="bg-red-500 text-white px-3 py-1 rounded">Delete</button>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end
end
