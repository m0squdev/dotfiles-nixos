# Central switch for XDG default-application handling. Turning `xdg.mimeApps`
# on is what makes Home Manager own ~/.config/mimeapps.list; it is cross-cutting
# infrastructure, so it lives here rather than in whichever app happens to set a
# default first.
#
# The associations themselves stay with the app that owns them and merge in via
# the module system — e.g. Zen registers itself as the http/https/html handler in
# ../modules/apps/zen.nix. Add a new default the same way (in that app's module,
# or here if it belongs to no single module):
#
#     xdg.mimeApps.defaultApplications."application/pdf" = [ "org.gnome.Papers.desktop" ];
{ ... }:
{
  xdg.mimeApps.enable = true;
}
