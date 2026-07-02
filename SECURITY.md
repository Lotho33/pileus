# Security Policy

## Reporting a vulnerability

Please report security issues **privately**, not as a public issue or pull
request.

Use GitHub's private vulnerability reporting:
**the repository's *Security* tab → *Report a vulnerability***. This opens a
private advisory visible only to the maintainers.

Include, as far as you can:

- affected target(s) (Android TV, mobile, desktop, web) and version / commit
- steps to reproduce or a proof of concept
- impact assessment

We aim to acknowledge a report within a week and to agree a disclosure
timeline with you before any public write-up.

## Supported versions

Pileus ships from the `main` line; only the latest release receives fixes.
There is no long-term support branch.

## Scope notes

Pileus is a **client** for a server the user hosts themselves (Mycelium).
Threats in scope for this repo are those in the client: credential / token
handling, the pairing flow, TLS trust decisions, the update-check code, and
handling of untrusted data returned by a server or its plugins. The server
and its plugins are a separate project.

## Diagnostic logging (by design)

The app has a hidden **"Diagnostica (log su adb)"** toggle in Preferences,
off by default. When enabled, Pileus writes verbose diagnostics to the
platform log (`adb logcat`, tagged `pileus/perf` and `pileus/jank`),
**including plugin and media identifiers and the resolved stream host**.
This is intended for field debugging on a device you control. Anyone with
read access to that device's logs while the toggle is on can see what is
being played and from where. Leave it off unless you are actively
debugging, and turn it back off afterwards (it survives an app restart).

Release builds otherwise strip diagnostic `debugPrint` output.
