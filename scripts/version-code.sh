#!/usr/bin/env bash
# Prints the Android versionCode for a release version:
#
#   scripts/version-code.sh 1.6.8   # -> 106080000
#
# MAJOR*10^8 + MINOR*10^6 + PATCH*10^4. Every workflow (release.yml's
# sideload APKs and store jobs, store.yml) derives it from the version
# instead of its own run number: Play and Amazon reject a versionCode that
# isn't higher than the last one uploaded, and per-workflow run counters
# drift apart (Play got store.yml's, Amazon release.yml's). The low 4 digits
# stay free for Flutter's --split-per-abi offset (abi*1000 added to it).
# Valid for MINOR/PATCH < 100; the largest Android accepts is 2100000000.
set -euo pipefail
v=${1:?usage: $0 X.Y.Z}
[[ "$v" =~ ^v?([0-9]+)\.([0-9]+)\.([0-9]+)$ ]] || { echo "bad version: $v" >&2; exit 2; }
major=${BASH_REMATCH[1]} minor=${BASH_REMATCH[2]} patch=${BASH_REMATCH[3]}
(( minor < 100 && patch < 100 )) || { echo "minor/patch must be < 100: $v" >&2; exit 2; }
echo $(( major * 100000000 + minor * 1000000 + patch * 10000 ))
