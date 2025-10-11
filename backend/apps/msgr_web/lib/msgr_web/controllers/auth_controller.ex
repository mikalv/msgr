defmodule MessngrWeb.AuthController do
  use MessngrWeb, :controller

  alias Messngr.Auth.Challenge

  action_fallback MessngrWeb.FallbackController

  def challenge(conn, params) do
    case Messngr.start_auth_challenge(params) do
      {:ok, %Challenge{} = challenge, code} ->
        conn
        |> put_status(:created)
        |> render(:challenge,
          challenge: challenge,
          code: maybe_expose_code(code),
          target_hint: target_hint(challenge)
        )

      {:error, reason} ->
        {:error, reason}
    end
  end

  def verify(conn, params) do
    with challenge_id when is_binary(challenge_id) <- Map.get(params, "challenge_id"),
         code when is_binary(code) <- Map.get(params, "code"),
         {:ok, result} <- Messngr.verify_auth_challenge(challenge_id, code, params) do
      render(conn, :session, result: result)
    else
      nil -> {:error, :bad_request}
      {:error, reason} -> {:error, reason}
    end
  end

  def oidc(conn, params) do
    case Messngr.complete_oidc(params) do
      {:ok, result} -> render(conn, :session, result: result)
      {:error, reason} -> {:error, reason}
    end
  end

  defp maybe_expose_code(code) do
    if Application.get_env(:msgr_web, :expose_otp_codes, false) do
      code
    else
      nil
    end
  end

  defp target_hint(%Challenge{channel: :email, target: target}) do
    [prefix | domain] = String.split(target, "@")
    masked_prefix =
      prefix
      |> String.slice(0, 2)
      |> Kernel.<>("***")

    masked_domain =
      domain
      |> Enum.join("@")

    masked_prefix <> "@" <> masked_domain
  end

  defp target_hint(%Challenge{channel: :phone, target: target}) do
    tail = target |> String.slice(-2, 2) || "**"
    "+***#{tail}"
  end
end

