defmodule Messngr.Channels do
  @moduledoc """
  Context module for tenant-scoped channel operations.

  All functions take `prefix` (the tenant schema name) as the first argument.
  """

  alias Teams.TenantModels.{Channel, ChannelMembership}

  import Ecto.Query

  @doc """
  Lists all channels in the tenant.
  """
  def list_channels(prefix) do
    Channel.list(prefix)
  end

  @doc """
  Lists public channels in the tenant.
  """
  def list_public_channels(prefix) do
    Channel.list_public(prefix)
  end

  @doc """
  Gets a channel by id. Raises if not found.
  """
  def get_channel!(prefix, id) do
    case Channel.get_by_id(prefix, id) do
      nil -> raise Ecto.NoResultsError, queryable: Channel
      channel -> channel
    end
  end

  @doc """
  Gets a channel by id. Returns nil if not found.
  """
  def get_channel(prefix, id) do
    Channel.get_by_id(prefix, id)
  end

  @doc """
  Creates a new channel with optional icon.

  ## Attrs
    * `:name` — required
    * `:icon` — optional emoji
    * `:visibility` — "public" (default) or "private"
    * `:topic` — optional
    * `:created_by` — profile id of the creator
  """
  def create_channel(prefix, attrs) do
    with {:ok, channel} <- Channel.create(prefix, attrs) do
      # Auto-join creator if created_by is set
      if attrs[:created_by] || attrs["created_by"] do
        creator_id = attrs[:created_by] || attrs["created_by"]

        ChannelMembership.join(prefix, %{
          channel_id: channel.id,
          profile_id: creator_id,
          role: "admin"
        })
      end

      {:ok, channel}
    end
  end

  @doc """
  Creates a DM channel between the given profile ids.

  If a DM between the exact same set of profiles already exists, returns it.
  For 2 profiles → kind "dm", for 3+ → kind "group_dm".
  """
  def create_dm(prefix, profile_ids) when is_list(profile_ids) do
    kind = if length(profile_ids) <= 2, do: "dm", else: "group_dm"

    # Generate a stable slug for DM lookup
    sorted_ids = Enum.sort(profile_ids)
    dm_slug = "dm-" <> (:crypto.hash(:sha256, Enum.join(sorted_ids, ":")) |> Base.encode16(case: :lower) |> binary_part(0, 12))

    case Channel.get_by_slug(prefix, dm_slug) do
      nil ->
        with {:ok, channel} <-
               Channel.create(prefix, %{
                 name: dm_slug,
                 slug: dm_slug,
                 kind: kind,
                 visibility: "private"
               }) do
          # Add all participants
          Enum.each(profile_ids, fn pid ->
            ChannelMembership.join(prefix, %{
              channel_id: channel.id,
              profile_id: pid
            })
          end)

          {:ok, channel}
        end

      existing ->
        {:ok, existing}
    end
  end

  @doc """
  Lists members of a channel.
  """
  def list_members(prefix, channel_id) do
    ChannelMembership.members_of(prefix, channel_id)
  end
end
