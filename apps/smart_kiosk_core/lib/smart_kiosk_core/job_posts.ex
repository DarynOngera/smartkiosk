defmodule SmartKioskCore.JobPosts do
  @moduledoc """
  The JobPosts context.
  """

  import Ecto.Query
  alias SmartKioskCore.Repo
  alias SmartKioskCore.Schemas.JobPost

  @doc """
  Returns the list of all active job posts.
  """
  def list_active_job_posts do
    JobPost
    |> where([jp], jp.status == "active")
    |> order_by([jp], desc: jp.inserted_at)
    |> preload([:shop])
    |> Repo.all()
  end

  @doc """
  Gets a single job post by id.
  """
  def get_job_post!(id) do
    JobPost
    |> where([jp], jp.id == ^id)
    |> preload([:shop])
    |> Repo.one!()
  end

  @doc """
  Creates a job post.
  """
  def create_job_post(attrs \\ %{}) do
    %JobPost{}
    |> JobPost.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a job post.
  """
  def update_job_post(%JobPost{} = job_post, attrs) do
    job_post
    |> JobPost.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a job post.
  """
  def delete_job_post(%JobPost{} = job_post) do
    Repo.delete(job_post)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking job post changes.
  """
  def change_job_post(%JobPost{} = job_post, attrs \\ %{}) do
    JobPost.changeset(job_post, attrs)
  end
end
