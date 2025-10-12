defmodule Messngr.ShareLinks.ShareLink do
  @moduledoc """
  Represents a shareable resource that bridges can use when a network requires
  a public URL or out-of-band download instructions (e.g. IRC, SMS).

  Share links keep track of ownership, expiry, usage limits, and the payload
  needed for bridges to reconstruct an attachment, location pin, or Msgr invite.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Messngr.Accounts.{Account, Profile}
  alias Messngr.Bridges.BridgeAccount

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type kind :: :image | :video | :audio | :file | :location | :invite | :document | :other
  @type t :: %__MODULE__{}

  schema "share_links" do
    field :token, :string
    field :kind, Ecto.Enum,
      values: [:image, :video, :audio, :file, :location, :invite, :document, :other],
      default: :other

    field :usage, Ecto.Enum, values: [:bridge, :invite, :external, :internal], default: :bridge
    field :title, :string
    field :description, :string
    field :payload, :map, default: %{}
    field :metadata, :map, default: %{}
    field :source, :map, default: %{}
    field :capabilities, :map, default: %{}
    field :expires_at, :utc_datetime
    field :view_count, :integer, default: 0
    field :max_views, :integer

    belongs_to :account, Account
    belongs_to :profile, Profile
    belongs_to :bridge_account, BridgeAccount

    timestamps(type: :utc_datetime)
  end

  @doc false
  def creation_changeset(%__MODULE__{} = link, attrs) do
    link
    |> cast(attrs, [
      :account_id,
      :profile_id,
      :bridge_account_id,
      :token,
      :kind,
      :usage,
      :title,
      :description,
      :payload,
      :metadata,
      :source,
      :capabilities,
      :expires_at,
      :max_views
    ])
    |> validate_required([:account_id, :kind])
    |> ensure_token()
    |> put_default_usage()
    |> put_default_payloads()
    |> put_default_capabilities()
    |> put_default_expiry()
    |> validate_number(:max_views, greater_than: 0)
    |> validate_future_expiry()
    |> unique_constraint(:token)
  end

  @doc """
  Returns the default capability profile for a given share link kind.
  """
  @spec default_capabilities(atom() | String.t() | nil) :: map()
  def default_capabilities(kind) do
    kind
    |> normalise_kind()
    |> capability_profiles()
  end

  @doc """
  Default TTL (seconds) for a given share link kind.
  """
  @spec default_ttl(atom() | String.t() | nil) :: pos_integer()
  def default_ttl(kind) do
    case normalise_kind(kind) do
      :invite -> 2_592_000
      :location -> 86_400
      :image -> 604_800
      :video -> 604_800
      :audio -> 604_800
      :file -> 604_800
      :document -> 604_800
      _ -> 604_800
    end
  end

  @doc """
  Indicates whether a share link is expired.
  """
  @spec expired?(t()) :: boolean()
  def expired?(%__MODULE__{expires_at: nil}), do: false

  def expired?(%__MODULE__{expires_at: expires_at}) do
    DateTime.compare(DateTime.utc_now(), expires_at) == :gt
  end

  @doc """
  Indicates whether the link has exhausted the maximum view budget.
  """
  @spec maxed_out?(t()) :: boolean()
  def maxed_out?(%__MODULE__{max_views: nil}), do: false

  def maxed_out?(%__MODULE__{view_count: count, max_views: max}) when is_integer(max) do
    count >= max
  end

  @doc """
  Remaining view count before the link expires (if limited).
  """
  @spec remaining_views(t()) :: :infinite | non_neg_integer()
  def remaining_views(%__MODULE__{max_views: nil}), do: :infinite

  def remaining_views(%__MODULE__{view_count: count, max_views: max}) when is_integer(max) do
    max - count |> max(0)
  end

  @doc """
  Builds a changeset that increments the view counter by one.
  """
  @spec increment_view_changeset(t()) :: Ecto.Changeset.t()
  def increment_view_changeset(%__MODULE__{view_count: count} = link) do
    change(link, view_count: count + 1)
  end

  defp ensure_token(%Ecto.Changeset{} = changeset) do
    case fetch_field(changeset, :token) do
      :error -> put_change(changeset, :token, generate_token())
      {:data, nil} -> put_change(changeset, :token, generate_token())
      {:changes, nil} -> put_change(changeset, :token, generate_token())
      _ -> changeset
    end
  end

  defp put_default_usage(%Ecto.Changeset{} = changeset) do
    case fetch_field(changeset, :usage) do
      {:data, nil} -> put_change(changeset, :usage, :bridge)
      {:changes, nil} -> put_change(changeset, :usage, :bridge)
      _ -> changeset
    end
  end

  defp put_default_payloads(%Ecto.Changeset{} = changeset) do
    changeset
    |> ensure_map_field(:payload)
    |> ensure_map_field(:metadata)
    |> ensure_map_field(:source)
  end

  defp ensure_map_field(%Ecto.Changeset{} = changeset, field) do
    value = get_field(changeset, field)

    cond do
      is_map(value) -> changeset
      is_nil(value) -> put_change(changeset, field, %{})
      true -> add_error(changeset, field, "must be a map")
    end
  end

  defp put_default_capabilities(%Ecto.Changeset{} = changeset) do
    current = get_field(changeset, :capabilities)

    cond do
      is_map(current) and map_size(current) > 0 -> changeset
      true ->
        kind = get_field(changeset, :kind)
        put_change(changeset, :capabilities, default_capabilities(kind))
    end
  end

  defp put_default_expiry(%Ecto.Changeset{} = changeset) do
    case get_field(changeset, :expires_at) do
      nil ->
        kind = get_field(changeset, :kind)
        ttl = default_ttl(kind)
        expires_at = DateTime.add(DateTime.utc_now(), ttl, :second)
        put_change(changeset, :expires_at, expires_at)

      _ ->
        changeset
    end
  end

  defp validate_future_expiry(%Ecto.Changeset{} = changeset) do
    expires_at = get_field(changeset, :expires_at)

    if expires_at && DateTime.compare(expires_at, DateTime.utc_now()) == :lt do
      add_error(changeset, :expires_at, "must be in the future")
    else
      changeset
    end
  end

  defp generate_token do
    32
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end

  defp capability_profiles(:image) do
    %{
      "targets" => %{
        "irc" => %{"mode" => "link_only", "payload_keys" => ["public_url", "title"]},
        "xmpp" => %{
          "mode" => "fetch_upload",
          "payload_keys" => ["download", "content_type", "filename"]
        },
        "telegram" => %{"mode" => "native_forward", "payload_keys" => ["download", "caption"]},
        "signal" => %{"mode" => "native_forward", "payload_keys" => ["download"]},
        "whatsapp" => %{"mode" => "native_forward", "payload_keys" => ["download"]}
      },
      "supports" => ["thumbnail", "caption"],
      "kind" => "image"
    }
  end

  defp capability_profiles(:video) do
    %{
      "targets" => %{
        "irc" => %{"mode" => "link_only", "payload_keys" => ["public_url", "title"]},
        "xmpp" => %{
          "mode" => "fetch_upload",
          "payload_keys" => ["download", "content_type", "duration"]
        },
        "telegram" => %{"mode" => "native_forward", "payload_keys" => ["download", "caption"]},
        "signal" => %{"mode" => "native_forward", "payload_keys" => ["download"]},
        "whatsapp" => %{"mode" => "native_forward", "payload_keys" => ["download"]}
      },
      "supports" => ["thumbnail", "caption", "duration"],
      "kind" => "video"
    }
  end

  defp capability_profiles(:audio) do
    %{
      "targets" => %{
        "irc" => %{"mode" => "link_only", "payload_keys" => ["public_url", "title"]},
        "xmpp" => %{"mode" => "fetch_upload", "payload_keys" => ["download", "content_type"]},
        "telegram" => %{"mode" => "native_forward", "payload_keys" => ["download", "waveform"]},
        "signal" => %{"mode" => "native_forward", "payload_keys" => ["download"]}
      },
      "supports" => ["duration", "waveform"],
      "kind" => "audio"
    }
  end

  defp capability_profiles(:file) do
    %{
      "targets" => %{
        "irc" => %{"mode" => "link_only", "payload_keys" => ["public_url", "filename"]},
        "xmpp" => %{"mode" => "fetch_upload", "payload_keys" => ["download", "filename"]},
        "telegram" => %{"mode" => "native_forward", "payload_keys" => ["download", "filename"]},
        "signal" => %{"mode" => "native_forward", "payload_keys" => ["download", "filename"]},
        "whatsapp" => %{"mode" => "native_forward", "payload_keys" => ["download", "filename"]}
      },
      "supports" => ["checksum"],
      "kind" => "file"
    }
  end

  defp capability_profiles(:document), do: capability_profiles(:file)

  defp capability_profiles(:location) do
    %{
      "targets" => %{
        "irc" => %{"mode" => "link_only", "payload_keys" => ["public_url", "geo_uri"]},
        "xmpp" => %{"mode" => "native_location", "payload_keys" => ["latitude", "longitude", "label"]},
        "telegram" => %{"mode" => "native_location", "payload_keys" => ["latitude", "longitude", "accuracy"]},
        "signal" => %{"mode" => "native_forward", "payload_keys" => ["latitude", "longitude"]}
      },
      "supports" => ["live", "accuracy"],
      "kind" => "location"
    }
  end

  defp capability_profiles(:invite) do
    %{
      "targets" => %{
        "irc" => %{"mode" => "link_only", "payload_keys" => ["public_url", "code"]},
        "xmpp" => %{"mode" => "link_only", "payload_keys" => ["public_url", "code"]},
        "telegram" => %{"mode" => "link_only", "payload_keys" => ["public_url", "code"]},
        "signal" => %{"mode" => "link_only", "payload_keys" => ["public_url", "code"]},
        "whatsapp" => %{"mode" => "link_only", "payload_keys" => ["public_url", "code"]}
      },
      "supports" => ["deeplink", "qr"],
      "kind" => "invite"
    }
  end

  defp capability_profiles(:other) do
    %{
      "targets" => %{"irc" => %{"mode" => "link_only", "payload_keys" => ["public_url"]}},
      "supports" => [],
      "kind" => "other"
    }
  end

  defp capability_profiles(_), do: capability_profiles(:other)

  defp normalise_kind(kind) when kind in [:image, :video, :audio, :file, :location, :invite, :document, :other],
    do: kind

  defp normalise_kind(kind) when is_binary(kind) do
    kind
    |> String.downcase()
    |> String.to_existing_atom()
  rescue
    ArgumentError -> :other
  end

  defp normalise_kind(_), do: :other
end

