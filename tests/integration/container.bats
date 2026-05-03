#!/usr/bin/env bats

# Set IMAGE_NAME in env to skip the local build (e.g. when testing a pre-built image).
IMAGE="${IMAGE_NAME:-bwdc-test}"
FIXTURES="$BATS_TEST_DIRNAME/../fixtures"
CONFIG_PATH="/home/bitwarden/.config/Bitwarden Directory Connector/data.json"

setup_file() {
    chmod +x "$FIXTURES/mock_bwdc.sh"
    if [ -z "$IMAGE_NAME" ]; then
        docker build -t "$IMAGE" "$BATS_TEST_DIRNAME/../.." >&2
    fi
}

# ---------------------------------------------------------------------------
# Image / binary sanity checks (no credentials needed)
# ---------------------------------------------------------------------------

@test "bwdc binary is present and executable" {
    run docker run --rm --entrypoint /bin/sh "$IMAGE" \
        -c "test -x /usr/local/bin/bwdc && echo ok"
    [ "$status" -eq 0 ]
    [ "$output" = "ok" ]
}

@test "container runs as non-root bitwarden user" {
    run docker run --rm --entrypoint /bin/sh "$IMAGE" -c "id -un"
    [ "$status" -eq 0 ]
    [ "$output" = "bitwarden" ]
}

@test "BITWARDENCLI_CONNECTOR_PLAINTEXT_SECRETS is true" {
    run docker run --rm --entrypoint /bin/sh "$IMAGE" \
        -c 'echo "$BITWARDENCLI_CONNECTOR_PLAINTEXT_SECRETS"'
    [ "$status" -eq 0 ]
    [ "$output" = "true" ]
}

@test "healthcheck.sh is present and executable" {
    run docker run --rm --entrypoint /bin/sh "$IMAGE" \
        -c "test -x /usr/local/bin/healthcheck.sh && echo ok"
    [ "$status" -eq 0 ]
    [ "$output" = "ok" ]
}

# ---------------------------------------------------------------------------
# Entrypoint behaviour
# ---------------------------------------------------------------------------

@test "entrypoint exits 1 with an error when data.json is not mounted" {
    run docker run --rm "$IMAGE"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Configuration file not found" ]]
}

@test "sync loop starts and writes heartbeat file" {
    local cid
    cid=$(docker run -d \
        -v "$FIXTURES/mock_bwdc.sh:/usr/local/bin/bwdc" \
        -v "$FIXTURES/data.json:$CONFIG_PATH" \
        -e SYNC_INTERVAL_MIN=60 \
        "$IMAGE")

    # Poll up to 15s for the heartbeat to appear
    local i=0
    while [ "$i" -lt 15 ]; do
        docker exec "$cid" test -f /tmp/bwdc-heartbeat 2>/dev/null && break
        sleep 1
        i=$((i + 1))
    done

    run docker exec "$cid" test -f /tmp/bwdc-heartbeat
    docker rm -f "$cid" >/dev/null 2>&1
    [ "$status" -eq 0 ]
}

@test "healthcheck passes after successful sync" {
    local cid
    cid=$(docker run -d \
        -v "$FIXTURES/mock_bwdc.sh:/usr/local/bin/bwdc" \
        -v "$FIXTURES/data.json:$CONFIG_PATH" \
        -e SYNC_INTERVAL_MIN=60 \
        "$IMAGE")

    # Wait for the sync loop to complete at least one iteration
    local i=0
    while [ "$i" -lt 15 ]; do
        docker exec "$cid" test -f /tmp/bwdc-heartbeat 2>/dev/null && break
        sleep 1
        i=$((i + 1))
    done

    run docker exec "$cid" /usr/local/bin/healthcheck.sh
    docker rm -f "$cid" >/dev/null 2>&1
    [ "$status" -eq 0 ]
}

@test "BW_SERVER env var causes bwdc config server to be called" {
    local cid
    cid=$(docker run -d \
        -v "$FIXTURES/mock_bwdc.sh:/usr/local/bin/bwdc" \
        -v "$FIXTURES/data.json:$CONFIG_PATH" \
        -e BW_SERVER=https://bw.example.com \
        -e SYNC_INTERVAL_MIN=60 \
        "$IMAGE")

    sleep 8

    run docker exec "$cid" cat /tmp/bwdc_calls
    docker rm -f "$cid" >/dev/null 2>&1
    [ "$status" -eq 0 ]
    [[ "$output" =~ "config server https://bw.example.com" ]]
}

