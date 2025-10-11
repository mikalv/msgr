defmodule Messngr do
  @moduledoc """
  Root namespace for domenelogikk. Gir helper-funksjoner slik at andre apps
  kan operere på kontoer, profiler og chatter uten å importere moduler direkte.
  """

  alias Messngr.Accounts
  alias Messngr.Chat
  alias Messngr.Auth

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

  # Auth
  defdelegate start_auth_challenge(attrs), to: Auth, as: :start_challenge
  defdelegate verify_auth_challenge(id, code, attrs \\ %{}), to: Auth, as: :verify_challenge
  defdelegate complete_oidc(attrs), to: Auth
end
