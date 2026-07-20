# NVIDIA GTX 1650 (TU117, Turing): use the proprietary driver, not nouveau.
# Nouveau can't reliably resume this card from S3 suspend — it hangs the compositor
# on wake, leaving a frozen wallpaper + dead cursor (the freeze that forced the hard
# reboot). The proprietary driver + powerManagement (which sets
# NVreg_PreserveVideoMemoryAllocations and enables the nvidia-suspend/resume services
# to save & restore VRAM across suspend) makes resume reliable.
#
# Desktop-only: a host without an NVIDIA GPU simply omits this module's import.
{ config, ... }:
{
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;      # required for Wayland / niri
    powerManagement.enable = true;  # preserve VRAM across suspend -> reliable resume
    open = false;                   # proprietary kernel module (most-tested on Turing)
    nvidiaSettings = true;          # provides the nvidia-settings GUI
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
}
