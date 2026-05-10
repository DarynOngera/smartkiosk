defmodule SmartKioskWeb.Api.RiderStubController do
  @moduledoc """
  Phase 1 stub for the rider mobile app API.

  This controller holds the API contract for rider endpoints so the rest
  of the system (delivery assignment, location tracking, PubSub broadcasts)
  can be developed and tested without the native app being built.

  Replace the stub implementations with real business logic in Phase 3
  when the React Native / Flutter app is ready.

  All endpoints require a rider auth token in the Authorization header:
    Authorization: Bearer <rider_session_token>
  """
  use SmartKioskWeb, :controller

  import Ecto.Query

  alias SmartKioskCore.Repo
  alias SmartKioskCore.Schemas.{Rider, Delivery}
  alias SmartKioskCore.Accounts

  # ── POST /api/rider/location ───────────────────────────────────────────────
  @doc """
  Updates a rider's current GPS coordinates and availability status.

  Body: { "lat": float, "lng": float, "status": "available" | "on_delivery" | "offline" }
  """
  def update_location(conn, params) do
    with {:ok, rider} <- get_rider_from_token(conn),
         {:ok, updated} <-
           rider
           |> Rider.location_changeset(%{
             current_lat: params["lat"],
             current_lng: params["lng"],
             status: params["status"] || rider.status
           })
           |> Repo.update() do
      # Broadcast location to PubSub so LiveView delivery tracker can subscribe
      Phoenix.PubSub.broadcast(
        SmartKiosk.PubSub,
        "rider:#{rider.id}:location",
        {:location_update,
         %{lat: updated.current_lat, lng: updated.current_lng, status: updated.status}}
      )

      json(conn, %{ok: true, status: updated.status})
    else
      {:error, :unauthorized} -> unauthorized(conn)
      {:error, changeset} -> json(conn |> put_status(422), %{errors: format_errors(changeset)})
    end
  end

  # ── GET /api/rider/tasks ──────────────────────────────────────────────────
  @doc """
  Returns the rider's current task queue (pending + active deliveries).
  """
  def list_tasks(conn, _params) do
    with {:ok, rider} <- get_rider_from_token(conn) do
      tasks =
        from(d in Delivery,
          where:
            d.rider_id == ^rider.id and d.status in [:pending_pickup, :picked_up, :in_transit],
          preload: [order: [:shop, items: :product]]
        )
        |> Repo.all()

      json(conn, %{tasks: Enum.map(tasks, &format_task/1)})
    else
      {:error, :unauthorized} -> unauthorized(conn)
    end
  end

  # ── POST /api/rider/tasks/:id/status ─────────────────────────────────────
  @doc """
  Updates a delivery task status.

  Body: { "status": "picked_up" | "in_transit" | "delivered" | "failed" }
  """
  def update_task_status(conn, %{"id" => delivery_id, "status" => new_status}) do
    with {:ok, rider} <- get_rider_from_token(conn),
         %Delivery{} = delivery <- Repo.get_by(Delivery, id: delivery_id, rider_id: rider.id),
         {:ok, updated} <-
           delivery
           |> Delivery.status_changeset(String.to_existing_atom(new_status))
           |> Repo.update() do
      Phoenix.PubSub.broadcast(
        SmartKiosk.PubSub,
        "delivery:#{delivery.id}",
        {:status_update, updated.status}
      )

      json(conn, %{ok: true, status: updated.status})
    else
      {:error, :unauthorized} -> unauthorized(conn)
      nil -> json(conn |> put_status(404), %{error: "task not found"})
      {:error, cs} -> json(conn |> put_status(422), %{errors: format_errors(cs)})
    end
  end

  # ── Private helpers ────────────────────────────────────────────────────────

  defp get_rider_from_token(conn) do
    # Stub: uses the same session token as the web app.
    # Phase 3: replace with a dedicated Bearer token / JWT for the native app.
    token =
      conn
      |> get_req_header("authorization")
      |> List.first("")
      |> String.replace_prefix("Bearer ", "")

    case Accounts.get_user_by_session_token(token) do
      nil ->
        {:error, :unauthorized}

      user ->
        case Repo.get_by(Rider, user_id: user.id) do
          nil -> {:error, :unauthorized}
          rider -> {:ok, rider}
        end
    end
  end

  defp unauthorized(conn) do
    conn
    |> put_status(401)
    |> json(%{error: "unauthorized"})
  end

  defp format_task(%Delivery{} = d) do
    %{
      id: d.id,
      status: d.status,
      pickup: %{
        lat: d.pickup_lat,
        lng: d.pickup_lng,
        address: d.order && d.order.shop && d.order.shop.address
      },
      dropoff: %{
        lat: d.dropoff_lat,
        lng: d.dropoff_lng,
        address: d.order && d.order.delivery_address
      },
      items:
        Enum.map((d.order && d.order.items) || [], fn i ->
          %{name: i.product_name, qty: i.quantity}
        end)
    }
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
