#!/bin/bash
set -e

echo "Starting rollerblades container..."

# Validate required config
if [[ ! -f "/cfg/repos.txt" ]]; then
    echo "Error: /cfg/repos.txt not found" >&2
    echo "Mount a config directory with repos.txt to /cfg:" >&2
    echo "  docker run -v ./cfg:/cfg:ro ..." >&2
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

# Set up SSH if a key directory is mounted
if [[ -d "/root/.ssh" ]]; then
    chmod 700 /root/.ssh
    # Fix permissions on any key files
    for f in /root/.ssh/id_rsa /root/.ssh/id_ed25519 /root/.ssh/id_ecdsa; do
        [[ -f "$f" ]] && chmod 600 "$f"
    done
    [[ -f /root/.ssh/known_hosts ]] && chmod 644 /root/.ssh/known_hosts
    echo "SSH directory mounted, key permissions set."
fi

# Show configuration
echo "Configuration:"
echo "  Sleep time:    ${RB_SLEEP_TIME}"
echo "  Output dir:    ${RB_OUTPUT_DIR}"
echo "  Clone prefix:  ${RB_CLONE_PREFIX}"
echo "  Repos file:    /cfg/repos.txt"

# Show signing key info
if [[ -f "${RB_SIGNING_PUBLIC_KEY}" ]]; then
    fingerprint=$(openssl dgst -sha256 "${RB_SIGNING_PUBLIC_KEY}" 2>/dev/null | awk '{print $2}')
    echo "  Signing key:   ${fingerprint:0:16}...${fingerprint: -16}"
else
    echo "  Signing key:   (not found!)"
fi

# Show MOTD status
if [[ -f "/cfg/motd.txt" ]]; then
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
