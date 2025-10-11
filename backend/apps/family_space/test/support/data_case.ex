defmodule FamilySpace.DataCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  using do
    quote do
      use Messngr.DataCase
    end
  end
end
