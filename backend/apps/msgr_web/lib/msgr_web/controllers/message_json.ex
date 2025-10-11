defmodule MessngrWeb.MessageJSON do
  alias Messngr.Chat.Message
  alias Messngr.Accounts.Profile

  def index(%{page: %{entries: messages, meta: meta}}) do
    %{data: Enum.map(messages, &message/1), meta: cursor_meta(meta)}
  end

  def show(%{message: message}) do
    %{data: message(message)}
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

  defp cursor_meta(meta) do
    %{
      before_id: meta[:before_id],
      after_id: meta[:after_id],
      around_id: meta[:around_id],
      has_more: meta[:has_more]
    }
  end
end
