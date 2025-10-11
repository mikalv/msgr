defmodule Messngr do
  @moduledoc """
  Root namespace for domenelogikk. Gir helper-funksjoner slik at andre apps
  kan operere på kontoer, profiler og chatter uten å importere moduler direkte.
  """

  alias Messngr.{AI, Accounts, Auth, Chat}

  # Accounts
  defdelegate list_accounts, to: Accounts
  defdelegate get_account!(id), to: Accounts
  defdelegate create_account(attrs), to: Accounts
  defdelegate create_profile(attrs), to: Accounts
  defdelegate list_profiles(account_id), to: Accounts
  defdelegate get_profile!(id), to: Accounts

  # Chat
  defdelegate ensure_direct_conversation(profile_a_id, profile_b_id), to: Chat
  defdelegate send_message(conversation_id, profile_id, attrs), to: Chat
  def list_messages(conversation_id, opts \\ []), do: Chat.list_messages(conversation_id, opts)
  defdelegate ensure_membership(conversation_id, profile_id), to: Chat

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
