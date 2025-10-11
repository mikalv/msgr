defmodule SlackApi.SlackId do
  @moduledoc """
  Deterministic helpers for encoding internal UUIDs to Slack-like identifiers.
  """

  alias Messngr.Accounts.{Account, Profile}
  alias Messngr.Chat.{Conversation, Message}

  @type conversation_kind :: :channel | :group | :direct

  @doc """
  Encodes a conversation struct or tuple to a Slack-style channel ID.
  """
  @spec conversation(Conversation.t() | {conversation_kind(), binary()}) :: String.t()
  def conversation(%Conversation{kind: kind, id: id}), do: conversation({kind, id})

  def conversation({kind, id}) when kind in [:channel, :group, :direct] and is_binary(id) do
    prefix =
      case kind do
        :channel -> "C"
        :group -> "G"
        :direct -> "D"
      end

    prefix <> Base.url_encode64(id, padding: false)
  end

  @doc """
  Decodes a Slack-style channel ID to its kind and UUID.
  """
  @spec decode_conversation(String.t()) :: {:ok, {conversation_kind(), binary()}} | :error
  def decode_conversation(<<prefix::binary-size(1), rest::binary>>) do
    with {:ok, kind} <- conversation_kind_from_prefix(prefix),
         {:ok, id} <- decode_id(rest) do
      {:ok, {kind, id}}
    end
  end

  def decode_conversation(_), do: :error

  @doc """
  Encodes a profile to a Slack user ID.
  """
  @spec profile(Profile.t() | binary()) :: String.t()
  def profile(%Profile{id: id}), do: profile(id)
  def profile(id) when is_binary(id), do: "U" <> Base.url_encode64(id, padding: false)

  @doc """
  Decodes a Slack user ID.
  """
  @spec decode_profile(String.t()) :: {:ok, binary()} | :error
  def decode_profile("U" <> rest), do: decode_id(rest)
  def decode_profile(_), do: :error

  @doc """
  Encodes an account to a Slack team/workspace ID.
  """
  @spec team(Account.t() | binary()) :: String.t()
  def team(%Account{id: id}), do: team(id)
  def team(id) when is_binary(id), do: "T" <> Base.url_encode64(id, padding: false)

  @doc """
  Decodes a Slack team ID back to the UUID.
  """
  @spec decode_team(String.t()) :: {:ok, binary()} | :error
  def decode_team("T" <> rest), do: decode_id(rest)
  def decode_team(_), do: :error

  @doc """
  Encodes a message struct into a cursor token.
  """
  @spec message_cursor(Message.t() | binary()) :: String.t()
  def message_cursor(%Message{id: id}), do: message_cursor(id)
  def message_cursor(nil), do: nil
  def message_cursor(id) when is_binary(id), do: Base.url_encode64(id, padding: false)

  @doc """
  Decodes a message cursor token back to the message UUID.
  """
  @spec decode_message_cursor(String.t() | nil) :: {:ok, binary()} | :error
  def decode_message_cursor(nil), do: :error

  def decode_message_cursor(token) when is_binary(token) and token != "" do
    decode_id(token)
  end

  def decode_message_cursor(_), do: :error

  @doc """
  Encodes a generic cursor from a UUID.
  """
  @spec cursor(binary() | nil) :: String.t() | nil
  def cursor(nil), do: nil
  def cursor(id) when is_binary(id), do: Base.url_encode64(id, padding: false)

  @doc """
  Decodes a generic cursor token to the original UUID.
  """
  @spec decode_cursor(String.t() | nil) :: {:ok, binary()} | :error
  def decode_cursor(nil), do: :error

  def decode_cursor(token) when is_binary(token) and token != "" do
    decode_id(token)
  end

  def decode_cursor(_), do: :error

  defp decode_id(token) do
    case Base.url_decode64(token, padding: false) do
      {:ok, id} -> {:ok, id}
      :error -> :error
    end
  end

  defp conversation_kind_from_prefix("C"), do: {:ok, :channel}
  defp conversation_kind_from_prefix("G"), do: {:ok, :group}
  defp conversation_kind_from_prefix("D"), do: {:ok, :direct}
  defp conversation_kind_from_prefix(_), do: :error
end
