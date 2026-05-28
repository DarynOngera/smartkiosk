defmodule SmartKioskWeb.Careers.JobFormLive do
  use SmartKioskWeb, :live_view

  alias SmartKioskCore.JobPosts

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    job_post = JobPosts.get_job_post!(id)
    shop = Map.get(socket.assigns, :current_shop)

    if shop && job_post.shop_id == shop.id do
      changeset = JobPosts.change_job_post(job_post)

      {:ok,
       socket
       |> assign(:job_post, job_post)
       |> assign(:changeset, changeset)
       |> assign(:page_title, "Edit Job Post")}
    else
      {:ok, redirect(socket, to: ~p"/careers")}
    end
  end

  def mount(_params, _session, socket) do
    shop = Map.get(socket.assigns, :current_shop)

    if shop do
      changeset =
        JobPosts.change_job_post(%SmartKioskCore.Schemas.JobPost{}, %{
          shop_id: shop.id,
          status: "active"
        })

      {:ok,
       socket
       |> assign(:job_post, nil)
       |> assign(:changeset, changeset)
       |> assign(:page_title, "Add Job Post")}
    else
      {:ok, redirect(socket, to: ~p"/careers")}
    end
  end

  @impl true
  def handle_event("save", %{"job_post" => job_post_params}, socket) do
    shop = Map.get(socket.assigns, :current_shop)

    job_post_params =
      if shop do
        Map.put(job_post_params, "shop_id", shop.id)
      else
        job_post_params
      end

    case socket.assigns.job_post do
      nil ->
        case JobPosts.create_job_post(job_post_params) do
          {:ok, _job_post} ->
            {:noreply,
             socket
             |> put_flash(:info, "Job post created successfully")
             |> redirect(to: ~p"/careers")}

          {:error, changeset} ->
            {:noreply, assign(socket, :changeset, changeset)}
        end

      job_post ->
        case JobPosts.update_job_post(job_post, job_post_params) do
          {:ok, _job_post} ->
            {:noreply,
             socket
             |> put_flash(:info, "Job post updated successfully")
             |> redirect(to: ~p"/careers")}

          {:error, changeset} ->
            {:noreply, assign(socket, :changeset, changeset)}
        end
    end
  end
end
