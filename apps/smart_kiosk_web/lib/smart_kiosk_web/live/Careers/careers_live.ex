defmodule SmartKioskWeb.Careers.CareersLive do
  use SmartKioskWeb, :live_view

  alias SmartKioskCore.JobPosts

  @impl true
  def mount(_params, _session, socket) do
    shop = Map.get(socket.assigns, :current_shop)

    if shop do
      job_posts =
        JobPosts.list_active_job_posts()
        |> Enum.filter(fn jp -> jp.shop_id == shop.id end)

      {:ok,
       socket
       |> assign(:job_posts, job_posts)
       |> assign(:page_title, "Manage Job Posts")}
    else
      {:ok, assign(socket, page_title: "Careers")}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    shop = Map.get(socket.assigns, :current_shop)

    if shop do
      job_post = JobPosts.get_job_post!(id)

      if job_post.shop_id == shop.id do
        {:ok, _} = JobPosts.delete_job_post(job_post)

        job_posts =
          JobPosts.list_active_job_posts()
          |> Enum.filter(fn jp -> jp.shop_id == shop.id end)

        {:noreply, assign(socket, :job_posts, job_posts)}
      else
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end
end
