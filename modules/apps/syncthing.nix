# Syncthing: continuous file sync, run as a systemd service under `valer`.
# The SERVICE is fully declarative (this block); the actual devices and folders
# are paired in the Web GUI at http://127.0.0.1:8384 and stored in
# ~/.config/syncthing (which holds this machine's PRIVATE key, a per-machine
# secret that's never committed). overrideDevices/overrideFolders are false so
# a rebuild never wipes what you set up in the GUI.
{ ... }:
{
  services.syncthing = {
    enable = true;
    user = "valer";
    group = "users";
    dataDir = "/home/valer";                      # default "~/Sync" folder lives here
    configDir = "/home/valer/.config/syncthing";  # config + keys where you'd expect them
    openDefaultPorts = true;                       # 22000/tcp+udp (sync) + 21027/udp (discovery)
    overrideDevices = false;                       # let the GUI own device pairing
    overrideFolders = false;                       # let the GUI own folder config
  };
}
