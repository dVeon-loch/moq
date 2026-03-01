FROM rust:bookworm AS builder

# cmake and clang are required by aws-lc-rs (statically linked TLS)
RUN apt-get update && apt-get install -y cmake clang pkg-config && rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY . .

ARG package=moq-relay

# moq and moq-token binaries come from differently-named cargo packages
RUN case "${package}" in \
    moq)       cargo build --release -p moq-cli ;; \
    moq-token) cargo build --release -p moq-token-cli ;; \
    *)         cargo build --release -p "${package}" ;; \
    esac && \
    cp target/release/${package} /output

FROM debian:bookworm-slim

ARG package=moq-relay

COPY --from=builder /output /usr/local/bin/app

ENTRYPOINT ["/usr/local/bin/app"]
