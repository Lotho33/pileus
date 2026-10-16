#!/usr/bin/env python3
"""Which store targets a release actually changes.

    scripts/release-targets.py                     # HEAD vs the latest tag
    scripts/release-targets.py --base v1.6.7 --head v1.6.8
    scripts/release-targets.py --force webos       # always count webos as changed
    scripts/release-targets.py --github-output     # also append to $GITHUB_OUTPUT

Targets (and the stores they feed):
    tv      Play (Android TV app) + Amazon Appstore   entry: lib/main.dart
    mobile  Play (mobile app)                         entry: lib/main_mobile.dart
    webos   LG Content Store (manual upload)          entry: lib/main_web_tv.dart

A target counts as changed when a file it is built from changed between
--base and --head. For Dart that set is computed, not hand-listed: every
lib/ file transitively imported/exported/part-ed from the target's entry
point (both sides of a conditional import). main.dart imports
main_mobile.dart only to hand the mobile flavor off to it, so tv/webos do
not follow that one edge — otherwise every mobile-only change would ship
the TV apps too. Non-Dart inputs per target are listed in EXTRA below.
pubspec.yaml counts only when something other than its `version:` line
changed (every release bumps that).
"""

import argparse
import fnmatch
import os
import re
import subprocess
import sys

ROOT = subprocess.run(
    ["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True, check=True
).stdout.strip()

ENTRIES = {
    "tv": "lib/main.dart",
    "mobile": "lib/main_mobile.dart",
    "webos": "lib/main_web_tv.dart",
}
# Import edges a target does not follow (see module doc).
BOUNDARY = {
    "tv": {"lib/main_mobile.dart"},
    "mobile": set(),
    "webos": {"lib/main_mobile.dart"},
}
COMMON = ["pubspec.yaml", "pubspec.lock", "assets/*"]
EXTRA = {
    "tv": ["android/*", "third_party/*", "!android/app/src/mobile/*"],
    "mobile": ["android/*", "third_party/*", "!android/app/src/tv/*"],
    "webos": ["web/*", "packaging/webos/*", "scripts/build-webos.sh"],
}

# One import/export/part directive, possibly spanning lines, up to its ';'.
DIRECTIVE = re.compile(r"^\s*(?:import|export|part)\s+(?!of\b)([^;]*);", re.M | re.S)
QUOTED = re.compile(r"""['"]([^'"]+\.dart)['"]""")


def git(*args):
    return subprocess.run(
        ["git", *args], cwd=ROOT, capture_output=True, text=True, check=True
    ).stdout


def dart_closure(entry, boundary):
    seen, stack = set(), [entry]
    while stack:
        path = stack.pop()
        if path in seen or not os.path.isfile(os.path.join(ROOT, path)):
            continue
        seen.add(path)
        with open(os.path.join(ROOT, path), encoding="utf-8") as f:
            src = f.read()
        for directive in DIRECTIVE.findall(src):
            for uri in QUOTED.findall(directive):
                if uri.startswith("package:pileus/"):
                    dep = "lib/" + uri[len("package:pileus/"):]
                elif ":" in uri:
                    continue  # dart:, other packages
                else:
                    dep = os.path.normpath(os.path.join(os.path.dirname(path), uri))
                if dep not in boundary:
                    stack.append(dep)
    return seen


def matches(path, patterns):
    hit = False
    for p in patterns:
        if p.startswith("!"):
            if fnmatch.fnmatch(path, p[1:]):
                return False
        elif fnmatch.fnmatch(path, p):
            hit = True
    return hit


def pubspec_really_changed(base, head):
    diff = git("diff", "--unified=0", base, head, "--", "pubspec.yaml")
    for line in diff.splitlines():
        if line.startswith(("+++", "---")) or not line.startswith(("+", "-")):
            continue
        if not re.match(r"^[+-]version:", line):
            return True
    return False


def latest_tag(ref):
    try:
        return git("describe", "--tags", "--abbrev=0", "--match", "v*.*.*", ref).strip()
    except subprocess.CalledProcessError:
        return None


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--base", help="previous release (default: latest tag before --head)")
    ap.add_argument("--head", default="HEAD")
    ap.add_argument("--force", default="", help="comma list of targets, or 'all'")
    ap.add_argument("--github-output", action="store_true")
    args = ap.parse_args()

    base = args.base
    if not base:
        # When --head is itself a tag, step back one so it isn't its own base.
        base = latest_tag(f"{args.head}^" if _is_tag(args.head) else args.head)
    forced = set(ENTRIES) if args.force.strip() == "all" else {
        t.strip() for t in args.force.split(",") if t.strip()
    }
    unknown = forced - set(ENTRIES)
    if unknown:
        sys.exit(f"unknown target(s): {', '.join(sorted(unknown))}")

    if base is None:
        print("no previous release tag: every target counts as changed")
        changed_files = None
    else:
        changed_files = [f for f in git("diff", "--name-only", base, args.head).splitlines() if f]
        if "pubspec.yaml" in changed_files and not pubspec_really_changed(base, args.head):
            changed_files.remove("pubspec.yaml")
        print(f"changes {base}..{args.head}: {len(changed_files)} file(s)")

    result = {}
    for target, entry in ENTRIES.items():
        if changed_files is None:
            result[target], reasons = True, ["first release"]
        else:
            closure = dart_closure(entry, BOUNDARY[target])
            reasons = [
                f for f in changed_files
                if f in closure or matches(f, COMMON + EXTRA[target])
            ]
            result[target] = bool(reasons)
        if target in forced and not result[target]:
            result[target], reasons = True, ["--force"]
        state = "CHANGED" if result[target] else "unchanged"
        print(f"  {target:7s} {state}")
        for r in reasons[:8]:
            print(f"            {r}")
        if len(reasons) > 8:
            print(f"            … +{len(reasons) - 8} more")

    if args.github_output:
        play = [t for t in ("tv", "mobile") if result[t]]
        with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as out:
            for target, changed in result.items():
                out.write(f"{target}={'true' if changed else 'false'}\n")
            out.write(f"play_matrix={_json_list(play)}\n")


def _is_tag(ref):
    try:
        git("describe", "--tags", "--exact-match", ref)
        return True
    except subprocess.CalledProcessError:
        return False


def _json_list(items):
    return "[" + ",".join(f'"{i}"' for i in items) + "]"


if __name__ == "__main__":
    main()
