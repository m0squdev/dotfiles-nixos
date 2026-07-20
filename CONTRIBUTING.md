# Editing this config

NixOS **flake** + **Home Manager**. One command rebuilds the OS *and* lays down
every dotfile:

```sh
sudo nixos-rebuild switch --flake ~/PWUE/dotfiles-nixos#valerios-nix
```

Always edit files **in this repo**, then rebuild. Never edit the live
`~/.config/*` copies (they're read-only symlinks into the Nix store) or
`/etc/nixos`.

## Layout

```
flake.nix                                  entry point; defines each host
hosts/<host>/configuration.nix             composition root — imports modules + host-only settings
hosts/<host>/hardware-configuration.nix    auto-generated, per-machine (never shared)
modules/core/*.nix                         always-on system essentials (boot, nix, locale, audio, …)
modules/desktop/*.nix                      niri + GNOME session, theming, fonts, input method
modules/hardware/*.nix                     GPU / machine quirks (imported only where relevant)
modules/apps/*.nix                         applications
home/*.nix                                 Home Manager (user dotfiles)
config/  local/  assets/                   the actual dotfiles / scripts / wallpapers HM symlinks
```

## Turn something on or off for a host

Everything a host runs is **one line** in `hosts/<host>/configuration.nix`:

- **A feature/app module** → an `imports` line. Delete the line to drop it.
  (e.g. remove `../../modules/hardware/nvidia.nix` on a machine with no NVIDIA GPU.)
- **A one-line app** → it lives in `modules/apps/misc.nix`. Remove its package
  from the list, or its `programs.<x>.enable` / `services.<x>.enable` line.

## Add a new host (e.g. a laptop)

1. On the new machine run `nixos-generate-config` and copy its generated
   `hardware-configuration.nix` into `hosts/<name>/`.
2. Add `hosts/<name>/configuration.nix` that imports the subset of `modules/*`
   that host wants (skip `modules/hardware/nvidia.nix`, drop apps you don't
   need, add a host-specific hardware module if needed).
3. Register it in `flake.nix` under `nixosConfigurations.<name>`.

## THE RULE: one line stays in `misc`, more than one line gets its own module

- If adding an app is **a single line** — one package in a list, or one
  `programs.<x>.enable = true;` — put it in **`modules/apps/misc.nix`**.
- The moment it needs **more than one line** of configuration (options, a service
  block, an overlay, a `let` binding, packages *and* settings) — pull it out into
  its **own ad-hoc module** `modules/apps/<name>.nix`, and import that file from
  the host's `configuration.nix`. Keep the app's package *and* all of its config
  together in that one file.

Already following the rule: `modules/apps/zen.nix` (flake + wrapper),
`modules/apps/syncthing.nix` (service block). Staying in `misc.nix`:
`firefox`/`kdeconnect` (`.enable`), `obsidian`/`vesktop` (a package).

The same rule applies to `modules/{core,desktop,hardware}/` and to `home/`: a
one-liner joins an existing grouped file; anything with real configuration earns
its own file (see `home/gtk.nix` vs `home/dotfiles.nix` on the Home-Manager side).

### Why "one line = shared file", not "one file per app"?

A module that is *imported* but disabled still runs its top-level `let` bindings
at evaluation time. `modules/apps/zen.nix` does `builtins.getFlake` in a `let`,
so keeping it in its own file means that fetch happens **only** on hosts that
import it — drop the import and there's zero Zen-related work. Trivial packages
have no such cost, so bundling them in `misc.nix` keeps the tree small without
paying anything.
