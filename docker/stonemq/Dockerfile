# syntax=docker/dockerfile:1.6

ARG STONEMQ_REPOSITORY=https://github.com/jonefeewang/stonemq.git
ARG STONEMQ_REF=main

FROM rust:1.80 as builder
ARG STONEMQ_REPOSITORY
ARG STONEMQ_REF

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       git \
       pkg-config \
       libssl-dev \
       clang \
       make \
       ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN git clone --depth 1 --branch "$STONEMQ_REF" "$STONEMQ_REPOSITORY" .
RUN cargo build --release --bin stonemq

FROM debian:bookworm-slim as runtime
ARG STONEMQ_REF

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates netcat-openbsd tini \
    && rm -rf /var/lib/apt/lists/*

ENV STONEMQ_HOME=/var/lib/stonemq
ENV STONEMQ_CONFIG_DIR=/etc/stonemq
ENV STONEMQ_CONFIG_FILE=${STONEMQ_CONFIG_DIR}/conf.toml

RUN useradd --system --create-home --home-dir ${STONEMQ_HOME} --shell /usr/sbin/nologin stonemq

WORKDIR ${STONEMQ_HOME}

COPY --from=builder /src/target/release/stonemq /usr/local/bin/stonemq
RUN mkdir -p ${STONEMQ_CONFIG_DIR}
COPY docker/stonemq/conf.toml ${STONEMQ_CONFIG_FILE}

RUN mkdir -p ${STONEMQ_HOME}/journal ${STONEMQ_HOME}/queue ${STONEMQ_HOME}/kv_db \
    && chown -R stonemq:stonemq ${STONEMQ_HOME} ${STONEMQ_CONFIG_DIR}

USER stonemq

EXPOSE 9092

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/stonemq"]
CMD ["--conf", "/etc/stonemq/conf.toml"]
