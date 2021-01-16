#!/usr/bin/env bash
# Copyright (c) 2020 José Manuel Barroso Galindo <theypsilon@gmail.com>

set -euo pipefail

CURL_RETRY="--connect-timeout 15 --max-time 120 --retry 3 --retry-delay 5"
SSL_SECURITY_OPTION=""
MISTER_DEVEL_REPOS_URL="https://api.github.com/users/mister-db9/repos"
FORKS_INI_URL="https://raw.githubusercontent.com/MiSTer-DB9/Forks_MiSTer/master/Forks.ini"

QUIET="false"
SAVE_API_RESPONSE="false"
LOAD_API_RESPONSE="false"
EARLY_EXIT="false"
while getopts ":qsle" opt; do
    case ${opt} in
        q )
            QUIET="true"
            ;;
        s )
            SAVE_API_RESPONSE="true"
            ;;
        l )
            LOAD_API_RESPONSE="true"
            ;;
        e )
            EARLY_EXIT="true"
            ;;
        * )
            echo "Invalid Option: -$OPTARG" 1>&2
            exit 1
            ;;
    esac
done

if [[ "${QUIET}" == "false" ]] ; then
    echo "Loading sources..."
    echo
fi

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
    UPSTREAM_REPO="${fork[upstream_repo]}"
    TMP="${UPSTREAM_REPO##*/}"
    CORES+=("${TMP%.git}")
done
#CORES+=("SD-Installer-Win64_MiSTer")

API_RESPONSE_SAVE_FILE="${API_RESPONSE_SAVE_FILE:-github_api.txt}"
if [[ "${SAVE_API_RESPONSE}" == "true" ]] ; then
    rm "${API_RESPONSE_SAVE_FILE}" 2> /dev/null || true
fi

ALL_REPOSITORIES=()
API_PAGE=0
LOOP_CONDITION=true
while ${LOOP_CONDITION} ; do
    API_PAGE=$((API_PAGE+1))
        
    if [[ "${LOAD_API_RESPONSE}" == "false" ]] ; then
        API_RESPONSE=$(curl ${CURL_RETRY} ${SSL_SECURITY_OPTION} -sSLf "${MISTER_DEVEL_REPOS_URL}?per_page=100&page=${API_PAGE}&$(date +%s)")
    else
        API_RESPONSE=$(cat "${API_RESPONSE_SAVE_FILE}")
        LOOP_CONDITION=false
    fi
    if [[ "${SAVE_API_RESPONSE}" == "true" ]] ; then
        echo "${API_RESPONSE}" >> "${API_RESPONSE_SAVE_FILE}"
    fi
    PAGE_REPOSITORIES=( $(echo "${API_RESPONSE}" | jq -r '[.[] | .name + "|" + .owner.login + "|" + .svn_url + "|" + .default_branch + "|" + .updated_at] | .[]') )
    [[ "${#PAGE_REPOSITORIES[@]}" == "0" ]] && break
    ALL_REPOSITORIES+=( ${PAGE_REPOSITORIES[@]} )
done

DB_FILE=${DB_FILE:-"./.github/cores_db.txt"}

CORES_COMPARE_STRING=" ${CORES[@]^^} "
echo -n "" > "${DB_FILE}"
for line in "${ALL_REPOSITORIES[@]} "
do
    CORE_NAME="${line%%|*}"
    if [[ "${CORES_COMPARE_STRING}" =~ " ${CORE_NAME^^} " ]]; then
        echo "${line}" >> "${DB_FILE}"
    elif [[ "${QUIET}" == "false" ]] ; then
        echo "Skipped ${CORE_NAME}: ${line}"
    fi
done

if [[ "${QUIET}" == "false" ]] ; then
    echo
    echo "DB Content:"
    cat "${DB_FILE}"
    echo
    echo "Total cores: "$(wc -l "${DB_FILE}" | awk '{print $1}')
    echo
fi

if [[ "${EARLY_EXIT}" == "true" ]] ; then
    exit 0
fi

git config --global user.email "theypsilon@gmail.com"
git config --global user.name "The CI/CD Bot"

git add "${DB_FILE}"

if ! git diff --staged --quiet --exit-code ; then
    git commit -m "BOT: Cores DB updated."
    git push origin master
else
    echo "Nothing to be done."
fi
