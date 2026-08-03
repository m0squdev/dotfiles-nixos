# Working in this repo

Read [CONTRIBUTING.md](CONTRIBUTING.md) first — it has the layout, the
one-line-vs-own-module rule, and how to add a host. This file only records the
things that are easy to get wrong when editing from an agent session.

## Never edit the live dotfiles

`~/.config/*` are **read-only symlinks into the Nix store**. Editing them either
fails or is silently discarded on the next rebuild. Always edit the source in
`config/`, `local/` or `assets/` here, then rebuild. Same for `/etc/nixos` —
this flake replaces it.

## New files must be staged before they exist to Nix

Flakes only see **git-tracked** files. A brand-new `.nix` file (or dotfile under
`config/`) fails evaluation with *"Path ... is not tracked by Git"* until it is
staged:

```sh
git add <new-file>
```

Staging is enough — no commit required.

## Verify without sudo, then hand the rebuild over

Evaluating and building the whole system needs no privileges, so check work
this way first:

```sh
nix build --no-link .#nixosConfigurations.valerios-nix.config.system.build.toplevel
```

Only activating it needs root, and that command is the user's to run:

```sh
sudo nixos-rebuild switch --flake ~/PWUE/dotfiles-nixos#valerios-nix
```

Batch changes and ask for **one** rebuild at the end rather than one per edit.

## Pulling in a package that isn't in nixpkgs

When the upstream ships a **flake**, two patterns are in use and the choice is
forced, not stylistic:

- **`builtins.getFlake` inside the app's own module** (see `modules/apps/zen.nix`)
  — preferred. The fetch only happens on hosts that import that module.
- **A real flake input in `flake.nix` + `specialArgs`** (see
  `modules/apps/claude-desktop.nix`) — required when the upstream flake ships an
  **incomplete `flake.lock`**. `getFlake` then dies with *"cannot update unlocked
  flake input ... in pure mode"*, because it would have to resolve the missing
  transitive inputs at evaluation time. Declaring it as an input makes this
  repo's `flake.lock` pin them.

When the upstream is **just a source tree** (no flake, no release), write a
plain derivation and `pkgs.callPackage` it from the module that needs it — see
`modules/desktop/bibata-catppuccin-cursor.nix` (the Catppuccin-recolored cursor,
built with `resvg` + `clickgen`), wired into `modules/desktop/theming.nix`.

Pin a rev in every case.

## Config files an app writes back to

Anything symlinked by `home/dotfiles.nix` is read-only at runtime, so an app's
own settings UI cannot persist into it. Where that matters the file says so —
see `config/fcitx5/profile` and `config/Claude/claude-desktop-extra.jsonc`.
Prefer editing the repo copy; don't "fix" it by unmanaging the file without
asking.
