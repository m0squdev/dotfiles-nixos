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

    # Claude Desktop (claude-desktop-extra) — Catppuccin Mocha theme selection.
    # NOTE: like fcitx5's profile above, this becomes a read-only store symlink,
    # so the app's own Ctrl+Shift+T theme picker can't persist a change — edit
    # ../config/Claude/claude-desktop-extra.jsonc instead.
    "Claude/claude-desktop-extra.jsonc".source = ../config/Claude/claude-desktop-extra.jsonc;

    # GTK 3 (adw-gtk3 follows the Catppuccin theme). GTK 4 lives in ./gtk.nix.
    "gtk-3.0/settings.ini".source = ../config/gtk-3.0/settings.ini;

    # KDE global palette (single file directly under ~/.config)
    "kdeglobals".source = ../config/kdeglobals;
  };

  # GNOME Text Editor / GtkSourceView 5 Catppuccin Mocha style scheme.
  home.file.".local/share/gtksourceview-5/styles/catppuccin-mocha.xml".source =
    ../local/share/gtksourceview-5/styles/catppuccin-mocha.xml;

  # Nautilus' "New Document" submenu is literally a listing of ~/Templates —
  # empty directory, no submenu — so one empty file there is the whole feature.
  # (XDG_TEMPLATES_DIR in ~/.config/user-dirs.dirs is the default $HOME/Templates;
  # this hardcodes that path, so move it there and here together.)
  #
  # Deliberately no extension, so the menu entry and the file it makes are both
  # plain "Empty Text File". The cost is that a zero-byte file with no extension
  # has nothing for shared-mime-info to go on and types as application/x-zerosize
  # rather than text/plain — nothing is registered to open that, so a fresh one
  # may not launch an editor until it has content. Giving this file a single
  # newline is the fix if that bites; it stays visually empty and sniffs as text.
  #
  # Nautilus copies templates with G_FILE_COPY_TARGET_DEFAULT_PERMS, so the new
  # file gets normal permissions rather than inheriting 0444 from the store.
  home.file."Templates/Empty Text File".text = "";

  # Wallpaper — referenced by niri (swaybg) and hyprlock.
  home.file.".local/share/backgrounds/wall.jpg".source =
    ../assets/wallpapers/wall.jpg;
}
