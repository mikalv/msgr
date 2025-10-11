defmodule Teams.ClientBootstrap do
  require Logger
  alias Teams.Repo
  alias Teams.TenantModels.{Conversation, Profile, Room}

  @spec build_bootstrap_payload_for(String.t(), Teams.TenantModels.Profile.t()) :: %{rooms: [map], conversations: [map], messages: [map], profiles: [map], team: map}
  def build_bootstrap_payload_for(tenant, %Profile{} = profile) do
    rooms = Room.list_with_me(tenant, profile) |> Enum.map(&filter_ecto_model_for_json(&1))
    conversations = Conversation.list_with_me(tenant, profile) |> Enum.map(&filter_ecto_model_for_json(&1))
    profiles = Profile.list(tenant) |> Enum.map(&filter_ecto_model_for_json(&1))

    messages = List.flatten(Enum.map(rooms, fn room ->
      Teams.TenantModels.Message.get_for_room(tenant, room.id) |> Enum.map(&filter_msg_for_json(&1))
    end))

    %{rooms: rooms, conversations: conversations, messages: messages, profiles: profiles, team: tenant}
  end

  @spec build_bootstrap_payload_for(String.t(), String.t()) :: map
  def build_bootstrap_payload_for(tenant, profileID) do
    profile = Profile.get_by_id(tenant, profileID)
    build_bootstrap_payload_for(tenant, profile)
  end

  defp filter_msg_for_json(msg), do: Map.drop(Map.from_struct(msg), [:__meta__, :id, :metadata, :room, :conversation, :profile, :parent, :children])

  defp filter_ecto_model_for_json(model), do: Map.drop(Map.from_struct(model), [:__meta__])
end
