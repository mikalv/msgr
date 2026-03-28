defmodule Messngr.Auth.Notifier.BulkSmsAdapter do
  @moduledoc """
  SMS delivery via BulkSMS eAPI (simple HTTP GET).
  """

  @behaviour Messngr.Auth.Notifier.SmsAdapter
  require Logger

  @api_url "https://bulksms.vsms.net/eapi/submission/send_sms/2/2.0"

  @impl true
  def deliver(target, code, _metadata) do
    config = Application.get_env(:msgr, __MODULE__, [])
    username = Keyword.fetch!(config, :username)
    password = Keyword.fetch!(config, :password)

    msisdn = target |> String.replace(~r/[^0-9]/, "")
    message = "Din Msgr-kode er #{code}. Gyldig i 10 minutter."

    url =
      "#{@api_url}?username=#{URI.encode_www_form(username)}" <>
        "&password=#{URI.encode_www_form(password)}" <>
        "&msisdn=#{msisdn}" <>
        "&message=#{URI.encode_www_form(message)}"

    case :hackney.request(:get, url, [], <<>>, [:with_body]) do
      {:ok, 200, _headers, body} ->
        case body |> String.split("|") |> List.first() do
          "0" ->
            Logger.info("BulkSMS delivered to #{target}")
            :ok

          error_code ->
            Logger.warning("BulkSMS error: #{body}")
            {:error, {:bulksms_error, error_code, body}}
        end

      {:ok, status, _headers, body} ->
        Logger.warning("BulkSMS HTTP #{status}: #{body}")
        {:error, {:bulksms_error, status, body}}

      {:error, reason} ->
        Logger.warning("BulkSMS request failed: #{inspect(reason)}")
        {:error, {:http_error, reason}}
    end
  end
end
