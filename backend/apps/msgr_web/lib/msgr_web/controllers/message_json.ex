defmodule MessngrWeb.MessageJSON do
  alias Messngr.Chat.Message
  alias Messngr.Accounts.Profile

  def index(%{messages: messages}) do
    %{data: Enum.map(messages, &message/1)}
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
end
