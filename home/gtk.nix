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
}
