defmodule EdgeRouterTest do
  use ExUnit.Case
  doctest EdgeRouter

  test "greets the world" do
    assert EdgeRouter.hello() == :world
  end
end
