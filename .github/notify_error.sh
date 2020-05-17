#!/usr/bin/env bash
# Copyright (c) 2020 José Manuel Barroso Galindo <theypsilon@gmail.com>

set -euo pipefail

SENDER="jose@josebg.com"

if (( "$#" < 2 )); then
    >&2 echo "Must run $0 REASON emails+"
    exit 1
fi

REASON="$1"

shift

RECIPIENT="["
for var in "$@"
do
    RECIPIENT="${RECIPIENT}{\"email\": \"${var}\"},"
done
RECIPIENT="${RECIPIENT:0:${#RECIPIENT} - 1}]"

json_escape () {
    printf '%s' "$1" | python -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
}

DIFF=$(git diff)
STATUS=$(git status)

DIFF="${DIFF//$'\n'/<br />}"
STATUS="${STATUS//$'\n'/<br />}"

DIFF=$(json_escape "$DIFF")
STATUS=$(json_escape "$STATUS")

SUBJECT="Build broken at ${GITHUB_REPOSITORY}@${GITHUB_SHA:0:5}!"
MESSAGE="<p>Release build failed!</p> \
<p>Reason '${REASON}'.</p> \
<p>Latest commit: <a href='https://github.com/${GITHUB_REPOSITORY}/commit/${GITHUB_SHA}'></a>https://github.com/${GITHUB_REPOSITORY}/commit/${GITHUB_SHA}</p> \
<p>Follow these steps to see more details about what has gone wrong:</p> \
<ol> \
  <li>Go to https://github.com/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}</li> \
  <li>Click on 'build' in the left side.</li> \
  <li>Open the 'Sync + Release' section.</li> \
  <li>Follow the log to find the errors.</li> \
</ol> \
<p>Fix the issues and you'll stop receiving this message.</p> \
<br /> \
<p>-------------------------------------------------------------------------------------------</p> \
<p>GIT STATUS:</p> \
<p>${STATUS:1:${#STATUS}-2}</p> \
<p>-------------------------------------------------------------------------------------------</p> \
<p>GIT DIFF:</p> \
<p>${DIFF:1:${#DIFF}-2}</p> \
"

POST_DATA="{
    \"personalizations\": [
        {
            \"to\": ${RECIPIENT}
        }
    ],
    \"from\": {\"email\": \"${SENDER}\"},
    \"subject\": \"${SUBJECT}\",
    \"content\": [
        {
            \"type\": \"text/html\",
            \"value\": \"${MESSAGE}\"
        }
    ]
}"

curl --fail --request POST \
  --url https://api.sendgrid.com/v3/mail/send \
  --header "Authorization: Bearer ${NOTIFICATION_API_KEY}" \
  --header "Content-Type: application/json" \
  --data "${POST_DATA}"

echo "Email sent OK!"
exit 1