# GTK 4 / libadwaita theming (Home Manager side). This is the one dotfile entry
# that's more than a symlink, so it gets its own module: a hand-written named-
# color recolor (fixes half-themed Nautilus), plus the icon `assets` pointed live
# at the catppuccin-gtk *system* theme (../modules/desktop/theming.nix) via an
# out-of-store symlink so they never go stale. GTK 3 is a one-liner in
# ./dotfiles.nix.
{ config, ... }:
{
  xdg.configFile = {
    "gtk-4.0/settings.ini".source = ../config/gtk-4.0/settings.ini;
    "gtk-4.0/gtk.css".source = ../config/gtk-4.0/gtk.css;
    "gtk-4.0/gtk-dark.css".source = ../config/gtk-4.0/gtk-dark.css;
    "gtk-4.0/assets".source = config.lib.file.mkOutOfStoreSymlink
      "/run/current-system/sw/share/themes/catppuccin-mocha-mauve-standard+normal/gtk-4.0/assets";
  };

  # The desktop-wide "prefer dark" signal. The `gtk-application-prefer-dark-theme`
  # flag in the settings.ini files (GTK 3 and 4) is the LEGACY GTK mechanism and
  # never reaches the freedesktop portal — so xdg-desktop-portal reports "no
  # colour preference" and portal-aware apps that follow the system (Zen/Firefox
  # in auto mode, libadwaita apps, …) fall back to LIGHT. This gsettings key is
  # the modern signal the portal actually exposes; prefer-dark is what makes
  # those apps resolve to dark and pick up the Catppuccin theming.
  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";

  # Show dotfiles in Nautilus by default (equivalent to toggling Ctrl+H on every
  # launch). Nautilus 50 DEPRECATED its own `org.gnome.nautilus.preferences
  # show-hidden-files` — its schema marks that key "ignored" and now reads the GTK
  # file-chooser `show-hidden` key instead (which the file-picker dialogs share).
  # So the setting genuinely IS a GTK one now, which is why it lives here.
  dconf.settings."org/gtk/Settings/FileChooser".show-hidden = true;
}
