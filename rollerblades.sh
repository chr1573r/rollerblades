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

gfx_init(){
	reset
}

header(){
	echo '|)  || _   | |   | _  _'
	echo '|\()||(/_|`|)|(|(|(/__\'
	echo
}

deploy (){
	while IFS= read -r repo; do
		url="${CLONE_PREFIX}/${repo}${CLONE_SUFFIX}"
		repo_dir="${REPOS_DIR}/${repo}"

		echo "Processing '$repo'"

		if [[ -d "${repo_dir}" ]]; then
			cd "${repo_dir}"
			git pull
			cd ..
		else
			git -C "${REPOS_DIR}" clone "$url"
		fi

		cd "${repo_dir}"
		git archive --format=tar HEAD | gzip > "${OUTPUT_DIR}/${repo}.tar.gz"
		echo "$date" > "${OUTPUT_DIR}/${repo}.updated.txt"
		cd ..
		echo "Finished processing '$repo'"
		echo
	done < "${CFG_DIR}/repos.txt"

}

while true; do
	gfx_init
	header
	echo "Downloading and publishing repos"
	deploy
	echo "Rollerblades - Latest deployment: $(date), next update in ${SLEEP_TIME}" > "${OUTPUT_DIR}/index.html"
	echo '# # # # # # # #'
	echo "$(date): Done, sleeping (${SLEEP_TIME})"
	sleep "${SLEEP_TIME}"
done
