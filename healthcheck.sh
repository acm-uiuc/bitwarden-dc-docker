#!/bin/sh
set -e
HEARTBEAT_FILE="${HEARTBEAT_FILE:-/tmp/bwdc-heartbeat}"
SYNC_INTERVAL_MIN=${SYNC_INTERVAL_MIN:-5}

# Allow 2x the sync interval plus a 60s buffer before declaring unhealthy.
# This tolerates one missed sync due to transient retries.
MAX_AGE_SEC=$(( SYNC_INTERVAL_MIN * 60 * 2 + 60 ))

if [ ! -f "$HEARTBEAT_FILE" ]; then
    echo "UNHEALTHY: heartbeat file missing"
    exit 1
fi

last=$(cat "$HEARTBEAT_FILE")
now=$(date +%s)
age=$((now - last))

if [ "$age" -gt "$MAX_AGE_SEC" ]; then
    echo "UNHEALTHY: last sync was ${age}s ago (max ${MAX_AGE_SEC}s)"
    exit 1
fi

echo "OK: last sync ${age}s ago"
exit 0