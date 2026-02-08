# rollerblades

A lightweight distribution tool that monitors git repositories and publishes them as signed tar.gz archives.

## Features

- Monitors multiple git repositories for changes
- Creates tar.gz archives using `git archive`
- Cryptographic signing with OpenSSL SHA256 (mandatory)
- Generates package index for [sk8](https://github.com/chr1573r/sk8) clients
- Built-in web server via Docker (nginx)
- Auto-generates signing keys if none provided
- Runs as daemon or one-shot mode

## Quick Start

### Docker (recommended)

```bash
# Initialize config and signing keys
./rollerblades.sh --init

# Add repos to monitor
cp config/repos.txt.example config/repos.txt
# Edit config/repos.txt - add your repo names

# Build and run
docker build -t rollerblades .
docker run -d --name rollerblades \
  --restart unless-stopped \
  -p 8080:80 \
  -v $(pwd)/config:/config:ro \
  -v $(pwd)/keys:/keys:ro \
  -e RB_CLONE_PREFIX=https://github.com/your-org \
  rollerblades

# Packages available at http://localhost:8080
```

### Fully automatic Docker (keys auto-generated)

If you just want to get going, only `repos.txt` is required. Signing keys are generated automatically on first start:

```bash
mkdir config
echo "my-repo" > config/repos.txt

docker build -t rollerblades .
docker run -d --name rollerblades \
  --restart unless-stopped \
  -p 8080:80 \
  -v $(pwd)/config:/config:ro \
  -e RB_CLONE_PREFIX=https://github.com/your-org \
  rollerblades

# Check logs for the auto-generated key fingerprint:
docker logs rollerblades
```

### Standalone (no Docker)

```bash
./rollerblades.sh --init
cp config/repos.txt.example config/repos.txt
# Edit config/repos.txt, then:
./rollerblades.sh --once
```

## Connecting Clients

Tell your users to install [sk8](https://github.com/chr1573r/sk8) and connect:

```bash
# Non-interactive setup (scripts/CI)
SK8_RB_URL=http://your-server:8080 sk8 list

# Interactive setup
sk8
# Enter URL when prompted: http://your-server:8080
```

## Command Line Options

```
Usage: rollerblades.sh [OPTIONS]

Options:
  --init        Initialize directory structure and generate signing keys
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
| `SIGNING_PRIVATE_KEY` | `RB_SIGNING_PRIVATE_KEY` | `/keys/private.pem` | Path to private key |
| `SIGNING_PUBLIC_KEY` | `RB_SIGNING_PUBLIC_KEY` | `/keys/public.pem` | Path to public key |
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

Keys can be generated automatically with `--init`, or manually:

```bash
openssl genrsa -out keys/private.pem 4096
openssl rsa -in keys/private.pem -pubout -out keys/public.pem
```

The public key is automatically copied to the output directory as `rollerblades.pub` for clients to verify packages.

## Message of the Day (MOTD)

You can display a server message to clients by creating an MOTD file:

```bash
echo "Welcome to my package server!" > config/motd.txt
```

The MOTD is:
- Displayed on the `index.html` status page (HTML escaped for security)
- Served as `motd.txt` for sk8 clients to display
- Automatically sanitized (max 4KB, control characters stripped)

## Docker Volumes

| Path | Description |
|------|-------------|
| `/config` | Config directory containing repos.txt (required, mount read-only) |
| `/keys` | Signing keys (auto-generated if not mounted) |
| `/repos` | Git clones (persistent, managed by Docker) |
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

## License

MIT License - Copyright (c) 2022 Christer Jonassen
