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

    # Claude Desktop (see ./modules/apps/claude-desktop.nix).
    #
    # This one is a real flake INPUT rather than the module-local
    # `builtins.getFlake` that ./modules/apps/zen.nix uses, because upstream's
    # own flake.lock is incomplete — it omits its flake-utils and nixpkgs
    # entries. getFlake would have to resolve those at evaluation time and dies
    # with "cannot update unlocked flake input 'flake-utils' in pure mode";
    # declaring it here makes OUR flake.lock pin them instead.
    #
    # Deliberately NOT `inputs.nixpkgs.follows = "nixpkgs"`: it expects a newer
    # nixpkgs than the 26.05 release this host is pinned to, and it only
    # unpacks a vendored binary, so letting it keep its own nixpkgs costs a
    # little extra evaluation but avoids a version-skew breakage.
    claude-desktop-extra.url =
      "github:patrickjaja/claude-desktop-extra/55bb93d559e045736bd73742e9e63d238bde5ad3";

    # Zen browser (see ./modules/apps/zen.nix).
    #
    # A real flake INPUT rather than the module-local `builtins.getFlake` used
    # for the plain package, because we now consume this flake's *home-manager
    # module* (`homeModules.beta`) to manage Zen's profile, prefs and theme
    # declaratively. That module imports `mkFirefoxModule` from
    # `home-manager.outPath`, so it MUST resolve to the SAME Home Manager that
    # evaluates our user config — otherwise the two versions' option schemas
    # skew. `follows` pins both nixpkgs and home-manager to ours; getFlake
    # cannot express that. Rev matches the one the old inline getFlake used.
    zen-browser = {
      url =
        "github:0xc000022070/zen-browser-flake/51602966429e8ccae61324e56b51c37308d1b64e";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };

  # `inputs@` so the whole input set can be handed to the modules through
  # specialArgs below — ./modules/apps/claude-desktop.nix needs it.
  outputs = inputs@{ self, nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";

      # Every host is assembled identically — same nixpkgs, same Home Manager
      # wiring. The ONLY thing that varies is the composition root, which is
      # where a host picks its modules and its generated hardware scan. Adding a
      # machine is therefore one line in nixosConfigurations below.
      mkHost = configuration: nixpkgs.lib.nixosSystem {
        inherit system;
        # Makes `inputs` available as a module argument (used by
        # ./modules/apps/claude-desktop.nix).
        specialArgs = { inherit inputs; };
        modules = [
          # This host's composition root: imports the feature modules under
          # ./modules and declares what's unique to that machine.
          configuration

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
    in
    {
      # Build with:  sudo nixos-rebuild switch --flake ~/PWUE/dotfiles-nixos#<name>
      # (the bare `--flake ~/PWUE/dotfiles-nixos` also works on each machine,
      #  since the output names match their hostnames.)
      nixosConfigurations = {
        # Desktop: NVIDIA GTX 1650.
        valerios-nix = mkHost ./hosts/valerios-nix/configuration.nix;

        # HP Laptop 14s-dq0xxx: Intel UHD 620, battery/lid/backlight.
        valerios-laptop = mkHost ./hosts/valerios-laptop/configuration.nix;
      };
    };
}
