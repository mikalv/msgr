defmodule Messngr.Noise.SessionStoreTest do
  use Messngr.DataCase, async: true

  alias Messngr.Noise.SessionStore
  alias Messngr.Noise.SessionStore.Actor
  alias Messngr.Transport.Noise.Registry
  alias Messngr.Transport.Noise.Session

  setup do
    registry = start_supervised!({Registry, name: Module.concat(__MODULE__, Registry), ttl: 50})
    %{registry: registry}
  end

  describe "issue/2" do
    test "stores the session and actor metadata", %{registry: registry} do
      actor = %{
        account_id: Ecto.UUID.generate(),
        profile_id: Ecto.UUID.generate(),
        device_id: Ecto.UUID.generate(),
        device_public_key: Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
      }

      {:ok, session} = SessionStore.issue(actor, registry: registry)
      assert %Session{} = session
      assert {:ok, fetched, %Actor{} = stored_actor} = SessionStore.fetch(Session.token(session), registry: registry)
      assert fetched.id == session.id
      assert stored_actor.account_id == actor.account_id
      assert stored_actor.device_public_key == actor.device_public_key
    end
  end

  describe "register/3" do
    test "attaches actor metadata to an existing session", %{registry: registry} do
      session = Session.established_session(actor: %{account_id: Ecto.UUID.generate(), profile_id: Ecto.UUID.generate()})
      actor = %{
        account_id: Ecto.UUID.generate(),
        profile_id: Ecto.UUID.generate(),
        device_public_key: Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
      }

      assert {:ok, %Session{} = stored} = SessionStore.register(session, actor, registry: registry)
      {:ok, fetched, %Actor{} = stored_actor} = SessionStore.fetch(Session.token(stored), registry: registry)
      assert fetched.id == stored.id
      assert stored_actor.device_public_key == actor.device_public_key
      refute stored_actor.device_id
    end
  end

  describe "delete/2" do
    test "removes stored sessions", %{registry: registry} do
      actor = %{account_id: Ecto.UUID.generate(), profile_id: Ecto.UUID.generate()}
      {:ok, session} = SessionStore.issue(actor, registry: registry)
      token = Session.token(session)

      assert :ok = SessionStore.delete(token, registry: registry)
      assert :error = SessionStore.fetch(token, registry: registry)
    end
  end

  describe "token helpers" do
    test "encode/decode roundtrip" do
      raw = <<0, 1, 2, 255, 128>>
      encoded = SessionStore.encode_token(raw)
      assert encoded == Base.url_encode64(raw, padding: false)
      assert {:ok, ^raw} = SessionStore.decode_token(encoded)
    end

    test "decodes padded tokens" do
      raw = <<1, 2, 3, 4>>
      encoded = Base.encode64(raw)
      assert {:ok, ^raw} = SessionStore.decode_token(encoded)
    end

    test "returns error for malformed token" do
      assert :error = SessionStore.decode_token("%##broken")
    end
  end
end

