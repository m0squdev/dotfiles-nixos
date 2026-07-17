# GNOME Console (kgx) — Catppuccin Mocha terminal palette

## Why a source patch (and not dconf)
kgx 50 has **no UI or config key** for the terminal colour palette. Colours are
hardcoded in its C source as "liveries". It *does* have a GSettings
`custom-liveries` key, but the loader is **broken on GLib 2.88**: it iterates the
`a{sv}` dict with the tuple format `"(&sv)"` instead of the dict-entry `"{&sv}"`,
which modern GLib rejects (`GLib-CRITICAL … '(&sv)' has type '(sv)' but value has
type '{sv}'`). So any livery set via dconf silently fails to load and kgx falls
back to its built-in palette. Confirmed by pixel-sampling: dconf route → default
kgx colours (#1c1c1f bg, #c01c28 red, …).

**Fix:** patch kgx's built-in fallback livery to Catppuccin Mocha (and fix the
loader bug) via a NixOS overlay. Verified by pixel-sampling the patched build:
bg #1e1e2e, red #f38ba8, green #a6e3a1, blue #89b4fa, … — exact Mocha.

## Files here
- `kgx-catppuccin-mocha.patch` — the source patch (built-in `standard_livery`
  → Mocha night+day; `(&sv)`→`{&sv}` loader fix). Goes in /etc/nixos/.
- `configuration.nix.staged` — copy of the system config with the
  `nixpkgs.overlays` block added. Diff it against the live one before applying.
- `gen-livery.sh` — palette source of truth (Catppuccin Mocha ANSI hex → doubles).

## Apply
    sudo cp ~/.config/kgx-mocha/kgx-catppuccin-mocha.patch /etc/nixos/
    sudo cp /etc/nixos/configuration.nix /etc/nixos/configuration.nix.pre-kgx-mocha.bak
    sudo cp ~/.config/kgx-mocha/configuration.nix.staged /etc/nixos/configuration.nix
    sudo nixos-rebuild switch
    # then close ALL Console windows (or re-login) so kgx restarts on the new binary

dconf keys were reset to defaults on purpose — theming comes purely from the patch.
