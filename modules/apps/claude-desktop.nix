# Claude Desktop — not packaged in nixpkgs, so it is pulled from a community
# flake. We use claude-desktop-extra, which repackages Anthropic's OFFICIAL
# Linux .deb (Anthropic ships a Debian/Ubuntu beta only, and no Nix package)
# and patches a theme engine into the Electron bundle.
#
# WHY THE "extra" FORK AND NOT THE PLAIN REPACKAGE (aaddrick/claude-desktop-
# debian): stock Claude Desktop has NO theme setting beyond Light/Dark/Match
# System — no accent picker, no custom palettes, and no Nix option anywhere
# (checked nixpkgs, home-manager, catppuccin/nix and all four community
# claude-desktop flakes). The app's UI is claude.ai loaded in Chromium, so the
# only way to recolour it is to inject CSS variables. This fork does exactly
# that, and ships Catppuccin Mocha/Macchiato/Frappé/Latte as BUILT-IN themes —
# so we get the real Catppuccin palette rather than an approximation, and the
# maintenance burden of hand-patching app.asar stays upstream.
#
# It tracks the same upstream version as the plain repackage (1.24012.9).
#
# The rev is pinned in ../../flake.nix — bump it there to update Claude Desktop.
# NOTE: the app self-updates its web content at runtime; the rev only pins the
# Electron shell + the theme patches.
#
# Unlike ./zen.nix this does NOT use `builtins.getFlake`: upstream's flake.lock
# omits its own flake-utils/nixpkgs entries, so a getFlake would fail pure
# evaluation. It is declared as a flake input instead — see the comment on
# `claude-desktop-extra` in ../../flake.nix. The cost is that the input is
# fetched even on a host that doesn't import this module.
#
# The theme itself is selected in ../../config/Claude/claude-desktop-extra.jsonc
# (wired up by ../../home/dotfiles.nix).
{ pkgs, inputs, ... }:
{
  environment.systemPackages = [
    inputs.claude-desktop-extra.packages.${pkgs.stdenv.hostPlatform.system}.claude-desktop-extra
  ];

  # Draw the window frame with the SYSTEM decorations (so niri's own border /
  # focus ring frames it, matching every other window) instead of the app's
  # integrated titlebar. `claude-desktop --diagnose` reports the current state as
  # "Titlebar = integrated (default)" without this. Equivalent to passing
  # `--native-titlebar`, but set here so it applies however the app is launched
  # — .desktop entry, fuzzel, or the Ctrl+Alt+Space Quick Entry bind.
  #
  # Set as a session variable rather than by wrapping the package: the launcher
  # derives its Wayland app_id and portal identity from /proc/self/exe, and an
  # extra wrapper layer is exactly what upsets that. Takes effect at next login.
  environment.sessionVariables.CLAUDE_NATIVE_TITLEBAR = "1";

  # NOTE: the app's "Quick Entry" popup is deliberately NOT bound to a key. Its
  # own global-hotkey routes cannot work here anyway (the xdg-desktop-portal
  # GlobalShortcuts backend doesn't bind on niri, and the GNOME fallback
  # `--install-gnome-hotkey` needs gsettings schemas this host doesn't have), and
  # the feature isn't wanted. If that ever changes, `claude-desktop --toggle` is
  # the documented escape hatch to bind from niri's config.kdl.
}
