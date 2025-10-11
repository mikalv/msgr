defmodule FamilySpace do
  @moduledoc """
  Domain logic for collaborative family spaces including shared calendars,
  shopping lists, and general todo management.
  """

  import Ecto.Query

  alias Messngr.Repo
  alias FamilySpace.{
    Event,
    Membership,
    ShoppingItem,
    ShoppingList,
    Space,
    TodoItem,
    TodoList
  }

  @default_time_zone "Etc/UTC"

  # -- Spaces -----------------------------------------------------------------

  @spec list_spaces(Ecto.UUID.t(), keyword()) :: [Space.t()]
  def list_spaces(profile_id, opts \\ []) do
    kind = Keyword.get(opts, :kind)

    Space
    |> join(:inner, [s], m in assoc(s, :memberships), on: m.profile_id == ^profile_id)
    |> maybe_filter_kind(kind)
    |> distinct(true)
    |> preload([s], memberships: [:profile])
    |> Repo.all()
  end

  @spec get_space!(Ecto.UUID.t(), keyword()) :: Space.t()
  def get_space!(space_id, opts \\ []) do
    preloads =
      opts
      |> Keyword.get(:preload, [memberships: [:profile]])

    Space
    |> Repo.get!(space_id)
    |> Repo.preload(preloads)
  end

  @spec create_space(Ecto.UUID.t(), map()) :: {:ok, Space.t()} | {:error, term()}
  def create_space(owner_profile_id, attrs) do
    attrs = Map.new(attrs)

    Repo.transaction(fn ->
      space_attrs =
        attrs
        |> Map.put_new(:time_zone, fetch_time_zone(attrs))
        |> Map.put(:slug, ensure_slug(attrs))

      with {:ok, %Space{id: space_id}} <- %Space{} |> Space.changeset(space_attrs) |> Repo.insert(),
           {:ok, _membership} <-
             %Membership{}
             |> Membership.changeset(%{
               space_id: space_id,
               profile_id: owner_profile_id,
               role: :owner
             })
             |> Repo.insert() do
        preload_space(space_id)
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> normalize_transaction()
  end

  @spec add_member(Ecto.UUID.t(), Ecto.UUID.t(), Membership.role()) ::
          {:ok, Membership.t()} | {:error, Ecto.Changeset.t()}
  def add_member(space_id, profile_id, role \\ :member) do
    %Membership{}
    |> Membership.changeset(%{space_id: space_id, profile_id: profile_id, role: role})
    |> Repo.insert()
  end

  @spec remove_member(Ecto.UUID.t(), Ecto.UUID.t()) :: {:ok, Membership.t()} | {:error, term()}
  def remove_member(space_id, profile_id) do
    case Repo.get_by(Membership, space_id: space_id, profile_id: profile_id) do
      nil -> {:error, :not_found}
      membership -> Repo.delete(membership)
    end
  end

  @spec ensure_membership(Ecto.UUID.t(), Ecto.UUID.t()) :: Membership.t()
  def ensure_membership(space_id, profile_id) do
    Repo.get_by!(Membership, space_id: space_id, profile_id: profile_id)
  end

  # -- Calendar ----------------------------------------------------------------

  @spec list_events(Ecto.UUID.t(), keyword()) :: [Event.t()]
  def list_events(space_id, opts \\ []) do
    from_datetime = Keyword.get(opts, :from)
    to_datetime = Keyword.get(opts, :to)

    Event
    |> where([e], e.space_id == ^space_id)
    |> maybe_from(from_datetime)
    |> maybe_to(to_datetime)
    |> order_by([e], asc: e.starts_at, asc: e.inserted_at)
    |> Repo.all()
    |> Repo.preload([:creator, :updated_by])
  end

  @spec get_event!(Ecto.UUID.t(), Ecto.UUID.t()) :: Event.t()
  def get_event!(space_id, event_id) do
    Event
    |> Repo.get_by!(id: event_id, space_id: space_id)
    |> Repo.preload([:creator, :updated_by])
  end

  @spec create_event(Ecto.UUID.t(), Ecto.UUID.t(), map()) :: {:ok, Event.t()} | {:error, term()}
  def create_event(space_id, profile_id, attrs) do
    attrs = normalize_event_attrs(attrs)

    Repo.transaction(fn ->
      _ = ensure_membership(space_id, profile_id)

      event_attrs =
        attrs
        |> Map.put(:space_id, space_id)
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
  def update_event(space_id, event_id, profile_id, attrs) do
    attrs = normalize_event_attrs(attrs)

    Repo.transaction(fn ->
      _ = ensure_membership(space_id, profile_id)

      event = Repo.get_by!(Event, id: event_id, space_id: space_id)
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
  def delete_event(space_id, event_id, profile_id) do
    Repo.transaction(fn ->
      _ = ensure_membership(space_id, profile_id)

      event = Repo.get_by!(Event, id: event_id, space_id: space_id)

      case Repo.delete(event) do
        {:ok, event} -> event
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> normalize_transaction()
  end

  # -- Shopping lists ---------------------------------------------------------

  @spec list_shopping_lists(Ecto.UUID.t(), keyword()) :: [ShoppingList.t()]
  def list_shopping_lists(space_id, opts \\ []) do
    include_archived? = Keyword.get(opts, :include_archived, false)

    ShoppingList
    |> where([l], l.space_id == ^space_id)
    |> maybe_exclude_archived(include_archived?)
    |> order_by([l], asc: l.inserted_at)
    |> Repo.all()
    |> Repo.preload([:created_by, items: [:added_by, :checked_by]])
  end

  @spec get_shopping_list!(Ecto.UUID.t(), Ecto.UUID.t()) :: ShoppingList.t()
  def get_shopping_list!(space_id, list_id) do
    ShoppingList
    |> Repo.get_by!(id: list_id, space_id: space_id)
    |> Repo.preload([:created_by, items: [:added_by, :checked_by]])
  end

  @spec create_shopping_list(Ecto.UUID.t(), Ecto.UUID.t(), map()) ::
          {:ok, ShoppingList.t()} | {:error, term()}
  def create_shopping_list(space_id, profile_id, attrs) do
    attrs = Map.new(attrs)

    Repo.transaction(fn ->
      _ = ensure_membership(space_id, profile_id)

      list_attrs =
        attrs
        |> Map.put(:space_id, space_id)
        |> Map.put(:created_by_profile_id, profile_id)

      case %ShoppingList{} |> ShoppingList.changeset(list_attrs) |> Repo.insert() do
        {:ok, list} -> Repo.preload(list, [:created_by, items: [:added_by, :checked_by]])
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> normalize_transaction()
  end

  @spec update_shopping_list(Ecto.UUID.t(), Ecto.UUID.t(), Ecto.UUID.t(), map()) ::
          {:ok, ShoppingList.t()} | {:error, term()}
  def update_shopping_list(space_id, list_id, profile_id, attrs) do
    attrs = Map.new(attrs)

    Repo.transaction(fn ->
      _ = ensure_membership(space_id, profile_id)

      list = Repo.get_by!(ShoppingList, id: list_id, space_id: space_id)

      case list |> ShoppingList.changeset(attrs) |> Repo.update() do
        {:ok, list} -> Repo.preload(list, [:created_by, items: [:added_by, :checked_by]])
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> normalize_transaction()
  end

  @spec delete_shopping_list(Ecto.UUID.t(), Ecto.UUID.t(), Ecto.UUID.t()) ::
          {:ok, ShoppingList.t()} | {:error, term()}
  def delete_shopping_list(space_id, list_id, profile_id) do
    Repo.transaction(fn ->
      _ = ensure_membership(space_id, profile_id)

      list = Repo.get_by!(ShoppingList, id: list_id, space_id: space_id)

      case Repo.delete(list) do
        {:ok, list} -> list
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> normalize_transaction()
  end

  @spec add_shopping_item(Ecto.UUID.t(), Ecto.UUID.t(), Ecto.UUID.t(), map()) ::
          {:ok, ShoppingItem.t()} | {:error, term()}
  def add_shopping_item(space_id, list_id, profile_id, attrs) do
    attrs = Map.new(attrs)

    Repo.transaction(fn ->
      _list = ensure_shopping_list(space_id, list_id, profile_id)

      item_attrs =
        attrs
        |> Map.put(:list_id, list_id)
        |> Map.put(:added_by_profile_id, profile_id)
        |> maybe_put_checked(profile_id)

      case %ShoppingItem{} |> ShoppingItem.changeset(item_attrs) |> Repo.insert() do
        {:ok, item} -> Repo.preload(item, [:added_by, :checked_by])
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> normalize_transaction()
  end

  @spec update_shopping_item(Ecto.UUID.t(), Ecto.UUID.t(), Ecto.UUID.t(), Ecto.UUID.t(), map()) ::
          {:ok, ShoppingItem.t()} | {:error, term()}
  def update_shopping_item(space_id, list_id, item_id, profile_id, attrs) do
    attrs = Map.new(attrs)

    Repo.transaction(fn ->
      ensure_shopping_list(space_id, list_id, profile_id)

      item = Repo.get_by!(ShoppingItem, id: item_id, list_id: list_id)

      update_attrs =
        attrs
        |> maybe_put_checked(profile_id)

      case item |> ShoppingItem.changeset(update_attrs) |> Repo.update() do
        {:ok, item} -> Repo.preload(item, [:added_by, :checked_by])
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> normalize_transaction()
  end

  @spec delete_shopping_item(Ecto.UUID.t(), Ecto.UUID.t(), Ecto.UUID.t(), Ecto.UUID.t()) ::
          {:ok, ShoppingItem.t()} | {:error, term()}
  def delete_shopping_item(space_id, list_id, item_id, profile_id) do
    Repo.transaction(fn ->
      ensure_shopping_list(space_id, list_id, profile_id)

      item = Repo.get_by!(ShoppingItem, id: item_id, list_id: list_id)

      case Repo.delete(item) do
        {:ok, item} -> item
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> normalize_transaction()
  end

  # -- Todo lists -------------------------------------------------------------

  @spec list_todo_lists(Ecto.UUID.t(), keyword()) :: [TodoList.t()]
  def list_todo_lists(space_id, opts \\ []) do
    include_archived? = Keyword.get(opts, :include_archived, false)

    TodoList
    |> where([l], l.space_id == ^space_id)
    |> maybe_exclude_archived(include_archived?)
    |> order_by([l], asc: l.inserted_at)
    |> Repo.all()
    |> Repo.preload([:created_by, items: [:created_by, :assignee, :completed_by]])
  end

  @spec get_todo_list!(Ecto.UUID.t(), Ecto.UUID.t()) :: TodoList.t()
  def get_todo_list!(space_id, list_id) do
    TodoList
    |> Repo.get_by!(id: list_id, space_id: space_id)
    |> Repo.preload([:created_by, items: [:created_by, :assignee, :completed_by]])
  end

  @spec create_todo_list(Ecto.UUID.t(), Ecto.UUID.t(), map()) ::
          {:ok, TodoList.t()} | {:error, term()}
  def create_todo_list(space_id, profile_id, attrs) do
    attrs = Map.new(attrs)

    Repo.transaction(fn ->
      _ = ensure_membership(space_id, profile_id)

      list_attrs =
        attrs
        |> Map.put(:space_id, space_id)
        |> Map.put(:created_by_profile_id, profile_id)

      case %TodoList{} |> TodoList.changeset(list_attrs) |> Repo.insert() do
        {:ok, list} -> Repo.preload(list, [:created_by, items: [:created_by, :assignee, :completed_by]])
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> normalize_transaction()
  end

  @spec update_todo_list(Ecto.UUID.t(), Ecto.UUID.t(), Ecto.UUID.t(), map()) ::
          {:ok, TodoList.t()} | {:error, term()}
  def update_todo_list(space_id, list_id, profile_id, attrs) do
    attrs = Map.new(attrs)

    Repo.transaction(fn ->
      _ = ensure_membership(space_id, profile_id)

      list = Repo.get_by!(TodoList, id: list_id, space_id: space_id)

      case list |> TodoList.changeset(attrs) |> Repo.update() do
        {:ok, list} -> Repo.preload(list, [:created_by, items: [:created_by, :assignee, :completed_by]])
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> normalize_transaction()
  end

  @spec delete_todo_list(Ecto.UUID.t(), Ecto.UUID.t(), Ecto.UUID.t()) ::
          {:ok, TodoList.t()} | {:error, term()}
  def delete_todo_list(space_id, list_id, profile_id) do
    Repo.transaction(fn ->
      list = ensure_todo_list(space_id, list_id, profile_id)

      case Repo.delete(list) do
        {:ok, list} -> list
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> normalize_transaction()
  end

  @spec add_todo_item(Ecto.UUID.t(), Ecto.UUID.t(), Ecto.UUID.t(), map()) ::
          {:ok, TodoItem.t()} | {:error, term()}
  def add_todo_item(space_id, list_id, profile_id, attrs) do
    attrs = Map.new(attrs)

    Repo.transaction(fn ->
      _list = ensure_todo_list(space_id, list_id, profile_id)

      item_attrs =
        attrs
        |> Map.put(:list_id, list_id)
        |> Map.put(:created_by_profile_id, profile_id)
        |> maybe_put_completion(profile_id)

      case %TodoItem{} |> TodoItem.changeset(item_attrs) |> Repo.insert() do
        {:ok, item} -> Repo.preload(item, [:created_by, :assignee, :completed_by])
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> normalize_transaction()
  end

  @spec update_todo_item(
          Ecto.UUID.t(),
          Ecto.UUID.t(),
          Ecto.UUID.t(),
          Ecto.UUID.t(),
          map()
        ) :: {:ok, TodoItem.t()} | {:error, term()}
  def update_todo_item(space_id, list_id, item_id, profile_id, attrs) do
    attrs = Map.new(attrs)

    Repo.transaction(fn ->
      ensure_todo_list(space_id, list_id, profile_id)

      item = Repo.get_by!(TodoItem, id: item_id, list_id: list_id)

      update_attrs = maybe_put_completion(attrs, profile_id)

      case item |> TodoItem.changeset(update_attrs) |> Repo.update() do
        {:ok, item} -> Repo.preload(item, [:created_by, :assignee, :completed_by])
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> normalize_transaction()
  end

  @spec delete_todo_item(Ecto.UUID.t(), Ecto.UUID.t(), Ecto.UUID.t(), Ecto.UUID.t()) ::
          {:ok, TodoItem.t()} | {:error, term()}
  def delete_todo_item(space_id, list_id, item_id, profile_id) do
    Repo.transaction(fn ->
      ensure_todo_list(space_id, list_id, profile_id)

      item = Repo.get_by!(TodoItem, id: item_id, list_id: list_id)

      case Repo.delete(item) do
        {:ok, item} -> item
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> normalize_transaction()
  end

  # -- Helpers ----------------------------------------------------------------

  defp preload_space(space_id) do
    get_space!(space_id)
  end

  defp ensure_shopping_list(space_id, list_id, profile_id) do
    _ = ensure_membership(space_id, profile_id)

    case Repo.get_by(ShoppingList, id: list_id, space_id: space_id) do
      %ShoppingList{} = list -> list
      nil -> raise Ecto.NoResultsError, queryable: ShoppingList
    end
  end

  defp ensure_todo_list(space_id, list_id, profile_id) do
    _ = ensure_membership(space_id, profile_id)

    case Repo.get_by(TodoList, id: list_id, space_id: space_id) do
      %TodoList{} = list -> list
      nil -> raise Ecto.NoResultsError, queryable: TodoList
    end
  end

  defp maybe_filter_kind(query, nil), do: query
  defp maybe_filter_kind(query, kind) do
    where(query, [s], s.kind == ^kind)
  end

  defp maybe_from(query, nil), do: query
  defp maybe_from(query, %DateTime{} = from_datetime) do
    where(query, [e], e.ends_at >= ^from_datetime)
  end

  defp maybe_to(query, nil), do: query
  defp maybe_to(query, %DateTime{} = to_datetime) do
    where(query, [e], e.starts_at <= ^to_datetime)
  end

  defp maybe_exclude_archived(query, true), do: query
  defp maybe_exclude_archived(query, false) do
    where(query, [l], l.status != :archived)
  end

  defp ensure_slug(attrs) do
    attrs
    |> Map.get(:slug) || Map.get(attrs, "slug") || Map.get(attrs, :name) || Map.get(attrs, "name") || "space"
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
      "" -> "space"
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
    not Repo.exists?(from s in Space, where: s.slug == ^candidate)
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

  defp maybe_put_checked(attrs, profile_id) do
    attrs = Map.new(attrs)

    checked =
      case Map.fetch(attrs, :checked) do
        {:ok, value} -> value
        :error -> Map.get(attrs, "checked")
      end

    cond do
      checked in [true, "true", 1] ->
        attrs
        |> Map.put(:checked, true)
        |> Map.put_new(:checked_by_profile_id, profile_id)

      checked in [false, "false", 0] ->
        attrs
        |> Map.put(:checked, false)
        |> Map.put(:checked_by_profile_id, nil)

      true ->
        attrs
    end
  end

  defp maybe_put_completion(attrs, profile_id) do
    attrs = Map.new(attrs)
    status = Map.get(attrs, :status) || Map.get(attrs, "status")

    cond do
      status in [:done, "done"] and is_nil(Map.get(attrs, :completed_by_profile_id)) ->
        attrs
        |> Map.put(:completed_by_profile_id, profile_id)
        |> Map.put(:status, :done)

      status in [:pending, "pending", :in_progress, "in_progress"] ->
        attrs
        |> Map.put(:completed_by_profile_id, nil)

      true ->
        attrs
    end
  end

  defp normalize_transaction({:ok, result}), do: {:ok, result}
  defp normalize_transaction({:error, reason}), do: {:error, reason}
  defp normalize_transaction({:error, reason, _failed, _changes}), do: {:error, reason}
end
