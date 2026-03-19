# Find eligible builder and runner images at
# https://hub.docker.com/r/hexpm/elixir/tags
#
# This Dockerfile is optimized for Phoenix projects.
# Adjust versions to match your project's requirements.

ARG ELIXIR_VERSION=1.18.3
ARG OTP_VERSION=27.3.4.8
ARG DEBIAN_VERSION=bookworm-20260202-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

# ---- Build Stage ----
FROM ${BUILDER_IMAGE} AS builder

# Install build dependencies
RUN apt-get update -y && apt-get install -y build-essential git curl \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set build env
ENV MIX_ENV="prod"

WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && mix local.rebar --force

# Install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# Copy config files (before compile for config-time compilation)
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

# Copy application code
COPY lib lib
COPY business business
COPY priv priv
COPY assets assets
COPY rel rel

# Compile assets
RUN mix assets.deploy

# Compile the release (copy runtime config)
COPY config/runtime.exs config/
RUN mix compile

# Build the release
RUN mix release

# ---- Runner Stage ----
FROM ${RUNNER_IMAGE}

RUN apt-get update -y && \
    apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG="en_US.UTF-8"
ENV LANGUAGE="en_US:en"
ENV LC_ALL="en_US.UTF-8"

WORKDIR /app
RUN chown nobody /app

ENV MIX_ENV="prod"

# Copy the release from the build stage
COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/agentic_ui ./

USER nobody

# Migrate and start
CMD ["/app/bin/migrate_and_server"]
