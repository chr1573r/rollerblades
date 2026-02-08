#!/usr/bin/env bash

# Initialize directory structure and generate signing keys
# shellcheck disable=SC2120
run_init() {
  local init_dir="${1:-.}"

  echo '|)  || _   | |   | _  _'
  echo '|\()||(/_|`|)|(|(|(/__\'
  echo ""
  echo "Initializing rollerblades directory structure..."
  echo ""

  # Create directories
  for dir in config keys; do
    if [[ -d "$init_dir/$dir" ]]; then
      echo "  [exists]  $init_dir/$dir/"
    else
      mkdir -p "$init_dir/$dir"
      echo "  [created] $init_dir/$dir/"
    fi
  done

  # Create repos.txt.example if no repos.txt exists
  if [[ -f "$init_dir/config/repos.txt" ]]; then
    echo "  [exists]  $init_dir/config/repos.txt"
  else
    cat > "$init_dir/config/repos.txt.example" << 'EXAMPLE'
# Add repository names here, one per line.
# These are repo names appended to CLONE_PREFIX (not full URLs).
#
# Example: if CLONE_PREFIX is https://github.com/your-org
# and you add "my-tool", rollerblades will clone:
#   https://github.com/your-org/my-tool.git
#
# my-tool
# another-package
EXAMPLE
    echo "  [created] $init_dir/config/repos.txt.example"
  fi

  # Generate key pair if neither key exists
  if [[ -f "$init_dir/keys/private.pem" && -f "$init_dir/keys/public.pem" ]]; then
    echo ""
    echo "Signing keys already exist."
    local fp
    fp=$(openssl dgst -sha256 "$init_dir/keys/public.pem" 2>/dev/null | awk '{print $2}')
    echo "  Key fingerprint (SHA256): $fp"
  elif [[ -f "$init_dir/keys/private.pem" || -f "$init_dir/keys/public.pem" ]]; then
    echo ""
    echo "WARNING: Partial key pair found in $init_dir/keys/" >&2
    echo "  Both private.pem and public.pem must exist." >&2
    echo "  Remove the existing file and re-run --init to generate a fresh pair," >&2
    echo "  or manually provide both files." >&2
  else
    echo ""
    echo "Generating 4096-bit RSA signing key pair..."
    openssl genrsa -out "$init_dir/keys/private.pem" 4096 2>/dev/null
    openssl rsa -in "$init_dir/keys/private.pem" -pubout -out "$init_dir/keys/public.pem" 2>/dev/null
    chmod 600 "$init_dir/keys/private.pem"
    chmod 644 "$init_dir/keys/public.pem"

    local fp
    fp=$(openssl dgst -sha256 "$init_dir/keys/public.pem" 2>/dev/null | awk '{print $2}')
    echo ""
    echo "=========================================="
    echo "  KEY FINGERPRINT (SHA256):"
    echo "  $fp"
    echo "=========================================="
    echo ""
    echo "  Share this fingerprint with your sk8 users"
    echo "  so they can verify the right server."
  fi

  echo ""
  echo "Next steps:"
  if [[ ! -f "$init_dir/config/repos.txt" ]]; then
    echo "  1. Create config/repos.txt from the example:"
    echo "     cp config/repos.txt.example config/repos.txt"
    echo ""
    echo "  2. Edit config/repos.txt and add your repo names"
    echo ""
    echo "  3. Run with Docker:"
  else
    echo "  1. Run with Docker:"
  fi
  echo '     docker build -t rollerblades .'
  echo '     docker run -d --name rollerblades \'
  echo '       --restart unless-stopped \'
  echo '       -p 8080:80 \'
  echo '       -v $(pwd)/config:/config:ro \'
  echo '       -v $(pwd)/keys:/keys:ro \'
  echo '       -e RB_CLONE_PREFIX=https://github.com/your-org \'
  echo '       rollerblades'
  echo ""
  echo "  Or run standalone:"
  echo "     ./rollerblades.sh --once"
  echo ""
  echo "  Connect sk8 clients:"
  echo "     SK8_RB_URL=http://your-server:8080 sk8"
  echo ""
}

