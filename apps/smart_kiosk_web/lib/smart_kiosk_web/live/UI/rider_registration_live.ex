defmodule SmartKioskWeb.RiderRegistrationLive do
  use SmartKioskWeb, :live_view

  alias SmartKioskCore.JobPosts
  alias SmartKioskCore.Shops
  alias SmartKioskCore.Schemas.User

  @impl true
  def mount(%{"slug" => slug} = params, _session, socket) do
    case Shops.get_shop_by_slug(slug) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Shop not found")
         |> push_navigate(to: ~p"/")}

      shop ->
        job_post = load_job_post(shop, params["job_id"])
        changeset = User.registration_changeset(%User{}, %{})
        requires_license = requires_driving_license?(job_post)

        {:ok,
         socket
         |> assign(page_title: "Join #{shop.name} as a Rider")
         |> assign(shop: shop)
         |> assign(job_post: job_post)
         |> assign(requires_license: requires_license)
         |> assign_form(changeset)
         |> maybe_allow_upload(:license, requires_license)
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
    job_post = socket.assigns[:job_post]
    requires_license = socket.assigns[:requires_license]
    user_params = Map.put_new(user_params, "password", generated_password())

    id_urls = consume_rider_uploads(socket, :national_id)
    license_urls = if requires_license, do: consume_rider_uploads(socket, :license), else: []

    case {requires_license, license_urls, id_urls} do
      {true, [license_url], [id_url]} ->
        rider_attrs = %{
          license_url: license_url,
          national_id_url: id_url,
          job_post_id: job_post && job_post.id,
          verification_status: :pending
        }

        case Shops.register_rider(shop, user_params, rider_attrs) do
          {:ok, _user, _rider} ->
            {:noreply,
             socket
             |> put_flash(
               :info,
               success_message(shop, job_post)
             )
             |> push_navigate(to: thanks_path(shop, job_post))}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, handle_application_changeset_error(socket, changeset)}

          {:error, reason} when is_binary(reason) ->
            {:noreply, put_flash(socket, :error, reason)}
        end

      {false, _, [id_url]} ->
        rider_attrs = %{
          national_id_url: id_url,
          job_post_id: job_post && job_post.id,
          verification_status: :pending
        }

        case Shops.register_rider(shop, user_params, rider_attrs) do
          {:ok, _user, _rider} ->
            {:noreply,
             socket
             |> put_flash(:info, success_message(shop, job_post))
             |> push_navigate(to: thanks_path(shop, job_post))}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, handle_application_changeset_error(socket, changeset)}

          {:error, reason} when is_binary(reason) ->
            {:noreply, put_flash(socket, :error, reason)}
        end

      _ when requires_license ->
        {:noreply,
         put_flash(socket, :error, "Please upload your National ID and Driving License (PDF)")}

      _ ->
        {:noreply, put_flash(socket, :error, "Please upload your National ID (PDF)")}
    end
  end

  defp consume_rider_uploads(socket, name) do
    consume_uploaded_entries(socket, name, fn %{path: path}, _entry ->
      dest =
        Path.join([
          :code.priv_dir(:smart_kiosk_web),
          "static",
          "uploads",
          "riders",
          Path.basename(path) <> ".pdf"
        ])

      File.mkdir_p!(Path.dirname(dest))
      File.cp!(path, dest)
      {:ok, "/uploads/riders/" <> Path.basename(dest)}
    end)
  end

  defp assign_form(socket, changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp handle_application_changeset_error(socket, changeset) do
    socket
    |> assign_form(Map.put(changeset, :action, :insert))
    |> put_flash(:error, application_error_message(changeset))
  end

  defp application_error_message(%Ecto.Changeset{} = changeset) do
    case Keyword.get(changeset.errors, :base) do
      {message, _opts} -> message
      nil -> "Could not submit application. Check the highlighted fields."
    end
  end

  defp maybe_allow_upload(socket, _name, false), do: socket

  defp maybe_allow_upload(socket, name, true),
    do: allow_upload(socket, name, accept: ~w(.pdf), max_entries: 1)

  defp load_job_post(_shop, nil), do: nil

  defp load_job_post(shop, job_post_id) do
    case JobPosts.get_job_post!(job_post_id) do
      %{} = job_post when job_post.shop_id == shop.id -> job_post
      _ -> nil
    end
  rescue
    _ -> nil
  end

  defp success_message(shop, nil) do
    "Registration successful! #{shop.name} will verify your documents."
  end

  defp success_message(shop, job_post) do
    "Your application for #{job_post.title} at #{shop.name} was received. They will review it and get back to you soon."
  end

  defp requires_driving_license?(nil), do: false

  defp requires_driving_license?(job_post) do
    title = String.downcase(job_post.title || "")
    String.contains?(title, ["rider", "delivery", "driver", "courier"])
  end

  defp thanks_path(shop, nil), do: ~p"/shop/#{shop.slug}/rider/thanks"
  defp thanks_path(shop, job_post), do: ~p"/shop/#{shop.slug}/rider/thanks?job_id=#{job_post.id}"

  defp generated_password do
    :crypto.strong_rand_bytes(24) |> Base.url_encode64(padding: false)
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
            <h1 class="text-3xl font-bold text-white">
              <%= if @job_post do %>
                Apply for <%= @job_post.title %>
              <% else %>
                Join <%= @shop.name %>
              <% end %>
            </h1>
            <p class="text-slate-400 mt-2 text-sm">
              <%= if @job_post do %>
                Submit your application for this role. We only require your national ID.
              <% else %>
                Become a delivery partner for our shop.
              <% end %>
            </p>
          </div>

          <div class="bg-white/5 border border-white/10 rounded-3xl p-8 backdrop-blur-xl shadow-2xl">
            <.form
              for={@form}
              id="rider-registration-form"
              phx-submit="save"
              phx-change="validate"
              class="space-y-6"
            >
              <%= if @form.errors != [] do %>
                <div
                  id="rider-application-errors"
                  class="rounded-2xl border border-rose-500/30 bg-rose-500/10 p-4 text-sm text-rose-100"
                >
                  <p class="font-semibold text-rose-50">Application could not be submitted</p>
                  <ul class="mt-2 list-disc space-y-1 pl-5">
                    <%= for {field, errors} <- @form.errors do %>
                      <%= for error <- List.wrap(errors) do %>
                        <li>
                          <%= if field == :base do %>
                            <%= translate_error(error) %>
                          <% else %>
                            <span class="capitalize">
                              <%= field |> to_string() |> String.replace("_", " ") %>
                            </span>
                            <%= translate_error(error) %>
                          <% end %>
                        </li>
                      <% end %>
                    <% end %>
                  </ul>
                </div>
              <% end %>

              <div class="space-y-4">
                <h3 class="text-sm font-semibold text-slate-500 uppercase tracking-wider">
                  Personal Information
                </h3>
                <.input
                  field={@form[:full_name]}
                  type="text"
                  label="Full Name"
                  placeholder="John Doe"
                  required
                />
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <.input
                    field={@form[:email]}
                    type="email"
                    label="Email Address"
                    placeholder="john@example.com"
                    required
                  />
                  <.input
                    field={@form[:phone]}
                    type="tel"
                    label="Phone Number"
                    placeholder="+254 7XX XXX XXX"
                    required
                  />
                </div>
              </div>

              <div class="space-y-4 pt-6 border-t border-white/5">
                <h3 class="text-sm font-semibold text-slate-500 uppercase tracking-wider">
                  Documents
                </h3>

                <div>
                  <label class="block text-sm font-medium text-slate-300 mb-2">National ID</label>
                  <div class="relative border-2 border-dashed border-white/10 rounded-xl p-4 text-center hover:border-violet-500/50 transition-all">
                    <.live_file_input
                      upload={@uploads.national_id}
                      class="absolute inset-0 w-full h-full opacity-0 cursor-pointer"
                    />
                    <div class="space-y-1">
                      <.icon name="hero-identification" class="w-6 h-6 text-slate-500 mx-auto" />
                      <p class="text-[10px] text-slate-400">Click to upload your National ID</p>
                    </div>
                  </div>
                  <%= for entry <- @uploads.national_id.entries do %>
                    <div class="mt-2 text-[10px] text-violet-400 font-medium">
                      Selected: <%= entry.client_name %>
                    </div>
                  <% end %>
                </div>

                <%= if @requires_license do %>
                  <div class="pt-4">
                    <label class="block text-sm font-medium text-slate-300 mb-2">
                      Driving License
                    </label>
                    <div class="relative border-2 border-dashed border-white/10 rounded-xl p-4 text-center hover:border-violet-500/50 transition-all">
                      <.live_file_input
                        upload={@uploads.license}
                        class="absolute inset-0 w-full h-full opacity-0 cursor-pointer"
                      />
                      <div class="space-y-1">
                        <.icon name="hero-document-text" class="w-6 h-6 text-slate-500 mx-auto" />
                        <p class="text-[10px] text-slate-400">Click to upload your Driving License</p>
                      </div>
                    </div>
                    <%= for entry <- @uploads.license.entries do %>
                      <div class="mt-2 text-[10px] text-violet-400 font-medium">
                        Selected: <%= entry.client_name %>
                      </div>
                    <% end %>
                  </div>
                <% end %>
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
              Already have an account?
              <.link navigate={~p"/login"} class="text-violet-400 font-semibold hover:text-violet-300">
                Sign in
              </.link>
            </p>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
