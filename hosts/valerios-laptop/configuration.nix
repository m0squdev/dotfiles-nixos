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
    ../../modules/apps/libreoffice.nix

    # --- One-line apps / simple toggles (edit the list inside) ---
    ../../modules/apps/misc.nix
  ];

  networking.hostName = "valerios-laptop";

  # --- niri display layout (this host only) ---------------------------------
  # niri's entry point is ~/.config/niri/config.kdl. The cross-host config lives
  # in ../../config/niri/base.kdl (symlinked in by ../../home/dotfiles.nix); this
  # host's config.kdl just `include`s it and layers on the ONE thing unique to
  # this machine — where its external monitor sits. Keeping it here (not in the
  # shared base) is why the desktop never inherits this output block. niri
  # resolves the relative include against the symlink's own directory
  # (~/.config/niri), so `include "base.kdl"` needs no path.
  #
  # The built-in panel is pinned at the origin FIRST. This matters: niri places
  # explicitly-positioned outputs and then auto-places the rest to the RIGHT of
  # them, so if only the external were positioned, eDP-1 would be auto-dropped to
  # its right and the laptop would end up on the far right with the LG on its
  # left. Anchoring eDP-1 at 0,0 makes it the left reference the LG sits beside.
  #
  # The external is matched by the monitor's make/model/serial exactly as printed
  # by `niri msg outputs` — NOT the HDMI-A-1 connector — so it binds to THIS
  # specific LG panel on whatever port it lands on, and is simply inert whenever
  # that panel isn't connected. It sits to the right of eDP-1, raised so its
  # bottom edge is 1/3 of the laptop panel's height above the laptop's bottom edge:
  #   x = 1536 → eDP-1's logical width (1920 @ scale 1.25), i.e. flush to its right
  #   y = −504 → 576 − 1080, where 576 is the target bottom edge
  #              (laptop bottom 864 − 864/3 = 288) and 1080 is the LG's own
  #              logical height (1920×1080 @ scale 1)
  # The y value assumes the LG stays 1920×1080 @ scale 1; change its mode or
  # scale and its logical height — so this offset — has to be recomputed.
  home-manager.users.valer.xdg.configFile."niri/config.kdl".text = ''
    include "base.kdl"

    output "eDP-1" {
        position x=0 y=0
    }

    output "LG Electronics M2352D 0x01010101" {
        position x=1536 y=-504
    }
  '';

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