# Parse command line arguments
ONESHOT=false
SHOW_STATUS=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --init)
      run_init
      exit 0
      ;;
    --once|-1)
      ONESHOT=true
      shift
      ;;
    --status|-s)
      SHOW_STATUS=true
      shift
      ;;
    --help|-h)
      echo "Usage: rollerblades.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --init        Initialize directory structure and generate signing keys"
      echo "  --once, -1    Run once and exit (no loop)"
      echo "  --status, -s  Show deployment status and exit"
      echo "  --help, -h    Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

if ! [[ -d "$SCRIPT_DIR" ]]; then
	echo "Error: Could not locate rollerblades install directory" >&2
	exit 1
fi

# Support both env vars and config file (env vars take precedence)
# Paths can be overridden for container use
CFG_DIR="${RB_CFG_DIR:-${SCRIPT_DIR}/cfg}"
REPOS_DIR="${RB_REPOS_DIR:-${SCRIPT_DIR}/repos}"

# Create repos dir if it doesn't exist
if ! [[ -d "$REPOS_DIR" ]]; then
	echo "Creating repos directory: $REPOS_DIR"
	mkdir -p "$REPOS_DIR" || {
		echo "Error: Could not create repos directory" >&2
		exit 1
	}
fi

# Load config file if it exists (env vars will override)
if [[ -f "$CFG_DIR/settings.txt" ]]; then
	source "${CFG_DIR}/settings.txt"
fi

# Check for repos.txt
if ! [[ -f "$CFG_DIR/repos.txt" ]]; then
	echo "Error: Repos file does not exist at $CFG_DIR/repos.txt" >&2
	exit 1
fi

# Apply environment variable overrides (these take precedence over config file)
SLEEP_TIME="${RB_SLEEP_TIME:-${SLEEP_TIME:-5m}}"
OUTPUT_DIR="${RB_OUTPUT_DIR:-${OUTPUT_DIR:-/output}}"
CLONE_PREFIX="${RB_CLONE_PREFIX:-${CLONE_PREFIX:-https://github.com}}"
CLONE_SUFFIX="${RB_CLONE_SUFFIX:-${CLONE_SUFFIX:-.git}}"
SIGNING_PRIVATE_KEY="${RB_SIGNING_PRIVATE_KEY:-${SIGNING_PRIVATE_KEY:-}}"
SIGNING_PUBLIC_KEY="${RB_SIGNING_PUBLIC_KEY:-${SIGNING_PUBLIC_KEY:-}}"
LOG_FILE="${RB_LOG_FILE:-${LOG_FILE:-}}"
MOTD="${RB_MOTD:-${MOTD:-}}"

# Validate signing keys (signing is mandatory)
if [[ -z "$SIGNING_PRIVATE_KEY" ]] || [[ -z "$SIGNING_PUBLIC_KEY" ]]; then
	echo "Error: Signing keys are required." >&2
	echo "Set SIGNING_PRIVATE_KEY and SIGNING_PUBLIC_KEY in settings.txt" >&2
	echo "or via RB_SIGNING_PRIVATE_KEY and RB_SIGNING_PUBLIC_KEY env vars." >&2
	exit 1
fi

if [[ ! -f "$SIGNING_PRIVATE_KEY" ]]; then
	echo "Error: Private key not found: $SIGNING_PRIVATE_KEY" >&2
	exit 1
fi

if [[ ! -f "$SIGNING_PUBLIC_KEY" ]]; then
	echo "Error: Public key not found: $SIGNING_PUBLIC_KEY" >&2
	exit 1
fi

# Ensure output directory exists
if ! [[ -d "$OUTPUT_DIR" ]]; then
	echo "Creating output directory: $OUTPUT_DIR"
	mkdir -p "$OUTPUT_DIR" || {
		echo "Error: Could not create output directory" >&2
		exit 1
	}
fi

# Copy public key to output dir for clients
cp "$SIGNING_PUBLIC_KEY" "${OUTPUT_DIR}/rollerblades.pub"

# Resolve MOTD file path and copy to output dir if it exists
MOTD_FILE="${RB_MOTD:-${MOTD:-${CFG_DIR}/motd.txt}}"
if [[ -f "$MOTD_FILE" ]]; then
	# Limit MOTD size (server admin controls content)
	head -c 4096 "$MOTD_FILE" > "${OUTPUT_DIR}/motd.txt"
fi

# HTML escape function for safe output
html_escape() {
	sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g'
}

