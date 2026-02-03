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
mkdir -p cfg repos

# Add repos to monitor (one per line)
echo "my-repo" > cfg/repos.txt

# Create settings
cat > cfg/settings.txt << 'EOF'
SLEEP_TIME=5m
OUTPUT_DIR=/var/www/packages
CLONE_PREFIX=https://github.com/your-org
CLONE_SUFFIX=.git
SIGNING=false
EOF

# Run
./rollerblades.sh
```

### Docker

```bash
# Create config
mkdir config
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
| `SIGNING` | `RB_SIGNING` | `false` | Enable package signing |
| `SIGNING_PRIVATE_KEY` | `RB_SIGNING_PRIVATE_KEY` | - | Path to private key |
| `SIGNING_PUBLIC_KEY` | `RB_SIGNING_PUBLIC_KEY` | - | Path to public key |
| `LOG_FILE` | `RB_LOG_FILE` | - | Optional internal log file |
| `MOTD` | `RB_MOTD` | - | Optional message file for index.html |

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

Generate signing keys:

```bash
# Generate private key
openssl genrsa -out cfg/rollerblades.key 4096

# Generate public key
openssl rsa -in cfg/rollerblades.key -pubout -out cfg/rollerblades.pub
```

Enable in settings:

```bash
SIGNING=true
SIGNING_PRIVATE_KEY="$CFG_DIR/rollerblades.key"
SIGNING_PUBLIC_KEY="$CFG_DIR/rollerblades.pub"
```

The public key is automatically copied to the output directory for clients.

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
      - ./config/repos.txt:/config/repos.txt:ro
      - rb-repos:/repos
      - rb-output:/output
    environment:
      RB_SLEEP_TIME: "5m"
      RB_CLONE_PREFIX: "https://github.com/your-org"

volumes:
  rb-repos:
  rb-output:
```

### Volumes

| Path | Description |
|------|-------------|
| `/config/repos.txt` | Package list (required, mount as file) |
| `/repos` | Git clones (persistent volume) |
| `/output` | Published packages (served by nginx) |
| `/keys` | Signing keys (optional) |

## Output Structure

```
OUTPUT_DIR/
├── index.html           # Status page
├── packages.txt         # Package index for sk8
├── rollerblades.log     # Status log
├── rollerblades.pub     # Public key (if signing enabled)
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
