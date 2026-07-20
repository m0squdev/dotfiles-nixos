# Catppuccin Mocha (mauve accent) theming, system side. The matching user-level
# bits (GTK CSS, Kvantum/qt6ct config, kgx livery toolkit) are placed by Home
# Manager — see ../../home/gtk.nix and ../../home/dotfiles.nix.
{ pkgs, ... }:
{
  # Theme Qt/KDE apps (kdeconnect-app, etc.) with Catppuccin Mocha via Kvantum.
  # This installs qt5ct + qt6ct AND the Kvantum style engine for BOTH Qt5 & Qt6,
  # and — crucially on NixOS — wires QT_PLUGIN_PATH so those plugins are actually
  # found (a bare environment.systemPackages install does not). It also sets
  # QT_STYLE_OVERRIDE=kvantum. The Kvantum *theme* itself (catppuccin-kvantum) is
  # in the package list below and selected in ~/.config/Kvantum/kvantum.kvconfig;
  # ~/.config/niri/config.kdl overrides QT_QPA_PLATFORMTHEME to qt6ct so Qt6 apps
  # use qt6ct for icons/fonts.
  qt = {
    enable = true;
    platformTheme = "qt5ct";   # installs qt5ct + qt6ct, wires QT_PLUGIN_PATH
    style = "kvantum";         # installs Kvantum (Qt5 + Qt6) + sets QT_STYLE_OVERRIDE
  };

  # --- GNOME Console (kgx): Catppuccin Mocha terminal palette ---
  # kgx 50 has no UI or config key for the terminal colour palette; the palette is
  # hardcoded in its C source as "liveries". Its custom-livery loader is also broken
  # on this system's GLib 2.88: it iterates the a{sv} custom-liveries dict with the
  # tuple format string "(&sv)" instead of the dict-entry "{&sv}", which modern GLib
  # rejects — so user liveries set via GSettings/dconf never load and kgx always falls
  # back to its built-in palette. We therefore patch the built-in fallback livery to
  # Catppuccin Mocha (and fix the loader bug) so kgx renders Mocha out of the box.
  # Patch file lives next to this module (./kgx-catppuccin-mocha.patch).
  nixpkgs.overlays = [
    (final: prev: {
      gnome-console = prev.gnome-console.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ./kgx-catppuccin-mocha.patch ];
      });
    })
  ];

  environment.systemPackages = with pkgs; [
    (catppuccin-gtk.override {
      accents = [ "mauve" ];   # accent used across the whole setup
      variant = "mocha";
      size = "standard";
      tweaks = [ "normal" ];
    })
    adw-gtk3                    # lets GTK3 apps follow the theme cleanly
    papirus-icon-theme          # Papirus-Dark icons (pairs well with Catppuccin)
    catppuccin-cursors.mochaDark
    # Kvantum theme for Qt/KDE apps (matches the mauve accent). The Kvantum ENGINE
    # + qt5ct/qt6ct come from the `qt = { … }` block above; this is just the theme
    # it renders. Provides "catppuccin-mocha-mauve", selected in ~/.config/Kvantum/.
    (catppuccin-kvantum.override { accent = "mauve"; variant = "mocha"; })
  ];
}
