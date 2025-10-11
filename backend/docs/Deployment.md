Your application is ready to be deployed in a release!

See https://hexdocs.pm/mix/Mix.Tasks.Release.html for more information about Elixir releases.

Using the generated Dockerfile, your release will be bundled into
a Docker image, ready for deployment on platforms that support Docker.

For more information about deploying with Docker see
https://hexdocs.pm/phoenix/releases.html#containers

Here are some useful release commands you can run in any release environment:

    # To build a release
    mix release

    # To start your system with the Phoenix server running
    _build/dev/rel/msgr_web/bin/server

    # To run migrations
    _build/dev/rel/msgr_web/bin/migrate

Once the release is running you can connect to it remotely:

    _build/dev/rel/msgr_web/bin/msgr_web remote

To list all commands:

    _build/dev/rel/msgr_web/bin/msgr_web

[warn] Conditional server startup is missing from runtime configuration.

Add the following to the top of your config/runtime.exs:

    if System.get_env("PHX_SERVER") do
      config :msgr_web, MessngrWeb.Endpoint, server: true
    end

[warn] Environment based URL export is missing from runtime configuration.

Add the following to your config/runtime.exs:

    host = System.get_env("PHX_HOST") || "example.com"

    config :msgr_web, MessngrWeb.Endpoint,
      ...,
      url: [host: host, port: 443]

