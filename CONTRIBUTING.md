# Editing this config

NixOS **flake** + **Home Manager**. One command rebuilds the OS *and* lays down
every dotfile:

```sh
sudo nixos-rebuild switch --flake ~/PWUE/dotfiles-nixos#<host>
```

`<host>` is `valerios-nix` (desktop) or `valerios-laptop` (HP 14s). On either
machine the bare `--flake ~/PWUE/dotfiles-nixos` also works, since the output
names match the hostnames.

Always edit files **in this repo**, then rebuild. Never edit the live
`~/.config/*` copies (they're read-only symlinks into the Nix store) or
`/etc/nixos`.

Both hosts share every module; a change to `modules/*` or `home/*` lands on both
the next time each one rebuilds. Check the other host still evaluates before
assuming a change is host-local — it costs nothing and needs no privileges:

```sh
nix eval --raw .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath
```

## Layout

```
flake.nix                                  entry point; `mkHost` + one line per host
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

## Add a new host

`hosts/valerios-laptop/` is the worked example — copy its shape.

1. On the new machine run `nixos-generate-config`, copy the generated
   `hardware-configuration.nix` into `hosts/<name>/`, and **`git add` it**.
   Flakes only see git-tracked files, so until it is staged evaluation dies with
   *"Path ... is not tracked by Git"* — and the file is per-machine, so it is
   never copied from another host.
2. Add `hosts/<name>/configuration.nix` importing the subset of `modules/*` that
   host wants: drop apps you don't need, and take only the `modules/hardware/*`
   files that match the metal (`nvidia.nix` for the GTX 1650, `intel-graphics.nix`
   for an Intel iGPU, `laptop.nix` for anything with a battery, `fingerprint.nix`
   only for the Elan `04f3:0c00` reader). Anything genuinely unique to that one
   machine — the hostname, a modprobe quirk — stays inline in this file rather
   than becoming a module.
3. Register it in `flake.nix`. `mkHost` does all the assembly (nixpkgs, Home
   Manager, `specialArgs`), so this is one line:

   ```nix
   nixosConfigurations = {
     <name> = mkHost ./hosts/<name>/configuration.nix;
   };
   ```

   Nothing else in `flake.nix` should need touching — if you find yourself
   editing `mkHost` for one host, that setting probably belongs in that host's
   `configuration.nix` instead.
4. Set `system.stateVersion` in the new host file to the release it is
   *installed* from, and leave it there. It is not a "current version" field.

## THE RULE: one line stays in `misc`, more than one line gets its own module

- If adding an app is **a single line** — one package in a list, or one
  `programs.<x>.enable = true;` — put it in **`modules/apps/misc.nix`**.
- The moment it needs **more than one line** of configuration (options, a service
  block, an overlay, a `let` binding, packages *and* settings) — pull it out into
  its **own ad-hoc module** `modules/apps/<name>.nix`, and import that file from
  the host's `configuration.nix`. Keep the app's package *and* all of its config
  together in that one file.

Already following the rule: `modules/apps/zen.nix` (flake + wrapper),
`modules/apps/syncthing.nix` (service block), `home/vesktop.nix` (package +
its Catppuccin theme). Staying in `misc.nix`: `firefox`/`kdeconnect`
(`.enable`), `obsidian`/`libreoffice` (a package).

The same rule applies to `modules/{core,desktop,hardware}/` and to `home/`: a
one-liner joins an existing grouped file; anything with real configuration earns
its own file (see `home/gtk.nix` vs `home/dotfiles.nix` on the Home-Manager side).

On the hardware side it has a second job: it is also how a host opts *out*.
`laptop.nix` and `fingerprint.nix` are separate files rather than one
`hp-14s.nix` because the split is what makes them reusable — a second laptop
with a different reader takes `laptop.nix` and leaves `fingerprint.nix`.

### Why "one line = shared file", not "one file per app"?

A module that is *imported* but disabled still runs its top-level `let` bindings
at evaluation time. `modules/apps/zen.nix` does `builtins.getFlake` in a `let`,
so keeping it in its own file means that fetch happens **only** on hosts that
import it — drop the import and there's zero Zen-related work. Trivial packages
have no such cost, so bundling them in `misc.nix` keeps the tree small without
paying anything.

`modules/hardware/fingerprint.nix` is the same trick for a much bigger bill: its
`let` does a `builtins.fetchGit` of a libfprint fork *and* the host that imports
it compiles libfprint and fprintd from source. The desktop, which has no
fingerprint reader, pays none of that purely by not having the import line.
