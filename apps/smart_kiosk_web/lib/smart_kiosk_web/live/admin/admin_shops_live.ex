defmodule SmartKioskWeb.AdminShopsLive do
  alias SmartKioskCore.Shops
  use SmartKioskWeb, :live_view

  @page_size 20

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Admin - Shops")
      |> assign(:cart_count, 0)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    page = params |> Map.get("page", "1") |> String.to_integer() |> max(1)

    shops_page = Shops.list_shops(page: page, page_size: @page_size)

    socket =
      socket
      |> assign(:shops, shops_page.entries)
      |> assign(:page, shops_page.page_number)
      |> assign(:page_size, shops_page.page_size)
      |> assign(:total_shops, shops_page.total_entries)
      |> assign(:total_pages, shops_page.total_pages)

    {:noreply, socket}
  end

  @impl true
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
                <.link
                  navigate={"/admin/shops/#{shop.id}"}
                  class="bg-blue-500 text-white px-3 py-1 rounded text-sm hover:bg-blue-600"
                >
                  View
                </.link>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>

      <div class="flex items-center justify-between mt-4 text-sm">
        <p class="text-gray-600">
          Showing page <%= @page %> of <%= @total_pages %> (<%= @total_shops %> total shops)
        </p>
        <div class="flex gap-2">
          <.link
            :if={@page > 1}
            patch={~p"/admin/shops?page=#{@page - 1}"}
            class="px-3 py-1.5 bg-gray-200 hover:bg-gray-300 rounded text-gray-700"
          >
            ← Previous
          </.link>
          <.link
            :if={@page < @total_pages}
            patch={~p"/admin/shops?page=#{@page + 1}"}
            class="px-3 py-1.5 bg-gray-200 hover:bg-gray-300 rounded text-gray-700"
          >
            Next →
          </.link>
        </div>
      </div>
    </div>
    """
  end
end
