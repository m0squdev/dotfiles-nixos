# LibreOffice — the package plus the one env var that makes it follow the
# Catppuccin GTK theme.
#
# Why the env var: LibreOffice picks its VCL plugin (the toolkit it draws with)
# from the running desktop. Under niri, XDG_CURRENT_DESKTOP=niri is unknown to
# it, so it falls back to the generic `gen` plugin — which ignores GTK theming
# entirely and renders the bare, un-themed Motif-ish look. Forcing the gtk3
# plugin makes it draw with GTK and pick up adw-gtk3 (catppuccin-mocha-mauve),
# exactly like the other GTK apps. (This build ships only the `gen` and `gtk3`
# plugins — no Qt/KDE one — so gtk3 is the themed choice here.)
{ pkgs, ... }:
{
  environment.sessionVariables.SAL_USE_VCLPLUGIN = "gtk3";

  environment.systemPackages = [ pkgs.libreoffice ]; # office suite (GTK build)
}
