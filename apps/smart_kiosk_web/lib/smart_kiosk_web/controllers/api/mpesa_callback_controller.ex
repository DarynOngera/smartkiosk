defmodule SmartKioskWeb.Api.MpesaCallbackController do
  @moduledoc """
  Receives M-PESA webhook callbacks.

  Endpoints are intentionally unauthenticated and CSRF-free because they are
  called by Safaricom's servers.
  """
  use SmartKioskWeb, :controller

  require Logger

  @doc """
  POST /api/mpesa/callback

  Used for STK push confirmations and other asynchronous notifications.
  """
  def create(conn, params) do
    Logger.info("M-PESA callback received: #{inspect(params)}")
    json(conn, %{ok: true})
  end

  @doc """
  POST /api/mpesa/validation

  Used for transaction validation. Responds with a standard accept payload.
  """
  def validation(conn, params) do
    Logger.info("M-PESA validation received: #{inspect(params)}")
    json(conn, %{ResultCode: 0, ResultDesc: "Accepted"})
  end
end
