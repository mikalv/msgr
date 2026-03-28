defmodule Teams.ClientBootstrap do
  require Logger
  alias Teams.Repo
  alias Teams.TenantModels.{Conversation, Profile, Channel}

  @spec build_bootstrap_payload_for(String.t(), Teams.TenantModels.Profile.t()) :: %{
          channels: [map],
          conversations: [map],
          messages: [map],
          profiles: [map],
          team: map
        }
  def build_bootstrap_payload_for(tenant, %Profile{} = profile) do
    channels = Channel.list_with_me(tenant, profile) |> Enum.map(&filter_ecto_model_for_json(&1))

    conversations =
      Conversation.list_with_me(tenant, profile) |> Enum.map(&filter_ecto_model_for_json(&1))

    profiles = Profile.list(tenant) |> Enum.map(&filter_ecto_model_for_json(&1))

    messages =
      List.flatten(
        Enum.map(channels, fn channel ->
          Teams.TenantModels.Message.get_for_channel(tenant, channel.id)
          |> Enum.map(&filter_msg_for_json(&1))
        end)
      )

    %{
      channels: channels,
      conversations: conversations,
      messages: messages,
      profiles: profiles,
      team: tenant
    }
  end

  @spec build_bootstrap_payload_for(String.t(), String.t()) :: map
  def build_bootstrap_payload_for(tenant, profileID) do
    profile = Profile.get_by_id(tenant, profileID)
    build_bootstrap_payload_for(tenant, profile)
  end

  defp filter_msg_for_json(msg),
    do:
      Map.drop(Map.from_struct(msg), [
        :__meta__,
        :id,
        :metadata,
        :channel,
        :conversation,
        :profile,
        :parent,
        :children
      ])

  defp filter_ecto_model_for_json(model), do: Map.drop(Map.from_struct(model), [:__meta__])
end
