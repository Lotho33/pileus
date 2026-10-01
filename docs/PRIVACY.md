# Privacy Policy — Pileus

_Last updated: 2026-10-01_

Pileus is a client application. It does not operate any servers of its
own, does not collect, store, or transmit any personal data to its
developer or to any third party, and has no analytics, advertising, or
tracking of any kind.

## What Pileus does

Pileus connects **only** to the Mycelium server address you provide —
either one discovered automatically on your local network, or one you
type in manually (including a remote server over HTTPS). All of the
app's functionality — browsing, search, playback, your profile, watch
history, settings — is implemented by exchanging data directly with
**that server**, which you (or whoever operates it) control.

Pileus does not contact any other server, except:

- the GitHub releases API (`api.github.com`), only in non-store builds,
  to check whether a newer version is available. This sends no personal
  data — it's a plain, unauthenticated read of public release metadata.
  Store builds (Google Play, Amazon Appstore, Samsung/LG) disable this
  check entirely, since those stores handle updates themselves.

## What stays on your device

- The server address and device pairing credentials, so you don't have to
  re-pair on every launch.
- Cached catalog data and images, to make browsing faster — cleared from
  Preferences at any time ("Svuota cache catalogo").
- App preferences (subtitle style, buffer size, low-power mode, and
  similar settings).

None of this is sent anywhere except back to the Mycelium server you
paired with — Pileus has no backend of its own to send it to.

## What the server you connect to sees

Because Pileus is a client for a server you choose, that server
necessarily sees your activity within it — what you browse, search for,
and watch — the same way any client app's server does. Pileus has no
visibility into, and no control over, how that server's operator handles
that data. If you're connecting to a server you don't operate yourself,
ask its operator about their own data practices.

## Diagnostic logging (opt-in, off by default)

Preferences has a hidden "Diagnostica" toggle. When turned on, Pileus
writes verbose diagnostic output to the device's own system log —
intended for troubleshooting a specific device with someone who has
access to it. This log can include plugin/media identifiers and the
resolved server host. It never leaves the device on its own; it's
visible only to someone with direct access to the device's logs while
the toggle is on. Leave it off unless you're actively debugging an issue.

## Permissions

See `README.md`'s Android section for the full list of permissions the
app requests and why — in short: internet access (to talk to your
server), WiFi/network state (for LAN server discovery), and standard
media-playback permissions (keeping the screen/CPU awake and playback
running while backgrounded).

## Children's privacy

Pileus collects no personal data from anyone, including children, and has
no mechanism for a user (of any age) to submit personal data to its
developer.

## Changes to this policy

Any change to this policy will be published in this same file, in the
public source repository.

## Contact

Pileus is open source: [github.com/Lotho33/pileus](https://github.com/Lotho33/pileus).
Open an issue there for any privacy question. For a security-sensitive
report, use GitHub's private vulnerability reporting instead — see
`SECURITY.md`.
