defmodule Messngr.Secrets.Manager do
  @moduledoc """
  Behaviour describing a secrets manager capable of returning secret material.

  Implementations must return either the raw secret string or a map with
  metadata when `fetch/2` is invoked. When a map is returned the key
  `"SecretString"` is expected to contain the secret payload as defined by AWS
  Secrets Manager. This allows the default implementation to interoperate with
  AWS while still being generic enough for alternative managers.
  """

  @callback fetch(secret_id :: binary(), opts :: keyword()) ::
              {:ok, binary() | map()} | {:error, term()}
end
