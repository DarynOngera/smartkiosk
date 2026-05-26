defmodule SmartKioskWeb.Plugs.EnsureSessionId do
  @moduledoc """
  Ensures every browser session has a stable `:session_id`.

  Used to support guest carts by associating cart items to the session.
  """

  import Plug.Conn

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    case get_session(conn, :session_id) do
      session_id when is_binary(session_id) and byte_size(session_id) > 0 ->
        conn

      _ ->
        put_session(conn, :session_id, generate_session_id())
    end
  end

  defp generate_session_id do
    16
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end
end