# determine if internal logging will be enabled
if [[ -z "$LOG_FILE" ]]; then
	rb_feature_filelog="false"
else
	rb_feature_filelog="true"
fi

# print line to console and optionally internal log
ut(){
	echo "$*"
	log "$*"
}

# print line without line terminator to console and optionally internal log
utn(){
	echo -n "$*"
	logn "$*"
}

# print header to console and optionally internal log
header(){
	ut '|)  || _   | |   | _  _'
	ut '|\()||(/_|`|)|(|(|(/__\'
	ut
}

# create file signature with public key
sign(){ # sign <key> <signature output> <file to sign>
	openssl dgst -sha256 -sign "$1" -out "$2" "$3"
}

# verify a signed file
sign_verify(){ # sign_check <public key> <signature file> <file to verify>
	openssl dgst -sha256 -verify "$1" -signature "$2" "$3"
}

# log to console, internal log (optional), and published log
multilog(){ 
	ut "$*"
	weblog "$*"
}

# log to internal log 
log(){ 
	if "$rb_feature_filelog"; then
		echo "$*" >> "${LOG_FILE}"
	fi
}

# log to internal log without line terminator
logn(){ 
	if "$rb_feature_filelog"; then
		echo -n "$*" >> "${LOG_FILE}"
	fi
}

#init published log file. Uses motd file as template if specified
weblog_init(){
	if [[ -f "$MOTD_FILE" ]]; then
		cp "$MOTD_FILE" "${OUTPUT_DIR}/rollerblades.log"
	else
		echo -n > "${OUTPUT_DIR}/rollerblades.log"
	fi

}

#log to published log
weblog(){
	echo "$*" >> "${OUTPUT_DIR}/rollerblades.log"
}

#copy published log to index.html and wrap with pre tags
weblog_html(){
	{
		echo '<!DOCTYPE html><html><head><meta charset="utf-8"><title>Rollerblades</title></head><body>'
		# Include MOTD if it exists (HTML escaped)
		if [[ -f "${OUTPUT_DIR}/motd.txt" ]]; then
			echo '<div style="background:#f0f0f0;padding:10px;margin-bottom:10px;border-radius:5px;">'
			html_escape < "${OUTPUT_DIR}/motd.txt"
			echo '</div>'
		fi
		echo '<pre>'
		html_escape < "${OUTPUT_DIR}/rollerblades.log"
		echo '</pre></body></html>'
	} > "${OUTPUT_DIR}/index.html"
}

