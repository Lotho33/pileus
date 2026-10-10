#!/usr/bin/env bash
# Sets the Amazon Appstore API credentials (Client ID / Client Secret — the
# app-to-app OAuth2 credentials from the Amazon Developer Console, Settings >
# API Access) as GitHub Actions secrets on this repo, so a future workflow
# can talk to the Amazon Appstore Submission API directly instead of a human
# uploading the AAB/APK by hand (see store.yml's own header: today it only
# *builds* the artifacts, nothing talks to either store's API yet).
#
#   scripts/set-amazon-secrets.sh
#
# Prompts for both values interactively — the secret is typed hidden and
# never echoed, and neither value is ever passed as a CLI argument, so
# neither ends up in shell history or a process listing (`ps`). Both are
# piped straight into `gh secret set`, which encrypts each one with the
# repo's own public key before anything leaves this machine — the same path
# `gh` already uses for every other secret this repo has
# (ANDROID_KEYSTORE_BASE64 and friends, see release.yml/store.yml).
#
# Needs: `gh` installed and authenticated (gh auth login) with admin access
# to the repo below.
#
# Override via env:
#   PILEUS_REPO                owner/repo to set secrets on     (default: Lotho33/pileus)
#   AMAZON_CLIENT_ID_NAME      secret name for the client id    (default: AMAZON_CLIENT_ID)
#   AMAZON_CLIENT_SECRET_NAME  secret name for the client secret (default: AMAZON_CLIENT_SECRET)
set -euo pipefail

REPO="${PILEUS_REPO:-Lotho33/pileus}"
ID_NAME="${AMAZON_CLIENT_ID_NAME:-AMAZON_CLIENT_ID}"
SECRET_NAME="${AMAZON_CLIENT_SECRET_NAME:-AMAZON_CLIENT_SECRET}"

if ! command -v gh >/dev/null 2>&1; then
  echo "Errore: gh (GitHub CLI) non è installato. https://cli.github.com/" >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "Errore: non sei autenticato con gh. Esegui prima: gh auth login" >&2
  exit 1
fi

echo "Repo: $REPO"
echo "Secret: $ID_NAME, $SECRET_NAME"
echo

read -r -p "Amazon Client ID: " client_id
if [ -z "$client_id" ]; then
  echo "Errore: il Client ID non può essere vuoto." >&2
  exit 1
fi

read -r -s -p "Amazon Client Secret (non verrà mostrato a schermo): " client_secret
echo
if [ -z "$client_secret" ]; then
  echo "Errore: il Client Secret non può essere vuoto." >&2
  exit 1
fi

printf '%s' "$client_id" | gh secret set "$ID_NAME" --repo "$REPO"
printf '%s' "$client_secret" | gh secret set "$SECRET_NAME" --repo "$REPO"

unset client_id client_secret

echo
echo "Fatto. Secret presenti su $REPO:"
gh secret list --repo "$REPO" | grep -E "^($ID_NAME|$SECRET_NAME)[[:space:]]" || true
