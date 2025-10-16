defmodule Messngr.Notifications.PushAdapters.Log do
  @moduledoc """
  Push adapter that simply logs dispatches.
  Useful for development and tests.
  """

  require Logger

  alias Messngr.Notifications.DevicePushToken

  @spec push(DevicePushToken.t(), map(), map()) :: %{token_id: binary(), status: :queued}
  def push(%DevicePushToken{} = token, payload, context) do
    Logger.debug(fn ->
      [
        "push token=", token.id,
        " platform=", Atom.to_string(token.platform),
        " mode=", Atom.to_string(token.mode),
        " payload=", inspect(payload),
        " context=", inspect(context)
      ]
      |> IO.iodata_to_binary()
    end)

    %{token_id: token.id, status: :queued}
  end
end
