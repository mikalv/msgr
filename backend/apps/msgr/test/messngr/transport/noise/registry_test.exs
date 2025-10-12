defmodule Messngr.Transport.Noise.RegistryTest do
  use ExUnit.Case, async: false

  alias Messngr.Transport.Noise.Registry
  alias Messngr.Transport.Noise.Session
  alias Messngr.Transport.Noise.TestHelpers

  setup do
    %{registry: start_supervised!({Registry, ttl: 80, cleanup_interval: 20})}
  end

  describe "put/2 and fetch/2" do
    test "stores sessions by id and token", %{registry: registry} do
      session = established_session()

      {:ok, session} = Registry.put(registry, session)

      assert {:ok, ^session} = Registry.fetch(registry, session.id)
      assert {:ok, ^session} = Registry.fetch_by_token(registry, Session.token(session))
      assert Registry.count(registry) == 1

      updated_session = %{session | handshake_hash: <<"hash">>}
      {:ok, updated_session} = Registry.put(registry, updated_session)

      assert {:ok, ^updated_session} = Registry.fetch(registry, session.id)
      assert {:ok, ^updated_session} = Registry.fetch_by_token(registry, Session.token(updated_session))
      assert Registry.count(registry) == 1
    end
  end

  describe "touch/2" do
    test "extends TTL via token", %{registry: registry} do
      session = established_session()
      {:ok, session} = Registry.put(registry, session)

      Process.sleep(50)
      assert :ok = Registry.touch_by_token(registry, Session.token(session))

      Process.sleep(40)
      assert {:ok, _session} = Registry.fetch(registry, session.id)
    end
  end

  describe "expiry" do
    test "removes sessions once ttl elapses", %{registry: registry} do
      session = established_session()
      {:ok, session} = Registry.put(registry, session)

      assert Registry.count(registry) == 1
      Process.sleep(120)

      assert :error = Registry.fetch(registry, session.id)
      assert Registry.count(registry) == 0
    end
  end

  describe "delete/2" do
    test "removes sessions by token", %{registry: registry} do
      session = established_session()
      {:ok, session} = Registry.put(registry, session)

      assert :ok = Registry.delete_by_token(registry, Session.token(session))
      assert :error = Registry.fetch(registry, session.id)
      assert Registry.count(registry) == 0
    end
  end

  defp established_session(opts \\ []) do
    session = TestHelpers.build_session(:new, opts)
    client_state = TestHelpers.client_state(:nx)
    {session, _} = TestHelpers.handshake_pair(session, client_state)
    session
  end
end
