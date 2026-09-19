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

  # Load the display stack in the initrd, for the boot splash
  # (../core/plymouth.nix). This is a DELIBERATE, measured trade, not an
  # optimisation — the numbers are below so it can be re-judged rather than
  # guessed at, because both directions look obviously-correct from the wrong
  # angle.
  #
  # WHAT IT BUYS. Nothing is visible on this host before nvidia_drm exists.
  # Plymouth is NOT the late part: it starts ~2.8s in, inside the initrd, on
  # simpledrm. But this monitor never scans out the simpledrm/EFI framebuffer —
  # the same reason systemd-boot's own menu is invisible here — so the splash
  # only appears once nvidia_drm sets a real mode. Confirmed with the `spinner`
  # theme, which draws unconditionally and needs no firmware image: still black.
  # Loading the driver here moves that modeset from 8.79s to 5.71s, cutting the
  # black from ~6s to ~2.9s and giving a splash that lasts ~3.7s instead of ~1.3s.
  #
  # WHAT IT COSTS. The blob takes the initrd from 48 MB to 202 MB, and the
  # firmware must read all of it off the ESP before the kernel starts:
  #
  #            loader   initrd   userspace   sum of affected phases
  #   without   2.14s    2.04s     11.18s          15.36s
  #   with      3.31s    3.83s      8.78s          15.92s
  #
  # It saves 2.4s of userspace and pays 2.95s to read and unpack the initrd, so
  # it is ~0.6s SLOWER to a usable desktop (one sample per config, so ±0.3s).
  # Accepted knowingly: 0.6s is cheap for the splash actually being visible.
  #
  # DO NOT go further by killing simpledrm
  # (initcall_blacklist=simpledrm_platform_driver_init). It would close the
  # remaining gap by leaving the firmware's signal up until nvidia's modeset —
  # one display handover instead of two — but simpledrm is this box's ONLY
  # fallback framebuffer: single GPU, no iGPU, services.openssh.enable = false,
  # and an unreadable boot menu. A boot where nvidia_drm fails would have no
  # console, no rescue shell, no remote login and no way to pick an older
  # generation. Enable sshd first if you ever want to revisit it.
  boot.initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_drm" ];

  # PRECONDITION of the line above, and the reason it lives in this host-only
  # module rather than ../core/boot.nix: at ~217 MB of kernel+initrd per
  # generation against a 1 GB ESP, keeping every generation fills /boot after
  # about four rebuilds and nixos-rebuild then dies on ENOSPC. Three fits with
  # room to spare — steady ~650 MB, ~870 MB at the moment of a switch, before the
  # old entries are pruned.
  #
  # Only the BOOT MENU is capped. Older generations still exist in the store and
  # `nix-env --list-generations -p /nix/var/nix/profiles/system` still lists them;
  # they just cannot be picked at power-on, only switched to from a running
  # system. Drop the initrd line above and this cap can go with it.
  #
  # valerios-laptop never sees any of this: it does not import this module.
  boot.loader.systemd-boot.configurationLimit = 3;
}
