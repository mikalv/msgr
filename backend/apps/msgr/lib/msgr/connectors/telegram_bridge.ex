# credo:disable-for-this-file Credo.Check.Readability.Specs

defmodule Msgr.Connectors.TelegramBridge do
  @moduledoc """
  Connector facade for Telegram bridge daemons.

  The Elixir side only understands how to describe intents. The actual network
  traffic flows through a separate worker (Go, Python, etc.) that speaks the
  proprietary MTProto stack and reports back via the message queue.
  """

  alias Msgr.Connectors.ServiceBridge
  alias Messngr.Bridges

  @type bridge :: ServiceBridge.t()

  @spec new(keyword()) :: bridge()
  def new(opts), do: ServiceBridge.new(:telegram, opts)

  @doc """
  Initiates the out-of-band linking ceremony for a Telegram account.

  The payload delegates MTProto negotiations to the bridge worker which can be
  implemented in whichever language is most convenient.
  """
  @spec link_account(bridge(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def link_account(bridge, params, opts \\ []) do
    payload = Map.take(params, [:user_id, :phone_number, :session, :two_factor])

    case ServiceBridge.request(bridge, :link_account, payload, opts) do
      {:ok, response} ->
        case persist_link_response(bridge, params, response) do
          :ok -> {:ok, response}
          {:error, reason} -> {:error, reason}
        end

      other ->
        other
    end
  end

  @doc """
  Emits an outbound message intent for Telegram chats.
  """
  @spec send_message(bridge(), map(), keyword()) :: :ok | {:error, term()}
  def send_message(bridge, params, opts \\ []) do
    payload =
      params
      |> Map.take([:chat_id, :message, :entities, :reply_to, :media])
      |> Map.put_new(:metadata, Map.get(params, :metadata, %{}))

    ServiceBridge.publish(bridge, :outbound_message, payload, opts)
  end

  @doc """
  Acknowledges updates once the Elixir core has persisted them.
  """
  @spec ack_update(bridge(), map(), keyword()) :: :ok | {:error, term()}
  def ack_update(bridge, params, opts \\ []) do
    payload = Map.take(params, [:update_id, :status, :received_at])
    ServiceBridge.publish(bridge, :ack_update, payload, opts)
  end

  defp persist_link_response(%ServiceBridge{} = bridge, params, response) do
    status = Map.get(response, "status") || Map.get(response, :status)

    with :linked <- normalise_status(status),
         {:ok, account_id} <- fetch_account_id(params),
         attrs <- build_sync_attrs(response) do
      Bridges.sync_linked_identity(account_id, bridge.service, attrs)
      |> case do
        {:ok, _} -> :ok
        {:error, reason} -> {:error, reason}
      end
    else
      :skip -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalise_status(status) when status in ["linked", :linked], do: :linked
  defp normalise_status(_other), do: :skip

  defp fetch_account_id(params) when is_map(params) do
    params
    |> Map.get(:user_id) || Map.get(params, "user_id")
    |> case do
      nil -> {:error, :missing_account_id}
      value when is_binary(value) and value != "" -> {:ok, value}
      value -> {:error, {:invalid_account_id, value}}
    end
  end

  defp build_sync_attrs(response) when is_map(response) do
    user = Map.get(response, "user") || Map.get(response, :user) || %{}
    session = Map.get(response, "session") || Map.get(response, :session) || %{}
    capabilities = Map.get(response, "capabilities") || Map.get(response, :capabilities) || %{}

    contacts =
      response
      |> Map.get("contacts") || Map.get(response, :contacts) || []

    chats =
      response
      |> Map.get("chats") || Map.get(response, :chats) || []

    %{
      external_id: extract_user_id(user),
      display_name: extract_display_name(user),
      metadata: %{"user" => stringify_keys(user)},
      session: ensure_map(session),
      capabilities: ensure_map(capabilities),
      contacts: ensure_list(contacts),
      channels: ensure_list(chats)
    }
  end

  defp extract_user_id(user) do
    cond do
      is_map(user) and Map.has_key?(user, "id") -> to_string(user["id"])
      is_map(user) and Map.has_key?(user, :id) -> to_string(user[:id])
      true -> nil
    end
  end

  defp extract_display_name(user) when is_map(user) do
    username = Map.get(user, "username") || Map.get(user, :username)
    first = Map.get(user, "first_name") || Map.get(user, :first_name)
    last = Map.get(user, "last_name") || Map.get(user, :last_name)

    display =
      [first, last]
      |> Enum.filter(&(is_binary(&1) and &1 != ""))
      |> Enum.join(" ")

    cond do
      display != "" -> display
      is_binary(username) and username != "" -> username
      true -> extract_user_id(user)
    end
  end

  defp extract_display_name(_user), do: nil

  defp ensure_map(value) when is_map(value), do: value
  defp ensure_map(_), do: %{}

  defp ensure_list(value) when is_list(value), do: value
  defp ensure_list(_), do: []

  defp stringify_keys(map) when is_map(map) do
    map
    |> Enum.map(fn
      {key, value} when is_binary(key) -> {key, value}
      {key, value} when is_atom(key) -> {Atom.to_string(key), value}
      {key, value} -> {to_string(key), value}
    end)
    |> Map.new()
  end

  defp stringify_keys(_), do: %{}
end
