# Bootloader: systemd-boot on EFI.
{ ... }:
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # NOTE: configurationLimit is deliberately NOT set here. Unset means "keep
  # every generation in /boot", which is the right default while an initrd is a
  # few tens of MB — the laptop's is 53 MB and it keeps all of them.
  #
  # Capping it is a per-machine matter, so it belongs to whichever module makes
  # that machine's initrd big. Right now that is ../hardware/nvidia.nix, imported
  # only by valerios-desktop: it puts the NVIDIA blob in the initrd for the boot
  # splash and sets its own limit of 3 right next to the line that forces it.
  # Setting a cap here instead would quietly shrink the laptop's boot menu for a
  # problem the laptop does not have.
}
