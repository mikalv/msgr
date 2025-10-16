defmodule Messngr.Accounts.KeyStore do
  @moduledoc """
  High level API for managing per-profile keys and recovery material.

  The key store exposes helpers for provisioning new keys, rotating existing
  material, and managing backup codes that can be stored client side. All
  operations are transactional and scoped to the provided profile.
  """

  import Ecto.Query

  alias Messngr.Accounts.{Profile, ProfileBackupCode, ProfileKey}
  alias Messngr.Repo

  @type key_params :: %{
          required(:purpose) => ProfileKey.purpose(),
          required(:public_key) => String.t(),
          optional(:encrypted_payload) => binary() | nil,
          optional(:metadata) => map(),
          optional(:client_snapshot_version) => pos_integer(),
          optional(:rotated_at) => DateTime.t(),
          optional(:encryption) => map()
        }

  @doc """
  Creates or replaces the key for the given purpose. Replacements update the
  snapshot version so clients can detect refreshes.
  """
  @spec upsert_key(Profile.t() | binary(), key_params()) ::
          {:ok, ProfileKey.t()} | {:error, Ecto.Changeset.t()}
  def upsert_key(profile_or_id, params) when is_map(params) do
    Repo.transaction(fn ->
      profile = resolve_profile(profile_or_id)

      purpose = Map.fetch!(params, :purpose)

      existing =
        Repo.one(
          from key in ProfileKey,
            where: key.profile_id == ^profile.id and key.purpose == ^purpose,
            limit: 1,
            lock: "FOR UPDATE"
        )

      public_key = Map.fetch!(params, :public_key)

      attrs =
        params
        |> Map.put(:profile_id, profile.id)
        |> Map.put_new(:metadata, %{})
        |> Map.put(:fingerprint, fingerprint(to_string(public_key)))

      case existing do
        nil ->
          %ProfileKey{}
          |> ProfileKey.changeset(attrs)
          |> Repo.insert()

        %ProfileKey{} = key ->
          key
          |> ProfileKey.changeset(attrs |> Map.put(:client_snapshot_version, next_version(key)))
          |> Repo.update()
      end
    end)
    |> unwrap()
  end

  @doc """
  Fetches the active key for the requested purpose.
  """
  @spec fetch_key(Profile.t() | binary(), ProfileKey.purpose()) :: ProfileKey.t() | nil
  def fetch_key(profile_or_id, purpose) do
    profile = resolve_profile(profile_or_id)

    Repo.one(
      from key in ProfileKey,
        where: key.profile_id == ^profile.id and key.purpose == ^purpose,
        limit: 1
    )
  end

  @doc """
  Generates backup codes for the profile. Existing codes are rotated out by
  incrementing the generation counter.
  """
  @spec generate_backup_codes(Profile.t() | binary(), keyword()) :: {:ok, [binary()]} | {:error, term()}
  def generate_backup_codes(profile_or_id, opts \\ []) do
    quantity = Keyword.get(opts, :quantity, 10)

    Repo.transaction(fn ->
      profile = resolve_profile(profile_or_id)

      latest_generation =
        Repo.one(
          from code in ProfileBackupCode,
            where: code.profile_id == ^profile.id,
            select: max(code.generation)
        ) || 0

      Repo.delete_all(
        from code in ProfileBackupCode,
          where: code.profile_id == ^profile.id and is_nil(code.used_at)
      )

      codes = Enum.map(1..quantity, fn _ -> build_backup_code(profile.id, latest_generation + 1) end)

      Repo.insert_all(
        ProfileBackupCode,
        Enum.map(codes, fn %{hash: hash, salt: salt, record: record} ->
          %{
            id: Ecto.UUID.generate(),
            profile_id: profile.id,
            code_hash: hash,
            salt: salt,
            label: record.label,
            generation: record.generation,
            inserted_at: DateTime.utc_now(),
            updated_at: DateTime.utc_now()
          }
        end)
      )

      Enum.map(codes, & &1.code)
    end)
    |> unwrap()
  end

  @doc """
  Marks a backup code as used if the provided plaintext matches.
  """
  @spec redeem_backup_code(Profile.t() | binary(), binary()) :: :ok | {:error, :invalid_code}
  def redeem_backup_code(profile_or_id, plaintext) when is_binary(plaintext) do
    Repo.transaction(fn ->
      profile = resolve_profile(profile_or_id)

      code =
        Repo.one(
          from code in ProfileBackupCode,
            where:
              code.profile_id == ^profile.id and is_nil(code.used_at),
            lock: "FOR UPDATE"
        )

      cond do
        code == nil -> Repo.rollback(:invalid_code)
        verify_code(code, plaintext) ->
          Repo.update!(Ecto.Changeset.change(code, used_at: DateTime.utc_now()))
          :ok
        true -> Repo.rollback(:invalid_code)
      end
    end)
    |> case do
      {:ok, :ok} -> :ok
      {:error, :invalid_code} -> {:error, :invalid_code}
    end
  end

  @doc """
  Returns a fingerprint that is stable across identical public keys.
  """
  @spec fingerprint(binary()) :: String.t()
  def fingerprint(public_key) do
    :crypto.hash(:sha256, public_key)
    |> Base.encode16(case: :lower)
  end

  defp build_backup_code(profile_id, generation) do
    code = generate_code()
    salt = :crypto.strong_rand_bytes(16)
    hash = hash_code(profile_id, code, salt)

    %{
      code: formatted_code(code),
      hash: hash,
      salt: salt,
      record: %{label: "recovery", generation: generation}
    }
  end

  defp verify_code(%ProfileBackupCode{} = code, plaintext) do
    expected = hash_code(code.profile_id, plaintext, code.salt)
    secure_compare(expected, code.code_hash)
  end

  defp hash_code(profile_id, code, salt) do
    data = [profile_id, salt, code] |> Enum.join(":")
    :crypto.mac(:hmac, :sha256, salt, data)
  end

  defp generate_code do
    :crypto.strong_rand_bytes(8) |> Base.encode32(case: :lower, padding: false)
  end

  defp formatted_code(code) do
    code
    |> String.upcase()
    |> String.replace(~r/(.{4})/, "\\1-")
    |> String.trim_trailing("-")
  end

  defp resolve_profile(%Profile{id: id}), do: %Profile{id: id}
  defp resolve_profile(id) when is_binary(id), do: %Profile{id: id}

  defp next_version(%ProfileKey{client_snapshot_version: version}) when is_integer(version) do
    version + 1
  end

  defp unwrap({:ok, result}), do: {:ok, result}
  defp unwrap({:error, reason}), do: {:error, reason}

  defp secure_compare(a, b) when byte_size(a) == byte_size(b), do: Plug.Crypto.secure_compare(a, b)
  defp secure_compare(_a, _b), do: false
end
