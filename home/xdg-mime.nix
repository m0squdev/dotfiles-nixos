# Central switch for XDG default-application handling. Turning `xdg.mimeApps` on
# is what makes Home Manager own ~/.config/mimeapps.list; it is cross-cutting
# infrastructure imported on every host, so ONLY that switch belongs here.
#
# Deliberately NO associations live in this file. Each association must sit in the
# app's OWN module — the same module that installs the app (e.g. Zen registers
# itself as the http/https/html handler in ../modules/apps/zen.nix). Then a host
# that doesn't import that module also never points a MIME type at a handler it
# didn't install. Two corollaries:
#   * It never goes in ../modules/apps/misc.nix: that file is one-liner apps only,
#     and adding an association makes the app more than a line, so by THE RULE
#     (see CONTRIBUTING.md) it graduates to its own module first — associations
#     and install then live together there.
#   * A default that seems to "belong to no module" just means the app has no
#     module yet: create one and declare the association there.
{ ... }:
{
  xdg.mimeApps.enable = true;
}
