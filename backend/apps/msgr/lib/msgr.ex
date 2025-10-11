defmodule Messngr do
  @moduledoc """
  Root namespace for domenelogikk. Gir helper-funksjoner slik at andre apps
  kan operere på kontoer, profiler og chatter uten å importere moduler direkte.
  """

  alias Messngr.Accounts
  alias Messngr.Auth
  alias Messngr.Chat
  alias Messngr.Family

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

  # Family
  defdelegate list_families(profile_id), to: Family
  defdelegate get_family!(id, opts \\ []), to: Family
  defdelegate create_family(owner_profile_id, attrs), to: Family
  defdelegate add_family_member(family_id, profile_id, role \\ :member), to: Family, as: :add_member
  defdelegate remove_family_member(family_id, profile_id), to: Family, as: :remove_member
  defdelegate ensure_family_membership(family_id, profile_id), to: Family, as: :ensure_membership
  defdelegate list_family_events(family_id, opts \\ []), to: Family, as: :list_events
  defdelegate get_family_event!(family_id, event_id), to: Family, as: :get_event!
  defdelegate create_family_event(family_id, profile_id, attrs), to: Family, as: :create_event
  defdelegate update_family_event(family_id, event_id, profile_id, attrs),
              to: Family,
              as: :update_event
  defdelegate delete_family_event(family_id, event_id, profile_id), to: Family, as: :delete_event
end
