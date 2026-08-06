defmodule Messngr.Noise.DecibelSpikeTest do
  use ExUnit.Case, async: true

  @protocol "Noise_NX_25519_ChaChaPoly_Blake2b"
  @prologue "msgr-test/v1"

  alias Decibel.Crypto

  @tag noise: true
  test "decibel can perform an NX handshake and exchange messages" do
    {server_public, server_private} = Crypto.generate_keypair(:x25519)

    server_ref =
      Decibel.new(@protocol, :rsp, %{
        s: {server_public, server_private},
        prologue: @prologue
      })

    client_ref =
      Decibel.new(@protocol, :ini, %{
        rs: server_public,
        prologue: @prologue
      })

    # Handshake flight 1 (client -> server)
    msg1 = Decibel.handshake_encrypt(client_ref)
    assert is_list(msg1) or is_binary(msg1)
    Decibel.handshake_decrypt(server_ref, msg1)

    # Handshake flight 2 (server -> client)
    msg2 = Decibel.handshake_encrypt(server_ref)
    Decibel.handshake_decrypt(client_ref, msg2)

    # Handshake flight 3 (client -> server)
    msg3 = Decibel.handshake_encrypt(client_ref)
    Decibel.handshake_decrypt(server_ref, msg3)

    assert Decibel.is_handshake_complete?(client_ref)
    assert Decibel.is_handshake_complete?(server_ref)

    hash_client = Decibel.get_handshake_hash(client_ref)
    hash_server = Decibel.get_handshake_hash(server_ref)
    assert byte_size(hash_client) == 32
    assert hash_client == hash_server

    plaintext = "hello decibel"
    ciphertext = IO.iodata_to_binary(Decibel.encrypt(client_ref, plaintext))
    refute ciphertext == plaintext
    assert Decibel.decrypt(server_ref, ciphertext) == plaintext

    reply = "handshake ack"
    reply_cipher = IO.iodata_to_binary(Decibel.encrypt(server_ref, reply))
    assert Decibel.decrypt(client_ref, reply_cipher) == reply

    # Rekey outbound (client) and inbound (server) streams
    :ok = Decibel.rekey(client_ref, :out)
    :ok = Decibel.rekey(server_ref, :in)

    rekey_cipher = IO.iodata_to_binary(Decibel.encrypt(client_ref, "after rekey"))
    assert Decibel.decrypt(server_ref, rekey_cipher) == "after rekey"
  end
end
