defmodule MessngrWeb.RouterJWT do
  @moduledoc """
  JWT-related routes to be merged into the main router.

  Add the following line to `MessngrWeb.Router` in the unauthenticated API scope
  (next to the existing auth routes):

      post "/v1/auth/refresh", AuthController, :refresh

  This was kept in a separate file to avoid merge conflicts with Track A (App Platform)
  which is concurrently modifying router.ex.
  """
end
