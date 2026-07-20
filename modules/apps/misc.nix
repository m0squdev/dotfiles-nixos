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
  programs.firefox.enable = true;
  programs.kdeconnect.enable = true;
  services.printing.enable = true;   # CUPS

  # Plain packages.
  environment.systemPackages = with pkgs; [
    vesktop
    stremio-linux-shell   # Stremio media center (native GTK/webkit shell; old qt5 `stremio` was removed from nixpkgs 2026-02)
    geary                 # email client
    obsidian              # Markdown knowledge base / notes
    libreoffice           # office suite (GTK build, follows the Catppuccin GTK theme)
    alacritty             # terminal (Mod+T); Catppuccin Mocha config via Home Manager
    claude-code
    git
    vim                   # editor for configuration.nix (nano is installed by default too)
  ];
}
