defmodule MessngrWeb.ConversationChannel do
  @moduledoc """
  Phoenix Channel som eksponerer sanntidsoppdateringer for samtaler.
  """

  use MessngrWeb, :channel

  alias Ecto.Changeset
  alias Messngr
  alias Messngr.Chat
  alias MessngrWeb.MessageJSON

  @impl true
  def join("conversation:" <> conversation_id, params, socket) do
    with {:ok, profile} <- fetch_profile(params),
         :ok <- authorize_membership(conversation_id, profile) do
      :ok = Chat.subscribe_to_conversation(conversation_id)

      socket =
        socket
        |> assign(:conversation_id, conversation_id)
        |> assign(:current_profile, profile)

      {:ok, socket}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def handle_in("message:create", payload, socket) when is_map(payload) do
    with {:ok, body} <- extract_body(payload),
         {:ok, message} <-
           Messngr.send_message(socket.assigns.conversation_id, socket.assigns.current_profile.id, %{
             "body" => body
           }) do
      {:reply, {:ok, MessageJSON.show(%{message: message})}, socket}
    else
      {:error, %Changeset{} = changeset} ->
        {:reply, {:error, %{errors: translate_errors(changeset)}}, socket}

      {:error, %{errors: _} = errors} ->
        {:reply, {:error, errors}, socket}

      {:error, %{reason: _} = reason} ->
        {:reply, {:error, reason}, socket}

      {:error, reason} when is_binary(reason) ->
        {:reply, {:error, %{errors: [reason]}}, socket}
    end
  end

  def handle_in("message:create", _payload, socket) do
    {:reply, {:error, %{errors: ["invalid payload"]}}, socket}
  end

  @impl true
  def handle_info({:message_created, message}, socket) do
    push(socket, "message_created", MessageJSON.show(%{message: message}))
    {:noreply, socket}
  end

  defp fetch_profile(%{"account_id" => account_id, "profile_id" => profile_id}) do
    profile = Chat.ensure_profile!(account_id, profile_id)
    {:ok, profile}
  rescue
    _ -> {:error, %{reason: "unauthorized"}}
  end

  defp fetch_profile(_), do: {:error, %{reason: "unauthorized"}}

  defp authorize_membership(conversation_id, profile) do
    case Messngr.ensure_membership(conversation_id, profile.id) do
      _participant -> :ok
    end
  rescue
    Ecto.NoResultsError -> {:error, %{reason: "forbidden"}}
  end

  defp extract_body(%{"body" => body}) when is_binary(body) do
    trimmed = String.trim(body)

    if trimmed == "" do
      {:error, %{errors: ["body can't be blank"]}}
    else
      {:ok, trimmed}
    end
  end

  defp extract_body(_), do: {:error, %{errors: ["body is required"]}}

  defp translate_errors(changeset) do
    Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
