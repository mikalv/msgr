defmodule Messngr.Accounts.Profile do
  @moduledoc """
  Profiles separate modes (Jobb, Privat, Familie) under én konto med egne
  preferanser og sikkerhetspolicyer.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @default_theme %{
    "mode" => "system",
    "variant" => "default",
    "primary" => "#4C6EF5",
    "accent" => "#EDF2FF",
    "background" => "#0B1B3A",
    "contrast" => "#F8F9FA"
  }

  @default_notification_policy %{
    "allow_push" => true,
    "allow_email" => false,
    "allow_sms" => false,
    "muted_labels" => [],
    "quiet_hours" => %{"enabled" => false, "start" => "22:00", "end" => "07:00"}
  }

  @default_security_policy %{
    "requires_pin" => false,
    "biometrics_enabled" => false,
    "lock_after_minutes" => 5,
    "sensitive_notifications" => "hide_content"
  }

  @theme_keys MapSet.new(Map.keys(@default_theme))
  @quiet_hours_keys MapSet.new(Map.keys(@default_notification_policy["quiet_hours"]))
  @notification_keys MapSet.new(Map.keys(@default_notification_policy))
  @security_keys MapSet.new(Map.keys(@default_security_policy))
  @allowed_modes MapSet.new(["light", "dark", "system"])
  @allowed_sensitivity MapSet.new(["show", "hide_content", "hide_all"])

  schema "profiles" do
    field :name, :string
    field :slug, :string
    field :mode, Ecto.Enum, values: [:private, :work, :family], default: :private
    field :theme, :map, default: @default_theme
    field :notification_policy, :map, default: @default_notification_policy
    field :security_policy, :map, default: @default_security_policy

    belongs_to :account, Messngr.Accounts.Account
    has_many :devices, Messngr.Accounts.Device
    has_many :keys, Messngr.Accounts.ProfileKey
    has_many :backup_codes, Messngr.Accounts.ProfileBackupCode

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(profile, attrs) do
    profile
    |> cast(attrs, [:name, :slug, :mode, :theme, :notification_policy, :security_policy, :account_id])
    |> validate_required([:name, :account_id])
    |> validate_length(:name, min: 2, max: 80)
    |> normalize_preferences()
    |> put_default_slug()
    |> unique_constraint(:slug, name: :profiles_account_id_slug_index)
  end

  defp put_default_slug(%{changes: %{slug: slug}} = changeset) when slug not in [nil, ""] do
    changeset
  end

  defp put_default_slug(%{changes: %{name: name}, data: %{id: id}} = changeset) when not is_nil(id) do
    slug =
      name
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]/, "-")
      |> String.replace(~r/-+/, "-")
      |> String.trim("-")

    change(changeset, slug: slug)
  end

  defp put_default_slug(%{changes: %{name: name}} = changeset) do
    slug =
      name
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]/, "-")
      |> String.replace(~r/-+/, "-")
      |> String.trim("-")

    change(changeset, slug: slug)
  end

  defp put_default_slug(changeset), do: changeset

  defp normalize_preferences(changeset) do
    changeset
    |> normalize_theme()
    |> normalize_notification_policy()
    |> normalize_security_policy()
  end

  defp normalize_theme(%Ecto.Changeset{} = changeset) do
    with {:ok, theme} <- resolve_map(changeset, :theme, @default_theme),
         {:ok, normalized} <- validate_theme(theme) do
      put_change(changeset, :theme, normalized)
    else
      :invalid -> add_error(changeset, :theme, "must be a map")
      {:error, errors} -> add_map_errors(changeset, :theme, errors)
    end
  end

  defp normalize_notification_policy(%Ecto.Changeset{} = changeset) do
    with {:ok, policy} <- resolve_map(changeset, :notification_policy, @default_notification_policy),
         {:ok, normalized} <- validate_notification_policy(policy) do
      put_change(changeset, :notification_policy, normalized)
    else
      :invalid -> add_error(changeset, :notification_policy, "must be a map")
      {:error, errors} -> add_map_errors(changeset, :notification_policy, errors)
    end
  end

  defp normalize_security_policy(%Ecto.Changeset{} = changeset) do
    with {:ok, policy} <- resolve_map(changeset, :security_policy, @default_security_policy),
         {:ok, normalized} <- validate_security_policy(policy) do
      put_change(changeset, :security_policy, normalized)
    else
      :invalid -> add_error(changeset, :security_policy, "must be a map")
      {:error, errors} -> add_map_errors(changeset, :security_policy, errors)
    end
  end

  defp resolve_map(changeset, field, default) do
    base = get_field(changeset, field) || %{}

    case get_change(changeset, field, base) do
      value when is_map(value) ->
        value
        |> stringify_keys()
        |> deep_merge(default)
        |> then(&{:ok, &1})

      nil -> {:ok, default}
      _ -> :invalid
    end
  end

  defp validate_theme(theme) do
    theme = Map.take(theme, MapSet.to_list(@theme_keys))
    theme =
      case Map.fetch(theme, "mode") do
        {:ok, value} when is_binary(value) -> Map.put(theme, "mode", String.downcase(value))
        _ -> theme
      end

    errors =
      []
      |> validate_required_hex(theme, "primary")
      |> validate_required_hex(theme, "accent")
      |> validate_required_hex(theme, "background")
      |> validate_required_hex(theme, "contrast")
      |> validate_inclusion(theme, "mode", @allowed_modes, "must be light, dark or system")
      |> validate_string(theme, "variant")

    if errors == [] do
      {:ok, Map.merge(@default_theme, theme)}
    else
      {:error, errors}
    end
  end

  defp validate_notification_policy(policy) do
    policy = Map.take(policy, MapSet.to_list(@notification_keys))

    quiet_hours =
      policy
      |> Map.get("quiet_hours", %{})
      |> case do
        value when is_map(value) ->
          value
          |> stringify_keys()
          |> Map.take(MapSet.to_list(@quiet_hours_keys))
          |> deep_merge(@default_notification_policy["quiet_hours"])

        _ ->
          @default_notification_policy["quiet_hours"]
      end

    policy =
      policy
      |> Map.put("quiet_hours", quiet_hours)
      |> Map.update("muted_labels", [], fn value ->
        cond do
          is_list(value) ->
            value
            |> Enum.map(&to_string/1)
            |> Enum.reject(&(&1 |> String.trim() == ""))
            |> Enum.uniq()

          true -> []
        end
      end)

    errors =
      []
      |> validate_boolean(policy, "allow_push")
      |> validate_boolean(policy, "allow_email")
      |> validate_boolean(policy, "allow_sms")
      |> validate_quiet_hours(policy["quiet_hours"])

    if errors == [] do
      {:ok, deep_merge(@default_notification_policy, policy)}
    else
      {:error, errors}
    end
  end

  defp validate_security_policy(policy) do
    policy = Map.take(policy, MapSet.to_list(@security_keys))
    policy =
      case Map.fetch(policy, "lock_after_minutes") do
        {:ok, value} when is_binary(value) ->
          case Integer.parse(value) do
            {int, _} -> Map.put(policy, "lock_after_minutes", int)
            _ -> policy
          end

        _ -> policy
      end

    policy =
      case Map.fetch(policy, "sensitive_notifications") do
        {:ok, value} when is_binary(value) -> Map.put(policy, "sensitive_notifications", String.downcase(value))
        _ -> policy
      end

    errors =
      []
      |> validate_boolean(policy, "requires_pin")
      |> validate_boolean(policy, "biometrics_enabled")
      |> validate_integer_range(policy, "lock_after_minutes", 0, 1440)
      |> validate_inclusion(
        policy,
        "sensitive_notifications",
        @allowed_sensitivity,
        "must be one of show, hide_content or hide_all"
      )

    if errors == [] do
      {:ok, deep_merge(@default_security_policy, policy)}
    else
      {:error, errors}
    end
  end

  defp validate_quiet_hours(errors, %{"enabled" => enabled} = quiet_hours) do
    errors
    |> validate_boolean(%{"quiet_hours.enabled" => enabled}, "quiet_hours.enabled")
    |> validate_time(quiet_hours, "quiet_hours.start")
    |> validate_time(quiet_hours, "quiet_hours.end")
  end

  defp validate_quiet_hours(errors, _), do: [{:quiet_hours, "must be a map"} | errors]

  defp validate_boolean(errors, map, key) do
    case Map.fetch(map, key) do
      {:ok, value} when is_boolean(value) -> errors
      {:ok, _} -> [{String.to_atom(key), "must be true or false"} | errors]
      :error -> errors
    end
  end

  defp validate_integer_range(errors, map, key, min, max) do
    case Map.fetch(map, key) do
      {:ok, value} when is_integer(value) and value >= min and value <= max -> errors
      {:ok, value} when is_binary(value) ->
        case Integer.parse(value) do
          {int, _} when int >= min and int <= max -> errors
          _ -> [{String.to_atom(key), "must be between #{min} and #{max}"} | errors]
        end

      {:ok, _} -> [{String.to_atom(key), "must be between #{min} and #{max}"} | errors]
      :error -> errors
    end
  end

  defp validate_required_hex(errors, map, key) do
    case Map.fetch(map, key) do
      {:ok, value} when is_binary(value) ->
        if Regex.match?(~r/^#?(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/, value) do
          errors
        else
          [{String.to_atom(key), "must be a hex colour (e.g. #AABBCC)"} | errors]
        end

      {:ok, _} -> [{String.to_atom(key), "must be a hex colour (e.g. #AABBCC)"} | errors]
      :error -> [{String.to_atom(key), "is required"} | errors]
    end
  end

  defp validate_inclusion(errors, map, key, allowed, message) do
    case Map.fetch(map, key) do
      {:ok, value} when is_binary(value) ->
        downcased = String.downcase(value)

        cond do
          MapSet.member?(allowed, downcased) -> errors
          MapSet.member?(allowed, value) -> errors
          true -> [{String.to_atom(key), message} | errors]
        end

      {:ok, _} -> [{String.to_atom(key), message} | errors]
      :error -> errors
    end
  end

  defp validate_string(errors, map, key) do
    case Map.fetch(map, key) do
      {:ok, value} when is_binary(value) ->
        if String.trim(value) != "" do
          errors
        else
          [{String.to_atom(key), "must be a string"} | errors]
        end

      {:ok, nil} ->
        errors

      {:ok, _} ->
        [{String.to_atom(key), "must be a string"} | errors]

      :error ->
        errors
    end
  end

  defp validate_time(errors, map, key) do
    trimmed_key = key |> String.split(".") |> List.last()

    case Map.fetch(map, trimmed_key) do
      {:ok, value} when is_binary(value) ->
        if Regex.match?(~r/^(?:[01]\d|2[0-3]):[0-5]\d$/, value) do
          errors
        else
          [{String.to_atom(key), "must be HH:MM"} | errors]
        end

      {:ok, _} ->
        [{String.to_atom(key), "must be HH:MM"} | errors]

      :error ->
        errors
    end
  end

  defp add_map_errors(changeset, field, errors) do
    Enum.reduce(errors, changeset, fn {subfield, message}, acc ->
      add_error(acc, field, "#{subfield}: #{message}")
    end)
  end

  defp stringify_keys(map) when is_map(map) do
    map
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      string_key =
        cond do
          is_atom(key) -> Atom.to_string(key)
          is_binary(key) -> key
          true -> to_string(key)
        end

      Map.put(acc, string_key, if(is_map(value), do: stringify_keys(value), else: value))
    end)
  end

  defp deep_merge(left, right) do
    Map.merge(left, right, fn _key, l, r ->
      cond do
        is_map(l) and is_map(r) -> deep_merge(l, r)
        true -> r
      end
    end)
  end
end
