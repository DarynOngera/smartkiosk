defmodule SmartKioskWeb.RiderApplicationThanksLive do
  use SmartKioskWeb, :live_view

  alias SmartKioskCore.JobPosts
  alias SmartKioskCore.Shops

  @impl true
  def mount(%{"slug" => slug} = params, _session, socket) do
    case Shops.get_shop_by_slug(slug) do
      nil ->
        {:ok, push_navigate(socket, to: ~p"/")}

      shop ->
        {:ok,
         socket
         |> assign(:shop, shop)
         |> assign(:job_post, load_job_post(shop, params["job_id"]))
         |> assign(:page_title, "Application Received")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_path={~p"/shop/#{@shop.slug}/rider/thanks"}>
      <div class="min-h-screen bg-slate-50 px-4 py-16 sm:px-6 lg:px-8">
        <div class="mx-auto max-w-2xl">
          <div class="rounded-3xl bg-white p-8 text-center shadow-sm ring-1 ring-slate-200 sm:p-12">
            <div class="mx-auto mb-6 flex h-16 w-16 items-center justify-center rounded-2xl bg-emerald-50">
              <.icon name="hero-check-circle" class="h-8 w-8 text-emerald-600" />
            </div>
            <h1 class="text-3xl font-bold tracking-tight text-slate-900 sm:text-4xl">
              Thank you for applying to work with us
            </h1>
            <%= if @job_post do %>
              <p class="mt-3 text-lg font-semibold text-violet-700"><%= @job_post.title %></p>
            <% end %>
            <p class="mx-auto mt-4 max-w-xl text-base leading-7 text-slate-600">
              <%= @shop.name %> will review your application and get back to you soon.
            </p>

            <div class="mt-8 flex flex-col items-center justify-center gap-3 sm:flex-row">
              <.link
                navigate={~p"/jobs"}
                class="inline-flex items-center justify-center rounded-xl border border-slate-200 bg-white px-5 py-3 font-semibold text-slate-700 transition-colors hover:bg-slate-50"
              >
                Browse more jobs
              </.link>
              <.link
                navigate={~p"/shop/#{@shop.slug}"}
                class="inline-flex items-center justify-center rounded-xl bg-violet-600 px-5 py-3 font-semibold text-white shadow-sm shadow-violet-600/20 transition-colors hover:bg-violet-700"
              >
                Back to shop
              </.link>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp load_job_post(_shop, nil), do: nil

  defp load_job_post(shop, job_post_id) do
    case JobPosts.get_job_post!(job_post_id) do
      %{} = job_post when job_post.shop_id == shop.id -> job_post
      _ -> nil
    end
  rescue
    _ -> nil
  end
end
