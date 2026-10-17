---
title: Pileus on Linux
---

# Pileus on Linux (Flatpak)

Pileus is distributed as a Flatpak from its own signed repository (it is
not on Flathub). The runtime (`org.freedesktop.Platform`) comes from
Flathub, which is already configured on most distributions.

## Install

```sh
flatpak install --user https://lotho33.github.io/pileus/flatpak/io.github.lotho33.Pileus.flatpakref
```

or add the repository first, then install from it (GNOME Software / KDE
Discover will also show it):

```sh
flatpak remote-add --user --if-not-exists pileus https://lotho33.github.io/pileus/flatpak/pileus.flatpakrepo
flatpak install --user pileus io.github.lotho33.Pileus
```

Run it from the application menu, or with `flatpak run io.github.lotho33.Pileus`.

## Update

```sh
flatpak update
```

(GNOME Software, KDE Discover and Bazaar pick updates up automatically.)

## Offline install

Every [release](https://github.com/Lotho33/pileus/releases) also has a
single-file bundle, `pileus-<version>-linux-x64.flatpak`:

```sh
flatpak install --user pileus-<version>-linux-x64.flatpak
```

## Signing key

The repository is signed with the key
`AD5C 6DA0 755A EEFA 6A69  E1B8 BCFB A0FF C89C 0C4B`
([public key](flatpak/pileus-flatpak.gpg)); `flatpak` checks it
automatically — the key is embedded in the `.flatpakref`/`.flatpakrepo`.
