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
  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";

    # The GTK theme via gsettings/dconf, mirroring gtk-theme-name in
    # config/gtk-3.0/settings.ini. Ordinary GTK apps under niri read settings.ini,
    # but apps that consult dconf instead — notably LibreOffice's gtk3 VCL plugin,
    # which the nixpkgs wrapper wires to dconf through GIO_EXTRA_MODULES — read
    # THIS key, whose schema default is "Adwaita", and so render un-themed. Set it
    # here so both theming paths agree. (On valerios-nix this key had been set
    # imperatively via `gsettings`, so LibreOffice happened to be themed there but
    # not on a clean apply of the same config — this makes it uniform.)
    gtk-theme = "catppuccin-mocha-mauve-standard+normal";
  };

  # Show dotfiles in Nautilus by default (equivalent to toggling Ctrl+H on every
  # launch). Nautilus 50 DEPRECATED its own `org.gnome.nautilus.preferences
  # show-hidden-files` — its schema marks that key "ignored" and now reads the GTK
  # file-chooser `show-hidden` key instead (which the file-picker dialogs share).
  # So the setting genuinely IS a GTK one now, which is why it lives here.
  dconf.settings."org/gtk/Settings/FileChooser".show-hidden = true;

  # Select the Catppuccin Mocha GtkSourceView scheme (id "catppuccin-mocha")
  # delivered by ./dotfiles.nix. GtkSourceView has NO global "default scheme"
  # setting — each app chooses its own — so it is set here on GNOME Text Editor,
  # the only GtkSourceView-5 consumer on these hosts. style-variant is pinned to
  # dark so the editor uses this (dark) scheme outright instead of trying to
  # resolve a light counterpart, consistent with the prefer-dark desktop above.
  dconf.settings."org/gnome/TextEditor" = {
    style-scheme = "catppuccin-mocha";
    style-variant = "dark";
  };
}
