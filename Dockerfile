FROM debian:bookworm-slim

ARG BWDC_VERSION=2026.1.0

RUN apt-get update && apt-get install -y --no-install-recommends \
    libsecret-1-0 \
    curl \
    unzip \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN curl -L "https://github.com/bitwarden/directory-connector/releases/download/v${BWDC_VERSION}/bwdc-linux-${BWDC_VERSION}.zip" -o /tmp/bwdc.zip && \
    unzip /tmp/bwdc.zip -d /usr/local/bin && \
    chmod +x /usr/local/bin/bwdc && \
    rm /tmp/bwdc.zip

RUN useradd -r -s /bin/false bitwarden && \
    mkdir -p /home/bitwarden/.config/Bitwarden\ Directory\ Connector && \
    chown -R bitwarden:bitwarden /home/bitwarden

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh && sed -i 's/\r$//' /entrypoint.sh

ENV BITWARDENCLI_CONNECTOR_PLAINTEXT_SECRETS=true

USER bitwarden

ENTRYPOINT ["/entrypoint.sh"]
