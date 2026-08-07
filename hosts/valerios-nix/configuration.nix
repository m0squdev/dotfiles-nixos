# Host: valerios-nix (desktop) — composition root.
#
# This file only COMPOSES modules and declares what is unique to THIS machine.
# To drop a feature or app from this host, delete its import line below (or, for
# the one-line apps, edit ../../modules/apps/misc.nix). Another host — e.g. a
# laptop — gets its own hosts/<name>/configuration.nix importing the subset it
# wants, plus its own generated hardware-configuration.nix.
#
# Build:  sudo nixos-rebuild switch --flake ~/PWUE/dotfiles-nixos#valerios-nix
{ ... }:
{
  imports = [
    # This machine's auto-generated hardware scan (never shared between hosts).
    ./hardware-configuration.nix

    # --- Core system (always on) ---
    ../../modules/core/boot.nix
    ../../modules/core/nix.nix
    ../../modules/core/locale.nix
    ../../modules/core/networking.nix
    ../../modules/core/users.nix
    ../../modules/core/audio.nix
    ../../modules/core/bluetooth.nix
    ../../modules/core/graphics.nix
    ../../modules/core/swap.nix

    # --- Desktop (niri + GNOME session, theming, fonts, input method) ---
    ../../modules/desktop/gnome.nix
    ../../modules/desktop/niri.nix
    ../../modules/desktop/fonts.nix
    ../../modules/desktop/input-method.nix
    ../../modules/desktop/theming.nix

    # --- Hardware quirks (desktop-only: a laptop omits this line) ---
    ../../modules/hardware/nvidia.nix

    # --- Apps with real configuration (each its own ad-hoc module) ---
    ../../modules/apps/zen.nix
    ../../modules/apps/syncthing.nix
    ../../modules/apps/claude-desktop.nix
    ../../modules/apps/libreoffice.nix

    # --- One-line apps / simple toggles (edit the list inside) ---
    ../../modules/apps/misc.nix
  ];

  networking.hostName = "valerios-nix";

  # --- niri display layout (this host only) ---------------------------------
  # niri's entry point is ~/.config/niri/config.kdl. The cross-host config lives
  # in ../../config/niri/base.kdl (symlinked in by ../../home/dotfiles.nix). This
  # host needs no monitor-specific tweaks, so its config.kdl is just the include —
  # add `output "…"` blocks after it if this machine ever needs a fixed layout
  # (see hosts/valerios-laptop/configuration.nix for the pattern).
  home-manager.users.valer.xdg.configFile."niri/config.kdl".text = ''
    include "base.kdl"
  '';

  # NixOS release whose stateful defaults (file locations, DB versions, …) this
  # machine was first installed with. Do NOT bump casually — read `man
  # configuration.nix` / the manual first. Home Manager's home.stateVersion in
  # ../../home/home.nix tracks this.
  system.stateVersion = "26.05";
}
