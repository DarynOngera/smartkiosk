defmodule SmartKioskWeb.SearchBar do
  @moduledoc """
  Reusable search bar component for searching products and shops.
  """
  use SmartKioskWeb, :html

  @doc """
  Renders a search bar with placeholder and submit handler.

  ## Attributes

  * `placeholder` - Text to show when input is empty
  * `value` - Current search value
  * `phx-target` - LiveView component to handle search events
  * `phx-change` - Event name for input changes
  * `phx-submit` - Event name for form submission
  """
  attr :placeholder, :string, default: "Search products or shops..."
  attr :value, :string, default: ""
  attr :phx_target, :string, default: ""
  attr :phx_change, :string, default: "search"
  attr :phx_submit, :string, default: "search_submit"

  def search_bar(assigns) do
    ~H"""
    <div class="relative max-w-2xl mx-auto w-full">
      <form
        phx-target={@phx_target}
        phx-change={@phx_change}
        phx-submit={@phx_submit}
        class="relative"
      >
        <div class="relative">
          <input
            type="text"
            name="query"
            value={@value}
            placeholder={@placeholder}
            class="w-full px-5 py-3 pl-12 bg-white/5 border border-white/10 rounded-2xl text-white placeholder:text-slate-500 focus:bg-white/10 focus:border-violet-500/50 focus:ring-2 focus:ring-violet-500/20 transition-all outline-none"
            autocomplete="off"
          />
          <div class="absolute left-4 top-1/2 -translate-y-1/2">
            <.icon name="hero-magnifying-glass" class="w-5 h-5 text-slate-400" />
          </div>
        </div>
        <button
          type="submit"
          class="absolute right-2 top-1/2 -translate-y-1/2 px-4 py-2 bg-violet-500 hover:bg-violet-400 text-white rounded-xl font-medium transition-all text-sm"
        >
          Search
        </button>
      </form>
    </div>
    """
  end

  @doc """
  Renders search results dropdown for live search suggestions.
  """
  attr :results, :list, default: []
  attr :loading, :boolean, default: false
  attr :query, :string, default: ""

  def search_results(assigns) do
    ~H"""
    <div class="absolute top-full left-0 right-0 mt-2 bg-[#0B0F1A] border border-white/10 rounded-2xl shadow-xl z-50 max-h-96 overflow-y-auto">
      <%= if @loading do %>
        <div class="p-6 text-center">
          <div class="inline-flex items-center gap-2">
            <div class="w-4 h-4 border-2 border-violet-500 border-t-transparent rounded-full animate-spin">
            </div>
            <span class="text-slate-400">Searching...</span>
          </div>
        </div>
      <% else %>
        <%= if @query == "" do %>
          <div class="p-6 text-center text-slate-500">
            <.icon name="hero-magnifying-glass" class="w-8 h-8 mx-auto mb-2" />
            <p>Start typing to search products and shops</p>
          </div>
        <% else %>
          <%= if @results == [] do %>
            <div class="p-6 text-center text-slate-500">
              <.icon name="hero-x-circle" class="w-8 h-8 mx-auto mb-2" />
              <p>No results found for "<%= @query %>"</p>
            </div>
          <% else %>
            <div class="py-2">
              <%= for result <- @results do %>
                <.search_result_item result={result} />
              <% end %>
            </div>
          <% end %>
        <% end %>
      <% end %>
    </div>
    """
  end

  defp search_result_item(%{result: %{type: :product}} = assigns) do
    ~H"""
    <.link
      navigate={~p"/shop/#{@result.shop.slug}/product/#{@result.id}"}
      class="flex items-center gap-4 p-4 hover:bg-white/5 transition-colors"
    >
      <div class="w-12 h-12 bg-slate-800 rounded-lg flex items-center justify-center flex-shrink-0">
        <%= if @result.images != [] and List.first(@result.images) do %>
          <img
            src={List.first(@result.images).url}
            alt={@result.name}
            class="w-full h-full object-cover rounded-lg"
          />
        <% else %>
          <.icon name="hero-photo" class="w-6 h-6 text-slate-600" />
        <% end %>
      </div>
      <div class="flex-1 min-w-0">
        <h4 class="font-semibold text-white truncate"><%= @result.name %></h4>
        <p class="text-sm text-slate-500 truncate"><%= @result.shop.name %></p>
        <p class="text-violet-400 font-bold">KES <%= @result.price %></p>
      </div>
      <div class="text-xs text-slate-400">
        Product
      </div>
    </.link>
    """
  end

  defp search_result_item(%{result: %{type: :shop}} = assigns) do
    ~H"""
    <.link
      navigate={~p"/shop/#{@result.slug}"}
      class="flex items-center gap-4 p-4 hover:bg-white/5 transition-colors"
    >
      <div class="w-12 h-12 bg-gradient-to-br from-violet-500/20 to-indigo-500/10 rounded-lg flex items-center justify-center flex-shrink-0">
        <.icon name="hero-storefront" class="w-6 h-6 text-violet-400" />
      </div>
      <div class="flex-1 min-w-0">
        <h4 class="font-semibold text-white truncate"><%= @result.name %></h4>
        <p class="text-sm text-slate-500 truncate"><%= @result.description || "Shop" %></p>
        <p class="text-xs text-slate-400 mt-1">
          <%= @result.city %>, <%= @result.country %>
        </p>
      </div>
      <div class="text-xs text-slate-400">
        Shop
      </div>
    </.link>
    """
  end
end
