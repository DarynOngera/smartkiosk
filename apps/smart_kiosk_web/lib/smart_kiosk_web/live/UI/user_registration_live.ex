defmodule SmartKioskWeb.UserRegistrationLive do
  @moduledoc """
  Premium minimalist registration interface.
  """
  use SmartKioskWeb, :live_view

  alias SmartKioskCore.Accounts

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#0B0F1A] flex lg:h-screen lg:overflow-hidden">
      <%!-- Left Side: Marketing Content --%>
      <div class="hidden lg:flex lg:w-1/2 flex-col justify-center px-12 py-8 relative h-full overflow-hidden">
        <%!-- Background Ambient Glows --%>
        <div class="absolute top-0 left-0 w-[400px] h-[400px] bg-violet-500/15 rounded-full blur-[120px] pointer-events-none -translate-x-1/4 -translate-y-1/4">
        </div>
        <div class="absolute bottom-0 right-0 w-[300px] h-[300px] bg-indigo-500/10 rounded-full blur-[100px] pointer-events-none translate-x-1/4 translate-y-1/4">
        </div>

        <div class="relative z-10">
          <%!-- Logo --%>
          <div class="flex items-center gap-3 mb-6">
            <div class="w-10 h-10 bg-gradient-to-tr from-violet-500 to-indigo-400 rounded-xl flex items-center justify-center shadow-lg shadow-violet-500/20">
              <.icon name="hero-shopping-bag-solid" class="w-6 h-6 text-white" />
            </div>
            <span class="text-xl font-bold tracking-tight text-white">SmartKiosk</span>
          </div>

          <%!-- Hero Text --%>
          <h1 class="text-4xl font-bold text-white mb-3 leading-tight">
            Start selling online in minutes
          </h1>
          <p class="text-base text-slate-400 mb-6 leading-relaxed">
            Join thousands of businesses already using SmartKiosk to manage inventory, process payments, and grow their sales.
          </p>

          <%!-- Features --%>
          <div class="space-y-4">
            <div class="flex items-start gap-3">
              <div class="w-8 h-8 bg-violet-500/20 rounded-lg flex items-center justify-center flex-shrink-0">
                <.icon name="hero-bolt" class="w-4 h-4 text-violet-400" />
              </div>
              <div>
                <h3 class="text-white font-semibold mb-0.5 text-sm">Quick Setup</h3>
                <p class="text-slate-500 text-xs">
                  Get your shop up and running in less than 5 minutes
                </p>
              </div>
            </div>
            <div class="flex items-start gap-3">
              <div class="w-8 h-8 bg-violet-500/20 rounded-lg flex items-center justify-center flex-shrink-0">
                <.icon name="hero-device-phone-mobile" class="w-4 h-4 text-violet-400" />
              </div>
              <div>
                <h3 class="text-white font-semibold mb-0.5 text-sm">M-Pesa Integration</h3>
                <p class="text-slate-500 text-xs">
                  Accept payments seamlessly with Kenya's #1 mobile money
                </p>
              </div>
            </div>
            <div class="flex items-start gap-3">
              <div class="w-8 h-8 bg-violet-500/20 rounded-lg flex items-center justify-center flex-shrink-0">
                <.icon name="hero-chart-bar" class="w-4 h-4 text-violet-400" />
              </div>
              <div>
                <h3 class="text-white font-semibold mb-0.5 text-sm">Real-time Analytics</h3>
                <p class="text-slate-500 text-xs">
                  Track sales, inventory, and customer insights instantly
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>

      <%!-- Right Side: Registration Form --%>
      <div class="w-full lg:w-1/2 flex items-center justify-center px-6 py-6 relative">
        <%!-- Mobile Background Glows --%>
        <div class="lg:hidden absolute top-1/4 left-1/2 -translate-x-1/2 w-[400px] h-[400px] bg-violet-500/15 rounded-full blur-[120px] pointer-events-none">
        </div>

        <div class="w-full max-w-[420px] z-10">
          <%!-- Mobile Logo --%>
          <div class="lg:hidden flex flex-col items-center mb-6">
            <div class="w-10 h-10 bg-gradient-to-tr from-violet-500 to-indigo-400 rounded-xl mb-3 flex items-center justify-center shadow-lg shadow-violet-500/20">
              <.icon name="hero-shopping-bag-solid" class="w-6 h-6 text-white" />
            </div>
            <h1 class="text-white text-xl font-bold tracking-tight">Create your account</h1>
            <p class="text-slate-500 mt-1 text-xs">Start selling with SmartKiosk in minutes</p>
          </div>

          <%!-- Desktop Header --%>
          <div class="hidden lg:block mb-6">
            <h1 class="text-white text-2xl font-bold tracking-tight mb-1">Create your account</h1>
            <p class="text-slate-500 text-sm">Join thousands of businesses on SmartKiosk</p>
          </div>

          <%!-- Registration Type Toggle --%>
          <div class="flex items-center justify-center gap-1 p-1 bg-slate-800/50 border border-white/5 rounded-full mb-6">
            <button
              type="button"
              phx-click="select_type"
              phx-value-type="customer"
              class={[
                "flex items-center gap-2 px-4 py-2 rounded-full text-xs font-medium transition-all duration-300",
                @reg_type == "customer" && "bg-violet-500 text-white shadow-lg shadow-violet-500/25",
                @reg_type != "customer" && "text-slate-400 hover:text-white"
              ]}
            >
              <.icon name="hero-user" class="w-4 h-4" /> Customer
            </button>
            <button
              type="button"
              phx-click="select_type"
              phx-value-type="shop"
              class={[
                "flex items-center gap-2 px-4 py-2 rounded-full text-xs font-medium transition-all duration-300",
                @reg_type == "shop" && "bg-violet-500 text-white shadow-lg shadow-violet-500/25",
                @reg_type != "shop" && "text-slate-400 hover:text-white"
              ]}
            >
              <.icon name="hero-storefront" class="w-4 h-4" /> Shop Owner
            </button>
          </div>

          <%!-- The Registration Card --%>
          <div class="bg-white/5 backdrop-blur-xl border border-white/10 rounded-2xl p-6 shadow-2xl">
            <.form
              for={@form}
              id="registration_form"
              phx-submit="save"
              phx-change="validate"
              class="space-y-4"
            >
              <%!-- Full Name --%>
              <div class="space-y-2">
                <label class="text-[11px] uppercase tracking-[0.2em] text-slate-400 font-bold ml-1">
                  Full Name
                </label>
                <div class="relative group">
                  <div class="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none text-slate-500 group-focus-within:text-violet-400 transition-colors">
                    <.icon name="hero-user" class="w-5 h-5" />
                  </div>
                  <input
                    type="text"
                    id="full_name"
                    name={@form[:full_name].name}
                    value={@form[:full_name].value}
                    placeholder="John Doe"
                    required
                    class={[
                      "w-full bg-slate-900/50 border rounded-xl py-3 pl-12 pr-4 text-white placeholder:text-slate-600 focus:outline-none focus:ring-2 focus:ring-violet-500/50 transition-all text-sm",
                      @form[:full_name].errors != [] &&
                        "border-red-500/50 focus:border-red-500 focus:ring-red-500/30",
                      @form[:full_name].errors == [] && "border-white/5 focus:border-violet-500"
                    ]}
                  />
                </div>
              </div>

              <%!-- Email --%>
              <div class="space-y-2">
                <label class="text-[11px] uppercase tracking-[0.2em] text-slate-400 font-bold ml-1">
                  Email Address
                </label>
                <div class="relative group">
                  <div class="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none text-slate-500 group-focus-within:text-violet-400 transition-colors">
                    <.icon name="hero-envelope" class="w-5 h-5" />
                  </div>
                  <input
                    type="email"
                    id="email"
                    name={@form[:email].name}
                    value={@form[:email].value}
                    placeholder="name@company.com"
                    required
                    class={[
                      "w-full bg-slate-900/50 border rounded-xl py-3 pl-12 pr-4 text-white placeholder:text-slate-600 focus:outline-none focus:ring-2 focus:ring-violet-500/50 transition-all text-sm",
                      @form[:email].errors != [] &&
                        "border-red-500/50 focus:border-red-500 focus:ring-red-500/30",
                      @form[:email].errors == [] && "border-white/5 focus:border-violet-500"
                    ]}
                  />
                </div>
              </div>

              <%!-- Phone --%>
              <div class="space-y-2">
                <label class="text-[11px] uppercase tracking-[0.2em] text-slate-400 font-bold ml-1">
                  Phone Number
                </label>
                <div class="relative group">
                  <div class="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none text-slate-500 group-focus-within:text-violet-400 transition-colors">
                    <.icon name="hero-phone" class="w-5 h-5" />
                  </div>
                  <input
                    type="tel"
                    id="phone"
                    name={@form[:phone].name}
                    value={@form[:phone].value}
                    placeholder="+254 712 345 678"
                    required
                    class={[
                      "w-full bg-slate-900/50 border rounded-xl py-3 pl-12 pr-4 text-white placeholder:text-slate-600 focus:outline-none focus:ring-2 focus:ring-violet-500/50 transition-all text-sm",
                      @form[:phone].errors != [] &&
                        "border-red-500/50 focus:border-red-500 focus:ring-red-500/30",
                      @form[:phone].errors == [] && "border-white/5 focus:border-violet-500"
                    ]}
                  />
                </div>
              </div>

              <%= if @reg_type == "shop" do %>
                <%!-- Shop Details --%>
                <div class="grid grid-cols-2 gap-4 animate-fade-in">
                  <div class="space-y-2">
                    <label class="text-[11px] uppercase tracking-[0.2em] text-slate-400 font-bold ml-1">
                      City
                    </label>
                    <input
                      type="text"
                      name="registration[city]"
                      value={@form[:city].value}
                      placeholder="Nairobi"
                      class="w-full bg-slate-900/50 border border-white/5 rounded-xl py-3 px-4 text-white placeholder:text-slate-600 focus:outline-none focus:ring-2 focus:ring-violet-500/50 transition-all text-sm"
                    />
                  </div>
                  <div class="space-y-2">
                    <label class="text-[11px] uppercase tracking-[0.2em] text-slate-400 font-bold ml-1">
                      Address
                    </label>
                    <input
                      type="text"
                      name="registration[address]"
                      value={@form[:address].value}
                      placeholder="Tom Mboya St"
                      class="w-full bg-slate-900/50 border border-white/10 rounded-xl py-3 px-4 text-white placeholder:text-slate-600 focus:outline-none focus:ring-2 focus:ring-violet-500/50 transition-all text-sm"
                    />
                  </div>
                </div>

                <div class="space-y-2 animate-fade-in">
                  <label class="text-[11px] uppercase tracking-[0.2em] text-slate-400 font-bold ml-1">
                    Shop Category
                  </label>
                  <select
                    name="registration[shop_category]"
                    class="w-full bg-slate-900/50 border border-white/5 rounded-xl py-3 px-4 text-white focus:ring-2 focus:ring-violet-500/50 transition-all text-sm"
                  >
                    <%= for {cat, label} <- @category_options do %>
                      <option
                        value={cat}
                        selected={@form[:shop_category].value == cat}
                        class="bg-slate-900"
                      >
                        <%= label %>
                      </option>
                    <% end %>
                  </select>
                </div>
              <% end %>

              <%!-- Password --%>
              <div class="space-y-2">
                <label class="text-[11px] uppercase tracking-[0.2em] text-slate-400 font-bold ml-1">
                  Password
                </label>
                <div class="relative group">
                  <div class="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none text-slate-500 group-focus-within:text-violet-400 transition-colors">
                    <.icon name="hero-lock-closed" class="w-5 h-5" />
                  </div>
                  <input
                    type="password"
                    name="registration[password]"
                    value={@form[:password].value}
                    required
                    minlength="12"
                    class="w-full bg-slate-900/50 border border-white/5 rounded-xl py-3 pl-12 pr-4 text-white placeholder:text-slate-600 focus:outline-none focus:ring-2 focus:ring-violet-500/50 transition-all text-sm"
                  />
                </div>
              </div>

              <button
                type="submit"
                phx-disable-with="Creating account..."
                class="w-full bg-violet-500 hover:bg-violet-400 text-white font-bold py-3 rounded-xl shadow-lg shadow-violet-500/20 transition-all active:scale-[0.98] text-sm"
              >
                <%= if @reg_type == "shop" do %>
                  Open my shop
                <% else %>
                  Create account
                <% end %>
              </button>
            </.form>
          </div>

          <%!-- Footer --%>
          <p class="text-center mt-6 text-slate-500 text-sm">
            Already have an account?
            <a
              href={~p"/login"}
              class="text-white font-semibold hover:text-violet-400 transition-colors"
            >
              Sign in
            </a>
          </p>
        </div>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_registration(%{})

    category_options =
      SmartKioskCore.Schemas.Shop.category_labels()
      |> Enum.map(fn {k, v} -> {to_string(k), v} end)

    plan_options = ["kiosk", "duka", "biashara", "enterprise"]

    {:ok,
     socket
     |> assign(:form, to_form(changeset, as: :registration))
     |> assign(:category_options, category_options)
     |> assign(:plan_options, plan_options)
     |> assign(:reg_type, "shop")
     |> assign(:page_title, "Create Account · SmartKiosk")}
  end

  def handle_event("validate", _params, socket) do
    # Simplification for now
    {:noreply, socket}
  end

  def handle_event("save", params, socket) do
    registration_params = normalize_registration_params(params)
    user_attrs = Map.take(registration_params, ["full_name", "email", "password", "phone"])

    if socket.assigns.reg_type == "shop" do
      shop_attrs = %{
        "name" => registration_params["full_name"] <> "'s Shop",
        "phone" => registration_params["phone"],
        "category" => registration_params["shop_category"],
        "address" => registration_params["address"] || "Nairobi",
        "city" => registration_params["city"] || "Nairobi",
        "country" => "KE",
        "plan" => "kiosk"
      }

      case Accounts.register_shop_owner(shop_attrs, user_attrs) do
        {:ok, _shop, _user} ->
          {:noreply, put_flash(socket, :info, "Shop created!") |> redirect(to: ~p"/login")}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Registration failed.")}
      end
    else
      case Accounts.register_user(user_attrs) do
        {:ok, _user} ->
          {:noreply, put_flash(socket, :info, "Account created!") |> redirect(to: ~p"/login")}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Registration failed.")}
      end
    end
  end

  def handle_event("select_type", %{"type" => type}, socket) do
    {:noreply, assign(socket, :reg_type, type)}
  end

  defp normalize_registration_params(params) do
    params["registration"] || %{}
  end
end
