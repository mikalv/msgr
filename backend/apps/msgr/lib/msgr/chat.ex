defmodule Messngr.Chat do
  @moduledoc """
  Chat contexts for å opprette samtaler, legge til deltakere og sende meldinger.
  """

  import Ecto.Query

  alias Phoenix.PubSub

  alias Messngr.{Accounts, Repo}
  alias Messngr.Chat.{Conversation, Message, Participant}

  @conversation_topic_prefix "conversation"

  @spec create_direct_conversation(binary(), binary()) ::
          {:ok, Conversation.t()} | {:error, Ecto.Changeset.t()} | {:error, term()}
  def create_direct_conversation(profile_a_id, profile_b_id) do
    Repo.transaction(fn ->
      with {:ok, conversation} <- %Conversation{} |> Conversation.changeset(%{kind: :direct}) |> Repo.insert(),
           {:ok, _} <- add_participant(conversation, profile_a_id, :owner),
           {:ok, _} <- add_participant(conversation, profile_b_id, :member) do
        preload_conversation(conversation.id)
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  @spec add_participant(Conversation.t(), binary(), :member | :owner) ::
          {:ok, Participant.t()} | {:error, Ecto.Changeset.t()}
  def add_participant(%Conversation{id: conversation_id}, profile_id, role \\ :member) do
    %Participant{}
    |> Participant.changeset(%{conversation_id: conversation_id, profile_id: profile_id, role: role})
    |> Repo.insert()
  end

  @spec send_message(binary(), binary(), map()) :: {:ok, Message.t()} | {:error, Ecto.Changeset.t()} | {:error, term()}
  def send_message(conversation_id, profile_id, attrs) do
    Repo.transaction(fn ->
      _participant = ensure_participant!(conversation_id, profile_id)

      payload =
        attrs
        |> Map.put_new("conversation_id", conversation_id)
        |> Map.put_new("profile_id", profile_id)
        |> Map.put_new_lazy("sent_at", fn -> DateTime.utc_now() end)

      case %Message{} |> Message.changeset(payload) |> Repo.insert() do
        {:ok, message} -> Repo.preload(message, :profile)
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> case do
      {:ok, message} ->
        broadcast_message(message)
        {:ok, message}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec list_messages(binary(), keyword()) :: [Message.t()]
  def list_messages(conversation_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    before_id = Keyword.get(opts, :before_id)

    base_query =
      from m in Message,
        where: m.conversation_id == ^conversation_id,
        order_by: [desc: m.sent_at, desc: m.inserted_at]

    query = base_query |> maybe_before(before_id) |> limit(^limit)

    query
    |> Repo.all()
    |> Repo.preload(:profile)
    |> Enum.reverse()
  end

  defp preload_conversation(id) do
    Conversation
    |> Repo.get!(id)
    |> Repo.preload(participants: [:profile])
  end

  defp ensure_participant!(conversation_id, profile_id) do
    Repo.get_by!(Participant, conversation_id: conversation_id, profile_id: profile_id)
  end

  defp maybe_before(query, nil), do: query

  defp maybe_before(query, message_id) do
    case Repo.get(Message, message_id) do
      %Message{inserted_at: inserted_at} -> from m in query, where: m.inserted_at < ^inserted_at
      _ -> query
    end
  end

  @spec conversation_for_profiles(binary(), binary()) :: Conversation.t() | nil
  def conversation_for_profiles(profile_a_id, profile_b_id) do
    Repo.one(
      from c in Conversation,
        join: pa in assoc(c, :participants),
        join: pb in assoc(c, :participants),
        where:
          c.kind == :direct and pa.profile_id == ^profile_a_id and pb.profile_id == ^profile_b_id,
        preload: [participants: [:profile]]
    )
  end

  @spec ensure_direct_conversation(binary(), binary()) :: {:ok, Conversation.t()} | {:error, term()}
  def ensure_direct_conversation(profile_a_id, profile_b_id) do
    case conversation_for_profiles(profile_a_id, profile_b_id) do
      nil -> create_direct_conversation(profile_a_id, profile_b_id)
      conversation -> {:ok, conversation}
    end
  end

  @doc """
  Subscribe prosessen til PubSub-strømmen for en gitt samtale.
  """
  @spec subscribe_to_conversation(binary()) :: :ok | {:error, term()}
  def subscribe_to_conversation(conversation_id) do
    PubSub.subscribe(Messngr.PubSub, conversation_topic(conversation_id))
  end

  @doc false
  def broadcast_message(%Message{} = message) do
    PubSub.broadcast(
      Messngr.PubSub,
      conversation_topic(message.conversation_id),
      {:message_created, message}
    )

    :ok
  end

  @spec ensure_profile!(binary(), binary()) :: Accounts.Profile.t()
  def ensure_profile!(account_id, profile_id) do
    profile = Accounts.get_profile!(profile_id)

    if profile.account_id != account_id do
      raise ArgumentError, "profile does not belong to account"
    end

    profile
  end

  @spec ensure_membership(binary(), binary()) :: Participant.t()
  def ensure_membership(conversation_id, profile_id) do
    ensure_participant!(conversation_id, profile_id)
  end

  defp conversation_topic(conversation_id) do
    "#{@conversation_topic_prefix}:#{conversation_id}"
  end
end
