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


header(){
	echo '|)  || _   | |   | _  _'
	echo '|\()||(/_|`|)|(|(|(/__\'
	echo
}

sign(){ # sign <key> <signature output> <file to sign>
	openssl dgst -sha256 -sign "$1" -out "$2" "$3"
}
sign_verify(){ # sign_check <public key> <signature file> <file to verify>
	openssl dgst -sha256 -verify "$1" -signature "$2" "$3"
}

deploy (){
	repo_count=0
	while IFS= read -r repo; do
		url="${CLONE_PREFIX}/${repo}${CLONE_SUFFIX}"
		repo_dir="${REPOS_DIR}/${repo}"
		release="${OUTPUT_DIR}/${repo}.tar.gz"
		echo "Processing '$repo'"
		((repo_count++))

		if [[ -d "${repo_dir}" ]]; then
			cd "${repo_dir}"
			git pull
			cd ..
		else
			git -C "${REPOS_DIR}" clone "$url"
		fi

		cd "${repo_dir}"
		git archive --format=tar HEAD | gzip > "${release}"
		if "$SIGNING"; then
			echo "Signing release.."
			sign "$SIGNING_PRIVATE_KEY" "${release}.signature" "${release}"
			echo -n "Checking signature.. "
			sign_verify "$SIGNING_PUBLIC_KEY" "${release}.signature" "${release}" && ((repo_success++))
		elif [[ -f "${release}" ]]; then
			((repo_success++))	
		fi
		echo "$date" > "${OUTPUT_DIR}/${repo}.updated.txt"
		cd ..
		echo "Finished processing '$repo'"
		echo
	done < "${CFG_DIR}/repos.txt"
}

report(){
if [[ -f "$MOTD" ]]; then
		cat "$MOTD" > "${OUTPUT_DIR}/index.html"
	else
		echo -n > "${OUTPUT_DIR}/index.html"
	fi
	echo "Rollerblades - Latest deployment: $(date). ${repo_success}/${repo_count} repos deployed successfully. Next update in ${SLEEP_TIME}" >> "${OUTPUT_DIR}/index.html"
}

while true; do
	header
	echo "$(date): Start"
	echo "Downloading and publishing repos"
	deploy
	echo "${repo_success}/${repo_count} repos deployed successfully"
	echo "Updating report"
	report
	echo '# # # # # # # #'
	echo "$(date): Done, sleeping (${SLEEP_TIME})"
	sleep "${SLEEP_TIME}"
done
