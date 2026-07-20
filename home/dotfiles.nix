# The bulk of the user dotfiles: each entry symlinks a file/dir from this repo's
# config/ or local/ into ~/.config or ~/.local. `recursive = true` symlinks each
# file individually, leaving the directory itself writable so apps can still drop
# runtime files (caches, sockets, …) alongside the managed ones.
#
# One-liners only — anything needing real logic gets its own module (see
# ./gtk.nix and CONTRIBUTING.md).
{ ... }:
{
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

    # Terminal (Mod+T) — Catppuccin Mocha, JetBrainsMono Nerd Font
    "alacritty" = { source = ../config/alacritty; recursive = true; };

    # GNOME Console (kgx) Catppuccin-Mocha livery toolkit (patch + generator)
    "kgx-mocha" = { source = ../config/kgx-mocha; recursive = true; };

    # Qt / KDE theming (Kvantum engine theme + qt6ct)
    "Kvantum" = { source = ../config/Kvantum; recursive = true; };
    "qt6ct" = { source = ../config/qt6ct; recursive = true; };

    # Input method (fcitx5): active profile + notification settings.
    # NOTE: `profile` becomes a read-only store symlink, so changes made via
    # fcitx5-configtool won't persist — edit ../config/fcitx5/profile instead.
    "fcitx5" = { source = ../config/fcitx5; recursive = true; };

    # NOTE: vesktop autostart intentionally NOT managed here — niri already
    # launches it via spawn-at-startup (start-after-tray.sh, minimized). A
    # second XDG-autostart copy just raced and crash-looped, so it was dropped.

    # GTK 3 (adw-gtk3 follows the Catppuccin theme). GTK 4 lives in ./gtk.nix.
    "gtk-3.0/settings.ini".source = ../config/gtk-3.0/settings.ini;

    # KDE global palette (single file directly under ~/.config)
    "kdeglobals".source = ../config/kdeglobals;
  };

  # GNOME Text Editor / GtkSourceView 5 Catppuccin Mocha style scheme.
  home.file.".local/share/gtksourceview-5/styles/catppuccin-mocha.xml".source =
    ../local/share/gtksourceview-5/styles/catppuccin-mocha.xml;

  # Wallpaper — referenced by niri (swaybg) and hyprlock.
  home.file.".local/share/backgrounds/wall.jpg".source =
    ../assets/wallpapers/wall.jpg;
}
