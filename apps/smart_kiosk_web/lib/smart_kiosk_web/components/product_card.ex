defmodule SmartKioskWeb.Components.ProductCard do
  use Phoenix.Component
  import SmartKioskWeb.CoreComponents

  @doc """
  Renders a product card for the dashboard or storefront.
  """
  attr :product, :map, required: true
  attr :on_add, :string, default: "add_to_cart"

  def product_card(assigns) do
    ~H"""
    <div class="flex items-center justify-between p-4 bg-white/5 rounded-xl border border-white/5 hover:border-violet-500/30 transition-all">
      <div class="flex items-center gap-4">
        <div class="w-10 h-10 bg-slate-800 rounded-lg flex items-center justify-center text-slate-400 font-bold overflow-hidden">
          <%= if @product.images != [] do %>
            <img
              src={List.first(@product.images).url}
              alt={@product.name}
              class="w-full h-full object-cover"
            />
          <% else %>
            <%= String.slice(@product.name, 0..1) |> String.upcase() %>
          <% end %>
        </div>
        <div>
          <p class="text-white font-semibold"><%= @product.name %></p>
          <p class="text-slate-500 text-xs"><%= @product.sku %></p>
        </div>
      </div>
      <div class="flex items-center gap-6">
        <div class="text-right">
          <p class="text-white font-bold">KES <%= @product.price %></p>
          <p class={[
            "text-xs font-semibold",
            if(@product.stock_qty <= @product.low_stock_threshold,
              do: "text-red-400",
              else: "text-emerald-400"
            )
          ]}>
            <%= @product.stock_qty %> in stock
          </p>
        </div>
        <button
          phx-click={@on_add}
          phx-value-product_id={@product.id}
          class="p-2 bg-white/5 hover:bg-violet-500 rounded-lg transition-colors"
        >
          <.icon name="hero-plus" class="w-4 h-4 text-white" />
        </button>
      </div>
    </div>
    """
  end
end
