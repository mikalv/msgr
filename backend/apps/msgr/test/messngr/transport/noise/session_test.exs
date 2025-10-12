defmodule Messngr.Transport.Noise.SessionTest do
  use ExUnit.Case, async: true

  alias Messngr.Transport.Noise.Session
  alias Messngr.Transport.Noise.TestHelpers

  describe "new_device/1" do
    test "completes NX handshake and exchanges ciphertext" do
      session = TestHelpers.build_session(:new)
      client_state = TestHelpers.client_state(:nx)

      {session, client_split} = TestHelpers.handshake_pair(session, client_state)

      assert Session.established?(session)
      assert session.current_pattern == :nx
      assert byte_size(Session.token(session)) == session.token_bytes
      assert Session.remote_static(session) == TestHelpers.client_public()

      {:ok, ciphertext, session_after_encrypt} = Session.encrypt(session, "hello noise")
      session = session_after_encrypt
      {:ok, plaintext, client_split} = TestHelpers.decrypt_client(client_split, ciphertext)
      assert plaintext == "hello noise"

      {:ok, reply_cipher, client_split} = TestHelpers.encrypt_client(client_split, "reply")
      {:ok, reply_plain, session_after_decrypt} = Session.decrypt(session, reply_cipher)
      session = session_after_decrypt
      assert reply_plain == "reply"

      {:ok, ciphertext, session_after_second} = Session.encrypt(session, "second")
      session = session_after_second
      {:ok, roundtrip, _client_split} = TestHelpers.decrypt_client(client_split, ciphertext)
      assert roundtrip == "second"
    end
  end

  describe "known_device/1" do
    test "performs IK handshake when the static key matches" do
      session =
        TestHelpers.build_session(:known,
          remote_static: TestHelpers.client_public()
        )

      client_state = TestHelpers.client_state(:ik)

      {session, _client_split} = TestHelpers.handshake_pair(session, client_state)

      assert Session.established?(session)
      assert session.current_pattern == :ik
      assert Session.remote_static(session) == TestHelpers.client_public()
    end

    test "falls back to XX when IK cannot decrypt the payload" do
      rotated = TestHelpers.rotated_client_static()

      session =
        TestHelpers.build_session(:known,
          remote_static: TestHelpers.client_public(),
          token_bytes: 16
        )

      client_state =
        TestHelpers.client_state(:xx,
          client_static: rotated
        )

      {session, _client_split} = TestHelpers.handshake_pair(session, client_state)

      assert Session.established?(session)
      assert session.current_pattern == :xx
      assert Session.remote_static(session) == TestHelpers.client_public(rotated)
      assert byte_size(Session.token(session)) == 16
    end
  end

  describe "rekey/2" do
    test "rekeys both cipher states" do
      session =
        TestHelpers.build_session(:known,
          remote_static: TestHelpers.client_public()
        )

      client_state = TestHelpers.client_state(:ik)
      {session, client_split} = TestHelpers.handshake_pair(session, client_state)

      {:ok, session_after_rekey} = Session.rekey(session, :tx)
      session = session_after_rekey
      client_split = TestHelpers.rekey_client(client_split, :rx)

      {:ok, ciphertext, session_after_encrypt} = Session.encrypt(session, "after-rekey")
      session = session_after_encrypt
      {:ok, plaintext, client_split} = TestHelpers.decrypt_client(client_split, ciphertext)
      assert plaintext == "after-rekey"

      {:ok, session_after_rekey} = Session.rekey(session, :both)
      session = session_after_rekey
      client_split = TestHelpers.rekey_client(client_split, :both)

      {:ok, ciphertext, session_after_second} = Session.encrypt(session, "second-rekey")
      session = session_after_second
      {:ok, plaintext, _client_split} = TestHelpers.decrypt_client(client_split, ciphertext)
      assert plaintext == "second-rekey"
    end
  end

  describe "token generation" do
    test "honours custom generator and size" do
      token_fun = fn size -> <<size::32, :binary.copy(<<0>>, max(size - 4, 0))::binary>> end

      session =
        TestHelpers.build_session(:new,
          token_bytes: 20,
          token_generator: token_fun
        )

      client_state = TestHelpers.client_state(:nx)
      {session, _} = TestHelpers.handshake_pair(session, client_state)

      token = Session.token(session)
      assert byte_size(token) == 20
      <<size::32, _::binary>> = token
      assert size == 20
    end

    test "property: default generator emits tokens of configured length" do
      tokens =
        Enum.map(1..5, fn _ ->
          session = TestHelpers.build_session(:new, token_bytes: 24)
          client_state = TestHelpers.client_state(:nx)
          {session, _} = TestHelpers.handshake_pair(session, client_state)
          Session.token(session)
        end)

      assert Enum.all?(tokens, &(byte_size(&1) == 24))
    end
  end

  test "known_device/1 requires a remote static key" do
    assert_raise ArgumentError, fn ->
      Session.known_device(server_static: TestHelpers.server_static())
    end
  end
end
