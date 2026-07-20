# Networking via NetworkManager. (The hostname is set per-host in
# hosts/<host>/configuration.nix.)
{ ... }:
{
  networking.networkmanager.enable = true;
}
