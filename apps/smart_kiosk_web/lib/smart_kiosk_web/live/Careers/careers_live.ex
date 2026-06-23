defmodule SmartKioskWeb.Careers.CareersLive do
  use SmartKioskWeb, :live_view

  alias SmartKioskCore.JobPosts
  alias SmartKioskCore.Schemas.JobPost
  alias SmartKioskCore.Shops

  @impl true
  def mount(_params, _session, socket) do
    shop = current_shop(socket)

    if shop do
      job_posts = JobPosts.list_job_posts_for_shop(shop)

      {:ok,
       socket
       |> assign(:current_shop, shop)
       |> assign(:job_post, nil)
       |> assign(:form, nil)
       |> assign(:job_posts, job_posts)
       |> assign(:page_title, "Manage Job Posts")}
    else
      {:ok,
       socket
       |> assign(:current_shop, nil)
       |> assign(:job_post, nil)
       |> assign(:form, nil)
       |> assign(:job_posts, [])
       |> assign(:page_title, "Careers")}
    end
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    shop = socket.assigns[:current_shop]

    if shop do
      job_post = JobPosts.get_job_post!(id)

      if job_post.shop_id == shop.id do
        {:ok, _} = JobPosts.delete_job_post(job_post)

        {:noreply, refresh_job_posts(socket)}
      else
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_status", %{"id" => id}, socket) do
    shop = socket.assigns[:current_shop]

    if shop do
      job_post = JobPosts.get_job_post!(id)

      if job_post.shop_id == shop.id do
        {:ok, _} = JobPosts.toggle_job_post_status(job_post)
        {:noreply, refresh_job_posts(socket)}
      else
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("validate", %{"job_post" => job_post_params}, socket) do
    job_post =
      socket.assigns.job_post ||
        %JobPost{shop_id: socket.assigns.current_shop.id, status: "active"}

    changeset =
      JobPosts.change_job_post(job_post, job_post_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"job_post" => job_post_params}, socket) do
    shop = socket.assigns[:current_shop]

    if shop do
      job_post_params = Map.put(job_post_params, "shop_id", shop.id)

      case socket.assigns.job_post do
        nil ->
          case JobPosts.create_job_post(job_post_params) do
            {:ok, _job_post} ->
              {:noreply,
               socket
               |> refresh_job_posts()
               |> put_flash(:info, "Job post created successfully")
               |> push_patch(to: ~p"/careers")}

            {:error, changeset} ->
              {:noreply, assign(socket, :form, to_form(changeset))}
          end

        job_post ->
          case JobPosts.update_job_post(job_post, job_post_params) do
            {:ok, _job_post} ->
              {:noreply,
               socket
               |> refresh_job_posts()
               |> put_flash(:info, "Job post updated successfully")
               |> push_patch(to: ~p"/careers")}

            {:error, changeset} ->
              {:noreply, assign(socket, :form, to_form(changeset))}
          end
      end
    else
      {:noreply, socket}
    end
  end

  defp refresh_job_posts(socket) do
    assign(socket, :job_posts, JobPosts.list_job_posts_for_shop(socket.assigns.current_shop))
  end

  defp apply_action(socket, :new, _params) do
    shop = socket.assigns[:current_shop]

    if shop do
      changeset =
        JobPosts.change_job_post(%JobPost{}, %{
          shop_id: shop.id,
          status: "active"
        })

      socket
      |> assign(:page_title, "Add Job Post")
      |> assign(:job_post, nil)
      |> assign(:form, to_form(changeset))
    else
      socket
      |> assign(:page_title, "Careers")
      |> assign(:job_post, nil)
      |> assign(:form, nil)
    end
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Manage Job Posts")
    |> assign(:job_post, nil)
    |> assign(:form, nil)
  end

  defp apply_action(socket, _action, _params) do
    apply_action(socket, :index, %{})
  end

  defp current_shop(socket) do
    socket.assigns[:current_shop] ||
      case socket.assigns[:current_user] do
        nil -> nil
        user -> Shops.get_shop_for_user(user)
      end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_path="/careers"
      current_user={@current_user}
      current_shop={@current_shop}
    >
      <div class="min-h-screen bg-slate-50">
        <div class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8 lg:py-10">
          <div class="mb-8">
            <.header>
              Manage Job Posts
              <:subtitle>Create, publish, and retire shop roles from one place.</:subtitle>
              <:actions>
                <%= if @current_shop do %>
                  <.link
                    patch={~p"/careers/new"}
                    class="inline-flex items-center gap-2 rounded-xl border border-transparent bg-violet-600 px-4 py-2 text-sm font-medium text-white shadow-sm shadow-violet-600/20 transition-all hover:bg-violet-700"
                  >
                    <.icon name="hero-plus" class="h-4 w-4" /> Add Job Post
                  </.link>
                <% end %>
              </:actions>
            </.header>
          </div>

          <div class="rounded-3xl bg-white px-5 py-6 shadow-sm ring-1 ring-slate-200 sm:px-6 lg:px-8">
            <%= if @current_shop do %>
              <%= if @job_posts == [] do %>
                <div class="rounded-3xl border border-dashed border-slate-200 bg-slate-50 p-12 text-center">
                  <div class="mx-auto mb-4 flex h-14 w-14 items-center justify-center rounded-2xl bg-violet-50">
                    <.icon name="hero-briefcase" class="h-7 w-7 text-violet-600" />
                  </div>
                  <div class="text-xl font-semibold text-slate-900">No job postings yet</div>
                  <p class="mx-auto mb-6 mt-2 max-w-md text-slate-500">
                    Create a post for your shop and it will appear here immediately after you submit it.
                  </p>
                  <.link
                    patch={~p"/careers/new"}
                    class="inline-flex items-center gap-2 rounded-xl bg-violet-600 px-4 py-2 text-sm font-medium text-white shadow-sm shadow-violet-600/20 transition-all hover:bg-violet-700"
                  >
                    <.icon name="hero-plus" class="h-4 w-4" /> Create your first job post
                  </.link>
                </div>
              <% else %>
                <div class="grid gap-4">
                  <%= for job_post <- @job_posts do %>
                    <div class="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm transition-shadow hover:shadow-md">
                      <div class="flex flex-col gap-5 md:flex-row md:items-start md:justify-between">
                        <div class="flex-1">
                          <div class="mb-3 flex items-center gap-3">
                            <div class="flex h-11 w-11 items-center justify-center rounded-2xl bg-violet-50">
                              <.icon name="hero-briefcase" class="h-5 w-5 text-violet-600" />
                            </div>
                            <div>
                              <h3 class="text-lg font-semibold leading-tight text-slate-900">
                                <%= job_post.title %>
                              </h3>
                              <p class="text-xs uppercase tracking-wider text-slate-400">Job post</p>
                            </div>
                          </div>
                          <p class="mb-4 max-w-3xl text-sm text-slate-600 line-clamp-2">
                            <%= job_post.description %>
                          </p>
                          <div class="flex flex-wrap items-center gap-3 text-xs text-slate-500">
                            <span class="rounded-full bg-slate-100 px-3 py-1">
                              Posted <%= Calendar.strftime(job_post.inserted_at, "%B %d, %Y") %>
                            </span>
                            <span class={[
                              "inline-flex items-center rounded-full px-3 py-1 text-xs font-semibold",
                              job_post.status == "active" && "bg-emerald-50 text-emerald-700",
                              job_post.status == "overdue" && "bg-amber-50 text-amber-700",
                              job_post.status not in ["active", "overdue"] &&
                                "bg-slate-100 text-slate-700"
                            ]}>
                              <%= job_post.status %>
                            </span>
                          </div>
                        </div>

                        <div class="flex flex-wrap items-center gap-2">
                          <.link
                            navigate={~p"/jobs/#{job_post.id}/edit"}
                            class="inline-flex items-center gap-2 rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm font-medium text-slate-700 transition-colors hover:bg-slate-50"
                          >
                            <.icon name="hero-pencil-square" class="h-4 w-4" /> Edit
                          </.link>
                          <button
                            phx-click="toggle_status"
                            phx-value-id={job_post.id}
                            class="inline-flex items-center gap-2 rounded-xl border border-amber-200 bg-white px-3 py-2 text-sm font-medium text-amber-700 transition-colors hover:bg-amber-50"
                          >
                            <.icon name="hero-arrow-path" class="h-4 w-4" />
                            <%= if job_post.status == "active",
                              do: "Mark Overdue",
                              else: "Mark Active" %>
                          </button>
                          <button
                            phx-click="delete"
                            phx-value-id={job_post.id}
                            class="inline-flex items-center gap-2 rounded-xl border border-red-200 bg-white px-3 py-2 text-sm font-medium text-red-700 transition-colors hover:bg-red-50"
                            data-confirm="Are you sure you want to delete this job post?"
                          >
                            <.icon name="hero-trash" class="h-4 w-4" /> Delete
                          </button>
                        </div>
                      </div>
                    </div>
                  <% end %>
                </div>
              <% end %>
            <% else %>
              <div class="rounded-3xl border border-slate-200 bg-slate-50 p-12 text-center">
                <div class="text-xl font-semibold text-slate-900">
                  You need to be logged in as a shop owner to manage job posts
                </div>
                <p class="mt-2 text-slate-500">
                  Sign in with a shop account to create and manage your roles.
                </p>
                <%= if @current_user do %>
                  <.link
                    navigate={~p"/create-shop"}
                    class="mt-4 inline-flex items-center rounded-xl border border-transparent bg-violet-600 px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-violet-700"
                  >
                    Create a Shop
                  </.link>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
      </div>

      <%= if @live_action == :new do %>
        <.modal id="job-post-modal" show on_cancel={JS.patch(~p"/careers")}>
          <div class="p-1">
            <div class="mb-6">
              <h2 class="text-2xl font-bold text-slate-900">Create Job Post</h2>
              <p class="mt-1 text-sm text-slate-500">
                Publish a new role for your shop without leaving this page.
              </p>
            </div>

            <.form
              for={@form}
              id="job-post-form"
              phx-change="validate"
              phx-submit="save"
              class="space-y-5"
            >
              <.input
                field={@form[:title]}
                type="text"
                label="Job Title"
                placeholder="e.g., Delivery Rider"
              />
              <.input
                field={@form[:description]}
                type="textarea"
                label="Description"
                placeholder="Describe the role and responsibilities..."
                rows="4"
              />
              <.input
                field={@form[:requirements]}
                type="textarea"
                label="Requirements"
                placeholder="List the requirements for this position..."
                rows="4"
              />
              <.input
                field={@form[:status]}
                type="select"
                label="Status"
                options={[{"Active", "active"}, {"Overdue", "overdue"}]}
              />

              <div class="flex items-center justify-end gap-3 pt-2">
                <.link
                  patch={~p"/careers"}
                  class="rounded-xl border border-slate-200 px-4 py-2 text-slate-700 hover:bg-slate-50"
                >
                  Cancel
                </.link>
                <button
                  type="submit"
                  class="rounded-xl bg-violet-600 px-4 py-2 font-semibold text-white hover:bg-violet-700"
                >
                  Create Job Post
                </button>
              </div>
            </.form>
          </div>
        </.modal>
      <% end %>
    </Layouts.app>
    """
  end
end
