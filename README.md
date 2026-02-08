# rollerblades

A lightweight distribution tool that monitors git repositories and publishes them as signed tar.gz archives.

## Features

- Monitors multiple git repositories for changes
- Creates tar.gz archives using `git archive`
- Optional cryptographic signing with OpenSSL SHA256
- Generates package index for [sk8](https://github.com/chr1573r/sk8) clients
- Built-in web server support via Docker
- Runs as daemon or one-shot mode

## Quick Start

### Standalone

```bash
# Create directories
mkdir -p cfg repos keys

# Generate signing keys
openssl genrsa -out keys/private.pem 4096
openssl rsa -in keys/private.pem -pubout -out keys/public.pem

# Add repos to monitor (one per line)
echo "my-repo" > cfg/repos.txt

# Create settings
cat > cfg/settings.txt << 'EOF'
SLEEP_TIME=5m
OUTPUT_DIR=/var/www/packages
CLONE_PREFIX=https://github.com/your-org
CLONE_SUFFIX=.git
SIGNING_PRIVATE_KEY="$CFG_DIR/../keys/private.pem"
SIGNING_PUBLIC_KEY="$CFG_DIR/../keys/public.pem"
EOF

# Run
./rollerblades.sh
```

### Docker

```bash
# Create config and keys directories
mkdir -p config keys

# Generate signing keys
openssl genrsa -out keys/private.pem 4096
openssl rsa -in keys/private.pem -pubout -out keys/public.pem

# Add repos to monitor
echo "my-repo" > config/repos.txt

# Run with docker compose
docker compose up -d

# Packages available at http://localhost:8080
```

## Command Line Options

```
Usage: rollerblades.sh [OPTIONS]

Options:
  --once, -1    Run once and exit (for cron/manual triggers)
  --status, -s  Show deployment status and exit
  --help, -h    Show help message
```

## Configuration

Configuration can be provided via config file (`cfg/settings.txt`) or environment variables.
Environment variables take precedence over config file values.

| Setting | Env Variable | Default | Description |
|---------|--------------|---------|-------------|
| `SLEEP_TIME` | `RB_SLEEP_TIME` | `5m` | Interval between update checks |
| `OUTPUT_DIR` | `RB_OUTPUT_DIR` | `/output` | Where to publish archives |
| `CLONE_PREFIX` | `RB_CLONE_PREFIX` | `https://github.com` | Git URL prefix |
| `CLONE_SUFFIX` | `RB_CLONE_SUFFIX` | `.git` | Git URL suffix |
| `SIGNING_PRIVATE_KEY` | `RB_SIGNING_PRIVATE_KEY` | **required** | Path to private key |
| `SIGNING_PUBLIC_KEY` | `RB_SIGNING_PUBLIC_KEY` | **required** | Path to public key |
| `LOG_FILE` | `RB_LOG_FILE` | - | Optional internal log file |
| `MOTD` | `RB_MOTD` | `cfg/motd.txt` | Optional message of the day file |

### Directory Overrides (for containers)

| Env Variable | Default | Description |
|--------------|---------|-------------|
| `RB_CFG_DIR` | `./cfg` | Config directory |
| `RB_REPOS_DIR` | `./repos` | Git clones directory |

### repos.txt Format

```
# Comments start with #
my-tool
another-package
dotfiles
```

## Package Signing

All packages are cryptographically signed using SHA256. Signing is mandatory.

Generate signing keys:

```bash
# Generate private key
openssl genrsa -out keys/private.pem 4096

# Generate public key
openssl rsa -in keys/private.pem -pubout -out keys/public.pem
```

Configure in settings.txt or via environment variables:

```bash
SIGNING_PRIVATE_KEY="/path/to/private.pem"
SIGNING_PUBLIC_KEY="/path/to/public.pem"
```

The public key is automatically copied to the output directory as `rollerblades.pub` for clients to verify packages.

## Message of the Day (MOTD)

You can display a server message to clients by creating an MOTD file:

```bash
echo "Welcome to my package server!" > cfg/motd.txt
```

The MOTD is:
- Displayed on the `index.html` status page (HTML escaped for security)
- Served as `motd.txt` for sk8 clients to display
- Automatically sanitized (max 4KB, control characters stripped)

## Docker Deployment

### Build

```bash
docker build -t rollerblades .
```

### Docker Compose

```yaml
services:
  rollerblades:
    build: .
    ports:
      - "8080:80"
    volumes:
      - ./config:/config:ro
      - ./keys:/keys:ro
      - rb-repos:/repos
      - rb-output:/output
    environment:
      RB_SLEEP_TIME: "5m"
      RB_CLONE_PREFIX: "https://github.com/your-org"
      RB_SIGNING_PRIVATE_KEY: "/keys/private.pem"
      RB_SIGNING_PUBLIC_KEY: "/keys/public.pem"

volumes:
  rb-repos:
  rb-output:
```

### Volumes

| Path | Description |
|------|-------------|
| `/config` | Config directory containing repos.txt (required) |
| `/keys` | Signing keys directory (required) |
| `/repos` | Git clones (persistent volume) |
| `/output` | Published packages (served by nginx) |

## Output Structure

```
OUTPUT_DIR/
├── index.html           # Status page (includes MOTD if present)
├── packages.txt         # Package index for sk8
├── rollerblades.log     # Status log
├── rollerblades.pub     # Public key for verification
├── motd.txt             # Server message (optional)
├── my-tool.tar.gz       # Package archive
├── my-tool.signature    # Package signature
└── my-tool.updated      # Last update timestamp
```

## Client

Use [sk8](https://github.com/chr1573r/sk8) to install packages:

```bash
sk8 update              # Fetch package index
sk8 list                # Show available packages
sk8 install my-tool     # Install a package
```

## License

MIT License - Copyright (c) 2022 Christer Jonassen
