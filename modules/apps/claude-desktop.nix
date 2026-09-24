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
# It tracks the same upstream version as the plain repackage (2.7032.0).
#
# The rev is pinned in ../../flake.nix — bump it there to update Claude Desktop.
# NOTE: the app self-updates its web content at runtime; the rev only pins the
# Electron shell + the theme patches. When Claude Desktop shows an "update
# required" notice (as it did once Opus 4.8 shipped), it's the shell that's too
# old — bump the flake rev.
#
# Unlike ./zen.nix this does NOT use `builtins.getFlake`: upstream's flake.lock
# omits its own flake-utils/nixpkgs entries, so a getFlake would fail pure
# evaluation. It is declared as a flake input instead — see the comment on
# `claude-desktop-extra` in ../../flake.nix. The cost is that the input is
# fetched even on a host that doesn't import this module.
#
# The theme itself is selected in ../../config/Claude/claude-desktop-extra.jsonc
# (wired up by ../../home/dotfiles.nix).
#
# No overrideAttrs here anymore. Earlier revs needed two: a corrected src hash
# (upstream's v1.24012.9 release asset was re-published with different bytes) and
# an RPATH on the vendored node-pty prebuild (so Claude Code inside the app could
# open a shell). As of this rev both are handled upstream — release assets are
# immutable with a matching baked-in hash, and packaging/nix/package.nix now
# patches libstdc++ into pty.node itself, with a tripwire that fails the build if
# the .deb layout ever moves the binding. So we consume the flake package as-is.
{ pkgs, inputs, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
  claude-desktop-extra = inputs.claude-desktop-extra.packages.${system}.claude-desktop-extra;
in
{
  environment.systemPackages = [ claude-desktop-extra ];

  # Claude Desktop spawns a self-downloaded `claude` CLI binary (at
  # ~/.config/Claude/claude-code/<ver>/claude) that is a dynamically linked
  # generic-Linux ELF. NixOS has no dynamic linker at the standard FHS path, so
  # the binary dies with "Could not start dynamically linked executable".
  #
  # nix-ld installs a stub ld at /lib64/ld-linux-x86-64.so.2 that resolves
  # libraries from nix-ld.libraries. patchelf is not viable here because Claude
  # Desktop auto-updates the binary and any patch would be overwritten.
  #
  # (This is the app's OWN in-bundle Claude Code, separate from the terminal
  # `claude` in ./claude-code.nix — upstream leaves the flake's claude-code at
  # null, so the app keeps self-downloading its copy and this stays needed.)
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc.lib  # libstdc++.so.6, needed by the Claude Code Node binary
  ];

  # Draw the window frame with the SYSTEM decorations (so niri's own border /
  # focus ring frames it, matching every other window) instead of the app's
  # integrated titlebar. `claude-desktop --diagnose` reports the current state as
  # "Titlebar = integrated (default)" without this. Equivalent to passing
  # `--native-titlebar`, but set here so it applies however the app is launched
  # — .desktop entry, fuzzel, or the Ctrl+Alt+Space Quick Entry bind. Still read
  # by fix_native_frame's CLAUDE_NATIVE_TITLEBAR check as of 2.7032.0.
  #
  # Set as a session variable rather than by wrapping the package: the launcher
  # derives its Wayland app_id and portal identity from /proc/self/exe, and an
  # extra wrapper layer is exactly what upsets that. Takes effect at next login.
  environment.sessionVariables.CLAUDE_NATIVE_TITLEBAR = "1";

  # Point Chromium's sandbox at the bundled helper, or the app SIGILLs on launch
  # before any window appears (`app-com.anthropic.Claude-<pid>.scope` dumps core,
  # signal 4). This is the one thing that breaks on the 2.7032.0 bump:
  #
  # The old package ran the app through nixpkgs' `electron` WRAPPER, which exports
  # CHROME_DEVEL_SANDBOX pointing at electron's chrome-sandbox. 2.7032.0 instead
  # copies electron's *unwrapped* dist and runs it directly, so that variable is
  # never set. With it unset Chromium auto-discovers the `chrome-sandbox` sitting
  # next to its binary (the copied dist ships one), finds it lacks the SUID bit —
  # the Nix store CANNOT carry one, unlike the .deb/.rpm/pacman builds that
  # chmod it 4755 root — and treats a misconfigured *auto-discovered* helper as
  # fatal: "found, but is not configured correctly", which aborts via `ud2` →
  # SIGILL. Upstream's launcher only adds --no-sandbox for AppImages, and its
  # comment wrongly assumes the Nix path keeps electron's wrapper, so nothing
  # rescues us here.
  #
  # Setting CHROME_DEVEL_SANDBOX to ANY explicit path dodges that fatal
  # auto-discovery: an explicitly-named helper that turns out unusable makes
  # Chromium fall back to the unprivileged-user-namespace sandbox instead of
  # aborting (userns is enabled here — /proc/sys/user/max_user_namespaces is
  # nonzero — and is the NixOS default sandbox for Electron/Chromium anyway). So
  # the sandbox stays ON for the remote claude.ai content; we just steer past the
  # crash. Verified: unset → core dumps; set → window opens, theme applies.
  #
  # We point it at the app's OWN bundled helper so it tracks the package on every
  # rev bump. A session variable (not a package wrapper) for the same app_id /
  # /proc/self/exe reason as the titlebar var above — takes effect at next login,
  # so log out and back in (or reboot) after the rebuild.
  environment.sessionVariables.CHROME_DEVEL_SANDBOX =
    "${claude-desktop-extra}/lib/claude-desktop/chrome-sandbox";

  # NOTE: the app's "Quick Entry" popup is deliberately NOT bound to a key. Its
  # own global-hotkey routes cannot work here anyway (the xdg-desktop-portal
  # GlobalShortcuts backend doesn't bind on niri, and the GNOME fallback
  # `--install-gnome-hotkey` needs gsettings schemas this host doesn't have), and
  # the feature isn't wanted. If that ever changes, `claude-desktop --toggle` is
  # the documented escape hatch to bind from niri's base.kdl.
}
