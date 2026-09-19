# Boot splash: Plymouth. Shared by every host — a splash is not
# machine-specific.
#
# The theme is left at NixOS's default, `bgrt`: it draws the firmware's own boot
# logo (the OEM image the UEFI already put on screen, handed over via the ACPI
# BGRT table) with a spinner under it, and falls back to the `spinner` theme —
# NixOS snowflake on black — on machines that publish no such image. Nothing
# here is themed to match the rest of the setup on purpose; set
# `boot.plymouth.theme` + `themePackages` if that ever changes.
#
# What IS machine-specific is whether the real GPU's DRM driver goes into the
# initrd, and on valerios-desktop that turned out to be the difference between a
# splash and a black screen rather than a nicety. Both vendor modules now do it,
# for very different prices — ../hardware/intel-graphics.nix for a few MB,
# ../hardware/nvidia.nix for ~150 MB and a generation cap. The measurement that
# forced the second one is written up there; read it before undoing either.
#
# Worth knowing if you ever debug this again: Plymouth is never the late part.
# It starts ~2.8s in, inside the initrd, as soon as there is any DRM device. If
# the screen is black anyway, the question is which device the monitor is
# actually scanning out — not when Plymouth ran.
{ ... }:
{
  boot.plymouth.enable = true;   # also appends `splash` to boot.kernelParams

  # A splash is only a splash if nothing else draws over it. Left alone, the
  # kernel and udev keep printing to the very console Plymouth is rendering on,
  # and the boot is a wall of text with a spinner fighting through it:
  #
  #   quiet + consoleLogLevel = 0   kernel messages off the console
  #   udev.log_level=3              udev down to errors (it is the loudest one)
  #   initrd.verbose = false        the same treatment for stage 1
  #
  # Nothing is lost, only hidden — press Esc during boot to drop the splash and
  # watch the messages scroll live, and `journalctl -b` still has every one of
  # them afterwards.
  boot.kernelParams = [ "quiet" "udev.log_level=3" ];
  boot.consoleLogLevel = 0;
  boot.initrd.verbose = false;

  # Deliberately NOT touched here: boot.loader.timeout. systemd-boot's generation
  # menu counts down before any of this runs, so the splash still comes after the
  # usual list. Set it to 0 in ./boot.nix to go straight to the splash; with
  # systemd-boot the menu stays reachable by holding Space at power-on.
}
