defmodule SmartKioskWeb.Careers.JobBoardLive do
  use SmartKioskWeb, :live_view

  alias SmartKioskCore.JobPosts

  @impl true
  def mount(_params, _session, socket) do
    job_posts = JobPosts.list_active_job_posts()

    {:ok,
     socket
     |> assign(:current_shop, nil)
     |> assign(:job_posts, job_posts)
     |> assign(:page_title, "Job Board")}
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
        <div class="mx-auto max-w-7xl px-4 py-10 sm:px-6 lg:px-8 lg:py-14">
          <div class="mb-8">
            <.header>
              Job Board
              <:subtitle>Find your next opportunity.</:subtitle>
              <:actions>
                <.back navigate={~p"/"}>Back to Home</.back>
              </:actions>
            </.header>
          </div>

          <div class="rounded-3xl bg-white p-6 shadow-sm ring-1 ring-slate-200 sm:p-8">
            <%= if @job_posts == [] do %>
              <div class="rounded-3xl border border-dashed border-slate-200 bg-slate-50 px-6 py-16 text-center">
                <div class="mx-auto mb-4 flex h-14 w-14 items-center justify-center rounded-2xl bg-violet-50">
                  <.icon name="hero-briefcase" class="h-7 w-7 text-violet-600" />
                </div>
                <div class="text-xl font-semibold text-slate-900">
                  No active job postings at the moment
                </div>
                <p class="mx-auto mt-2 max-w-md text-sm text-slate-500">
                  Check back later for new opportunities from shops near you.
                </p>
              </div>
            <% else %>
              <div class="grid gap-6 md:grid-cols-2 xl:grid-cols-3">
                <%= for job_post <- @job_posts do %>
                  <.link
                    navigate={~p"/jobs/#{job_post.id}"}
                    class="group block rounded-3xl border border-slate-200 bg-white p-6 shadow-sm transition-all hover:-translate-y-0.5 hover:shadow-md"
                  >
                    <div class="mb-4 flex items-start justify-between gap-4">
                      <div class="flex-1">
                        <h3 class="text-lg font-semibold text-slate-900 group-hover:text-violet-700">
                          <%= job_post.title %>
                        </h3>
                        <p class="mt-1 text-sm text-slate-500">
                          <%= if job_post.shop do %>
                            <%= job_post.shop.name %>
                          <% else %>
                            Shop
                          <% end %>
                        </p>
                      </div>
                      <span class="inline-flex items-center rounded-full bg-emerald-50 px-2.5 py-1 text-xs font-medium text-emerald-700">
                        Active
                      </span>
                    </div>

                    <p class="mb-5 line-clamp-3 text-sm leading-6 text-slate-600">
                      <%= job_post.description %>
                    </p>

                    <div class="flex items-center justify-between text-xs text-slate-500">
                      <span>Posted <%= Calendar.strftime(job_post.inserted_at, "%B %d, %Y") %></span>
                      <span class="font-medium text-violet-700">View details →</span>
                    </div>
                  </.link>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
