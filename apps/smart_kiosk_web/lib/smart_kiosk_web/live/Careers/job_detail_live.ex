defmodule SmartKioskWeb.Careers.JobDetailLive do
  use SmartKioskWeb, :live_view

  alias SmartKioskCore.JobPosts

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    job_post = JobPosts.get_job_post!(id)

    {:ok,
     socket
     |> assign(:current_shop, nil)
     |> assign(:job_post, job_post)
     |> assign(:page_title, job_post.title)}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    job_post = JobPosts.get_job_post!(id)

    {:noreply,
     socket
     |> assign(:current_shop, nil)
     |> assign(:job_post, job_post)
     |> assign(:page_title, job_post.title)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_path="/jobs"
      current_user={@current_user}
      current_shop={@current_shop}
    >
      <div class="bg-slate-50">
        <div class="mx-auto max-w-4xl px-4 py-10 sm:px-6 lg:px-8 lg:py-14">
          <div class="mb-8">
            <.header>
              <%= @job_post.title %>
              <:subtitle>
                <%= if @job_post.shop do %>
                  <%= @job_post.shop.name %>
                <% else %>
                  Shop
                <% end %>
              </:subtitle>
              <:actions>
                <.back navigate={~p"/jobs"}>Back to Job Board</.back>
              </:actions>
            </.header>
          </div>

          <div class="overflow-hidden rounded-3xl bg-white shadow-sm ring-1 ring-slate-200">
            <div class="border-b border-slate-200 bg-slate-50 p-6 sm:p-8">
              <div class="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
                <div>
                  <h1 class="text-2xl font-bold tracking-tight text-slate-900">
                    <%= @job_post.title %>
                  </h1>
                  <div class="mt-2 flex flex-wrap items-center gap-3 text-sm text-slate-500">
                    <span>
                      <%= if @job_post.shop do %>
                        <%= @job_post.shop.name %>
                      <% else %>
                        Shop
                      <% end %>
                    </span>
                    <span class="hidden sm:inline">•</span>
                    <span>Posted <%= Calendar.strftime(@job_post.inserted_at, "%B %d, %Y") %></span>
                  </div>
                </div>
                <span class="inline-flex items-center rounded-full bg-emerald-50 px-3 py-1 text-sm font-medium text-emerald-700">
                  Active
                </span>
              </div>
            </div>

            <div class="space-y-8 p-6 sm:p-8">
              <section>
                <h2 class="mb-3 text-lg font-semibold text-slate-900">Job Description</h2>
                <p class="max-w-none whitespace-pre-line text-sm leading-7 text-slate-600">
                  <%= @job_post.description %>
                </p>
              </section>

              <section>
                <h2 class="mb-3 text-lg font-semibold text-slate-900">Requirements</h2>
                <p class="max-w-none whitespace-pre-line text-sm leading-7 text-slate-600">
                  <%= @job_post.requirements %>
                </p>
              </section>

              <div class="border-t border-slate-200 pt-6">
                <.link
                  navigate={
                    ~p"/shop/#{if @job_post.shop, do: @job_post.shop.slug, else: ""}/rider/register?job_id=#{@job_post.id}"
                  }
                  class="inline-flex items-center justify-center rounded-xl bg-violet-600 px-6 py-3 text-base font-medium text-white transition-colors hover:bg-violet-700 focus:outline-none focus:ring-2 focus:ring-violet-500 focus:ring-offset-2"
                >
                  Apply for this Position
                </.link>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
