# Home Manager entry point for user `valer`. Composes the modules below; the
# actual dotfiles live in this repo's config/, local/ and assets/ and are
# symlinked into place on each rebuild. Edit the files IN THIS REPO, then re-run
# `nixos-rebuild switch` (the live copies under ~/.config are read-only symlinks
# into the Nix store).
{ ... }:
{
  imports = [
    ./dotfiles.nix   # the bulk of ~/.config/* symlinks (one-liners)
    ./gtk.nix        # GTK theming (the one entry that needs real logic)
  ];

  home.username = "valer";
  home.homeDirectory = "/home/valer";

  # Matches the system's release; do not bump casually (see the note on
  # system.stateVersion in ../hosts/valerios-nix/configuration.nix).
  home.stateVersion = "26.05";
}
