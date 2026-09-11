# One-line apps and simple toggles.
#
# Everything here is a SINGLE line: one package in the list, or one `*.enable`.
# The moment an app needs more than a line of configuration, pull it out into its
# own module under modules/apps/ and import it from the host's configuration.nix
# (see CONTRIBUTING.md, and ./zen.nix / ./syncthing.nix as examples).
#
# To drop one of these from a host, delete its line.
{ pkgs, ... }:
{
  # Programs / services with a NixOS module (installs + wires them up).
  programs.kdeconnect.enable = true;
  # printing (CUPS) moved to ./printing.nix — it now carries the HP drivers and
  # an Avahi block for network-printer discovery, so per THE RULE it earned its
  # own module.

  # Plain packages.
  environment.systemPackages = with pkgs; [
    # vesktop moved to ../../home/vesktop.nix — it now carries config (the
    # Catppuccin online theme), so per THE RULE it earned its own module.
    stremio-linux-shell   # Stremio media center (native GTK/webkit shell; old qt5 `stremio` was removed from nixpkgs 2026-02)
    geary                 # email client
    fragments             # GNOME BitTorrent client (GTK/libadwaita, follows the Catppuccin GTK theme)
    komikku               # manga reader/downloader (GTK/libadwaita, follows the Catppuccin GTK theme)
    obsidian              # Markdown knowledge base / notes
    codex                 # OpenAI Codex CLI (declarative Nix package; replaces the temporary npm install)
    # libreoffice moved to ../../modules/apps/libreoffice.nix — it needs the
    # SAL_USE_VCLPLUGIN env var (else it's un-themed under niri), so per THE RULE
    # it earned its own module.
    alacritty             # terminal (Mod+T); Catppuccin Mocha config via Home Manager
    git
    vim                   # editor for configuration.nix (nano is installed by default too)
  ];
}
