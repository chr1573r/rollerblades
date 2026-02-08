#!/bin/bash
set -e

echo "Starting rollerblades container..."

# Validate required config
if [[ ! -f "/config/repos.txt" ]]; then
    echo "Error: /config/repos.txt not found" >&2
    echo "Mount a config directory with repos.txt to /config:" >&2
    echo "  docker run -v ./config:/config:ro ..." >&2
    exit 1
fi

# Auto-generate signing keys if not present
if [[ ! -f "${RB_SIGNING_PRIVATE_KEY}" ]] || [[ ! -f "${RB_SIGNING_PUBLIC_KEY}" ]]; then
    echo ""
    echo "=========================================="
    echo "  No signing keys found."
    echo "  Generating 4096-bit RSA key pair..."
    echo "=========================================="
    echo ""
    openssl genrsa -out "${RB_SIGNING_PRIVATE_KEY}" 4096 2>/dev/null
    openssl rsa -in "${RB_SIGNING_PRIVATE_KEY}" -pubout -out "${RB_SIGNING_PUBLIC_KEY}" 2>/dev/null
    chmod 600 "${RB_SIGNING_PRIVATE_KEY}"
    chmod 644 "${RB_SIGNING_PUBLIC_KEY}"
    fingerprint=$(openssl dgst -sha256 "${RB_SIGNING_PUBLIC_KEY}" 2>/dev/null | awk '{print $2}')
    echo "=========================================="
    echo "  AUTO-GENERATED KEY FINGERPRINT (SHA256):"
    echo "  $fingerprint"
    echo ""
    echo "  For production, generate persistent keys:"
    echo "    ./rollerblades.sh --init"
    echo "  and mount them: -v ./keys:/keys:ro"
    echo "=========================================="
    echo ""
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
