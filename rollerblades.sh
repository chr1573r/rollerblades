#!/usr/bin/env bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

if ! [[ -d "$SCRIPT_DIR" ]]; then
	echo "Error: Could not locate rollerblades install directory"
	exit 1
fi

CFG_DIR="${SCRIPT_DIR}/cfg"
REPOS_DIR="${SCRIPT_DIR}/repos"

if ! [[ -d "$REPOS_DIR" ]]; then
	echo "Error: Could not locate repos directory"
	exit 1
fi

if ! [[ -f "$CFG_DIR/settings.txt" ]]; then
	echo "Error: Settings file does not exist"
	exit 1
fi


if ! [[ -f "$CFG_DIR/repos.txt" ]]; then
	echo "Error: Repos file does not exist"
	exit 1
fi

# load cfg
source "${CFG_DIR}/settings.txt"

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
	if [[ -f "$MOTD" ]]; then
		cp "$MOTD" "${OUTPUT_DIR}/rollerblades.log"
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
	echo '<pre>' > "${OUTPUT_DIR}/index.html"
	cat "${OUTPUT_DIR}/rollerblades.log" >> "${OUTPUT_DIR}/index.html"
	echo '</pre>' >> "${OUTPUT_DIR}/index.html"
}

# download and publish repos
deploy (){
	repo_count=0
	repo_success=0
	repo_skip=0

	repo_deploy=false

	# Process each repo
	while IFS= read -r repo; do
		url="${CLONE_PREFIX}/${repo}${CLONE_SUFFIX}"
		repo_dir="${REPOS_DIR}/${repo}"
		release="${OUTPUT_DIR}/${repo}"
		ut "##### Processing '$repo' #####"
		((repo_count++))

		if [[ -d "${repo_dir}" ]]; then
			cd "${repo_dir}"
			ut "Checking if remote repo has changed since last deploy"
			if git remote update > /dev/null; then
				repo_local_revision="$(git rev-parse HEAD)"
				repo_remote_revision="$(git rev-parse @{u})"
				if [[ "$repo_remote_revision" != "$repo_remote_revision" ]]; then
					ut "Remote has changed, updating local repo"
			
					# Pull repo
					
					repo_git_status="$?"
					if git pull; then
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
			cd ..
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
			cd "${repo_dir}"
			git archive --format=tar HEAD | gzip > "${release}.tar.gz"
			if "$SIGNING"; then
				ut "Signing release.."
				sign "$SIGNING_PRIVATE_KEY" "${release}.signature" "${release}.tar.gz"
				utn "Checking signature.. "
				if ut $(sign_verify "$SIGNING_PUBLIC_KEY" "${release}.signature" "${release}.tar.gz"); then
					((repo_success++))
					date > "${release}.updated"
				fi
			elif [[ -f "${release}.tar.gz" ]]; then
				((repo_success++))
				date > "${release}.updated"
			fi
			cd ..
		fi
		ut "#####  Finished '$repo'  #####"
	done < "${CFG_DIR}/repos.txt"
}


# main loop
while true; do
	weblog_init
	header
	ut "$(date): Start"
	ut "Processing repos"
	deploy
	multilog "Rollerblades - $(date)"
	multilog "Repos processed: ${repo_count} ($repo_success deployed, $repo_skip skipped, $((repo_count - repo_success - repo_skip)) failed)"
	weblog_html
	if ! [[ -z "${SLEEP_TIME}" ]]; then
		ut "Sleeping (${SLEEP_TIME})"
		sleep "${SLEEP_TIME}"
	else
		exit
	fi
	ut '# # # # # # # #'
done
