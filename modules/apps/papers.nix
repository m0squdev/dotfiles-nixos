# Papers (GNOME's "Document Viewer", the Evince successor) — the package plus
# the PDF association, which is the only reason this module exists.
#
# Without it `application/pdf` resolved to draw.desktop, i.e. LibreOffice Draw:
# nothing *claimed* PDFs, so the association fell back to whatever the desktop
# database sorted first among the apps that merely support the type, and
# LibreOffice registers Draw as a PDF *editor*. Naming a default here settles it.
#
# Papers already arrives with the GNOME suite, so the package line is not what
# installs it in practice. It is here because ../../home/xdg-mime.nix requires an
# association to live in the module that installs its handler — that invariant is
# what stops a host importing this file from pointing PDFs at a missing app.
{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.papers ]; # PDF/DjVu/comic-book viewer

  # Only application/pdf: Papers' desktop entry also claims djvu, tiff and the
  # comic-book types, but those are left alone — komikku (../apps/misc.nix) is
  # the better handler for cbz/cbr, and nothing here should silently take them.
  home-manager.users.valer.xdg.mimeApps.defaultApplications."application/pdf" =
    [ "org.gnome.Papers.desktop" ];
}
