defmodule SmartKioskWeb.Plugs.EnsureSessionIdTest do
  use SmartKioskWeb.ConnCase, async: true

  alias SmartKioskWeb.Plugs.EnsureSessionId

  test "sets a session_id when missing", %{conn: conn} do
    conn =
      conn
      |> Plug.Test.init_test_session(%{})
      |> EnsureSessionId.call([])

    assert is_binary(get_session(conn, :session_id))
    assert byte_size(get_session(conn, :session_id)) > 0
  end

  test "keeps an existing session_id", %{conn: conn} do
    conn =
      conn
      |> Plug.Test.init_test_session(%{session_id: "existing"})
      |> EnsureSessionId.call([])

    assert get_session(conn, :session_id) == "existing"
  end
end
