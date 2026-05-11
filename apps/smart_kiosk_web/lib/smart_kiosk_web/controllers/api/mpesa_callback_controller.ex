defmodule SmartKioskWeb.Api.MpesaCallbackController do
  @moduledoc """
  Temporary controller stub for M-Pesa webhook endpoints.

  Real payment integration is deferred, but the routes remain in place so the
  callback contract is stable and the router compiles without warnings.
  """
  use SmartKioskWeb, :controller

  def create(conn, _params) do
    json(conn, %{result_code: 0, result_desc: "accepted"})
  end

  def validation(conn, _params) do
    json(conn, %{result_code: 0, result_desc: "accepted"})
  end
end
