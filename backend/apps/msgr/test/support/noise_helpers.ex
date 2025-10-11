defmodule Messngr.Transport.Noise.TestHelpers do
  @moduledoc false

  alias Messngr.Noise.KeyLoader
  alias Messngr.Transport.Noise.Session

  @prologue "msgr-test/v1"

  @doc "Deterministic server-side private key for tests"
  def server_static, do: :crypto.hash(:sha256, "server-static")

  @doc "Deterministic client private key for tests"
  def client_static, do: :crypto.hash(:sha256, "client-static")

  @doc "Secondary client key used when exercising fallback behaviour"
  def rotated_client_static, do: :crypto.hash(:sha256, "rotated-client-static")

  @doc "Convenience prologue"
  def prologue, do: @prologue

  def server_public do
    KeyLoader.public_key(server_static())
  end

  def client_public(private \\ client_static()) do
    KeyLoader.public_key(private)
  end

  def build_session(type, opts \\ []) do
    base_opts =
      opts
      |> Keyword.put_new(:server_static, server_static())
      |> Keyword.put_new(:prologue, prologue())

    case type do
      :new -> Session.new_device(base_opts)
      :known -> Session.known_device(base_opts)
    end
  end

  def client_state(pattern, opts \\ []) do
    options =
      [
        {:noise, protocol(pattern)},
        {:prologue, Keyword.get(opts, :prologue, prologue())},
        {:s, keypair(Keyword.get(opts, :client_static, client_static()))}
      ]
      |> maybe_put_remote_static(pattern, Keyword.get(opts, :server_public, server_public()))

    {:ok, state} = :enoise.handshake(options, :initiator)
    state
  end

  def handshake_pair(session, client_state) do
    do_handshake(session, client_state)
  end

  def decrypt_client(split_state, ciphertext, aad \\ <<>>) do
    with {:ok, rx, plaintext} <- :enoise_cipher_state.decrypt_with_ad(split_state.rx, aad, ciphertext) do
      {:ok, plaintext, %{split_state | rx: rx}}
    end
  end

  def encrypt_client(split_state, plaintext, aad \\ <<>>) do
    with {:ok, tx, ciphertext} <- :enoise_cipher_state.encrypt_with_ad(split_state.tx, aad, plaintext) do
      {:ok, ciphertext, %{split_state | tx: tx}}
    end
  end

  def rekey_client(split_state, direction) do
    case direction do
      :tx -> %{split_state | tx: :enoise_cipher_state.rekey(split_state.tx)}
      :rx -> %{split_state | rx: :enoise_cipher_state.rekey(split_state.rx)}
      :both -> rekey_client(split_state, :tx) |> rekey_client(:rx)
    end
  end

  defp do_handshake(session, client_state) do
    cond do
      Session.established?(session) ->
        {:ok, :done, split_state} = :enoise.step_handshake(client_state, :done)
        {session, split_state}

      true ->
        case :enoise_hs_state.next_message(client_state) do
          :out ->
            {:ok, :send, outbound, client_state} = :enoise.step_handshake(client_state, {:send, <<>>})
            {:ok, replies, session} = Session.recv(session, outbound)
            client_state = Enum.reduce(replies, client_state, &acknowledge/2)
            do_handshake(session, client_state)

          :in ->
            {:ok, replies, session} = Session.send(session)
            client_state = Enum.reduce(replies, client_state, &acknowledge/2)
            do_handshake(session, client_state)

          :done ->
            {:ok, :done, split_state} = :enoise.step_handshake(client_state, :done)
            {session, split_state}
        end
    end
  end

  defp acknowledge(message, client_state) do
    {:ok, :rcvd, _payload, client_state} = :enoise.step_handshake(client_state, {:rcvd, message})
    client_state
  end

  defp keypair(secret) do
    :enoise_keypair.new(:dh25519, secret, KeyLoader.public_key(secret))
  end

  defp protocol(:nx), do: "Noise_NX_25519_ChaChaPoly_Blake2b"
  defp protocol(:ik), do: "Noise_IK_25519_ChaChaPoly_Blake2b"
  defp protocol(:xx), do: "Noise_XX_25519_ChaChaPoly_Blake2b"

  defp maybe_put_remote_static(options, pattern, server_public)
       when pattern in [:nx, :ik] do
    Keyword.put(options, :rs, :enoise_keypair.new(:dh25519, server_public))
  end

  defp maybe_put_remote_static(options, _pattern, _public), do: options
end
