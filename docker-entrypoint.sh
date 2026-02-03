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
echo "  Signing:       ${RB_SIGNING}"
echo "  Repos file:    /config/repos.txt"
echo ""

# Start nginx in background
echo "Starting nginx..."
nginx

# Run rollerblades
echo "Starting rollerblades..."
exec /app/rollerblades.sh "$@"
