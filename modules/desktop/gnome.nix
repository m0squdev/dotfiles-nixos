# GNOME session, kept for its apps (Nautilus, Console, Text Editor, Settings,
# Calendar, …) and as a pickable fallback session.
#
# The login manager is NOT here: it is SDDM, in ./sddm.nix, which replaced GDM
# because GDM's look cannot be themed Catppuccin without repacking gnome-shell's
# gresource (the reasoning is written up in that file). Nothing in the GNOME
# desktop module depends on GDM specifically, so the two are independent — the
# niri session is still the default, via ./niri.nix.
{ ... }:
{
  services.xserver.enable = true;              # X server (still lives under xserver)
  services.desktopManager.gnome.enable = true; # renamed out of services.xserver.* in 25.05+
}
