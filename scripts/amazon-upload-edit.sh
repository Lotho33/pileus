#!/usr/bin/env bash
# Pushes one or more signed TV APKs to a *new* Amazon Appstore edit via the
# App Submission API:
# https://developer.amazon.com/docs/app-submission-api/
#
#   scripts/amazon-upload-edit.sh path/to/app-*.apk            # draft only
#   scripts/amazon-upload-edit.sh --submit path/to/app-*.apk   # + submit for review
#
# Steps, in order: get an OAuth2 access token, reuse the open edit or
# create one (see step 2), upload each APK to it and — only with --submit —
# commit the edit, which is what submits it for Amazon's review. Without
# --submit the edit stays IN_PROGRESS in the Developer Console for a human
# to review and submit. release.yml's amazon-submit job is the caller.
#
# A version still under review blocks any upload (Amazon allows one edit,
# and a submitted one can't be modified): that ends with a warning and
# exit 0, not a failure — re-run the tag once the review is over.
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

SUBMIT=0
if [ "${1:-}" = "--submit" ]; then
  SUBMIT=1
  shift
fi

if [ "$#" -eq 0 ]; then
  echo "Uso: $0 [--submit] path/to/app1.apk [app2.apk ...]" >&2
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

echo "== 2/3: edit per app $AMAZON_APP_ID =="
# Amazon allows only ONE open edit per app: POST /edits answers 412
# error_new_version_creation_not_allowed while one exists (e.g. left by a
# previous release that was never submitted) AND while a submitted version
# is still under review. So: reuse the open edit if there is one (dropping
# the APKs a previous run put in it), otherwise create a new one.
# (no open edit = 200 with an empty body/object or 404, depending on which
# doc you trust — both mean "none" here; anything else fails loud.)
tmp="$(mktemp)"
status="$(curl -sS -o "$tmp" -w '%{http_code}' "$API/edits" \
  -H "Authorization: Bearer $ACCESS_TOKEN")"
active_edit="$(cat "$tmp")"; rm -f "$tmp"
if [ "$status" != 200 ] && [ "$status" != 404 ]; then
  echo "::error::GET $API/edits -> HTTP $status" >&2
  echo "$active_edit" >&2
  exit 1
fi
EDIT_ID=""
[ "$status" = 200 ] && EDIT_ID="$(echo "$active_edit" | jq -r '.id // empty' 2>/dev/null || true)"
if [ -n "$EDIT_ID" ]; then
  edit_status="$(echo "$active_edit" | jq -r '.status // "?"')"
  if [ "$edit_status" != IN_PROGRESS ]; then
    # Submitted (e.g. REVIEW): every change to it answers 412
    # error_cannot_be_modified_in_state — v1.6.7's run died on exactly that.
    echo "::warning::L'edit Amazon aperto ($EDIT_ID) è in stato $edit_status: una versione è ancora in revisione e non si può modificare. APK NON caricati — rilancia questo tag (Actions > release > Run workflow) a revisione conclusa."
    exit 0
  fi
  echo "Edit aperto esistente: $EDIT_ID ($edit_status) — lo riuso."
  for apk_id in $(req GET "$API/edits/$EDIT_ID/apks" | jq -r '.[]?.id // empty'); do
    etag="$(curl -sS -D - -o /dev/null "$API/edits/$EDIT_ID/apks/$apk_id" \
      -H "Authorization: Bearer $ACCESS_TOKEN" | tr -d '\r' | awk 'tolower($1)=="etag:"{print $2}')"
    echo "  rimuovo APK precedente $apk_id"
    req DELETE "$API/edits/$EDIT_ID/apks/$apk_id" -H "If-Match: $etag" >/dev/null
  done
else
  tmp="$(mktemp)"
  status="$(curl -sS -o "$tmp" -w '%{http_code}' -X POST "$API/edits" \
    -H "Authorization: Bearer $ACCESS_TOKEN")"
  edit_response="$(cat "$tmp")"; rm -f "$tmp"
  if [ "$status" = 412 ] && echo "$edit_response" | grep -q error_new_version_creation_not_allowed; then
    # No open edit and still no new one allowed: the last submitted version
    # is under review (or awaiting publication). Nothing this job can fix —
    # warn instead of failing every release until Amazon finishes.
    echo "::warning::Amazon non permette un nuovo edit: una versione è ancora in revisione/in attesa di pubblicazione. APK NON caricati — ricarica questo tag (workflow_dispatch) a revisione conclusa."
    echo "$edit_response"
    exit 0
  fi
  if [ "$status" -lt 200 ] || [ "$status" -ge 300 ]; then
    echo "::error::POST $API/edits -> HTTP $status" >&2
    echo "$edit_response" >&2
    exit 1
  fi
  EDIT_ID="$(echo "$edit_response" | jq -r '.id // empty')"
  if [ -z "$EDIT_ID" ]; then
    echo "::error::editId non trovato nella risposta:" >&2
    echo "$edit_response" >&2
    exit 1
  fi
  echo "Edit creato: $EDIT_ID ($(echo "$edit_response" | jq -r '.status // "?"'))"
fi

echo "== 3/3: carico $# APK =="
for apk in "$@"; do
  name="$(basename "$apk")"
  echo "  -> $name ($(du -h "$apk" | cut -f1))"
  req POST "$API/edits/$EDIT_ID/apks/upload" \
    -H 'Content-Type: application/octet-stream' \
    -H "fileName: $name" \
    --data-binary "@$apk" >/dev/null
done

if [ "$SUBMIT" = 1 ]; then
  echo "== commit: invio in revisione =="
  etag="$(curl -sS -D - -o /dev/null "$API/edits/$EDIT_ID" \
    -H "Authorization: Bearer $ACCESS_TOKEN" | tr -d '\r' | awk 'tolower($1)=="etag:"{print $2}')"
  req POST "$API/edits/$EDIT_ID/commit" -H "If-Match: $etag" >/dev/null
  echo
  echo "Fatto — edit $EDIT_ID su app $AMAZON_APP_ID, $# APK caricati e INVIATI in revisione."
  exit 0
fi

cat <<EOF

Fatto — edit $EDIT_ID su app $AMAZON_APP_ID, $# APK caricati.
Stato: IN_PROGRESS — NON inviato in revisione (senza --submit).
Rivedilo e invialo da: Amazon Developer Console > Apps & Games > la tua app > App Submission.
EOF
