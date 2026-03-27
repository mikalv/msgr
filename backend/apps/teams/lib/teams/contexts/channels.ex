defmodule Teams.Channels do
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
  Lists channels visible to a profile: all public + private channels where the profile is a member.
  """
  def list_channels_for_profile(prefix, profile_id) do
    # Get IDs of private channels the profile is a member of
    private_channel_ids =
      from(cm in ChannelMembership,
        join: c in Channel, on: cm.channel_id == c.id,
        where: cm.profile_id == ^profile_id and c.visibility == "private",
        select: cm.channel_id
      )
      |> Teams.Repo.all(prefix: prefix)

    # All public channels + private channels the user is in
    from(c in Channel,
      where: c.visibility == "public" or c.id in ^private_channel_ids,
      order_by: [asc: c.name]
    )
    |> Teams.Repo.all(prefix: prefix)
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

    # Try to find existing DM first, then create if not found
    case Channel.get_by_slug(prefix, dm_slug) do
      nil ->
        case Channel.create(prefix, %{
               name: dm_slug,
               slug: dm_slug,
               kind: kind,
               visibility: "private"
             }) do
          {:ok, channel} ->
            # Add all participants (on_conflict: :nothing handles duplicates)
            Enum.each(profile_ids, fn pid ->
              ChannelMembership.join(prefix, %{
                channel_id: channel.id,
                profile_id: pid
              })
            end)

            {:ok, channel}

          {:error, %Ecto.Changeset{errors: [{:slug, _} | _]}} ->
            # Race condition: slug was created between check and insert
            case Channel.get_by_slug(prefix, dm_slug) do
              nil -> {:error, :dm_creation_failed}
              existing -> {:ok, existing}
            end

          {:error, reason} ->
            {:error, reason}
        end

      existing ->
        {:ok, existing}
    end
  end

  @doc """
  Adds multiple members to a channel.

  Skips any profile that is already a member (upsert-safe via
  `ON CONFLICT DO NOTHING` on the unique constraint).

  Returns `{:ok, count}` with the number of newly inserted memberships.
  """
  def add_members(prefix, channel_id, profile_ids) when is_list(profile_ids) do
    now = DateTime.utc_now()

    results =
      Enum.reduce(profile_ids, 0, fn pid, acc ->
        case ChannelMembership.join(prefix, %{
               channel_id: channel_id,
               profile_id: pid,
               role: "member",
               joined_at: now
             }) do
          {:ok, _} -> acc + 1
          {:error, _} -> acc  # already a member or invalid
        end
      end)

    {:ok, results}
  end

  @doc """
  Updates the topic of a channel.
  """
  def update_topic(prefix, channel_id, topic) when is_binary(topic) do
    case get_channel(prefix, channel_id) do
      nil ->
        {:error, :not_found}

      channel ->
        Channel.update(prefix, channel, %{topic: topic})
    end
  end

  @doc """
  Lists members of a channel with preloaded profiles.
  """
  def list_members(prefix, channel_id) do
    ChannelMembership.members_of(prefix, channel_id)
  end

  @doc """
  Removes a member from a channel.
  Returns `{count, nil}` where count is 0 or 1.
  """
  def remove_member(prefix, channel_id, profile_id) do
    ChannelMembership.leave(prefix, channel_id, profile_id)
  end

  @doc """
  Fetch the last message for each channel ID.
  Returns a map of channel_id => %{sender_name, text, inserted_at}.
  """
  def last_messages_for_channels(_prefix, []), do: %{}
  def last_messages_for_channels(prefix, channel_ids) do
    alias Teams.TenantModels.Message

    # Use a lateral join / window function to get one message per channel
    query = from(m in Message,
      where: m.channel_id in ^channel_ids and is_nil(m.deleted_at) and is_nil(m.thread_parent_id),
      distinct: m.channel_id,
      order_by: [asc: m.channel_id, desc: m.inserted_at],
      preload: [:sender_profile]
    )

    Teams.Repo.all(query, prefix: prefix)
    |> Enum.into(%{}, fn m ->
      text = case m.content do
        %{"text" => t} when is_binary(t) -> if(String.length(t) > 100, do: String.slice(t, 0, 100) <> "...", else: t)
        _ -> ""
      end

      sender_name = case m.sender_profile do
        nil -> "Unknown"
        p -> p.display_name || "Unknown"
      end

      {m.channel_id, %{
        sender_name: sender_name,
        text: text,
        inserted_at: m.inserted_at
      }}
    end)
  end
end
