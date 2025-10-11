defmodule MessngrWeb.FamilyJSON do
  alias Messngr.Accounts.Profile
  alias Messngr.Family.{Family, Membership}

  def index(%{families: families}) do
    %{data: Enum.map(families, &family/1)}
  end

  def show(%{family: family}) do
    %{data: family(family)}
  end

  defp family(%Family{} = family) do
    %{
      id: family.id,
      name: family.name,
      slug: family.slug,
      time_zone: family.time_zone,
      memberships: Enum.map(family.memberships, &membership/1)
    }
  end

  defp membership(%Membership{} = membership) do
    %{
      id: membership.id,
      role: membership.role,
      profile: profile(membership.profile)
    }
  end

  defp profile(%Profile{} = profile) do
    %{id: profile.id, name: profile.name, slug: profile.slug}
  end
end
