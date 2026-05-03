#!/usr/bin/env bats

HEALTHCHECK="$BATS_TEST_DIRNAME/../../healthcheck.sh"

setup() {
    export HEARTBEAT_FILE
    HEARTBEAT_FILE="$(mktemp)"
    export SYNC_INTERVAL_MIN=5
}

teardown() {
    rm -f "$HEARTBEAT_FILE"
}

@test "healthy when heartbeat is fresh" {
    date +%s > "$HEARTBEAT_FILE"
    run "$HEALTHCHECK"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "OK:" ]]
}

@test "unhealthy when heartbeat file is missing" {
    rm -f "$HEARTBEAT_FILE"
    run "$HEALTHCHECK"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "UNHEALTHY" ]]
}

@test "unhealthy when heartbeat is too old" {
    echo "1" > "$HEARTBEAT_FILE"
    run "$HEALTHCHECK"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "UNHEALTHY" ]]
}

@test "unhealthy when heartbeat exceeds 2x interval plus buffer" {
    # MAX_AGE_SEC = 1*60*2+60 = 180; write a timestamp 181s ago
    export SYNC_INTERVAL_MIN=1
    echo "$(($(date +%s) - 181))" > "$HEARTBEAT_FILE"
    run "$HEALTHCHECK"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "UNHEALTHY" ]]
}

@test "healthy when heartbeat is within 2x interval plus buffer" {
    export SYNC_INTERVAL_MIN=1
    # 60s ago is within 180s max
    echo "$(($(date +%s) - 60))" > "$HEARTBEAT_FILE"
    run "$HEALTHCHECK"
    [ "$status" -eq 0 ]
}

@test "output includes age in seconds" {
    date +%s > "$HEARTBEAT_FILE"
    run "$HEALTHCHECK"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "ago" ]]
}
