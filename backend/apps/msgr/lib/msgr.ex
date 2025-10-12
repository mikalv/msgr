defmodule Messngr do
  @moduledoc """
  Root namespace for domenelogikk. Gir helper-funksjoner slik at andre apps
  kan operere på kontoer, profiler og chatter uten å importere moduler direkte.
  """

  alias Messngr.{AI, Accounts, Auth, Chat, Media}

  # Accounts
  defdelegate list_accounts, to: Accounts
  defdelegate get_account!(id), to: Accounts
  defdelegate create_account(attrs), to: Accounts
  defdelegate create_profile(attrs), to: Accounts
  defdelegate list_profiles(account_id), to: Accounts
  defdelegate get_profile!(id), to: Accounts
  defdelegate list_devices(account_id), to: Accounts
  defdelegate get_device!(id), to: Accounts
  defdelegate create_device(attrs), to: Accounts
  defdelegate update_device(device, attrs), to: Accounts
  defdelegate delete_device(device), to: Accounts
  defdelegate activate_device(device), to: Accounts
  defdelegate deactivate_device(device), to: Accounts

  def import_contacts(account_id, contacts_attrs, opts \\ []) do
    Accounts.import_contacts(account_id, contacts_attrs, opts)
  end

  def lookup_known_contacts(targets) do
    Accounts.lookup_known_contacts(targets)
  end

  # Chat
  defdelegate ensure_direct_conversation(profile_a_id, profile_b_id), to: Chat
  def create_group_conversation(owner_profile_id, participant_ids, attrs \\ %{}) do
    Chat.create_group_conversation(owner_profile_id, participant_ids, attrs)
  end

  def create_channel_conversation(owner_profile_id, attrs \\ %{}) do
    Chat.create_channel_conversation(owner_profile_id, attrs)
  end
  defdelegate send_message(conversation_id, profile_id, attrs), to: Chat
  def list_messages(conversation_id, opts \\ []), do: Chat.list_messages(conversation_id, opts)
  def react_to_message(conversation_id, profile_id, message_id, emoji, opts \\ %{}) do
    Chat.react_to_message(conversation_id, profile_id, message_id, emoji, opts)
  end

  def remove_reaction(conversation_id, profile_id, message_id, emoji) do
    Chat.remove_reaction(conversation_id, profile_id, message_id, emoji)
  end

  def pin_message(conversation_id, profile_id, message_id, opts \\ %{}) do
    Chat.pin_message(conversation_id, profile_id, message_id, opts)
  end

  def unpin_message(conversation_id, profile_id, message_id) do
    Chat.unpin_message(conversation_id, profile_id, message_id)
  end

  def mark_message_read(conversation_id, profile_id, message_id, opts \\ %{}) do
    Chat.mark_message_read(conversation_id, profile_id, message_id, opts)
  end

  def acknowledge_message_delivery(conversation_id, profile_id, message_id, opts \\ %{}) do
    Chat.acknowledge_message_delivery(conversation_id, profile_id, message_id, opts)
  end

  def update_message(conversation_id, profile_id, message_id, attrs) do
    Chat.update_message(conversation_id, profile_id, message_id, attrs)
  end

  def delete_message(conversation_id, profile_id, message_id, opts \\ %{}) do
    Chat.delete_message(conversation_id, profile_id, message_id, opts)
  end
  def list_conversations(profile_id, opts \\ []), do: Chat.list_conversations(profile_id, opts)
  defdelegate ensure_membership(conversation_id, profile_id), to: Chat
  defdelegate watch_conversation(conversation_id, profile_id), to: Chat
  defdelegate unwatch_conversation(conversation_id, profile_id), to: Chat
  defdelegate list_watchers(conversation_id), to: Chat
  defdelegate broadcast_backlog(conversation_id, page), to: Chat
  defdelegate create_media_upload(conversation_id, profile_id, attrs), to: Media, as: :create_upload

  # AI
  defdelegate ai_chat(team_id, messages, opts \\ []), to: AI, as: :chat
  defdelegate ai_summarize(team_id, text, opts \\ []), to: AI, as: :summarize
  defdelegate ai_conversation_reply(team_id, conversation_id, profile, opts \\ []),
    to: AI,
    as: :conversation_reply

  defdelegate ai_run_prompt(team_id, prompt, opts \\ []), to: AI, as: :run_prompt

  # Auth
  defdelegate start_auth_challenge(attrs), to: Auth, as: :start_challenge
  defdelegate verify_auth_challenge(id, code, attrs \\ %{}), to: Auth, as: :verify_challenge
  defdelegate complete_oidc(attrs), to: Auth

end
