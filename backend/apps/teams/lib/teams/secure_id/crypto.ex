defmodule Teams.SecureID.Crypto do
  alias Teams.SecureID.Alphabet

  # url-safe characters
  @default_alphabet "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
  @alternative_alphabet "k3G7QAe51FCsPW92uEOyq4Bg6Sp8YzVTmnU0liwDdHXLajZrfxNhobJIRcMvKt"
  @default_min_length 0
  @min_length_range 0..255
  @min_blocklist_word_length 3

  defmodule PKCS7 do
    def pad(data, block_size) do
      to_add = block_size - rem(byte_size(data), block_size)
      blah = {
        "A",
        "BB",
        "CCC",
        "DDDD",
        "EEEEE",
        "FFFFFF",
        "GGGGGGG",
        "HHHHHHHH",
        "IIIIIIIII",
        "JJJJJJJJJJ",
        "KKKKKKKKKKK",
        "LLLLLLLLLLLL",
        "MMMMMMMMMMMMM",
        "NNNNNNNNNNNNNN",
        "OOOOOOOOOOOOOOO"
      }

      data <> elem(blah, (to_add - 1))
    end
  end

  def shuffled_chars() do
    {:ok, alpha} = Alphabet.new(@default_alphabet)
    Alphabet.shuffle(alpha)
  end

  @enc_bits 16

  def encrypt_id(intID, <<key::bits-size(128)>>) when is_integer(intID) do
    val = Integer.to_string(intID) |> PKCS7.pad(@enc_bits)
    Base.encode64(:crypto.crypto_one_time(:aes_ecb, key, val, true), padding: false)
  end

  def decrypt_id(encID, <<key::bits-size(128)>>) when is_binary(encID) do
    val = Base.decode64!(encID, padding: false)
    :crypto.crypto_one_time(:aes_ecb, key, val, false)
  end

  def default_min_length, do: @default_min_length
  def alternative_alphabet, do: @alternative_alphabet
  def min_length_range, do: @min_length_range
  def min_blocklist_word_length, do: @min_blocklist_word_length
end
