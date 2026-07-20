# GNOME session + GDM. GDM is the login manager (it launches the niri session by
# default — see ./niri.nix); the GNOME desktop is kept for its apps (Nautilus,
# Console, Text Editor, Settings, Calendar, …).
{ ... }:
{
  services.xserver.enable = true;              # X server (still lives under xserver)
  services.displayManager.gdm.enable = true;   # renamed out of services.xserver.* in 25.05+
  services.desktopManager.gnome.enable = true; # renamed out of services.xserver.* in 25.05+
}
