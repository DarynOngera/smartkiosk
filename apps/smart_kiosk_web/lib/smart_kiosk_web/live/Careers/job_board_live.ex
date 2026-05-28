defmodule SmartKioskWeb.Careers.JobBoardLive do
  use SmartKioskWeb, :live_view

  alias SmartKioskCore.JobPosts

  @impl true
  def mount(_params, _session, socket) do
    job_posts = JobPosts.list_active_job_posts()

    {:ok,
     socket
     |> assign(:job_posts, job_posts)
     |> assign(:page_title, "Job Board")}
  end
end
