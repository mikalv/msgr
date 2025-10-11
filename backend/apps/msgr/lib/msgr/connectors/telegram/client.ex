defmodule Messngr.Connectors.Telegram.Client do
  @moduledoc """
  Minimal HTTP client for the Telegram Bot API.

  The client focuses on the primitives we need to start bridging traffic:

    * Fetching updates so that inbound messages can be ingested into Msgr.
    * Sending messages while impersonating the linked Telegram identity.

  The module is intentionally stateless. Callers are expected to provide the
  access token that was granted during account linking along with any
  per-request options they need (parse mode, reply markup, etc.).
  """

  alias Finch.Response

  @type token :: String.t()
  @type chat_id :: integer() | String.t()
  @type request_opt :: {:finch, atom()} | {:base_url, String.t()}
  @type send_opt ::
          request_opt()
          | {:parse_mode, String.t()}
          | {:disable_notification, boolean()}
          | {:reply_markup, map()}
          | {:reply_to_message_id, integer()}
  @type update_opt ::
          request_opt()
          | {:offset, integer()}
          | {:limit, integer()}
          | {:timeout, integer()}
          | {:allowed_updates, [String.t()]}

  @default_base_url "https://api.telegram.org"

  @doc """
  Fetches updates using the bot access token.

  Only the documented options are supported to keep the API narrow while we
  build out the ingestion pipeline. The response body is decoded JSON and
  returned as `{:ok, map}` when the request is successful.
  """
  @spec get_updates(token(), [update_opt()]) :: {:ok, map()} | {:error, term()}
  def get_updates(token, opts \\ []) do
    query_params =
      opts
      |> Keyword.take([:offset, :limit, :timeout])
      |> Enum.reduce(%{}, fn {key, value}, acc -> Map.put(acc, Atom.to_string(key), value) end)
      |> maybe_put_allowed_updates(opts)

    request(:get, token, "/getUpdates", query_params, opts)
  end

  @doc """
  Sends a message to the provided chat.

  The payload supports a subset of fields that cover the vast majority of
  conversational use-cases. Additional options can be wired in as we expand the
  bridge capabilities.
  """
  @spec send_message(token(), chat_id(), String.t(), [send_opt()]) :: {:ok, map()} | {:error, term()}
  def send_message(token, chat_id, text, opts \\ []) do
    payload =
      opts
      |> Keyword.take([:parse_mode, :disable_notification, :reply_markup, :reply_to_message_id])
      |> Enum.reduce(%{"chat_id" => chat_id, "text" => text}, fn {key, value}, acc ->
        Map.put(acc, Atom.to_string(key), value)
      end)

    request(:post, token, "/sendMessage", payload, opts)
  end

  defp maybe_put_allowed_updates(params, opts) do
    case Keyword.get(opts, :allowed_updates) do
      nil -> params
      updates when is_list(updates) -> Map.put(params, "allowed_updates", Jason.encode!(updates))
    end
  end

  defp request(method, token, path, payload, opts) do
    finch = Keyword.get(opts, :finch, Messngr.Finch)
    base_url = Keyword.get(opts, :base_url, @default_base_url)
    url = build_url(base_url, token, path, method, payload)

    request =
      case method do
        :get ->
          Finch.build(:get, url, [])

        :post ->
          Finch.build(:post, url, [{"content-type", "application/json"}], Jason.encode!(payload))
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

  defp build_url(base_url, token, path, :get, params) do
    query = URI.encode_query(params)
    base_url <> "/bot" <> token <> path <> maybe_append_query(query)
  end

  defp build_url(base_url, token, path, :post, _params) do
    base_url <> "/bot" <> token <> path
  end

  defp maybe_append_query(""), do: ""
  defp maybe_append_query(query), do: "?" <> query

  defp decode_body(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> {:ok, decoded}
      {:error, reason} -> {:decode_error, reason}
    end
  end
end
