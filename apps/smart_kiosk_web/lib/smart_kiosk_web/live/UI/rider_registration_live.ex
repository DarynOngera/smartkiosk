defmodule SmartKioskWeb.RiderRegistrationLive do
  use SmartKioskWeb, :live_view

  alias SmartKioskCore.Shops
  alias SmartKioskCore.Schemas.User

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    case Shops.get_shop_by_slug(slug) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Shop not found")
         |> push_navigate(to: ~p"/")}

      shop ->
        changeset = User.registration_changeset(%User{}, %{})

        {:ok,
         socket
         |> assign(page_title: "Join #{shop.name} as a Rider")
         |> assign(shop: shop)
         |> assign_form(changeset)
         |> allow_upload(:license, accept: ~w(.pdf), max_entries: 1)
         |> allow_upload(:national_id, accept: ~w(.pdf), max_entries: 1)}
    end
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      %User{}
      |> User.registration_changeset(user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    shop = socket.assigns.shop

    # 1. Consume uploads
    license_urls = consume_rider_uploads(socket, :license)
    id_urls = consume_rider_uploads(socket, :national_id)

    case {license_urls, id_urls} do
      {[license_url], [id_url]} ->
        rider_attrs = %{
          license_url: license_url,
          national_id_url: id_url,
          verification_status: :pending
        }

        # 2. Register User + Rider under the specific shop
        case Shops.register_rider(shop, user_params, rider_attrs) do
          {:ok, _user, _rider} ->
            {:noreply,
             socket
             |> put_flash(:info, "Registration successful! #{shop.name} will verify your documents.")
             |> push_navigate(to: ~p"/login")}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign_form(socket, changeset)}

          {:error, reason} when is_binary(reason) ->
            {:noreply, put_flash(socket, :error, reason)}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Please upload both your License and National ID (PDF)")}
    end
  end

  defp consume_rider_uploads(socket, name) do
    consume_uploaded_entries(socket, name, fn %{path: path}, _entry ->
      dest = Path.join([:code.priv_dir(:smart_kiosk_web), "static", "uploads", "riders", Path.basename(path) <> ".pdf"])
      File.mkdir_p!(Path.dirname(dest))
      File.cp!(path, dest)
      {:ok, "/uploads/riders/" <> Path.basename(dest)}
    end)
  end

  defp assign_form(socket, changeset) do
    assign(socket, :form, to_form(changeset))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_path={~p"/shop/#{@shop.slug}/rider/register"}>
      <div class="min-h-screen bg-[#0B0F1A] text-white py-12 px-4 sm:px-6 lg:px-8">
        <div class="max-w-xl mx-auto">
          <div class="text-center mb-10">
            <div class="w-16 h-16 bg-violet-600 rounded-2xl flex items-center justify-center mx-auto mb-4 shadow-lg shadow-violet-500/20">
              <.icon name="hero-truck" class="w-10 h-10 text-white" />
            </div>
            <h1 class="text-3xl font-bold text-white">Join <%= @shop.name %></h1>
            <p class="text-slate-400 mt-2 text-sm">Become a delivery partner for our shop.</p>
          </div>

          <div class="bg-white/5 border border-white/10 rounded-3xl p-8 backdrop-blur-xl shadow-2xl">
            <.form for={@form} id="rider-registration-form" phx-submit="save" phx-change="validate" class="space-y-6">
              <div class="space-y-4">
                <h3 class="text-sm font-semibold text-slate-500 uppercase tracking-wider">Personal Information</h3>
                <.input field={@form[:full_name]} type="text" label="Full Name" placeholder="John Doe" required />
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <.input field={@form[:email]} type="email" label="Email Address" placeholder="john@example.com" required />
                  <.input field={@form[:phone]} type="tel" label="Phone Number" placeholder="+254 7XX XXX XXX" required />
                </div>
                <.input field={@form[:password]} type="password" label="Create Password" required />
              </div>

              <div class="space-y-4 pt-6 border-t border-white/5">
                <h3 class="text-sm font-semibold text-slate-500 uppercase tracking-wider">Document Upload (PDF only)</h3>

                <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                  <div>
                    <label class="block text-sm font-medium text-slate-300 mb-2">Driving License</label>
                    <div class="relative border-2 border-dashed border-white/10 rounded-xl p-4 text-center hover:border-violet-500/50 transition-all">
                      <.live_file_input upload={@uploads.license} class="absolute inset-0 w-full h-full opacity-0 cursor-pointer" />
                      <div class="space-y-1">
                        <.icon name="hero-document-text" class="w-6 h-6 text-slate-500 mx-auto" />
                        <p class="text-[10px] text-slate-400">Click to upload License</p>
                      </div>
                    </div>
                    <%= for entry <- @uploads.license.entries do %>
                      <div class="mt-2 text-[10px] text-violet-400 font-medium">Selected: <%= entry.client_name %></div>
                    <% end %>
                  </div>

                  <div>
                    <label class="block text-sm font-medium text-slate-300 mb-2">National ID</label>
                    <div class="relative border-2 border-dashed border-white/10 rounded-xl p-4 text-center hover:border-violet-500/50 transition-all">
                      <.live_file_input upload={@uploads.national_id} class="absolute inset-0 w-full h-full opacity-0 cursor-pointer" />
                      <div class="space-y-1">
                        <.icon name="hero-identification" class="w-6 h-6 text-slate-500 mx-auto" />
                        <p class="text-[10px] text-slate-400">Click to upload ID</p>
                      </div>
                    </div>
                    <%= for entry <- @uploads.national_id.entries do %>
                      <div class="mt-2 text-[10px] text-violet-400 font-medium">Selected: <%= entry.client_name %></div>
                    <% end %>
                  </div>
                </div>
              </div>

              <div class="pt-6">
                <button
                  type="submit"
                  phx-disable-with="Submitting..."
                  class="w-full py-4 bg-violet-600 hover:bg-violet-500 text-white rounded-xl font-bold text-lg transition-all shadow-lg shadow-violet-500/20"
                >
                  Submit Application
                </button>
              </div>
            </.form>
          </div>

          <div class="text-center mt-8">
            <p class="text-slate-500 text-sm">
              Already have an account? <.link navigate={~p"/login"} class="text-violet-400 font-semibold hover:text-violet-300">Sign in</.link>
            </p>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
