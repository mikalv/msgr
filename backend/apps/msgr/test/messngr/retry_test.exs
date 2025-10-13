defmodule Messngr.RetryTest do
  use Messngr.DataCase, async: true

  alias Messngr.Retry

  describe "run/2" do
    test "returns the function result when successful" do
      assert :ok = Retry.run(fn -> :ok end)
    end

    test "retries on transient DB connection errors" do
      {:ok, agent} = Agent.start_link(fn -> 0 end)

      result =
        Retry.run(fn ->
          attempt = Agent.get_and_update(agent, fn value -> {value + 1, value + 1} end)

          if attempt < 2 do
            raise DBConnection.ConnectionError.exception(message: "transient")
          else
            :done
          end
        end, backoff: 0, attempts: 3)

      assert :done = result
      assert Agent.get(agent, & &1) == 2
    end

    test "raises on permanent errors" do
      assert_raise RuntimeError, fn ->
        Retry.run(fn -> raise "boom" end, attempts: 2, backoff: 0)
      end
    end
  end
end
