#!/usr/bin/env bash
# Pushes one or more signed TV APKs to a *new* Amazon Appstore edit via the
# App Submission API:
# https://developer.amazon.com/docs/app-submission-api/
#
#   scripts/amazon-upload-edit.sh path/to/app-*.apk
#
# Three calls, in order: get an OAuth2 access token, create an edit, upload
# each APK to it. Deliberately stops there — it never commits/submits the
# edit. The edit is left in the Developer Console as IN_PROGRESS; open it,
# review it, and submit it for review by hand. release.yml's amazon-submit
# job is the only caller; see that job's own comment for why auto-submit is
# intentionally not wired up.
#
# Needs env:
#   AMAZON_CLIENT_ID / AMAZON_CLIENT_SECRET   App Submission API credentials
#                                              (Developer Console > Settings >
#                                              API Access) — see
#                                              scripts/set-amazon-secrets.sh
#   AMAZON_APP_ID                              this app's id (Developer
#                                              Console > your app >
#                                              "Additional information")
#
# NOTE ON API DETAIL CONFIDENCE: written against Amazon's current published
# docs (auth.html, python-example.html, the Feb-2025 "using the App
# Submission API" blog post), not against a live test run — Amazon's own
# pages disagree with each other on small details (the upload Content-Type
# header, for one: this script sends both a Content-Type and the fileName
# header some docs show as separately required). Every call below dumps the
# full raw response on any non-2xx status specifically so a wrong detail
# fails loud with Amazon's own error text in the log, not a bare curl exit
# code — if the very first real run fails, that response is exactly what to
# go back to the docs (or Amazon dev support) with.
set -euo pipefail

: "${AMAZON_CLIENT_ID:?set AMAZON_CLIENT_ID}"
: "${AMAZON_CLIENT_SECRET:?set AMAZON_CLIENT_SECRET}"
: "${AMAZON_APP_ID:?set AMAZON_APP_ID}"

if [ "$#" -eq 0 ]; then
  echo "Uso: $0 path/to/app1.apk [app2.apk ...]" >&2
  exit 1
fi
for apk in "$@"; do
  [ -f "$apk" ] || { echo "::error::file non trovato: $apk" >&2; exit 1; }
done

if ! command -v jq >/dev/null 2>&1; then
  echo "::error::serve jq (presente di default sui runner GitHub-hosted; installalo altrove con apt/dnf)" >&2
  exit 1
fi

API="https://developer.amazon.com/api/appstore/v1/applications/$AMAZON_APP_ID"

# GET/POST wrapper: on a non-2xx it prints the full response body (JSON
# error or otherwise) before failing, so the log always shows what Amazon
# actually said back, not just curl's own exit status.
req() {
  local method="$1" url="$2"; shift 2
  local tmp status
  tmp="$(mktemp)"
  status="$(curl -sS -o "$tmp" -w '%{http_code}' -X "$method" "$url" \
    -H "Authorization: Bearer $ACCESS_TOKEN" "$@")"
  if [ "$status" -lt 200 ] || [ "$status" -ge 300 ]; then
    echo "::error::$method $url -> HTTP $status" >&2
    cat "$tmp" >&2
    rm -f "$tmp"
    exit 1
  fi
  cat "$tmp"
  rm -f "$tmp"
}

echo "== 1/3: token OAuth2 (Login with Amazon, client_credentials) =="
token_response="$(curl -sS -X POST https://api.amazon.com/auth/o2/token \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode 'grant_type=client_credentials' \
  --data-urlencode "client_id=$AMAZON_CLIENT_ID" \
  --data-urlencode "client_secret=$AMAZON_CLIENT_SECRET" \
  --data-urlencode 'scope=appstore::apps:readwrite')"
ACCESS_TOKEN="$(echo "$token_response" | jq -r '.access_token // empty')"
if [ -z "$ACCESS_TOKEN" ]; then
  echo "::error::token non ottenuto. Risposta Amazon:" >&2
  echo "$token_response" >&2
  exit 1
fi
echo "Token ok (scade in $(echo "$token_response" | jq -r '.expires_in // "?"')s)."

echo "== 2/3: creo un nuovo edit per app $AMAZON_APP_ID =="
edit_response="$(req POST "$API/edits")"
EDIT_ID="$(echo "$edit_response" | jq -r '.id // empty')"
if [ -z "$EDIT_ID" ]; then
  echo "::error::editId non trovato nella risposta:" >&2
  echo "$edit_response" >&2
  exit 1
fi
echo "Edit creato: $EDIT_ID ($(echo "$edit_response" | jq -r '.status // "?"'))"

echo "== 3/3: carico $# APK =="
for apk in "$@"; do
  name="$(basename "$apk")"
  echo "  -> $name ($(du -h "$apk" | cut -f1))"
  req POST "$API/edits/$EDIT_ID/apks/upload" \
    -H 'Content-Type: application/octet-stream' \
    -H "fileName: $name" \
    --data-binary "@$apk" >/dev/null
done

cat <<EOF

Fatto — edit $EDIT_ID su app $AMAZON_APP_ID, $# APK caricati.
Stato: IN_PROGRESS — NON inviato in revisione (questo script non fa commit).
Rivedilo e invialo da: Amazon Developer Console > Apps & Games > la tua app > App Submission.
EOF
