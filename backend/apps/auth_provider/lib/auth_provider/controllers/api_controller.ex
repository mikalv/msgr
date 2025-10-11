defmodule AuthProvider.ApiController do
  use AuthProvider, :controller
  import Plug.Conn
  require Logger

  @refresh_opts [
    ttl: {4, :weeks},
    token_type: "refresh"
  ]

  def device_register(conn, %{"from" => from, "payload" => payload} = _params) do
    Logger.info "Payload: #{inspect payload}"
    if AuthProvider.DeviceHelper.validate_device_signature(payload) do
      {:ok, device} = AuthProvider.DeviceHelper.find_or_register_device(payload)
      Logger.info "Device #{inspect device}"
      json(conn, %{"deviceId" => from})
    else
      conn |> send_resp(401, Jason.encode!(%{"status" => "error", "error" => "Invalid signature"}))
    end
  end

  def login_code(conn, %{"from" => from, "code" => code, "msisdn" => msisdn} = _params) do
    Logger.info "Login code (#{code}) from #{msisdn} via deviceId #{from}"
    {:ok, user} = AuthProvider.UserHelper.find_or_register_user_by_msisdn(msisdn, from)
    actual_login_code(conn, msisdn, code, user)
  end

  def login_code(conn, %{"from" => from, "code" => code, "email" => email} = _params) do
    Logger.info "Login code (#{code}) from #{email} via deviceId #{from}"
    {:ok, user} = AuthProvider.UserHelper.find_or_register_user_by_email(email, from)
    actual_login_code(conn, email, code, user)
  end

  def actual_login_code(conn, identifier, code, user) do
    case AuthProvider.UserHelper.validate_login_code_for_user(code, user) do
      {:ok, :valid_code} ->
        {:ok, token, claims} = AuthProvider.Guardian.encode_and_sign(user)
        {:ok, refresh_token, _claims} = AuthProvider.Guardian.encode_and_sign(user, %{}, @refresh_opts)
        Logger.info "Issued out token=#{token}, claims=#{inspect claims} refresh=#{refresh_token}"
        json(conn, %{
          "status" => "ok",
          "claims" => claims,
          "user" => %{
            "accessToken" => token,
            "identifier" => identifier,
            "uid" => user.id,
            "refreshToken" => refresh_token
          }
        })
      {:error, :invalid_code} ->
        conn |> send_resp(401, Jason.encode!(%{"status" => "error", "error" => "Wrong code", "uid" => user.id}))
    end
  end


  def login(conn, %{"from" => from, "email" => email} = _params) do
    Logger.info "Login request from #{email} via deviceId #{from}"
    {:ok, user} = AuthProvider.UserHelper.find_or_register_user_by_email(email, from)
    :ok = AuthProvider.UserHelper.create_login_code_for_user(user)
    json(conn, %{"status" => "ok", "next" => "code", "uid" => user.id})
  end


  def login(conn, %{"from" => from, "msisdn" => msisdn} = _params) do
    Logger.info "Login request from #{msisdn} via deviceId #{from}"
    {:ok, user} = AuthProvider.UserHelper.find_or_register_user_by_msisdn(msisdn, from)
    :ok = AuthProvider.UserHelper.create_login_code_for_user(user)
    json(conn, %{"status" => "ok", "next" => "code", "uid" => user.id})
  end

  def login(conn, _params) do
    conn |> send_resp(400, Jason.encode!(%{"status" => "error", "error" => "Invalid parameters!"}))
  end

  def refresh_token(conn, %{"from" => from, "token" => token} = _params) do
    {:ok, claims} = AuthProvider.Guardian.decode_and_verify(token)
    Logger.info "Refresh token. Old claims: #{inspect claims}"
    {:ok, _old_stuff, {new_token, new_claims}} = AuthProvider.Guardian.refresh(token)
    json(conn, %{"status" => "ok", "token" => new_token, "claims" => new_claims, "uid" => new_claims["sub"]})
  end

  ## MongooseIM API implementation
  #
  # https://esl.github.io/MongooseDocs/latest/authentication-methods/http/#authentication-service-api
  #

  def check_password(conn, %{"user" => _user, "server" => _server, "pass" => token} = _params) do
    case AuthProvider.Guardian.resource_from_token(token) do
      {:ok, _user, _claims} ->
        conn |> send_resp(200, "true")
      {:error, msg} ->
        Logger.warning "check_password warning: #{inspect msg}"
        conn |> send_resp(200, "false")
    end
  end

  def user_exists(conn, %{"user" => user, "server" => _server} = _params) do
    if is_nil(AuthProvider.UserHelper.find_user_by_msisdn(user)) do
      conn |> send_resp(200, "false")
    else
      conn |> send_resp(200, "true")
    end
  end
end
