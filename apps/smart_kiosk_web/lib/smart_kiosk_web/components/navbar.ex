defmodule SmartKioskWeb.Navbar do
  @moduledoc """
  Navigation bar component with logo, cart, and user avatar.
  """
  use SmartKioskWeb, :html

  @doc """
  Renders the navigation bar.

  ## Attributes

  * `current_user` - The currently logged-in user (optional)
  * `user_shop` - The user's shop if they are an owner/manager (optional)
  * `cart_count` - Number of items in cart (default: 0)
  """
  attr :current_user, :map, default: nil
  attr :user_shop, :any, default: nil
  attr :cart_count, :integer, default: 0

  def navbar(assigns) do
    ~H"""
    <nav class="sticky top-0 z-50 bg-[#0B0F1A]/80 backdrop-blur-xl border-b border-white/5">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex items-center justify-between h-16">
          <%!-- Logo --%>
          <div class="flex items-center gap-3">
            <div class="w-9 h-9 bg-gradient-to-tr from-violet-500 to-indigo-400 rounded-lg flex items-center justify-center shadow-lg shadow-violet-500/20">
              <.icon name="hero-shopping-bag-solid" class="w-5 h-5 text-white" />
            </div>
            <span class="text-xl font-bold tracking-tight">SmartKiosk</span>
          </div>

          <%!-- Right Side Actions --%>
          <div class="flex items-center gap-4">
            <%!-- Theme Toggle --%>
            <button
              type="button"
              id="theme-toggle"
              phx-hook="ThemeToggle"
              class="p-2 rounded-xl hover:bg-white/5 transition-colors group"
              aria-label="Toggle theme"
            >
              <.icon
                name="hero-sun"
                class="w-6 h-6 text-slate-400 group-hover:text-white transition-colors sun-icon hidden"
              />
              <.icon
                name="hero-moon"
                class="w-6 h-6 text-slate-400 group-hover:text-white transition-colors moon-icon"
              />
            </button>

            <%!-- Cart Icon --%>
            <.link
              navigate="/cart"
              class="relative p-2 rounded-xl hover:bg-white/5 transition-colors group"
            >
              <.icon
                name="hero-shopping-cart"
                class="w-6 h-6 text-slate-400 group-hover:text-white transition-colors"
              />
              <%= if @cart_count > 0 do %>
                <span class="absolute -top-1 -right-1 w-5 h-5 bg-violet-500 rounded-full text-xs font-bold flex items-center justify-center">
                  <%= @cart_count %>
                </span>
              <% end %>
            </.link>

            <%!-- User Avatar / Profile Link --%>
            <%= if @current_user do %>
              <.user_avatar current_user={@current_user} user_shop={@user_shop} />
            <% else %>
              <.guest_actions />
            <% end %>
          </div>
        </div>
      </div>
    </nav>
    """
  end

  @doc """
  Renders the user avatar with fallback to shop logo or initials.
  """
  attr :current_user, :map, required: true
  attr :user_shop, :map, default: nil

  def user_avatar(assigns) do
    ~H"""
    <div class="flex items-center gap-2">
      <.link
        navigate="/dashboard"
        class="flex items-center gap-3 p-2 pr-4 rounded-xl hover:bg-white/5 transition-colors cursor-pointer group"
      >
        <%= cond do %>
          <% @current_user.avatar_url && @current_user.avatar_url != "" -> %>
            <img
              src={@current_user.avatar_url}
              alt="Avatar"
              class="w-9 h-9 rounded-full object-cover border border-violet-500/30"
            />
          <% @user_shop && @user_shop.logo_url && @user_shop.logo_url != "" -> %>
            <img
              src={@user_shop.logo_url}
              alt="Shop Logo"
              class="w-9 h-9 rounded-full object-cover border border-violet-500/30"
            />
          <% true -> %>
            <div class="w-9 h-9 bg-gradient-to-br from-violet-500/30 to-indigo-500/30 rounded-full flex items-center justify-center border border-violet-500/30">
              <span class="text-sm font-semibold text-violet-300">
                <%= get_initials(@current_user.full_name || @current_user.email) %>
              </span>
            </div>
        <% end %>
      </.link>

      <div class="w-px h-4 bg-white/10 mx-1"></div>

      <.link
        href={~p"/logout"}
        method="delete"
        class="p-2 text-slate-400 hover:text-red-400 transition-colors"
        title="Sign out"
      >
        <.icon name="hero-arrow-right-on-rectangle" class="w-5 h-5" />
      </.link>
    </div>
    """
  end

  @doc """
  Renders guest action buttons (Sign in / Get Started).
  """
  def guest_actions(assigns) do
    ~H"""
    <div class="flex items-center gap-2">
      <a
        href={~p"/login"}
        class="px-4 py-2 text-sm font-medium text-slate-300 hover:text-white transition-colors"
      >
        Sign in
      </a>
      <a
        href={~p"/register"}
        class="px-4 py-2 bg-violet-500 hover:bg-violet-400 text-white text-sm font-medium rounded-lg transition-colors"
      >
        Get Started
      </a>
    </div>
    """
  end

  defp get_initials(nil), do: "?"

  defp get_initials(name) do
    name
    |> String.split(" ")
    |> Enum.take(2)
    |> Enum.map(&String.first/1)
    |> Enum.join("")
    |> String.upcase()
  end
end
