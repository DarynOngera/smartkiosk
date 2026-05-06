defmodule SmartKioskWeb.UserNotifier do
  @moduledoc """
  Delivers transactional emails to users via Swoosh.

  In dev the Local adapter stores emails at http://localhost:4000/dev/mailbox.
  """

  import Swoosh.Email
  alias SmartKioskWeb.Mailer

  # ---------------------------------------------------------------------------
  # Email confirmation
  # ---------------------------------------------------------------------------

  @doc "Sends an account-confirmation link to the user."
  def deliver_confirmation_instructions(user, url) do
    deliver(user.email, "Confirm your SmartKiosk account", """
    Hi #{user.full_name || user.email},

    Welcome to SmartKiosk! Please confirm your email address by visiting:

        #{url}

    If you did not create an account you can safely ignore this email.
    """)
  end

  # ---------------------------------------------------------------------------
  # Password reset
  # ---------------------------------------------------------------------------

  @doc "Sends a password-reset link to the user."
  def deliver_reset_password_instructions(user, url) do
    deliver(user.email, "Reset your SmartKiosk password", """
    Hi #{user.full_name || user.email},

    You can reset your SmartKiosk password by visiting:

        #{url}

    The link expires in 10 minutes. If you did not request a reset, ignore this.
    """)
  end

  # ---------------------------------------------------------------------------
  # Email change
  # ---------------------------------------------------------------------------

  @doc "Sends an email-change confirmation link to the new address."
  def deliver_update_email_instructions(user, url) do
    deliver(user.email, "Confirm your new SmartKiosk email address", """
    Hi #{user.full_name || user.email},

    Confirm your new email address by visiting:

        #{url}

    If you did not request this change, ignore this email.
    """)
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp deliver(to, subject, body) do
    email =
      new()
      |> to(to)
      |> from({"SmartKiosk", "noreply@smartkiosk.co.ke"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end
end
