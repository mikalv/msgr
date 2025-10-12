defmodule MessngrWeb.AccountJSON do
  alias Messngr.Accounts.{Account, Profile}

  def index(%{accounts: accounts}) do
    %{data: Enum.map(accounts, &account/1)}
  end

  def show(%{account: account}) do
    %{data: account(account)}
  end

  defp account(%Account{} = account) do
    %{
      id: account.id,
      display_name: account.display_name,
      handle: account.handle,
      email: account.email,
      phone_number: account.phone_number,
      locale: account.locale,
      time_zone: account.time_zone,
      read_receipts_enabled: account.read_receipts_enabled,
      profiles: Enum.map(account.profiles, &profile/1)
    }
  end

  defp profile(%Profile{} = profile) do
    %{
      id: profile.id,
      name: profile.name,
      slug: profile.slug,
      mode: profile.mode,
      theme: profile.theme,
      notification_policy: profile.notification_policy,
      security_policy: profile.security_policy
    }
  end
end
