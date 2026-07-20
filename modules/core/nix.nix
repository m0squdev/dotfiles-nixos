# Nix daemon settings + unfree packages.
{ ... }:
{
  # Flakes + the unified `nix` CLI. Required to pull the Zen browser flake
  # (see ../apps/zen.nix, which uses builtins.getFlake).
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Allow unfree packages (NVIDIA driver, zen-browser, obsidian, …).
  nixpkgs.config.allowUnfree = true;
}