@test "BW_DIRECTORY_TYPE env var causes bwdc config directory to be called" {
    local cid
    cid=$(docker run -d \
        -v "$FIXTURES/mock_bwdc.sh:/usr/local/bin/bwdc" \
        -v "$FIXTURES/data.json:$CONFIG_PATH" \
        -e BW_DIRECTORY_TYPE=0 \
        -e SYNC_INTERVAL_MIN=60 \
        "$IMAGE")

    sleep 8

    run docker exec "$cid" cat /tmp/bwdc_calls
    docker rm -f "$cid" >/dev/null 2>&1
    [ "$status" -eq 0 ]
    [[ "$output" =~ "config directory 0" ]]
}

@test "BW_DIRECTORY_KEY with ldap type calls bwdc config ldap.password" {
    local cid
    cid=$(docker run -d \
        -v "$FIXTURES/mock_bwdc.sh:/usr/local/bin/bwdc" \
        -v "$FIXTURES/data.json:$CONFIG_PATH" \
        -e BW_DIRECTORY_TYPE=0 \
        -e BW_DIRECTORY_KEY=supersecret \
        -e SYNC_INTERVAL_MIN=60 \
        "$IMAGE")

    sleep 8

    run docker exec "$cid" cat /tmp/bwdc_calls
    docker rm -f "$cid" >/dev/null 2>&1
    [ "$status" -eq 0 ]
    [[ "$output" =~ "config ldap.password supersecret" ]]
}

@test "BW_DIRECTORY_KEY with azure type (numeric) calls bwdc config azure.key" {
    local cid
    cid=$(docker run -d \
        -v "$FIXTURES/mock_bwdc.sh:/usr/local/bin/bwdc" \
        -v "$FIXTURES/data.json:$CONFIG_PATH" \
        -e BW_DIRECTORY_TYPE=1 \
        -e BW_DIRECTORY_KEY=my-azure-secret \
        -e SYNC_INTERVAL_MIN=60 \
        "$IMAGE")

    sleep 8

    run docker exec "$cid" cat /tmp/bwdc_calls
    docker rm -f "$cid" >/dev/null 2>&1
    [ "$status" -eq 0 ]
    [[ "$output" =~ "config azure.key my-azure-secret" ]]
}

@test "BW_DIRECTORY_KEY with azure type (string) calls bwdc config azure.key" {
    local cid
    cid=$(docker run -d \
        -v "$FIXTURES/mock_bwdc.sh:/usr/local/bin/bwdc" \
        -v "$FIXTURES/data.json:$CONFIG_PATH" \
        -e BW_DIRECTORY_TYPE=azure \
        -e BW_DIRECTORY_KEY=my-azure-secret \
        -e SYNC_INTERVAL_MIN=60 \
        "$IMAGE")

    sleep 8

    run docker exec "$cid" cat /tmp/bwdc_calls
    docker rm -f "$cid" >/dev/null 2>&1
    [ "$status" -eq 0 ]
    [[ "$output" =~ "config azure.key my-azure-secret" ]]
}

@test "azure sync: bwdc config directory is set to type 1" {
    local cid
    cid=$(docker run -d \
        -v "$FIXTURES/mock_bwdc.sh:/usr/local/bin/bwdc" \
        -v "$FIXTURES/data.json:$CONFIG_PATH" \
        -e BW_DIRECTORY_TYPE=1 \
        -e BW_DIRECTORY_KEY=my-azure-secret \
        -e SYNC_INTERVAL_MIN=60 \
        "$IMAGE")

    sleep 8

    run docker exec "$cid" cat /tmp/bwdc_calls
    docker rm -f "$cid" >/dev/null 2>&1
    [ "$status" -eq 0 ]
    [[ "$output" =~ "config directory 1" ]]
    [[ "$output" =~ "config azure.key my-azure-secret" ]]
    [[ "$output" =~ "sync" ]]
}

@test "bwdc sync is called during the sync loop" {
    local cid
    cid=$(docker run -d \
        -v "$FIXTURES/mock_bwdc.sh:/usr/local/bin/bwdc" \
        -v "$FIXTURES/data.json:$CONFIG_PATH" \
        -e SYNC_INTERVAL_MIN=60 \
        "$IMAGE")

    sleep 8

    run docker exec "$cid" cat /tmp/bwdc_calls
    docker rm -f "$cid" >/dev/null 2>&1
    [ "$status" -eq 0 ]
    [[ "$output" =~ "sync" ]]
}
