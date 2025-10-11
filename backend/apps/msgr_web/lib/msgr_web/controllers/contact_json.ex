defmodule MessngrWeb.ContactJSON do
  alias Messngr.Accounts.Contact

  def index(%{contacts: contacts}) do
    %{data: Enum.map(contacts, &contact/1)}
  end

  def lookup(%{matches: matches}) do
    %{data: Enum.map(matches, &lookup_entry/1)}
  end

  defp contact(%Contact{} = contact) do
    %{
      id: contact.id,
      name: contact.name,
      email: contact.email,
      phone_number: contact.phone_number,
      labels: contact.labels,
      metadata: contact.metadata,
      account_id: contact.account_id,
      profile_id: contact.profile_id
    }
  end

  defp lookup_entry(%{query: query, match: match}) do
    %{
      query: %{
        email: query[:email],
        phone_number: query[:phone_number]
      },
      match: maybe_match(match)
    }
  end

  defp maybe_match(nil), do: nil

  defp maybe_match(match) do
    %{
      account_id: match.account_id,
      account_name: match.account_name,
      identity_kind: match.identity_kind,
      identity_value: match.identity_value,
      profile: match.profile
    }
  end
end
