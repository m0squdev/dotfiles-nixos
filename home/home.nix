{ config, pkgs, ... }:

# Home Manager: places every user-level dotfile for the niri / Catppuccin Mocha
# desktop. Files live in ../config and ../local; HM symlinks them into place on
# each rebuild. Edit the files IN THIS REPO, then re-run `nixos-rebuild switch`
# (the live copies under ~/.config are read-only symlinks into the Nix store).

{
  home.username = "valer";
  home.homeDirectory = "/home/valer";

  # Matches the system's release; do not bump casually (see the note in
  # nixos/configuration.nix about stateVersion).
  home.stateVersion = "26.05";

  # ---------------------------------------------------------------------------
  # ~/.config/*  (XDG config dir)
  # `recursive = true` symlinks each file individually, leaving the directory
  # itself writable so apps can still drop runtime files (caches, sockets, …)
  # alongside the managed ones.
  # ---------------------------------------------------------------------------
  xdg.configFile = {
    # Window manager + its helper scripts (cycle-input, volume, lock, idle, …)
    "niri" = { source = ../config/niri; recursive = true; };

    # Status bar + all its custom module scripts
    "waybar" = { source = ../config/waybar; recursive = true; };

    # Notification center, on-screen-display, and lockers
    "swaync" = { source = ../config/swaync; recursive = true; };
    "swayosd" = { source = ../config/swayosd; recursive = true; };
    "swaylock" = { source = ../config/swaylock; recursive = true; };
    "hypr" = { source = ../config/hypr; recursive = true; }; # hyprlock + now-playing

    # Application launcher
    "fuzzel" = { source = ../config/fuzzel; recursive = true; };

    # GNOME Console (kgx) Catppuccin-Mocha livery toolkit (patch + generator)
    "kgx-mocha" = { source = ../config/kgx-mocha; recursive = true; };

    # Qt / KDE theming (Kvantum engine theme + qt6ct)
    "Kvantum" = { source = ../config/Kvantum; recursive = true; };
    "qt6ct" = { source = ../config/qt6ct; recursive = true; };

    # Input method (fcitx5): active profile + notification settings.
    # NOTE: `profile` becomes a read-only store symlink, so changes made via
    # fcitx5-configtool won't persist — edit ../config/fcitx5/profile instead.
    "fcitx5" = { source = ../config/fcitx5; recursive = true; };

    # XDG autostart entries
    "autostart" = { source = ../config/autostart; recursive = true; };

    # GTK 3 (adw-gtk3 follows the Catppuccin theme)
    "gtk-3.0/settings.ini".source = ../config/gtk-3.0/settings.ini;

    # GTK 4 / libadwaita: hand-written named-color recolor (fixes half-themed
    # Nautilus). The image `assets` are shipped by the catppuccin-gtk *system*
    # theme, so point at them live rather than copying a soon-to-be-stale link.
    "gtk-4.0/settings.ini".source = ../config/gtk-4.0/settings.ini;
    "gtk-4.0/gtk.css".source = ../config/gtk-4.0/gtk.css;
    "gtk-4.0/gtk-dark.css".source = ../config/gtk-4.0/gtk-dark.css;
    "gtk-4.0/assets".source = config.lib.file.mkOutOfStoreSymlink
      "/run/current-system/sw/share/themes/catppuccin-mocha-mauve-standard+normal/gtk-4.0/assets";

    # KDE global palette (single file directly under ~/.config)
    "kdeglobals".source = ../config/kdeglobals;
  };

  # ---------------------------------------------------------------------------
  # ~/.local/share/*
  # ---------------------------------------------------------------------------
  # GNOME Text Editor / GtkSourceView 5 Catppuccin Mocha style scheme
  home.file.".local/share/gtksourceview-5/styles/catppuccin-mocha.xml".source =
    ../local/share/gtksourceview-5/styles/catppuccin-mocha.xml;

  # ---------------------------------------------------------------------------
  # Wallpaper — referenced by niri (swaybg) and hyprlock at ~/Pictures/Wallpapers/wall.jpg
  # ---------------------------------------------------------------------------
  home.file."Pictures/Wallpapers/wall.jpg".source = ../assets/wallpapers/wall.jpg;
}
