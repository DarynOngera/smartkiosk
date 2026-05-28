defmodule SmartKioskWeb.Careers.JobDetailLive do
  use SmartKioskWeb, :live_view

  alias SmartKioskCore.JobPosts

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    job_post = JobPosts.get_job_post!(id)

    {:ok,
     socket
     |> assign(:job_post, job_post)
     |> assign(:page_title, job_post.title)}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    job_post = JobPosts.get_job_post!(id)

    {:noreply,
     socket
     |> assign(:job_post, job_post)
     |> assign(:page_title, job_post.title)}
  end
end
