defmodule Messngr.ShareLinks do
  @moduledoc """
  Stores shareable resources that bridges can reference when the target network
  cannot receive the original payload directly (e.g. IRC attachments).

  The context keeps track of access limits, expiry, and provides helper
  functions to compute public URLs and msgr:// deep links that the clients can
  embed inside conversations.
  """

  import Ecto.Query, warn: false

  alias Messngr.Bridges.BridgeAccount
  alias Messngr.Repo
  alias Messngr.ShareLinks.ShareLink

  @permitted_attrs [
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
  ]

  @string_key_map Enum.into(@permitted_attrs, %{}, fn key -> {Atom.to_string(key), key} end)

  @type create_attrs :: map()
  @type token :: String.t()

  @doc """
  Creates a share link record with sensible defaults for expiry and capability
  metadata. If capabilities are not supplied, the default profile for the
  provided `:kind` will be stored.
  """
  @spec create_link(create_attrs()) :: {:ok, ShareLink.t()} | {:error, Ecto.Changeset.t()}
  def create_link(attrs) when is_map(attrs) do
    attrs = normalise_attrs(attrs)

    %ShareLink{}
    |> ShareLink.creation_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a share link scoped to a bridge account, automatically wiring the
  owning account identifier and defaulting the usage to `:bridge`.
  """
  @spec create_bridge_link(BridgeAccount.t(), atom() | String.t(), map()) ::
          {:ok, ShareLink.t()} | {:error, term()}
  def create_bridge_link(%BridgeAccount{} = bridge_account, kind, attrs \ %{}) do
    params =
      attrs
      |> normalise_attrs()
      |> Map.put(:account_id, bridge_account.account_id)
      |> Map.put(:bridge_account_id, bridge_account.id)
      |> Map.put(:usage, :bridge)
      |> Map.put(:kind, kind)
      |> maybe_attach_profile(bridge_account, attrs)

    create_link(params)
  end

  def create_bridge_link(nil, _kind, _attrs), do: {:error, :unknown_bridge_account}

  defp maybe_attach_profile(params, %BridgeAccount{} = bridge_account, attrs) do
    attrs = normalise_attrs(attrs)
    profile_id = Map.get(attrs, :profile_id)

    cond do
      is_binary(profile_id) -> Map.put(params, :profile_id, profile_id)
      Map.has_key?(bridge_account, :profile_id) && bridge_account.profile_id ->
        Map.put(params, :profile_id, bridge_account.profile_id)

      true ->
        params
    end
  end

  @doc """
  Fetches an active (non-expired) share link for delivery. When `track_view` is
  true the view counter is incremented, enforcing `:max_views` if configured.
  """
  @spec fetch_active(token(), keyword()) :: {:ok, ShareLink.t()} | {:error, term()}
  def fetch_active(token, opts \\ []) when is_binary(token) do
    track_view? = Keyword.get(opts, :track_view, true)

    token
    |> do_fetch_active(track_view?)
    |> case do
      {:ok, %ShareLink{} = link} -> {:ok, link}
      {:error, reason} -> {:error, reason}
    end
  end

  defp do_fetch_active(token, track_view?) do
    Repo.transaction(fn ->
      query = from link in ShareLink, where: link.token == ^token, lock: "FOR UPDATE"

      case Repo.one(query) do
        nil -> Repo.rollback(:not_found)
        %ShareLink{} = link ->
          cond do
            ShareLink.expired?(link) -> Repo.rollback(:expired)
            ShareLink.maxed_out?(link) -> Repo.rollback(:view_limit_reached)
            true ->
              if track_view? do
                link
                |> ShareLink.increment_view_changeset()
                |> Repo.update!()
              else
                link
              end
          end
      end
    end)
  end

  @doc """
  Calculates the public HTTPS URL for a share link token.
  """
  @spec public_url(ShareLink.t()) :: String.t()
  def public_url(%ShareLink{token: token}) do
    config = config()
    base = Keyword.get(config, :public_base_url, "https://share.msgr.local")
    prefix = Keyword.get(config, :public_path, "/share")

    uri = URI.parse(base)

    path =
      uri.path
      |> combine_path(prefix)
      |> combine_path("/#{token}")

    %{uri | path: path}
    |> URI.to_string()
  end

  @doc """
  Builds the `msgr://` deep link for the given share link record.
  """
  @spec msgr_url(ShareLink.t()) :: String.t()
  def msgr_url(%ShareLink{token: token, kind: kind}) do
    config = config()
    scheme = Keyword.get(config, :msgr_scheme, "msgr")
    host = Keyword.get(config, :msgr_host, "share")
    segments = Keyword.get(config, :msgr_path_segments, ["links"])

    encoded_segments =
      segments
      |> List.wrap()
      |> Enum.map(&to_string/1)
      |> Enum.map(&URI.encode_www_form/1)

    path =
      encoded_segments ++ [URI.encode_www_form(to_string(kind)), URI.encode_www_form(token)]
      |> Enum.join("/")

    "#{scheme}://#{host}/#{path}"
  end

  @doc """
  Default capability profile for a given kind.
  """
  @spec default_capabilities(atom() | String.t() | nil) :: map()
  defdelegate default_capabilities(kind), to: ShareLink

  @doc """
  Default TTL in seconds for a given kind.
  """
  @spec default_ttl(atom() | String.t() | nil) :: pos_integer()
  defdelegate default_ttl(kind), to: ShareLink

  @doc """
  Remaining view budget for a link.
  """
  @spec remaining_views(ShareLink.t()) :: :infinite | non_neg_integer()
  defdelegate remaining_views(link), to: ShareLink

  @doc """
  Convenience helper that returns whether the link is expired.
  """
  @spec expired?(ShareLink.t()) :: boolean()
  defdelegate expired?(link), to: ShareLink

  @doc """
  Returns raw configuration for the share link context.
  """
  @spec config() :: keyword()
  def config do
    Application.get_env(:msgr, __MODULE__, [])
  end

  defp combine_path(base, addition) do
    segments = split_path(base) ++ split_path(addition)

    case segments do
      [] -> "/"
      _ -> "/" <> Enum.join(segments, "/")
    end
  end

  defp split_path(nil), do: []
  defp split_path(""), do: []

  defp split_path(path) do
    path
    |> to_string()
    |> String.split("/", trim: true)
  end

  defp normalise_attrs(attrs) when is_map(attrs) do
    Enum.reduce(attrs, %{}, fn
      {key, value}, acc when key in @permitted_attrs -> Map.put(acc, key, value)
      {key, value}, acc when is_binary(key) ->
        case Map.get(@string_key_map, key) do
          nil -> acc
          attr_key -> Map.put(acc, attr_key, value)
        end

      {_key, _value}, acc -> acc
    end)
  end

  defp normalise_attrs(attrs) when is_list(attrs) do
    attrs
    |> Enum.into(%{})
    |> normalise_attrs()
  end

  defp normalise_attrs(_), do: %{}
end

