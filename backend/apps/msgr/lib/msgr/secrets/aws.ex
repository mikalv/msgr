defmodule Messngr.Secrets.Aws do
  @moduledoc """
  Minimal AWS Secrets Manager client that performs a signed `GetSecretValue`
  request using Erlang's `:httpc`.

  The module expects the following keys in `opts`:

    * `:region` - AWS region (e.g. "eu-north-1")
    * `:access_key_id` - AWS access key ID (defaults to `AWS_ACCESS_KEY_ID` env)
    * `:secret_access_key` - AWS secret access key (defaults to `AWS_SECRET_ACCESS_KEY` env)
    * `:session_token` - Optional session token (defaults to `AWS_SESSION_TOKEN` env)

  The returned payload matches the shape returned by AWS: a map containing either
  `"SecretString"` or `"SecretBinary"`.
  """

  @behaviour Messngr.Secrets.Manager

  @impl true
  def fetch(secret_id, opts \\ []) do
    region = Keyword.get(opts, :region) || System.get_env("AWS_REGION")

    with {:ok, region} when is_binary(region) <- validate_region(region),
         {:ok, credentials} <- credentials(opts),
         {:ok, body} <- request(secret_id, region, credentials) do
      {:ok, body}
    end
  end

  defp validate_region(nil), do: {:error, :missing_region}
  defp validate_region(region) when region == "", do: {:error, :missing_region}
  defp validate_region(region), do: {:ok, region}

  defp credentials(opts) do
    access_key_id = Keyword.get(opts, :access_key_id) || System.get_env("AWS_ACCESS_KEY_ID")
    secret_access_key =
      Keyword.get(opts, :secret_access_key) || System.get_env("AWS_SECRET_ACCESS_KEY")

    session_token = Keyword.get(opts, :session_token) || System.get_env("AWS_SESSION_TOKEN")

    cond do
      is_nil(access_key_id) or access_key_id == "" -> {:error, :missing_access_key_id}
      is_nil(secret_access_key) or secret_access_key == "" ->
        {:error, :missing_secret_access_key}
      true ->
        {:ok,
         %{
           access_key_id: access_key_id,
           secret_access_key: secret_access_key,
           session_token: session_token
         }}
    end
  end

  defp request(secret_id, region, creds) do
    payload = Jason.encode!(%{"SecretId" => secret_id})
    host = "secretsmanager.#{region}.amazonaws.com"
    amz_date = amz_timestamp()
    datestamp = String.slice(amz_date, 0, 8)

    canonical_headers =
      canonical_headers(
        host,
        amz_date,
        creds.session_token,
        "application/x-amz-json-1.1",
        "secretsmanager.GetSecretValue"
      )

    signed_headers =
      signed_headers(creds.session_token)

    payload_hash = sha256_hexdigest(payload)

    canonical_request =
      [
        "POST\n",
        "/\n",
        "\n",
        canonical_headers,
        "\n",
        signed_headers,
        "\n",
        payload_hash
      ]
      |> IO.iodata_to_binary()

    string_to_sign = build_string_to_sign(canonical_request, amz_date, datestamp, region)

    signature = sign(creds.secret_access_key, datestamp, region, string_to_sign)

    authorization =
      "AWS4-HMAC-SHA256 Credential=#{creds.access_key_id}/#{datestamp}/#{region}/secretsmanager/aws4_request, " <>
        "SignedHeaders=#{signed_headers}, Signature=#{signature}"

    headers =
      [
        {"host", host},
        {"content-type", "application/x-amz-json-1.1"},
        {"x-amz-date", amz_date},
        {"x-amz-target", "secretsmanager.GetSecretValue"},
        {"authorization", authorization}
      ]
      |> maybe_add_session_token(creds.session_token)

    :inets.start()
    :ssl.start()

    url = 'https://' ++ to_charlist(host) ++ '/'
    body = payload

    case :httpc.request(:post, {url, headers, 'application/x-amz-json-1.1', body}, [], []) do
      {:ok, {{_, 200, _}, response_headers, response_body}} ->
        {:ok, decode_body(response_headers, response_body)}

      {:ok, {{_, status, _}, _headers, response_body}} ->
        {:error, {:http_error, status, response_body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp canonical_headers(host, amz_date, session_token, content_type, target) do
    base = [
      "content-type:", content_type, "\n",
      "host:", host, "\n",
      "x-amz-date:", amz_date, "\n",
      "x-amz-target:", target, "\n"
    ]

    case session_token do
      nil -> IO.iodata_to_binary(base)
      "" -> IO.iodata_to_binary(base)
      token -> IO.iodata_to_binary(base ++ ["x-amz-security-token:", token, "\n"])
    end
  end

  defp signed_headers(session_token) when session_token in [nil, ""],
    do: "content-type;host;x-amz-date;x-amz-target"

  defp signed_headers(_session_token),
    do: "content-type;host;x-amz-date;x-amz-security-token;x-amz-target"

  defp build_string_to_sign(canonical_request, amz_date, datestamp, region) do
    hashed_request = sha256_hexdigest(canonical_request)

    IO.iodata_to_binary([
      "AWS4-HMAC-SHA256\n",
      amz_date,
      "\n",
      datestamp,
      "/",
      region,
      "/secretsmanager/aws4_request\n",
      hashed_request
    ])
  end

  defp sign(secret_access_key, datestamp, region, string_to_sign) do
    k_date = hmac("AWS4" <> secret_access_key, datestamp)
    k_region = hmac(k_date, region)
    k_service = hmac(k_region, "secretsmanager")
    k_signing = hmac(k_service, "aws4_request")

    string_to_sign
    |> hmac(k_signing)
    |> Base.encode16(case: :lower)
  end

  defp hmac(key, data), do: :crypto.mac(:hmac, :sha256, key, data)

  defp sha256_hexdigest(data) do
    :crypto.hash(:sha256, data)
    |> Base.encode16(case: :lower)
  end

  defp amz_timestamp do
    DateTime.utc_now()
    |> DateTime.truncate(:second)
    |> Calendar.strftime("%Y%m%dT%H%M%SZ")
  end

  defp maybe_add_session_token(headers, session_token) when session_token in [nil, ""],
    do: headers

  defp maybe_add_session_token(headers, session_token),
    do: headers ++ [{"x-amz-security-token", session_token}]

  defp decode_body(headers, body) do
    headers_map =
      headers
      |> Enum.map(fn {k, v} -> {String.downcase(to_string(k)), to_string(v)} end)
      |> Map.new()

    raw_body =
      case Map.get(headers_map, "content-encoding") do
        "gzip" -> :zlib.gunzip(body)
        _ -> body
      end

    Jason.decode!(to_string(raw_body))
  end
end
