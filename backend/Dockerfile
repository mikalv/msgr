# ==============================================================================
# Multi-stage Dockerfile for the Messngr Elixir umbrella
# Stages: build, dev, prod
# ==============================================================================

ARG ELIXIR_VERSION=1.17.2
ARG OTP_VERSION=27.0.1
ARG DEBIAN_VERSION=bullseye-20240904-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

# ==============================================================================
# Stage: build — compile deps and create the release
# ==============================================================================
FROM ${BUILDER_IMAGE} AS build

RUN apt-get update -y && apt-get install -y \
      build-essential git curl \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV="prod"

# Install mix dependencies (layer cache)
COPY mix.exs mix.lock ./
COPY config/config.exs config/prod.exs config/
COPY apps/auth_provider/mix.exs ./apps/auth_provider/mix.exs
COPY apps/edge_router/mix.exs   ./apps/edge_router/mix.exs
COPY apps/family_space/mix.exs  ./apps/family_space/mix.exs
COPY apps/llm_gateway/mix.exs   ./apps/llm_gateway/mix.exs
COPY apps/msgr/mix.exs          ./apps/msgr/mix.exs
COPY apps/msgr_web/mix.exs      ./apps/msgr_web/mix.exs
COPY apps/slack_api/mix.exs     ./apps/slack_api/mix.exs
COPY apps/teams/mix.exs         ./apps/teams/mix.exs

RUN mix deps.get --only $MIX_ENV && mix deps.compile

# Copy application source
COPY apps apps
COPY rel rel

# Asset compilation skipped — Flutter is the client, Phoenix serves API only.
# Re-enable when Phoenix LiveView or server-rendered pages are needed:
# RUN for app in msgr_web auth_provider teams; do \
#       if [ -d "apps/$app/assets" ]; then \
#         cd "/app/apps/$app" && mix assets.deploy && cd /app; \
#       fi; \
#     done

# Compile and build the release
RUN mix compile

# Runtime config does not require recompilation
COPY config/runtime.exs config/

RUN mix release chatd

# ==============================================================================
# Stage: dev — development image with tooling and hot-reload support
# ==============================================================================
FROM ${BUILDER_IMAGE} AS dev

RUN apt-get update -y && apt-get install -y \
      build-essential curl git inotify-tools libsodium-dev postgresql-client \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Install Node.js 18 for Phoenix asset tooling
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get update && apt-get install -y --no-install-recommends nodejs \
    && npm install --global npm@9 \
    && rm -rf /var/lib/apt/lists/*

ENV MIX_ENV=dev \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

# Copy minimal files to leverage Docker layer caching for deps
COPY mix.exs mix.lock ./
COPY config ./config
COPY apps/auth_provider/mix.exs ./apps/auth_provider/mix.exs
COPY apps/edge_router/mix.exs   ./apps/edge_router/mix.exs
COPY apps/family_space/mix.exs  ./apps/family_space/mix.exs
COPY apps/llm_gateway/mix.exs   ./apps/llm_gateway/mix.exs
COPY apps/msgr/mix.exs          ./apps/msgr/mix.exs
COPY apps/msgr_web/mix.exs      ./apps/msgr_web/mix.exs
COPY apps/slack_api/mix.exs     ./apps/slack_api/mix.exs
COPY apps/teams/mix.exs         ./apps/teams/mix.exs

RUN mix deps.get

CMD ["mix", "phx.server"]

# ==============================================================================
# Stage: prod — minimal runtime image with only the compiled release
# ==============================================================================
FROM ${RUNNER_IMAGE} AS prod

RUN apt-get update -y && \
    apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates curl \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    MIX_ENV="prod"

WORKDIR /app
RUN chown nobody /app

COPY --from=build --chown=nobody:root /app/_build/prod/rel/chatd ./

USER nobody

EXPOSE 4000 50052

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:4000/api/health || exit 1

CMD ["/app/bin/chatd", "start"]
