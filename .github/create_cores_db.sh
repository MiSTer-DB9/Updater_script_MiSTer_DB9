#!/usr/bin/env bash
# Copyright (c) 2020 José Manuel Barroso Galindo <theypsilon@gmail.com>

set -euo pipefail

CURL_RETRY="--connect-timeout 15 --max-time 120 --retry 3 --retry-delay 5"
SSL_SECURITY_OPTION=""
MISTER_DEVEL_REPOS_URL="https://api.github.com/users/mister-db9/repos"
FORKS_INI_URL="https://raw.githubusercontent.com/MiSTer-DB9/Forks_MiSTer/master/Forks.ini"

source <(curl ${CURL_RETRY} ${SSL_SECURITY_OPTION} "${FORKS_INI_URL}" 2> /dev/null | python -c "
import sys, ConfigParser
config = ConfigParser.ConfigParser()
config.readfp(sys.stdin)
for sec in config.sections():
    print \"declare -A %s\" % (sec)
    for key, val in config.items(sec):
        print '%s[%s]=\"%s\"' % (sec, key, val)
")

declare -a CORES
for i in ${Forks[syncing_forks]}
do
    declare -n fork="${i}"
    CORES+=("${fork[release_core_name]}")
done
CORES+=("SD-Installer-Win64")
CORES_COMPARE_STRING=" ${CORES[@]^^} "

ALL_REPOSITORIES=()
API_PAGE=0
while true ; do
    API_PAGE=$((API_PAGE+1))
    API_RESPONSE=$(curl ${CURL_RETRY} ${SSL_SECURITY_OPTION} -sSLf "${MISTER_DEVEL_REPOS_URL}?per_page=100&page=${API_PAGE}&$(date +%s)")
    PAGE_REPOSITORIES=( $(echo "${API_RESPONSE}" | jq -r '[.[] | .name + "|" + .owner.login + "|" + .svn_url + "|" + .default_branch + "|" + .updated_at] | .[]') )
    [[ "${#PAGE_REPOSITORIES[@]}" == "0" ]] && break
    ALL_REPOSITORIES+=( ${PAGE_REPOSITORIES[@]} )
done

DB_FILE=${DB_FILE:-"./.github/cores_db.txt"}

echo -n "" > "${DB_FILE}"
for line in "${ALL_REPOSITORIES[@]} "
do
    START_LINE="${line%%|*}"
    CORE_NAME="${START_LINE^^}"
    if [[ "${CORES_COMPARE_STRING}" =~ " ${CORE_NAME%%[^\s]MISTER} " ]]; then
        echo "${line}" >> "${DB_FILE}"
    fi
done

if [[ "${1:-}" == "--early-exit" ]] ; then
    exit 0
fi

echo "DB Content:"
cat "${DB_FILE}"
echo
echo "Total cores: ${#ALL_REPOSITORIES[@]}"
echo

git config --global user.email "theypsilon@gmail.com"
git config --global user.name "The CI/CD Bot"

git add "${DB_FILE}"

if ! git diff --staged --quiet --exit-code ; then
    git commit -m "BOT: Cores DB updated."
    git push origin master
else
    echo "Nothing to be done."
fi