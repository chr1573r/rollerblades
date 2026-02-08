#!/bin/bash
set -e

echo "Starting rollerblades container..."

# Validate required config
if [[ ! -f "/config/repos.txt" ]]; then
    echo "Error: /config/repos.txt not found"
    echo "Mount a repos.txt file to /config/repos.txt"
    exit 1
fi

# Show configuration
echo "Configuration:"
echo "  Sleep time:    ${RB_SLEEP_TIME}"
echo "  Output dir:    ${RB_OUTPUT_DIR}"
echo "  Clone prefix:  ${RB_CLONE_PREFIX}"
echo "  Repos file:    /config/repos.txt"

# Show signing key info
if [[ -f "${RB_SIGNING_PUBLIC_KEY}" ]]; then
    fingerprint=$(openssl dgst -sha256 "${RB_SIGNING_PUBLIC_KEY}" 2>/dev/null | awk '{print $2}')
    echo "  Signing key:   ${fingerprint:0:16}...${fingerprint: -16}"
else
    echo "  Signing key:   (not found!)"
fi

# Show MOTD status
if [[ -f "/config/motd.txt" ]]; then
    echo "  MOTD:          yes"
else
    echo "  MOTD:          (none)"
fi
echo ""

# Start nginx in background
echo "Starting nginx..."
nginx

# Run rollerblades
echo "Starting rollerblades..."
exec /app/rollerblades.sh "$@"
