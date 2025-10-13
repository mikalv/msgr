# credo:disable-for-this-file Credo.Check.Readability.Specs

defmodule Msgr.Connectors.SessionVault do
  @moduledoc """
  Moves sensitive session material into the bridge credential vault.

  Bridge daemons often return OAuth/RTM tokens inside the `session` payload when
  a user links an account. Persisting those secrets directly on the
  `bridge_accounts` table would leave them in plaintext. This helper extracts
  token-ish fields, stores them in the in-memory credential vault, and returns a
  scrubbed session map that callers can persist safely while retaining a
  reference (`credential_ref`) to the stored secrets.
  """

  alias Messngr.Bridges
  alias Messngr.Bridges.Auth.CredentialVault

  @type service :: atom() | String.t()
  @type account_id :: String.t()
  @type instance :: String.t() | atom() | nil
  @type session :: map() | nil

  @doc """
  Extracts sensitive token fields from `session`, stores them in the credential
  vault, and returns the sanitised session map.

  When no token material is present the original (string-keyed) session map is
  returned unchanged.
  """
  @spec scrub_and_store(service(), account_id(), instance(), session()) :: {:ok, map()} | {:error, term()}
  def scrub_and_store(service, account_id, instance, session)
      when (is_binary(account_id) or is_atom(account_id)) and (is_atom(service) or is_binary(service)) do
    normalised_service = normalise_service(service)
    normalised_account = normalise_account(account_id)
    normalised_instance = normalise_instance(instance)

    session_map = ensure_map(session)

    {token_payload, scrubbed_session} = extract_tokens(session_map)

    case token_payload do
      payload when payload in [%{}, nil] ->
        {:ok, scrubbed_session}

      payload ->
        session_id = session_identifier(normalised_account, normalised_instance)

        case CredentialVault.store_tokens(normalised_service, session_id, payload) do
          {:ok, ref} ->
            {:ok, Map.put(scrubbed_session, "credential_ref", ref)}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  def scrub_and_store(_service, _account_id, _instance, _session), do: {:ok, %{}}

  defp extract_tokens(session) when session in [%{}, nil], do: {%{}, %{}}

  defp extract_tokens(session) when is_map(session) do
    Enum.reduce(session, {%{}, %{}}, fn {key, value}, {token_acc, clean_acc} ->
      key_string = normalise_key(key)

      cond do
        key_string == "credential_ref" ->
          {token_acc, Map.put(clean_acc, key_string, value)}

        sensitive_key?(key_string) ->
          token_value = normalise_value(value)

          if token_value in [nil, "", %{}] do
            {token_acc, clean_acc}
          else
            {Map.put(token_acc, key_string, token_value), clean_acc}
          end

        is_map(value) ->
          {nested_tokens, nested_clean} = extract_tokens(value)
          updated_tokens =
            if nested_tokens == %{} do
              token_acc
            else
              Map.put(token_acc, key_string, nested_tokens)
            end

          {updated_tokens, Map.put(clean_acc, key_string, nested_clean)}

        is_list(value) ->
          {nested_tokens, nested_clean} = extract_tokens_from_list(value)
          updated_tokens =
            if nested_tokens == [] do
              token_acc
            else
              Map.put(token_acc, key_string, nested_tokens)
            end

          {updated_tokens, Map.put(clean_acc, key_string, nested_clean)}

        true ->
          {token_acc, Map.put(clean_acc, key_string, value)}
      end
    end)
  end

  defp extract_tokens(_session), do: {%{}, %{}}

  defp extract_tokens_from_list(list) do
    Enum.reduce(list, {[], []}, fn value, {token_acc, clean_acc} ->
      cond do
        is_map(value) ->
          {nested_tokens, nested_clean} = extract_tokens(value)
          token_acc =
            if nested_tokens == %{} do
              token_acc
            else
              token_acc ++ [nested_tokens]
            end

          {token_acc, clean_acc ++ [nested_clean]}

        is_list(value) ->
          {nested_tokens, nested_clean} = extract_tokens_from_list(value)
          token_acc =
            if nested_tokens == [] do
              token_acc
            else
              token_acc ++ [nested_tokens]
            end

          {token_acc, clean_acc ++ [nested_clean]}

        true ->
          {token_acc, clean_acc ++ [value]}
      end
    end)
  end

  defp ensure_map(nil), do: %{}
  defp ensure_map(session) when is_map(session), do: session
  defp ensure_map(_session), do: %{}

  defp normalise_service(service) when is_atom(service), do: Atom.to_string(service)
  defp normalise_service(service) when is_binary(service), do: String.downcase(String.trim(service))

  defp normalise_account(account) when is_binary(account), do: String.trim(account)
  defp normalise_account(account) when is_atom(account), do: account |> Atom.to_string() |> normalise_account()

  defp normalise_instance(nil), do: Bridges.default_instance()
  defp normalise_instance(instance) when is_atom(instance), do: instance |> Atom.to_string() |> normalise_instance()

  defp normalise_instance(instance) when is_binary(instance) do
    trimmed = String.trim(instance)

    if trimmed == "" do
      Bridges.default_instance()
    else
      trimmed
    end
  end

  defp session_identifier(account_id, instance), do: account_id <> "::" <> instance

  defp normalise_key(key) when is_binary(key), do: key
  defp normalise_key(key) when is_atom(key), do: Atom.to_string(key)
  defp normalise_key(key), do: to_string(key)

  defp normalise_value(value) when is_map(value) do
    value
    |> Enum.map(fn {key, nested} -> {normalise_key(key), normalise_value(nested)} end)
    |> Map.new()
  end

  defp normalise_value(value) when is_list(value), do: Enum.map(value, &normalise_value/1)
  defp normalise_value(value), do: value

  defp sensitive_key?(key) do
    downcased = String.downcase(key)

    String.contains?(downcased, "token") or
      String.contains?(downcased, "secret") or
      String.contains?(downcased, "password")
  end
end
