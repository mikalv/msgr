# Pending Noise tests

These suites targeted the in-process Elixir Noise transport (`Messngr.Transport.Noise.*`,
`Messngr.Noise.DevHandshake`, session registry) that has been replaced by the Rust
gateway.

They are kept as `.disabled` so `mix test` / coverage stay green until the flows are
reimplemented against the gateway (see issues #222 / #223).
