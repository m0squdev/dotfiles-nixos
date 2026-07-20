{
  description = "valer's NixOS + niri desktop — Catppuccin Mocha (system + dotfiles via Home Manager)";

  inputs = {
    # Pinned to the EXACT nixpkgs revision this machine was built from, so the
    # first `nixos-rebuild switch --flake` is a near-noop (everything is already
    # in your store / the binary cache) instead of a big download.
    #
    # To update later: change this to `github:nixos/nixpkgs/nixos-26.05` (latest
    # on the release branch) or a newer pinned rev, then `nix flake update`.
    nixpkgs.url = "github:nixos/nixpkgs/8f0500b9660505dc3cb647775fe9a978a74b5283";

    # Home Manager, kept in lockstep with nixpkgs via `follows`.
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
    in
    {
      # Build with:  sudo nixos-rebuild switch --flake ~/PWUE/dotfiles-nixos#valerios-nix
      # (the bare `--flake ~/PWUE/dotfiles-nixos` also works, since the output
      #  name matches this machine's hostname.)
      nixosConfigurations.valerios-nix = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          # This host's composition root: imports the feature modules under
          # ./modules and declares what's unique to this machine.
          ./hosts/valerios-nix/configuration.nix

          # Home Manager as a NixOS module, so ONE `nixos-rebuild switch`
          # rebuilds the system AND lays down every dotfile.
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;    # use the system's pkgs (overlays + allowUnfree)
            home-manager.useUserPackages = true;  # install user pkgs into /etc/profiles
            # On the FIRST switch, any pre-existing real dotfile that HM wants to
            # manage is renamed to <name>.hm-bak instead of aborting the build.
            home-manager.backupFileExtension = "hm-bak";
            home-manager.users.valer = import ./home/home.nix;
          }
        ];
      };
    };
}
