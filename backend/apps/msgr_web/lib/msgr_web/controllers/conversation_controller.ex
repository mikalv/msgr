defmodule MessngrWeb.ConversationController do
  use MessngrWeb, :controller

  alias Messngr

  action_fallback MessngrWeb.FallbackController

  def index(conn, params) do
    current_profile = conn.assigns.current_profile
    page = Messngr.list_conversations(current_profile.id, build_list_opts(params))

    render(conn, :index, page: page)
  end

  def create(conn, %{"target_profile_id" => target_profile_id}) do
    current_profile = conn.assigns.current_profile

    with {:ok, conversation} <-
           Messngr.ensure_direct_conversation(current_profile.id, target_profile_id) do
      render(conn, :show, conversation: conversation)
    end
  end

  def create(conn, %{"kind" => kind} = params) do
    current_profile = conn.assigns.current_profile
    normalized_kind = String.downcase(kind)

    case normalized_kind do
      "group" ->
        participant_ids = parse_participant_ids(params)
        attrs = %{
          topic: Map.get(params, "topic"),
          structure_type: parse_structure_type(params)
        }

        with {:ok, conversation} <-
               Messngr.create_group_conversation(current_profile.id, participant_ids, attrs) do
          render(conn, :show, conversation: conversation)
        end

      "channel" ->
        attrs = %{
          topic: Map.get(params, "topic"),
          participant_ids: parse_participant_ids(params),
          structure_type: parse_structure_type(params),
          visibility: parse_visibility(params)
        }

        with {:ok, conversation} <- Messngr.create_channel_conversation(current_profile.id, attrs) do
          render(conn, :show, conversation: conversation)
        end

      _ ->
        {:error, :bad_request}
    end
  end

  def create(_conn, _params), do: {:error, :bad_request}

  def watch(conn, %{"id" => conversation_id}) do
    current_profile = conn.assigns.current_profile

    with {:ok, payload} <- Messngr.watch_conversation(conversation_id, current_profile.id) do
      render(conn, :watchers, payload: payload)
    end
  rescue
    Ecto.NoResultsError -> {:error, :forbidden}
  end

  def unwatch(conn, %{"id" => conversation_id}) do
    current_profile = conn.assigns.current_profile

    with {:ok, payload} <- Messngr.unwatch_conversation(conversation_id, current_profile.id) do
      render(conn, :watchers, payload: payload)
    end
  rescue
    Ecto.NoResultsError -> {:error, :forbidden}
  end

  def watchers(conn, %{"id" => conversation_id}) do
    current_profile = conn.assigns.current_profile

    with _ <- Messngr.ensure_membership(conversation_id, current_profile.id) do
      payload = Messngr.list_watchers(conversation_id)
      render(conn, :watchers, payload: payload)
    end
  rescue
    Ecto.NoResultsError -> {:error, :forbidden}
  end

  defp parse_participant_ids(params) do
    params
    |> Map.get("participant_ids")
    |> Kernel.||(Map.get(params, "participantIds"))
    |> List.wrap()
    |> Enum.map(&to_string/1)
  end

  defp parse_structure_type(params) do
    params
    |> Map.get("structure_type")
    |> Kernel.||(Map.get(params, "structureType"))
  end

  defp parse_visibility(params) do
    params
    |> Map.get("visibility")
    |> Kernel.||(Map.get(params, "access"))
    |> Kernel.||(Map.get(params, "hidden") |> hidden_to_visibility())
  end

  defp build_list_opts(params) do
    []
    |> maybe_put(:limit, params["limit"])
    |> maybe_put(:after_id, params["after_id"])
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, :limit, value) do
    case Integer.parse(to_string(value)) do
      {int, _} when int > 0 and int <= 200 -> Keyword.put(opts, :limit, int)
      _ -> opts
    end
  end

  defp maybe_put(opts, :after_id, value), do: Keyword.put(opts, :after_id, value)

  defp hidden_to_visibility(nil), do: nil
  defp hidden_to_visibility(value) when value in [true, "true", 1, "1"], do: "private"
  defp hidden_to_visibility(_value), do: nil
end
