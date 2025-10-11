defmodule AuthProvider.Guardian do
  use Guardian, otp_app: :auth_provider,
                    permissions: %{
                      default: [:access],
                      teams: %{
                        owner: 0b000001,
                        admin: 0b000010,
                        channels_read: 0b000100,
                        channels_write: 0b001000,
                      }
                    }
  use Guardian.Permissions, encoding: Guardian.Permissions.BitwiseEncoding

  def issue_token_for_team(team_name, team_id, uid, profile_id \\ nil) do
    resource = AuthProvider.Account.User.get_by_uid(uid)
    if is_nil(profile_id) do
      encode_and_sign(resource, %{ten: team_name, tei: team_id})
    else
      encode_and_sign(resource, %{ten: team_name, tei: team_id, pid: profile_id})
    end
  end

  def subject_for_token(%{id: uid}, _claims) do
    # You can use any value for the subject of your token but
    # it should be useful in retrieving the resource later, see
    # how it being used on `resource_from_claims/1` function.
    # A unique `id` is a good subject, a non-unique email address
    # is a poor subject.
    sub = to_string(uid)
    {:ok, sub}
  end

  def subject_for_token(_, _) do
    {:error, :reason_for_error}
  end

  @spec resource_from_claims(any()) :: {:error, :reason_for_error} | {:ok, any()}
  def resource_from_claims(%{"sub" => id}) do
    # Here we'll look up our resource from the claims, the subject can be
    # found in the `"sub"` key. In above `subject_for_token/2` we returned
    # the resource id so here we'll rely on that to look it up.
    resource = AuthProvider.Account.User.get_by_uid(id)
    {:ok,  resource}
  end
  def resource_from_claims(_claims) do
    {:error, :reason_for_error}
  end

  def build_claims(claims, _resource, opts) do
    claims =
      claims
      |> encode_permissions_into_claims!(Keyword.get(opts, :permissions))
    {:ok, claims}
  end

  # Guardian DB callbacks

  def after_encode_and_sign(resource, claims, token, _options) do
    with {:ok, _} <- Guardian.DB.after_encode_and_sign(resource, claims["typ"], claims, token) do
      {:ok, token}
    end
  end

  def on_verify(claims, token, _options) do
    with {:ok, _} <- Guardian.DB.on_verify(claims, token) do
      {:ok, claims}
    end
  end

  def on_refresh({old_token, old_claims}, {new_token, new_claims}, _options) do
    with {:ok, _, _} <- Guardian.DB.on_refresh({old_token, old_claims}, {new_token, new_claims}) do
      {:ok, {old_token, old_claims}, {new_token, new_claims}}
    end
  end

  def on_revoke(claims, token, _options) do
    with {:ok, _} <- Guardian.DB.on_revoke(claims, token) do
      {:ok, claims}
    end
  end
end
