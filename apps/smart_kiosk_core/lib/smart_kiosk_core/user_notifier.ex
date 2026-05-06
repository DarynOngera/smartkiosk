defmodule SmartKioskCore.UserNotifier do
  @moduledoc """
  Behaviour and default no-op implementation for user email notifications.

  The real implementation lives in `SmartKioskWeb.UserNotifier` (where Swoosh
  is available).  Configure it in your app config:

      # config/config.exs
      config :smart_kiosk_core, :user_notifier, SmartKioskWeb.UserNotifier

  Falls back to a no-op (logs a warning) if unconfigured, so core tests
  don't need a mailer.
  """

  @callback deliver_confirmation_instructions(user :: map(), url :: String.t()) ::
              {:ok, term()} | {:error, term()}

  @callback deliver_reset_password_instructions(user :: map(), url :: String.t()) ::
              {:ok, term()} | {:error, term()}

  @callback deliver_update_email_instructions(user :: map(), url :: String.t()) ::
              {:ok, term()} | {:error, term()}

  # ---------------------------------------------------------------------------
  # Delegation helpers called by Accounts context
  # ---------------------------------------------------------------------------

  def deliver_confirmation_instructions(user, url) do
    impl().deliver_confirmation_instructions(user, url)
  end

  def deliver_reset_password_instructions(user, url) do
    impl().deliver_reset_password_instructions(user, url)
  end

  def deliver_update_email_instructions(user, url) do
    impl().deliver_update_email_instructions(user, url)
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp impl do
    Application.get_env(:smart_kiosk_core, :user_notifier, __MODULE__.Noop)
  end

  # ---------------------------------------------------------------------------
  # No-op fallback (used in tests / when notifier is not configured)
  # ---------------------------------------------------------------------------

  defmodule Noop do
    @moduledoc false
    @behaviour SmartKioskCore.UserNotifier

    require Logger

    def deliver_confirmation_instructions(user, url) do
      Logger.warning("[UserNotifier] confirmation email not sent to #{user.email} — url: #{url}")
      {:ok, :noop}
    end

    def deliver_reset_password_instructions(user, url) do
      Logger.warning("[UserNotifier] reset email not sent to #{user.email} — url: #{url}")
      {:ok, :noop}
    end

    def deliver_update_email_instructions(user, url) do
      Logger.warning("[UserNotifier] update-email not sent to #{user.email} — url: #{url}")
      {:ok, :noop}
    end
  end
end
