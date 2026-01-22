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

echo "Sync interval: every ${SYNC_INTERVAL_MIN} minutes."

if [ -n "$BW_SERVER" ]; then
    echo "Configuring server: ${BW_SERVER}"
    /usr/local/bin/bwdc config server "${BW_SERVER}"
fi

if [ -n "$BW_DIRECTORY_TYPE" ]; then
    echo "Configuring directory type: ${BW_DIRECTORY_TYPE}"
    /usr/local/bin/bwdc config directory "${BW_DIRECTORY_TYPE}"
fi

# Configure directory-specific secret key based on directory type
if [ -n "$BW_DIRECTORY_KEY" ]; then
    case "${BW_DIRECTORY_TYPE}" in
        0|ldap)
            echo "Configuring LDAP password..."
            /usr/local/bin/bwdc config ldap.password "${BW_DIRECTORY_KEY}"
            ;;
        1|azure)
            echo "Configuring Azure AD key..."
            /usr/local/bin/bwdc config azure.key "${BW_DIRECTORY_KEY}"
            ;;
        2|gsuite)
            echo "Configuring GSuite key..."
            /usr/local/bin/bwdc config gsuite.key "${BW_DIRECTORY_KEY}"
            ;;
        3|okta)
            echo "Configuring Okta token..."
            /usr/local/bin/bwdc config okta.token "${BW_DIRECTORY_KEY}"
            ;;
        4|onelogin)
            echo "Configuring OneLogin secret..."
            /usr/local/bin/bwdc config onelogin.secret "${BW_DIRECTORY_KEY}"
            ;;
        *)
            echo "WARNING: BW_DIRECTORY_KEY set but BW_DIRECTORY_TYPE not recognized: ${BW_DIRECTORY_TYPE}"
            echo "Valid types: 0 (ldap), 1 (azure), 2 (gsuite), 3 (okta), 4 (onelogin)"
            ;;
    esac
fi

echo "Logging in..."
/usr/local/bin/bwdc login || echo "Already logged in, continuing..."

echo "Starting sync loop..."
while true; do
    echo "[$(date)] Running sync..."
    /usr/local/bin/bwdc sync
    echo "Sleeping for ${SYNC_INTERVAL_SEC} seconds..."
    sleep "${SYNC_INTERVAL_SEC}"
done
