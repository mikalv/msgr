defmodule MainProxy.Test.Endpoint do
  use Phoenix.Endpoint, otp_app: :edge_router
  plug(MainProxy.Test.Router)
end
