FROM rust:bookworm AS builder

# cmake and clang are required by aws-lc-rs (statically linked TLS)
RUN apt-get update && apt-get install -y cmake clang pkg-config && rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY . .

RUN cargo build --release -p moq-relay && \
    cp target/release/moq-relay /output

FROM debian:bookworm-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends curl certbot python3-pip && \
    pip3 install --break-system-packages certbot-dns-bunny && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /output /usr/local/bin/moq-relay
COPY rs/moq-relay/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
