defmodule MessngrWeb.ConversationController do
  use MessngrWeb, :controller

  alias Messngr

  action_fallback MessngrWeb.FallbackController

  def create(conn, %{"target_profile_id" => target_profile_id}) do
    current_profile = conn.assigns.current_profile

    with {:ok, conversation} <-
           Messngr.ensure_direct_conversation(current_profile.id, target_profile_id) do
      render(conn, :show, conversation: conversation)
    end
  end

  def create(_conn, _params), do: {:error, :bad_request}
end
