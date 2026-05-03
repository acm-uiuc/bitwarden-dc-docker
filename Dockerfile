# Build stage
FROM node:24-bookworm AS builder

ARG BWDC_VERSION=2026.4.0

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    python3 \
    make \
    g++ \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

RUN git clone --depth 1 --branch v${BWDC_VERSION} \
    https://github.com/bitwarden/directory-connector.git .

RUN npm ci

RUN npm run build:cli:prod && npm run clean:dist:cli

# Determine arch and run pkg with correct target
RUN PKG_ARCH=$(uname -m | sed 's/x86_64/x64/' | sed 's/aarch64/arm64/') && \
    npx pkg ./src-cli --targets linux-${PKG_ARCH} --output ./dist-cli/linux/bwdc

# Runtime stage
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    libsecret-1-0 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /build/dist-cli/linux/ /usr/local/bin/
RUN chmod +x /usr/local/bin/bwdc

RUN useradd -r -s /bin/false bitwarden && \
    mkdir -p "/home/bitwarden/.config/Bitwarden Directory Connector" && \
    chown -R bitwarden:bitwarden /home/bitwarden

COPY entrypoint.sh /entrypoint.sh
COPY healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /entrypoint.sh /usr/local/bin/healthcheck.sh && \
    sed -i 's/\r$//' /entrypoint.sh /usr/local/bin/healthcheck.sh

ENV BITWARDENCLI_CONNECTOR_PLAINTEXT_SECRETS=true

HEALTHCHECK --interval=60s --timeout=10s --start-period=30s --retries=3 \
    CMD ["/usr/local/bin/healthcheck.sh"]

USER bitwarden
ENTRYPOINT ["/entrypoint.sh"]