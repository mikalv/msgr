defmodule Messngr.Family do
  @moduledoc """
  Domenelogikk for familier og delt kalender.
  """

  import Ecto.Query

  alias Messngr.Repo
  alias Messngr.Family.{Event, Family, Membership}

  @default_time_zone "Etc/UTC"

  @spec list_families(Ecto.UUID.t()) :: [Family.t()]
  def list_families(profile_id) do
    Family
    |> join(:inner, [f], m in assoc(f, :memberships), on: m.profile_id == ^profile_id)
    |> distinct(true)
    |> preload([f], memberships: [:profile])
    |> Repo.all()
  end

  @spec get_family!(Ecto.UUID.t(), keyword()) :: Family.t()
  def get_family!(family_id, opts \\ []) do
    preloads = Keyword.get(opts, :preload, [memberships: [:profile]])

    Family
    |> Repo.get!(family_id)
    |> Repo.preload(preloads)
  end

  @spec create_family(Ecto.UUID.t(), map()) :: {:ok, Family.t()} | {:error, term()}
  def create_family(owner_profile_id, attrs) do
    attrs = Map.new(attrs)

    Repo.transaction(fn ->
      family_attrs =
        attrs
        |> Map.put_new(:time_zone, fetch_time_zone(attrs))
        |> Map.put(:slug, ensure_slug(attrs))

      with {:ok, %Family{id: family_id}} <-
             %Family{} |> Family.changeset(family_attrs) |> Repo.insert(),
           {:ok, _membership} <-
             %Membership{}
             |> Membership.changeset(%{
               family_id: family_id,
               profile_id: owner_profile_id,
               role: :owner
             })
             |> Repo.insert() do
        preload_family(family_id)
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> normalize_transaction()
  end

  @spec add_member(Ecto.UUID.t(), Ecto.UUID.t(), Membership.role()) ::
          {:ok, Membership.t()} | {:error, Ecto.Changeset.t()}
  def add_member(family_id, profile_id, role \\ :member) do
    %Membership{}
    |> Membership.changeset(%{family_id: family_id, profile_id: profile_id, role: role})
    |> Repo.insert()
  end

  @spec remove_member(Ecto.UUID.t(), Ecto.UUID.t()) :: {:ok, Membership.t()} | {:error, term()}
  def remove_member(family_id, profile_id) do
    case Repo.get_by(Membership, family_id: family_id, profile_id: profile_id) do
      nil -> {:error, :not_found}
      membership -> Repo.delete(membership)
    end
  end

  @spec ensure_membership(Ecto.UUID.t(), Ecto.UUID.t()) :: Membership.t()
  def ensure_membership(family_id, profile_id) do
    Repo.get_by!(Membership, family_id: family_id, profile_id: profile_id)
  end

  @spec list_events(Ecto.UUID.t(), keyword()) :: [Event.t()]
  def list_events(family_id, opts \\ []) do
    from_datetime = Keyword.get(opts, :from)
    to_datetime = Keyword.get(opts, :to)

    Event
    |> where([e], e.family_id == ^family_id)
    |> maybe_from(from_datetime)
    |> maybe_to(to_datetime)
    |> order_by([e], asc: e.starts_at, asc: e.inserted_at)
    |> Repo.all()
    |> Repo.preload([:creator, :updated_by])
  end

  @spec get_event!(Ecto.UUID.t(), Ecto.UUID.t()) :: Event.t()
  def get_event!(family_id, event_id) do
    Event
    |> Repo.get_by!(id: event_id, family_id: family_id)
    |> Repo.preload([:creator, :updated_by])
  end

  @spec create_event(Ecto.UUID.t(), Ecto.UUID.t(), map()) ::
          {:ok, Event.t()} | {:error, term()}
  def create_event(family_id, profile_id, attrs) do
    attrs = normalize_event_attrs(attrs)

    Repo.transaction(fn ->
      _ = ensure_membership(family_id, profile_id)

      event_attrs =
        attrs
        |> Map.put(:family_id, family_id)
        |> Map.put(:created_by_profile_id, profile_id)
        |> Map.put(:updated_by_profile_id, profile_id)

      case %Event{} |> Event.changeset(event_attrs) |> Repo.insert() do
        {:ok, event} -> Repo.preload(event, [:creator, :updated_by])
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> normalize_transaction()
  end

  @spec update_event(Ecto.UUID.t(), Ecto.UUID.t(), Ecto.UUID.t(), map()) ::
          {:ok, Event.t()} | {:error, term()}
  def update_event(family_id, event_id, profile_id, attrs) do
    attrs = normalize_event_attrs(attrs)

    Repo.transaction(fn ->
      _ = ensure_membership(family_id, profile_id)

      event = Repo.get_by!(Event, id: event_id, family_id: family_id)

      update_attrs = Map.put(attrs, :updated_by_profile_id, profile_id)

      case event |> Event.changeset(update_attrs) |> Repo.update() do
        {:ok, event} -> Repo.preload(event, [:creator, :updated_by])
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> normalize_transaction()
  end

  @spec delete_event(Ecto.UUID.t(), Ecto.UUID.t(), Ecto.UUID.t()) ::
          {:ok, Event.t()} | {:error, term()}
  def delete_event(family_id, event_id, profile_id) do
    Repo.transaction(fn ->
      _ = ensure_membership(family_id, profile_id)

      event = Repo.get_by!(Event, id: event_id, family_id: family_id)

      case Repo.delete(event) do
        {:ok, event} -> event
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> normalize_transaction()
  end

  defp preload_family(family_id) do
    get_family!(family_id)
  end

  defp maybe_from(query, nil), do: query
  defp maybe_from(query, %DateTime{} = from_datetime) do
    where(query, [e], e.ends_at >= ^from_datetime)
  end

  defp maybe_to(query, nil), do: query
  defp maybe_to(query, %DateTime{} = to_datetime) do
    where(query, [e], e.starts_at <= ^to_datetime)
  end

  defp ensure_slug(attrs) do
    attrs
    |> Map.get(:slug) || Map.get(attrs, "slug") || Map.get(attrs, :name) || Map.get(attrs, "name") || "familie"
    |> slugify()
    |> unique_slug()
  end

  defp fetch_time_zone(attrs) do
    attrs[:time_zone] || attrs["time_zone"] || @default_time_zone
  end

  defp slugify(value) do
    value
    |> to_string()
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s-]/u, "")
    |> String.replace(~r/[\s_]+/, "-")
    |> String.trim("-")
    |> case do
      "" -> "familie"
      other -> other
    end
  end

  defp unique_slug(base_slug) do
    case slug_available?(base_slug) do
      true -> base_slug
      false -> unique_slug(base_slug, 2)
    end
  end

  defp unique_slug(base_slug, counter) do
    candidate = "#{base_slug}-#{counter}"

    if slug_available?(candidate) do
      candidate
    else
      unique_slug(base_slug, counter + 1)
    end
  end

  defp slug_available?(candidate) do
    not Repo.exists?(from f in Family, where: f.slug == ^candidate)
  end

  defp normalize_event_attrs(attrs) do
    attrs
    |> Map.new()
    |> maybe_put_ends_at()
  end

  defp maybe_put_ends_at(%{ends_at: _} = attrs), do: attrs
  defp maybe_put_ends_at(%{"ends_at" => _} = attrs), do: attrs

  defp maybe_put_ends_at(attrs) do
    case Map.get(attrs, :starts_at) || Map.get(attrs, "starts_at") do
      nil -> attrs
      starts_at -> Map.put(attrs, :ends_at, starts_at)
    end
  end

  defp normalize_transaction({:ok, result}), do: {:ok, result}
  defp normalize_transaction({:error, reason}), do: {:error, reason}
  defp normalize_transaction({:error, reason, _failed, _changes}), do: {:error, reason}
end
