defmodule MessngrWeb.AuthController do
  use MessngrWeb, :controller

  alias Messngr.Auth.Challenge

  action_fallback MessngrWeb.FallbackController

  def challenge(conn, params) do
    case Messngr.start_auth_challenge(params) do
      {:ok, %Challenge{} = challenge, _code} ->
        conn
        |> put_status(:created)
        |> render(:challenge,
          challenge: challenge,
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

  def bot_token(conn, %{"email" => email, "bot_secret" => secret}) do
    configured_secret = Application.get_env(:msgr_web, :bot_auth_secret)

    cond do
      configured_secret == nil || configured_secret == "" ->
        conn |> put_status(:not_found) |> json(%{error: "not_found"})

      secret != configured_secret ->
        conn |> put_status(:unauthorized) |> json(%{error: "invalid_secret"})

      true ->
        case Messngr.Auth.authenticate_bot(email) do
          {:ok, result} -> render(conn, :session, result: result)
          {:error, reason} -> {:error, reason}
        end
    end
  end

  def bot_token(conn, _params) do
    conn |> put_status(:bad_request) |> json(%{error: "email and bot_secret required"})
  end

  def oidc(conn, params) do
    case Messngr.complete_oidc(params) do
      {:ok, result} -> render(conn, :session, result: result)
      {:error, reason} -> {:error, reason}
    end
  end

  def refresh(conn, %{"refresh_token" => refresh_token}) when is_binary(refresh_token) do
    case Messngr.Auth.refresh_access_token(refresh_token) do
      {:ok, access_token} ->
        json(conn, %{access_token: access_token})

      {:error, _reason} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "invalid or expired refresh token"})
    end
  end

  def refresh(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "refresh_token is required"})
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

