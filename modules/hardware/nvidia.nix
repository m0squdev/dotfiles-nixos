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

  # DELIBERATELY NOT DONE HERE, though it is the usual advice:
  #
  #   boot.initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_drm" ];
  #
  # It works, and it does buy the thing it promises — the boot splash
  # (../core/plymouth.nix) would come up straight on this card instead of
  # starting on the EFI framebuffer (simpledrm) and handing over when nvidia_drm
  # loads in stage 2, which costs one mode change early in boot.
  #
  # The price is the problem. This driver is a ~150 MB blob, and putting it in
  # stage 1 took this host's initrd from 41 MB to 202 MB (measured). /boot is a
  # 1 GB ESP and boot.loader.systemd-boot.configurationLimit is unset, i.e. NixOS
  # keeps EVERY generation there — so at ~215 MB of kernel+initrd per generation
  # the ESP fills after about four rebuilds and `nixos-rebuild` then dies on
  # ENOSPC. Trading a working rebuild for one flicker is not a good trade.
  #
  # If you ever want it anyway, set configurationLimit (3 or so) in
  # ../core/boot.nix FIRST, and only then add the line above.
  # ../hardware/intel-graphics.nix does do this, because i915 is a few MB.
}
