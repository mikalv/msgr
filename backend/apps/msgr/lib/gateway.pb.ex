defmodule Noise.V1.SessionNotification do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :session_id, 1, type: :string, json_name: "sessionId"
  field :session_token, 2, type: :string, json_name: "sessionToken"
  field :pattern, 3, type: :string
  field :handshake_hash, 4, type: :bytes, json_name: "handshakeHash"
  field :device_key, 5, type: :string, json_name: "deviceKey"
  field :created_at, 6, type: :int64, json_name: "createdAt"
  field :ttl_seconds, 7, type: :int32, json_name: "ttlSeconds"
end

defmodule Noise.V1.SessionAck do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :acknowledged, 1, type: :bool
end

defmodule Noise.V1.VerifyTokenRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :session_token, 1, type: :string, json_name: "sessionToken"
end

defmodule Noise.V1.VerifyTokenResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :valid, 1, type: :bool
  field :session_id, 2, proto3_optional: true, type: :string, json_name: "sessionId"
  field :remaining_ttl, 3, proto3_optional: true, type: :int32, json_name: "remainingTtl"
  field :metadata, 4, proto3_optional: true, type: Noise.V1.SessionMetadata
end

defmodule Noise.V1.SessionMetadata do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :account_id, 1, proto3_optional: true, type: :string, json_name: "accountId"
  field :profile_id, 2, proto3_optional: true, type: :string, json_name: "profileId"
  field :device_id, 3, proto3_optional: true, type: :string, json_name: "deviceId"
  field :handshake_hash, 4, type: :bytes, json_name: "handshakeHash"
  field :pattern, 5, type: :string
end

defmodule Noise.V1.ValidateDeviceRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :device_public_key, 1, type: :string, json_name: "devicePublicKey"
end

defmodule Noise.V1.ValidateDeviceResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :valid, 1, type: :bool
  field :device_id, 2, proto3_optional: true, type: :string, json_name: "deviceId"
  field :account_id, 3, proto3_optional: true, type: :string, json_name: "accountId"
  field :profile_id, 4, proto3_optional: true, type: :string, json_name: "profileId"
  field :enabled, 5, proto3_optional: true, type: :bool
  field :error, 6, proto3_optional: true, type: :string
end

defmodule Noise.V1.BindAccountRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :session_id, 1, type: :string, json_name: "sessionId"
  field :session_token, 2, type: :string, json_name: "sessionToken"
  field :account_id, 3, type: :string, json_name: "accountId"
  field :profile_id, 4, proto3_optional: true, type: :string, json_name: "profileId"
  field :device_id, 5, proto3_optional: true, type: :string, json_name: "deviceId"
end

defmodule Noise.V1.BindAccountResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :success, 1, type: :bool
  field :error, 2, proto3_optional: true, type: :string
end

defmodule Noise.V1.DeleteSessionRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :session_id, 1, type: :string, json_name: "sessionId"
end

defmodule Noise.V1.DeleteSessionResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :deleted, 1, type: :bool
end

defmodule Noise.V1.HealthRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3
end

defmodule Noise.V1.HealthResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :status, 1, type: :string
  field :active_sessions, 2, type: :uint64, json_name: "activeSessions"
  field :uptime_seconds, 3, type: :uint64, json_name: "uptimeSeconds"
end
