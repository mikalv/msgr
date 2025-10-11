defmodule TeamsWeb.Plugs.AuthPipeline do
  use Guardian.Plug.Pipeline, otp_app: :teams,
    module: AuthProvider.Guardian,
    error_handler: TeamsWeb.AuthErrorHandler

  @claims %{typ: "access"}

  plug Guardian.Plug.VerifySession, claims: @claims
  plug Guardian.Plug.VerifyHeader, claims: @claims, scheme: "Bearer"
  plug Guardian.Plug.EnsureAuthenticated
  plug Guardian.Plug.LoadResource, allow_blank: true
end
