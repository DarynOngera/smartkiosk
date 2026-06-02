defmodule SmartKioskWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use SmartKioskWeb, :html
  import SmartKioskWeb.Navbar

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :current_path, :string,
    default: nil,
    doc: "the current request path for LiveView-safe conditional layout logic"

  attr :current_user, :any, default: nil, doc: "the currently signed-in user"
  attr :current_shop, :any, default: nil, doc: "the current shop in scope"
  attr :cart_count, :integer, default: 0, doc: "cart item count"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <% current_path =
      @current_path || (assigns[:conn] && Phoenix.Controller.current_path(assigns.conn)) %>

    <%= if current_path not in ["/login", "/register", "/reset-password"] and
            not String.starts_with?(current_path || "", "/reset-password/") do %>
      <.navbar current_user={@current_user} user_shop={@current_shop} cart_count={@cart_count} />
    <% end %>

    <main class="pb-12">
      <.flash_group flash={@flash} />
      <%= render_slot(@inner_block) %>
    </main>

    <.footer current_user={@current_user} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        <%= gettext("Attempting to reconnect") %>
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        <%= gettext("Attempting to reconnect") %>
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end

  @doc """
  SmartKiosk public footer.
  """
  attr :current_user, :any, default: nil, doc: "the currently signed-in user"

  def footer(assigns) do
    ~H"""
    <footer class="border-t border-slate-200 bg-slate-950 text-slate-300">
      <div class="mx-auto max-w-7xl px-4 py-12 sm:px-6 lg:px-8">
        <div class="grid gap-10 md:grid-cols-2 lg:grid-cols-4">
          <div class="space-y-4">
            <div class="flex items-center gap-3">
              <div class="flex h-10 w-10 items-center justify-center rounded-2xl bg-violet-600/15 text-violet-400">
                <.icon name="hero-shopping-bag" class="h-5 w-5" />
              </div>
              <div>
                <p class="text-lg font-semibold text-white">SmartKiosk</p>
                <p class="text-xs uppercase tracking-[0.25em] text-slate-500">Local commerce platform</p>
              </div>
            </div>
            <p class="max-w-sm text-sm leading-6 text-slate-400">
              SmartKiosk helps shops manage orders, staff, deliveries, careers, and payments from one place.
            </p>
            <div class="space-y-2 text-sm">
              <p class="text-slate-500">Email</p>
              <.link
                href="mailto:hello@smartkiosk.co.ke"
                class="text-slate-300 transition-colors hover:text-violet-300"
              >
                hello@smartkiosk.co.ke
              </.link>
            </div>
          </div>

          <div>
            <h3 class="text-sm font-semibold uppercase tracking-[0.2em] text-white">Valuable Links</h3>
            <ul class="mt-4 space-y-3 text-sm">
              <li>
                <.link navigate={~p"/"} class="transition-colors hover:text-violet-300">
                  Home
                </.link>
              </li>
              <li>
                <.link navigate={~p"/dashboard"} class="transition-colors hover:text-violet-300">
                  Dashboard
                </.link>
              </li>
              <li>
                <.link navigate={~p"/cart"} class="transition-colors hover:text-violet-300">
                  Cart
                </.link>
              </li>
              <li>
                <.link navigate={~p"/jobs"} class="transition-colors hover:text-violet-300">
                  Job Board
                </.link>
              </li>
            </ul>
          </div>

          <div>
            <h3 class="text-sm font-semibold uppercase tracking-[0.2em] text-white">Job Links</h3>
            <ul class="mt-4 space-y-3 text-sm">
              <li>
                <.link navigate={~p"/jobs"} class="transition-colors hover:text-violet-300">
                  Browse Jobs
                </.link>
              </li>
              <li>
                <.link navigate={~p"/careers"} class="transition-colors hover:text-violet-300">
                  Manage Job Posts
                </.link>
              </li>
              <li>
                <.link navigate={~p"/"} class="transition-colors hover:text-violet-300">
                  Shop Directory
                </.link>
              </li>
            </ul>
          </div>

          <div>
            <h3 class="text-sm font-semibold uppercase tracking-[0.2em] text-white">For Partners</h3>
            <ul class="mt-4 space-y-3 text-sm">
              <li>
                <.link href="mailto:suppliers@smartkiosk.co.ke" class="transition-colors hover:text-violet-300">
                  Supplier Link
                </.link>
              </li>
              <li>
                <.link navigate={~p"/pos"} class="transition-colors hover:text-violet-300">
                  POS
                </.link>
              </li>
              <li>
                <.link navigate={~p"/create-shop"} class="transition-colors hover:text-violet-300">
                  Open a Shop
                </.link>
              </li>
            </ul>
          </div>
        </div>

        <div class="mt-10 border-t border-white/10 pt-6 text-sm text-slate-500">
          <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
            <p>© <%= Date.utc_today().year %> SmartKiosk. All rights reserved.</p>
            <p>
              <%= if @current_user do %>
                Signed in as <span class="text-slate-300"><%= @current_user.full_name || @current_user.email %></span>
              <% else %>
                Built for shops, riders, suppliers, and customers.
              <% end %>
            </p>
          </div>
        </div>
      </div>
    </footer>
    """
  end
end
