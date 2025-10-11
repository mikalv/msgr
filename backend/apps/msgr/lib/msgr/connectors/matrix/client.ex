defmodule Messngr.Connectors.Matrix.Client do
  @moduledoc """
  Thin wrapper around the Matrix Client-Server API focused on the endpoints
  required for the first integration milestones.

  Supported flows:

    * Password based login to exchange credentials for an access token.
    * Syncing incremental updates so that Msgr can mirror Matrix rooms.
    * Sending room events (defaulting to `m.room.message`).
  """

  alias Finch.Response

  @type request_opt :: {:finch, atom()} | {:base_url, String.t()}
  @type login_opt :: request_opt()
  @type sync_opt :: request_opt()
  @type event_opt :: request_opt() | {:event_type, String.t()} | {:txn_id, String.t()}
  @default_base_url "https://matrix-client.matrix.org"

  @login_path "/_matrix/client/v3/login"
  @sync_path "/_matrix/client/v3/sync"

  @doc """
  Performs password based login.

  Returns the decoded JSON response from Matrix which includes the access token
  and device metadata on success.
  """
  @spec login(String.t(), String.t(), [login_opt()]) :: {:ok, map()} | {:error, term()}
  def login(username, password, opts \\ []) do
    base_url = Keyword.get(opts, :base_url, @default_base_url)

    payload = %{
      "type" => "m.login.password",
      "identifier" => %{"type" => "m.id.user", "user" => username},
      "password" => password
    }

    request(:post, base_url <> @login_path, payload, opts)
  end

  @doc """
  Fetches incremental sync data.

  `params` is a map that mirrors the query parameters accepted by `/_matrix/client/v3/sync`.
  """
  @spec sync(String.t(), map(), [sync_opt()]) :: {:ok, map()} | {:error, term()}
  def sync(access_token, params \\ %{}, opts \\ []) do
    base_url = Keyword.get(opts, :base_url, @default_base_url)

    query =
      params
      |> Map.take(["since", "timeout", "full_state", "set_presence"])
      |> Map.merge(Map.take(params, [:since, :timeout, :full_state, :set_presence]))
      |> Enum.into(%{})
      |> Map.put_new("timeout", params[:timeout] || params["timeout"])
      |> normalize_params()
      |> Map.put("access_token", access_token)
      |> URI.encode_query()

    request(:get, base_url <> @sync_path <> "?" <> query, %{}, opts)
  end

  @doc """
  Sends an event to a room. Defaults to an `m.room.message` with a generated
  transaction id when one is not provided.
  """
  @spec send_event(String.t(), String.t(), map(), [event_opt()]) :: {:ok, map()} | {:error, term()}
  def send_event(access_token, room_id, content, opts \\ []) do
    base_url = Keyword.get(opts, :base_url, @default_base_url)
    event_type = Keyword.get(opts, :event_type, "m.room.message")
    txn_id = Keyword.get(opts, :txn_id, UUID.uuid4())

    encoded_room_id = URI.encode(room_id, &URI.char_unreserved?/1)

    url =
      base_url <>
        "/_matrix/client/v3/rooms/" <> encoded_room_id <> "/send/" <> event_type <> "/" <> txn_id <>
        "?access_token=" <> URI.encode_www_form(access_token)

    request(:put, url, content, opts)
  end

  defp request(method, url, payload, opts) do
    finch = Keyword.get(opts, :finch, Messngr.Finch)

    request =
      case method do
        :get -> Finch.build(:get, url, [])
        :post -> Finch.build(:post, url, headers(), Jason.encode!(payload))
        :put -> Finch.build(:put, url, headers(), Jason.encode!(payload))
      end

    with {:ok, %Response{status: status} = response} <- Finch.request(request, finch),
         {:ok, decoded} <- decode_body(response.body) do
      case status do
        status when status in 200..299 -> {:ok, decoded}
        status -> {:error, {:http_error, status, decoded}}
      end
    else
      {:error, _} = error -> error
      {:decode_error, reason} -> {:error, {:decode_error, reason}}
    end
  end

  defp headers do
    [{"content-type", "application/json"}]
  end

  defp decode_body(""), do: {:ok, %{}}

  defp decode_body(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> {:ok, decoded}
      {:error, reason} -> {:decode_error, reason}
    end
  end

  defp normalize_params(params) do
    Enum.reduce(params, %{}, fn {key, value}, acc ->
      cond do
        is_nil(value) -> acc
        true -> Map.put(acc, normalize_key(key), value)
      end
    end)
  end

  defp normalize_key(key) when is_binary(key), do: key
  defp normalize_key(key) when is_atom(key), do: Atom.to_string(key)
end
