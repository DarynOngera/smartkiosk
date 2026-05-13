defmodule SmartKioskWeb.CartLive.Index do
  use SmartKioskWeb, :live_view

  alias SmartKioskCore.Cart

  def mount(_params, _session, socket) do
    current_user = socket.assigns[:current_user]
    # Assuming session_id is passed in params
    session_id = get_connect_params(socket)["session_id"]

    # Calculate initial cart count
    cart_count =
      cond do
        current_user -> Cart.get_user_cart_count(current_user)
        session_id -> Cart.get_session_cart_count(session_id)
        true -> 0
      end

    {:ok,
     assign(socket,
       page_title: "Your Cart",
       current_user: current_user,
       session_id: session_id,
       cart_count: cart_count
     )}
  end

  # Handle broadcasts to update cart count reactively
  def handle_info({:cart_updated, payload}, socket) do
    # Check if the update is relevant to the current user/session
    current_user_id = socket.assigns[:current_user] && socket.assigns[:current_user].id
    current_session_id = socket.assigns[:session_id]

    update_needed =
      case {current_user_id, current_session_id} do
        # No user or session, assume any update is relevant
        {nil, nil} -> true
        # Relevant if user IDs match
        {uid, _} when not is_nil(uid) -> payload.user_id == uid
        # Relevant if session IDs match
        {nil, sid} -> payload.session_id == sid
        # Should not happen with current logic
        _ -> false
      end

    if update_needed do
      new_cart_count =
        cond do
          socket.assigns[:current_user] -> Cart.get_user_cart_count(socket.assigns[:current_user])
          socket.assigns[:session_id] -> Cart.get_session_cart_count(socket.assigns[:session_id])
          true -> 0
        end

      {:noreply, assign(socket, :cart_count, new_cart_count)}
    else
      # No update needed for this socket
      {:noreply, socket}
    end
  end

  # Add other handle_event, handle_info, and render functions as needed for the Cart LiveView
  # For now, the core cart count logic is in place.
end
