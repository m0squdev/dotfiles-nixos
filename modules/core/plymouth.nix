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
# initrd, so the splash comes up at the final resolution instead of starting on
# the EFI framebuffer (simpledrm) and flipping when the driver binds in stage 2.
# That decision belongs to whichever vendor module the host imports, and the two
# went opposite ways on it for a reason worth reading before copying either:
# ../hardware/intel-graphics.nix does it (i915 is a few MB),
# ../hardware/nvidia.nix explicitly does not (the blob is ~150 MB of initrd).
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
  # menu counts down (5s) before any of this runs, so the splash still comes
  # after the usual list. Set it to 0 in ./boot.nix to go straight to the splash;
  # with systemd-boot the menu stays reachable by holding Space at power-on.
}
