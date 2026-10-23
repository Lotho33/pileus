#!/usr/bin/env bash
# Pushes one or more signed TV APKs to a *new* Amazon Appstore edit via the
# App Submission API:
# https://developer.amazon.com/docs/app-submission-api/
#
#   scripts/amazon-upload-edit.sh path/to/app-*.apk            # draft only
#   scripts/amazon-upload-edit.sh --submit path/to/app-*.apk   # + submit for review
#
# Steps, in order: get an OAuth2 access token, reuse the open edit or
# create one (see step 2), put each APK in it (see step 3) and — only with --submit —
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

# A new edit starts from the live version, APKs included. Each of those is
# REPLACED in place, not deleted and uploaded again: replace keeps the APK's
# own attributes — device targeting (documented, flows.html) and the
# "Apply Amazon DRM?" answer, which the API has no field for and which a
# freshly uploaded APK lacks (v1.6.9: commit refused with
# error_apk_drm_value_missing). Only APKs beyond the ones already there are
# uploaded new, and those still need the DRM answer in the Console once.
apk_etag() {
  curl -sS -D - -o /dev/null "$API/edits/$EDIT_ID/apks/$1" \
    -H "Authorization: Bearer $ACCESS_TOKEN" | tr -d '\r' | awk 'tolower($1)=="etag:"{print $2}'
}
# Not `mapfile < <(req …)`: a failing req in a process substitution can't
# stop the script, and an empty list would turn every replace into an upload.
apks_json="$(req GET "$API/edits/$EDIT_ID/apks")"
mapfile -t existing < <(echo "$apks_json" | jq -r '.[]?.id // empty')

echo "== 3/3: carico $# APK (nell'edit ce ne sono ${#existing[@]}) =="
i=0
for apk in "$@"; do
  name="$(basename "$apk")"
  if [ "$i" -lt "${#existing[@]}" ]; then
    apk_id="${existing[$i]}"
    echo "  -> $name ($(du -h "$apk" | cut -f1)) sostituisce l'APK $apk_id"
    req PUT "$API/edits/$EDIT_ID/apks/$apk_id/replace" \
      -H "If-Match: $(apk_etag "$apk_id")" \
      -H 'Content-Type: application/vnd.android.package-archive' \
      -H "fileName: $name" \
      --data-binary "@$apk" >/dev/null
  else
    echo "  -> $name ($(du -h "$apk" | cut -f1)) nuovo APK"
    echo "::warning::$name caricato come APK nuovo: se l'invio fallisce con error_apk_drm_value_missing, rispondi una volta \"Apply Amazon DRM?\" = No in Developer Console; dalle versioni dopo verrà sostituito e la risposta resta."
    req POST "$API/edits/$EDIT_ID/apks/upload" \
      -H 'Content-Type: application/vnd.android.package-archive' \
      -H "fileName: $name" \
      --data-binary "@$apk" >/dev/null
  fi
  i=$((i + 1))
done
# More APKs in the edit than this release ships (e.g. an ABI dropped):
# the extra ones go, or the old build would ship alongside the new one.
while [ "$i" -lt "${#existing[@]}" ]; do
  apk_id="${existing[$i]}"
  echo "  rimuovo APK in più $apk_id"
  req DELETE "$API/edits/$EDIT_ID/apks/$apk_id" -H "If-Match: $(apk_etag "$apk_id")" >/dev/null
  i=$((i + 1))
done

if [ "$SUBMIT" = 1 ]; then
  # Amazon refuses the commit while any listing language lacks "recent
  # changes" (v1.6.8: error_release_notes_incomplete for en-US). Generic
  # per-version notes, Italian for it-*, English for everything else.
  echo "== note di versione (recentChanges) =="
  version="${AMAZON_RELEASE_VERSION:-}"
  for lang in $(req GET "$API/edits/$EDIT_ID/listings" | jq -r '(.listings // .) | keys[]?'); do
    hdr="$(mktemp)"
    listing="$(req GET "$API/edits/$EDIT_ID/listings/$lang" -D "$hdr")"
    etag="$(tr -d '\r' < "$hdr" | awk 'tolower($1)=="etag:"{print $2}')"
    rm -f "$hdr"
    case "$lang" in
      it*) notes="Pileus $version: correzioni e miglioramenti." ;;
      *) notes="Pileus $version: bug fixes and improvements." ;;
    esac
    echo "$listing" | jq --arg n "$notes" '.recentChanges = $n' > "$hdr.json"
    req PUT "$API/edits/$EDIT_ID/listings/$lang" -H "If-Match: $etag" \
      -H 'Content-Type: application/json' --data-binary "@$hdr.json" >/dev/null
    rm -f "$hdr.json"
    echo "  $lang: $notes"
  done

  echo "== commit: invio in revisione =="
  etag="$(curl -sS -D - -o /dev/null "$API/edits/$EDIT_ID" \
    -H "Authorization: Bearer $ACCESS_TOKEN" | tr -d '\r' | awk 'tolower($1)=="etag:"{print $2}')"
  tmp="$(mktemp)"
  status="$(curl -sS -o "$tmp" -w '%{http_code}' -X POST "$API/edits/$EDIT_ID/commit" \
    -H "Authorization: Bearer $ACCESS_TOKEN" -H "If-Match: $etag")"
  if [ "$status" -lt 200 ] || [ "$status" -ge 300 ]; then
    # The APKs are in the edit already: say exactly what's left to do by
    # hand. error_apk_drm_value_missing = "Apply Amazon DRM?" unanswered —
    # only possible for an APK uploaded new (see step 3).
    echo "::error::APK caricati nell'edit $EDIT_ID, ma Amazon ha rifiutato l'invio (HTTP $status). Completa e invia da Developer Console > App Submission > la versione in corso. Errori:"
    jq -r '.errors[]? | "  - \(.errorCode): \(.errorMessage)"' "$tmp" 2>/dev/null || cat "$tmp"
    if grep -q error_apk_drm_value_missing "$tmp"; then
      echo "  (error_apk_drm_value_missing: nella sezione dell'APK rispondi a \"Apply Amazon DRM?\" — Pileus non usa l'SDK Appstore: No)"
    fi
    rm -f "$tmp"
    exit 1
  fi
  rm -f "$tmp"
  echo
  echo "Fatto — edit $EDIT_ID su app $AMAZON_APP_ID, $# APK caricati e INVIATI in revisione."
  exit 0
fi

cat <<EOF

Fatto — edit $EDIT_ID su app $AMAZON_APP_ID, $# APK caricati.
Stato: IN_PROGRESS — NON inviato in revisione (senza --submit).
Rivedilo e invialo da: Amazon Developer Console > Apps & Games > la tua app > App Submission.
EOF
