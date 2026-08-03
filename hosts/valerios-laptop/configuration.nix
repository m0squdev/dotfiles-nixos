# Host: valerios-laptop (HP Laptop 14s-dq0xxx) — composition root.
#
# Same job as ../valerios-nix/configuration.nix: COMPOSE modules and declare
# what is unique to THIS machine. What differs from the desktop:
#
#   - Intel UHD 620 iGPU and no discrete card, so ../../modules/hardware/nvidia.nix
#     is NOT imported and ../../modules/hardware/intel-graphics.nix is.
#   - It has a battery, a lid and a backlight -> ../../modules/hardware/laptop.nix.
#   - An Elan fingerprint reader that upstream libfprint cannot drive
#     -> ../../modules/hardware/fingerprint.nix.
#   - Realtek RTL8821CE Wi-Fi + Bluetooth on PCIe (see the notes at the bottom).
#
# Everything else — niri, GNOME apps, theming, fonts, the app set — is identical
# and comes from the shared modules.
#
# BEFORE THE FIRST BUILD: this directory needs its hardware-configuration.nix,
# which is generated on the machine and never shared between hosts. During the
# NixOS install (or afterwards) run `nixos-generate-config`, copy the result in
# here, and `git add` it — flakes only see git-tracked files.
#
# Build:  sudo nixos-rebuild switch --flake ~/PWUE/dotfiles-nixos#valerios-laptop
{ ... }:
{
  imports = [
    # This machine's auto-generated hardware scan (never shared between hosts).
    ./hardware-configuration.nix

    # --- Core system (always on) ---
    ../../modules/core/boot.nix
    ../../modules/core/nix.nix
    ../../modules/core/locale.nix
    ../../modules/core/networking.nix
    ../../modules/core/users.nix
    ../../modules/core/audio.nix
    ../../modules/core/bluetooth.nix
    ../../modules/core/graphics.nix
    ../../modules/core/swap.nix

    # --- Desktop (niri + GNOME session, theming, fonts, input method) ---
    ../../modules/desktop/gnome.nix
    ../../modules/desktop/niri.nix
    ../../modules/desktop/fonts.nix
    ../../modules/desktop/input-method.nix
    ../../modules/desktop/theming.nix

    # --- Hardware quirks ---
    # No nvidia.nix here: the only GPU is the CPU's integrated one.
    ../../modules/hardware/intel-graphics.nix
    ../../modules/hardware/laptop.nix
    ../../modules/hardware/fingerprint.nix

    # --- Apps with real configuration (each its own ad-hoc module) ---
    ../../modules/apps/zen.nix
    ../../modules/apps/syncthing.nix
    ../../modules/apps/claude-desktop.nix

    # --- One-line apps / simple toggles (edit the list inside) ---
    ../../modules/apps/misc.nix
  ];

  networking.hostName = "valerios-laptop";

  # The Wi-Fi/Bluetooth card is a Realtek RTL8821CE (rtw88_8821ce). Its firmware
  # is redistributable-but-unfree and is pulled in by
  # hardware.enableRedistributableFirmware, which the generated
  # hardware-configuration.nix already sets via not-detected.nix — so there is
  # nothing to do here as long as that import stays.
  #
  # This card once needed the out-of-tree rtl8821ce DKMS driver (the Arch install
  # carried `rtl8821ce-dkms-git` from December 2024 and later dropped it). It no
  # longer does: the in-tree rtw88_8821ce claims the device and is what the
  # machine runs on today, so there is NOTHING out-of-tree to port here.
  #
  # KNOWN QUIRK, deliberately left off because this unit does not need it: rtw88
  # on several HP models drops the link every few minutes, or fails to associate
  # after suspend/resume, because of PCIe ASPM. If that starts happening,
  # uncomment this and rebuild — it costs a little idle power:
  #
  #   boot.extraModprobeConfig = ''
  #     options rtw88_pci disable_aspm=1
  #   '';

  # The internal microphone needs NO special handling, despite the fingerprint
  # reader next to it doing so. It is a Realtek ALC236 on the ordinary
  # snd_hda_intel path (pin 0x12, "Internal Mic"), which the stock kernel drives:
  # no DKMS module, no model= quirk, no UCM override, and /etc/modprobe.d was
  # empty on the Arch install. What that machine did get was `alsa-utils`, i.e.
  # alsamixer — so the fix was almost certainly unmuting/boosting the capture
  # level, not a driver. ../../modules/core/audio.nix (PipeWire) is all that is
  # needed; if it records silence after the install, raise "Internal Mic Boost"
  # in alsamixer or the input level in GNOME Settings -> Sound before suspecting
  # the driver.

  # NixOS release whose stateful defaults (file locations, DB versions, …) this
  # machine was first installed with. Do NOT bump casually — read `man
  # configuration.nix` / the manual first. Home Manager's home.stateVersion in
  # ../../home/home.nix tracks this. Set to match the nixpkgs pinned in
  # ../../flake.nix; if you install from a newer ISO, use that release instead.
  system.stateVersion = "26.05";
}
