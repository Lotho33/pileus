#!/usr/bin/env bash
# Rilascia una nuova versione di Pileus.
#
#   scripts/release.sh 1.0.5            # bump + commit + tag v1.0.5 + push
#   scripts/release.sh 1.0.5 -n        # dry-run: mostra cosa farebbe e basta
#
# Il push del tag vX.Y.Z fa partire la pipeline CI (.forgejo/workflows/release.yml)
# che builda gli APK firmati + il tarball Linux e li allega alla release.
#
# Override via env:
#   PILEUS_RELEASE_REMOTE   git remote su cui pushare      (default: forgejo)
#   PILEUS_RELEASE_BRANCH   branch da pushare              (default: dev)
#   PILEUS_ACTIONS_URL      URL "segui la build" stampato a fine run
set -euo pipefail

REMOTE=${PILEUS_RELEASE_REMOTE:-forgejo}
BRANCH=${PILEUS_RELEASE_BRANCH:-dev}
ACTIONS_URL=${PILEUS_ACTIONS_URL:-}

ver=${1:-}
dry=false
[[ "${2:-}" == "-n" || "${2:-}" == "--dry-run" ]] && dry=true

if [[ ! "$ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "uso: $0 X.Y.Z [-n]   (es. $0 1.0.5)" >&2
  exit 2
fi
tag="v$ver"

cd "$(git rev-parse --show-toplevel)"

# --- controlli ---------------------------------------------------------------
cur_branch=$(git branch --show-current)
[[ "$cur_branch" == "$BRANCH" ]] || { echo "sei su '$cur_branch', non '$BRANCH'." >&2; exit 1; }

git fetch -q "$REMOTE" --tags || true
if git rev-parse -q --verify "refs/tags/$tag" >/dev/null || \
   git ls-remote --exit-code --tags "$REMOTE" "$tag" >/dev/null 2>&1; then
  echo "il tag $tag esiste gia (locale o su $REMOTE)." >&2
  exit 1
fi

# solo pubspec.yaml puo essere gia modificato tra i file tracciati
# (i file non tracciati non bloccano il rilascio)
dirty=$(git status --porcelain --untracked-files=no | grep -v ' pubspec.yaml$' || true)
[[ -z "$dirty" ]] || { echo "albero di lavoro sporco:"; echo "$dirty"; exit 1; }

# --- bump versione ---------------------------------------------------------
# versionCode Android = parte dopo il '+'. Lo teniamo a 0: la pipeline passa
# --build-number=<run number> e sovrascrive comunque.
new_line="version: ${ver}+0"
old_line=$(grep -E '^version:' pubspec.yaml)
echo "pubspec: '$old_line'  ->  '$new_line'"
echo "commit + tag $tag, poi push '$BRANCH' e '$tag' su '$REMOTE'"

if $dry; then echo "(dry-run, nulla eseguito)"; exit 0; fi

sed -i -E "s/^version:.*/${new_line}/" pubspec.yaml

git add pubspec.yaml
git commit -m "$tag" -m "" \
  -m "Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git tag -a "$tag" -m "$tag"

git push "$REMOTE" "$BRANCH"
git push "$REMOTE" "$tag"

echo
echo "fatto."
if [[ -n "$ACTIONS_URL" ]]; then
  echo "segui la build:  $ACTIONS_URL"
else
  echo "segui la build nella pagina Actions del remote '$REMOTE'."
fi
