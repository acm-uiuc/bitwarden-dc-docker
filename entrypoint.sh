#!/bin/sh
set -e

CONFIG_DIR="/home/bitwarden/.config/Bitwarden Directory Connector"
CONFIG_FILE="${CONFIG_DIR}/data.json"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Configuration file not found!"
    echo "Please mount your data.json to: ${CONFIG_FILE}"
    echo ""
    echo "Example:"
    echo "  docker run -v /path/to/data.json:\"${CONFIG_FILE}\":ro ..."
    echo ""
    echo "You can generate a data.json using the Bitwarden Directory Connector desktop app,"
    echo "or by running this container interactively:"
    echo "  docker run -it --entrypoint /bin/sh <image>"
    echo "  bwdc login"
    echo "  bwdc config directory <type>"
    echo "  bwdc data-file"
    exit 1
fi

SYNC_INTERVAL_MIN=${SYNC_INTERVAL_MIN:-5}
SYNC_INTERVAL_SEC=$((SYNC_INTERVAL_MIN * 60))
MAX_BACKOFF=${MAX_BACKOFF:-3600}

# Retry a command with exponential backoff
# Usage: retry <command> [args...]
retry() {
    local attempt=1
    local backoff=5

    until "$@"; do
        echo "Command failed: $*"
        echo "Attempt ${attempt} failed, retrying in ${backoff}s..."
        sleep "$backoff"
        attempt=$((attempt + 1))
        backoff=$((backoff * 2))
        [ "$backoff" -gt "$MAX_BACKOFF" ] && backoff=$MAX_BACKOFF
    done
}

echo "Sync interval: every ${SYNC_INTERVAL_MIN} minutes."

if [ -n "$BW_SERVER" ]; then
    echo "Configuring server: ${BW_SERVER}"
    retry /usr/local/bin/bwdc config server "${BW_SERVER}"
fi

if [ -n "$BW_DIRECTORY_TYPE" ]; then
    echo "Configuring directory type: ${BW_DIRECTORY_TYPE}"
    retry /usr/local/bin/bwdc config directory "${BW_DIRECTORY_TYPE}"
fi

if [ -n "$BW_DIRECTORY_KEY" ]; then
    case "${BW_DIRECTORY_TYPE}" in
        0|ldap)
            echo "Configuring LDAP password..."
            retry /usr/local/bin/bwdc config ldap.password "${BW_DIRECTORY_KEY}"
            ;;
        1|azure)
            echo "Configuring Azure AD key..."
            retry /usr/local/bin/bwdc config azure.key "${BW_DIRECTORY_KEY}"
            ;;
        2|gsuite)
            echo "Configuring GSuite key..."
            retry /usr/local/bin/bwdc config gsuite.key "${BW_DIRECTORY_KEY}"
            ;;
        3|okta)
            echo "Configuring Okta token..."
            retry /usr/local/bin/bwdc config okta.token "${BW_DIRECTORY_KEY}"
            ;;
        4|onelogin)
            echo "Configuring OneLogin secret..."
            retry /usr/local/bin/bwdc config onelogin.secret "${BW_DIRECTORY_KEY}"
            ;;
        *)
            echo "WARNING: BW_DIRECTORY_KEY set but BW_DIRECTORY_TYPE not recognized: ${BW_DIRECTORY_TYPE}"
            echo "Valid types: 0 (ldap), 1 (azure), 2 (gsuite), 3 (okta), 4 (onelogin)"
            ;;
    esac
fi

echo "Logging in..."
retry /usr/local/bin/bwdc login

echo "Starting sync loop..."
while true; do
    echo "[$(date)] Running sync..."
    retry /usr/local/bin/bwdc sync
    echo "Sleeping for ${SYNC_INTERVAL_SEC} seconds..."
    sleep "${SYNC_INTERVAL_SEC}"
done
