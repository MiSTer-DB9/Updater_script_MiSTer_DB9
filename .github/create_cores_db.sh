#!/usr/bin/env bash
# Copyright (c) 2020 José Manuel Barroso Galindo <theypsilon@gmail.com>

set -euo pipefail

CURL_RETRY="--connect-timeout 15 --max-time 120 --retry 3 --retry-delay 5"
SSL_SECURITY_OPTION=""
MISTER_DEVEL_REPOS_URL="https://api.github.com/users/mister-db9/repos"

ALL_REPOSITORIES=()
API_PAGE=0
while true ; do
    API_PAGE=$((API_PAGE+1))
    API_RESPONSE=$(curl ${CURL_RETRY} ${SSL_SECURITY_OPTION} -sSLf "${MISTER_DEVEL_REPOS_URL}?per_page=100&page=${API_PAGE}&$(date +%s)")
    PAGE_REPOSITORIES=( $(echo "${API_RESPONSE}" | jq -r '[.[] | .name + "|" + .owner.login + "|" + .svn_url + "|" + .default_branch + "|" + .updated_at] | .[]') )
    [[ "${#PAGE_REPOSITORIES[@]}" == "0" ]] && break
    ALL_REPOSITORIES+=( ${PAGE_REPOSITORIES[@]} )
done

DB_FILE="./.github/cores_db.txt.tmp"

rm -f "${DB_FILE}" || true
for line in "${ALL_REPOSITORIES[@]} "
do
   echo "${line}" >> "${DB_FILE}"
done

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