# Generate package index file
generate_index() {
	local index_file="${OUTPUT_DIR}/packages.txt"
	local index_tmp="${OUTPUT_DIR}/packages.txt.tmp"

	ut "Generating package index..."

	echo "# Package index generated $(date)" > "$index_tmp"
	echo "# Server: rollerblades" >> "$index_tmp"

	while IFS= read -r repo; do
		# Skip empty lines and comments
		[[ -z "$repo" || "$repo" =~ ^# ]] && continue
		# Only list repos that have been successfully deployed
		if [[ -f "${OUTPUT_DIR}/${repo}.tar.gz" ]]; then
			echo "$repo" >> "$index_tmp"
		fi
	done < "${CFG_DIR}/repos.txt"

	mv "$index_tmp" "$index_file"
	ut "Package index updated: $index_file"
}

# Show deployment status
show_status() {
	header
	echo "Deployment Status"
	echo "================="
	echo ""
	echo "Output directory: $OUTPUT_DIR"
	echo ""

	if [[ ! -f "${CFG_DIR}/repos.txt" ]]; then
		echo "Error: repos.txt not found"
		exit 1
	fi

	echo "Packages:"
	while IFS= read -r repo; do
		# Skip empty lines and comments
		[[ -z "$repo" || "$repo" =~ ^# ]] && continue

		local release="${OUTPUT_DIR}/${repo}"
		if [[ -f "${release}.tar.gz" ]]; then
			local size
			size=$(du -h "${release}.tar.gz" 2>/dev/null | cut -f1)
			local updated="unknown"
			if [[ -f "${release}.updated" ]]; then
				updated=$(cat "${release}.updated")
			fi
			local signed="no"
			if [[ -f "${release}.signature" ]]; then
				signed="yes"
			fi
			printf "  %-30s %8s  signed: %-3s  updated: %s\n" "$repo" "$size" "$signed" "$updated"
		else
			printf "  %-30s (not deployed)\n" "$repo"
		fi
	done < "${CFG_DIR}/repos.txt"

	echo ""
	if [[ -f "${OUTPUT_DIR}/packages.txt" ]]; then
		local pkg_count
		pkg_count=$(grep -cv '^#' "${OUTPUT_DIR}/packages.txt" 2>/dev/null || echo 0)
		echo "Package index: $pkg_count packages"
	else
		echo "Package index: not generated"
	fi
}

# download and publish repos
deploy (){
	repo_count=0
	repo_success=0
	repo_skip=0

	# Process each repo
	while IFS= read -r repo; do
		# Skip empty lines and comments
		[[ -z "$repo" || "$repo" =~ ^# ]] && continue

		# Reset deploy flag for each repo
		repo_deploy=false

		url="${CLONE_PREFIX}/${repo}${CLONE_SUFFIX}"
		repo_dir="${REPOS_DIR}/${repo}"
		release="${OUTPUT_DIR}/${repo}"
		ut "##### Processing '$repo' #####"
		((repo_count++))

		if [[ -d "${repo_dir}" ]]; then
			ut "Checking if remote repo has changed since last deploy"
			if git -C "${repo_dir}" remote update > /dev/null 2>&1; then
				repo_local_revision="$(git -C "${repo_dir}" rev-parse HEAD)"
				repo_remote_revision="$(git -C "${repo_dir}" rev-parse '@{u}' 2>/dev/null)" || repo_remote_revision=""
				if [[ -n "$repo_remote_revision" && "$repo_local_revision" != "$repo_remote_revision" ]]; then
					ut "Remote has changed, updating local repo"
					if git -C "${repo_dir}" pull; then
						repo_deploy=true
					else
						ut "Git pull failed for '$repo'"
					fi
				else
					ut "No changes to deploy for '$repo'"
					((repo_skip++))
				fi
			else
				ut "Git remote update failed for '$repo'"
			fi
		else
			ut "Cloning new repo"
			if git -C "${REPOS_DIR}" clone "$url"; then
				repo_deploy=true
			else
				ut "Git clone failed for '$repo'"
			fi
		fi

		# Publish repo if applicable
		if $repo_deploy; then
			ut "Publishing release.."
			# Use subshell for archive creation to handle cd safely
			if (
				set -o pipefail
				cd "${repo_dir}" || exit 1
				git archive --format=tar HEAD | gzip > "${release}.tar.gz.tmp"
			); then
				mv "${release}.tar.gz.tmp" "${release}.tar.gz"
			else
				ut "Error: git archive failed for '$repo'"
				rm -f "${release}.tar.gz.tmp"
				ut "#####  Finished '$repo'  #####"
				continue
			fi

			ut "Signing release.."
			sign "$SIGNING_PRIVATE_KEY" "${release}.signature" "${release}.tar.gz"
			ut "Checking signature.."
			if sign_verify "$SIGNING_PUBLIC_KEY" "${release}.signature" "${release}.tar.gz" >/dev/null 2>&1; then
				ut "Signature verified."
				((repo_success++))
				date > "${release}.updated"
			else
				ut "Error: Signature verification failed for '$repo'"
				rm -f "${release}.tar.gz" "${release}.signature"
			fi
		fi
		ut "#####  Finished '$repo'  #####"
	done < "${CFG_DIR}/repos.txt"
}


# Handle --status flag
if "$SHOW_STATUS"; then
	show_status
	exit 0
fi

# main loop
while true; do
	weblog_init
	header
	ut "$(date): Start"
	ut "Processing repos"
	deploy
	generate_index
	multilog "Rollerblades - $(date)"
	multilog "Repos processed: ${repo_count} ($repo_success deployed, $repo_skip skipped, $((repo_count - repo_success - repo_skip)) failed)"
	weblog_html

	# Exit after one run if --once flag was provided
	if "$ONESHOT"; then
		ut "One-shot mode: exiting."
		exit 0
	fi

	if [[ -n "${SLEEP_TIME}" ]]; then
		ut "Sleeping (${SLEEP_TIME})"
		sleep "${SLEEP_TIME}"
	else
		exit 0
	fi
	ut '# # # # # # # #'
done
