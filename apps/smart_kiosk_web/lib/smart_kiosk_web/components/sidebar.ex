defmodule SmartKioskWeb.Sidebar do
  @moduledoc """
  Responsive sidebar component with category filters.

  On desktop (lg+): Shows a sticky sidebar on the left.
  On mobile: Shows a horizontal scrollable category bar at the top of the content.
  """
  use SmartKioskWeb, :html

  @doc """
  Renders the category filter sidebar / mobile category bar.

  ## Attributes

  * `shop_categories` - Map of category atoms to labels
  * `selected_category` - Currently selected category (optional)
  """
  attr :shop_categories, :map, required: true
  attr :selected_category, :atom, default: nil

  def sidebar(assigns) do
    ~H"""
    <%!-- Mobile Horizontal Category Bar --%>
    <div class="lg:hidden border-b border-white/5 bg-[#0B0F1A]">
      <div class="px-4 py-3">
        <div class="flex items-center gap-2 overflow-x-auto overscroll-x-contain touch-pan-x scroll-smooth pb-2 pr-4 snap-x snap-mandatory scrollbar-thin">
          <.mobile_category_chip cat_key={nil} label="All" is_selected={is_nil(@selected_category)} />

          <%= for {cat_key, label} <- @shop_categories do %>
            <.mobile_category_chip
              cat_key={cat_key}
              label={label}
              is_selected={@selected_category == cat_key}
            />
          <% end %>
        </div>
      </div>
    </div>

    <%!-- Desktop Sticky Sidebar --%>
    <aside class="hidden lg:block w-72 xl:w-80 shrink-0 sticky top-16 h-[calc(100vh-4rem)] overflow-y-auto border-r border-white/5 bg-[#0B0F1A]/50 backdrop-blur-sm">
      <div class="p-5">
        <h2 class="text-xs font-bold uppercase tracking-wider text-slate-500 mb-4">
          Shop Categories
        </h2>

        <%= if @selected_category do %>
          <button
            phx-click="clear_filter"
            class="w-full mb-4 flex items-center gap-2 px-4 py-2.5 rounded-xl bg-violet-500/10 border border-violet-500/30 text-violet-400 text-sm font-medium hover:bg-violet-500/20 transition-colors"
          >
            <.icon name="hero-x-mark" class="w-4 h-4" /> Clear Filter
          </button>
        <% end %>

        <div class="space-y-0.5">
          <.category_button
            cat_key={nil}
            label="All Shops"
            icon="hero-squares-2x2"
            is_selected={is_nil(@selected_category)}
          />

          <%= for {cat_key, label} <- @shop_categories do %>
            <.category_button
              cat_key={cat_key}
              label={label}
              icon={category_icon(cat_key)}
              is_selected={@selected_category == cat_key}
            />
          <% end %>
        </div>
      </div>
    </aside>
    """
  end

  @doc """
  Renders a single category filter button for desktop sidebar.
  """
  attr :cat_key, :atom
  attr :label, :string, required: true
  attr :icon, :string, required: true
  attr :is_selected, :boolean, default: false

  def category_button(assigns) do
    ~H"""
    <button
      phx-click={if @cat_key, do: "filter_category", else: "clear_filter"}
      phx-value-category={@cat_key}
      class={[
        "w-full flex items-center gap-3 px-4 py-2.5 rounded-xl text-left text-sm font-medium transition-all",
        @is_selected && "bg-violet-500/20 text-violet-400 border border-violet-500/30",
        !@is_selected && "text-slate-400 hover:text-white hover:bg-white/5"
      ]}
    >
      <.icon name={@icon} class="w-5 h-5 flex-shrink-0" />
      <span class="truncate"><%= @label %></span>
    </button>
    """
  end

  @doc """
  Renders a compact category chip for mobile horizontal scroll.
  """
  attr :cat_key, :atom
  attr :label, :string, required: true
  attr :is_selected, :boolean, default: false

  def mobile_category_chip(assigns) do
    ~H"""
    <button
      phx-click={if @cat_key, do: "filter_category", else: "clear_filter"}
      phx-value-category={@cat_key}
      class={[
        "flex-shrink-0 px-4 py-2 rounded-full text-sm font-medium whitespace-nowrap transition-all snap-start",
        @is_selected && "bg-violet-500/20 text-violet-400 border border-violet-500/30",
        !@is_selected &&
          "bg-white/5 text-slate-400 border border-white/10 hover:bg-white/10 hover:text-white"
      ]}
    >
      <%= @label %>
    </button>
    """
  end

  @doc """
  Returns the icon name for a given category.
  """
  def category_icon(:electronics), do: "hero-device-phone-mobile"
  def category_icon(:general_shop), do: "hero-shopping-bag"
  def category_icon(:vegetables), do: "hero-beaker"
  def category_icon(:fruits), do: "hero-sun"
  def category_icon(:groceries), do: "hero-shopping-cart"
  def category_icon(:hardware), do: "hero-wrench"
  def category_icon(:garage), do: "hero-truck"
  def category_icon(:furniture), do: "hero-home"
  def category_icon(:services), do: "hero-hand-raised"
  def category_icon(:textiles), do: "hero-scissors"
  def category_icon(:cosmetics), do: "hero-sparkles"
  def category_icon(:bakery), do: "hero-cake"
  def category_icon(:butcher), do: "hero-fire"
  def category_icon(:pharmacy), do: "hero-heart"
  def category_icon(:restaurant), do: "hero-building-storefront"
  def category_icon(:cafe), do: "hero-cup"
  def category_icon(:beverages), do: "hero-beaker"
  def category_icon(:books), do: "hero-book-open"
  def category_icon(:stationery), do: "hero-pencil"
  def category_icon(:mobile_money), do: "hero-currency-dollar"
  def category_icon(:tailoring), do: "hero-scissors"
  def category_icon(:cleaning), do: "hero-trash"
  def category_icon(_), do: "hero-storefront"
end
