defmodule MessngrWeb.MessageJSON do
  alias Messngr.Chat.Message
  alias Messngr.Accounts.Profile

  def index(%{page: %{entries: entries, meta: meta}}) do
    %{data: Enum.map(entries, &message/1), meta: encode_meta(meta)}
  end

  def show(%{message: message}) do
    %{data: message(message)}
  end

  defp encode_meta(nil), do: %{start_cursor: nil, end_cursor: nil, has_more: %{before: false, after: false}}

  defp encode_meta(meta) when is_map(meta) do
    %{
      start_cursor: Map.get(meta, :start_cursor),
      end_cursor: Map.get(meta, :end_cursor),
      has_more: %{
        before: get_in(meta, [:has_more, :before]) || false,
        after: get_in(meta, [:has_more, :after]) || false
      }
    }
  end

  defp message(%Message{} = message) do
    %{
      id: message.id,
      type: message.kind |> to_string(),
      body: message.body,
      status: message.status,
      sent_at: message.sent_at,
      inserted_at: message.inserted_at,
      payload: message.payload || %{},
      profile: profile_payload(message.profile)
    }
  end

  defp profile_payload(%Profile{} = profile) do
    %{
      id: profile.id,
      name: profile.name,
      mode: profile.mode
    }
  end

  defp profile_payload(_), do: nil
end
