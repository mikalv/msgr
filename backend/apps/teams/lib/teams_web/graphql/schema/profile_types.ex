defmodule TeamsWeb.GraphQL.Schema.ProfileTypes do
  use Absinthe.Schema.Notation


  object :profile do
    field(:username, :string)
    field(:first_name, :string)
    field(:last_name, :string)
    field(:uid, :string)
    field(:status, :string)
    field(:avatar_url, :string)
    field(:inserted_at, :string)
    field(:updated_at, :string)
  end

end
