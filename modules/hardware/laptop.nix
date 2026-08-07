# Laptop-only bits: things that exist because the machine has a battery, a lid
# and a backlight. Nothing here is specific to one model — a second laptop
# imports the same file. Desktop hosts simply omit the import.
{ pkgs, lib, config, ... }:
{
  # --- Power profiles -------------------------------------------------------
  # power-profiles-daemon (power-saver / balanced / performance) rather than TLP:
  # the two conflict, and PPD is what GNOME Settings' Power panel and — more to
  # the point here — waybar's power pill drive. config/waybar/scripts/power.sh
  # calls `powerprofilesctl get` for its tooltip and `powerprofilesctl set` from
  # the right-click menu, so without this the pill shows a battery percentage and
  # its menu does nothing.
  #
  # GNOME's module already switches this on by mkDefault, but that is a side
  # effect of a desktop we don't log into (we run niri). State it explicitly so
  # the pill's behaviour doesn't depend on ../desktop/gnome.nix staying imported.
  services.power-profiles-daemon.enable = true;

  # Intel's thermal daemon. On a fanless-ish 15W U-series chip in a thin chassis
  # the firmware's own trip points are conservative; thermald applies the
  # platform's DPTF tables so it throttles gradually instead of hitting the
  # hard thermal limit and dropping to a crawl.
  services.thermald.enable = true;

  # --- Backlight ------------------------------------------------------------
  # The brightness keys go through brightnessctl (bound in config/niri/base.kdl
  # via ../desktop/niri.nix). Writing /sys/class/backlight/*/brightness is
  # root-only by default and logind does NOT hand the active session an ACL for
  # it, so the keys silently do nothing until both of these are in place:
  #
  #   1. brightnessctl's udev rule, which chgrp's the sysfs node to `video`.
  #      NixOS only installs rules from services.udev.packages — putting the
  #      package in environment.systemPackages (which ../desktop/niri.nix does)
  #      gets you the binary and not the rule.
  services.udev.packages = [ pkgs.brightnessctl ];
  #   2. the user in that group. Merged with the extraGroups list in
  #      ../core/users.nix rather than replacing it.
  users.users."valer".extraGroups = [ "video" ];

  # --- Battery pill repaint -------------------------------------------------
  # The waybar power pill (config/waybar/scripts/power.sh) polls on a 30s timer,
  # so left to itself the charging <-> discharging glyph could lag up to half a
  # minute behind the cable — and it sometimes flips quickly only because a poll
  # happened to land right after the event. The plug/unplug is knowable at once:
  # the AC adapter and the battery both sit under SUBSYSTEM=="power_supply" and
  # fire a "change" uevent the moment the cable moves (and again on every 1%
  # step). Turn each of those into the SIGRTMIN+10 the module already listens on
  # ("signal": 10 in config/waybar/config.jsonc, which re-runs its exec) so the
  # glyph flips immediately; the 30s poll stays as a backstop. pkill runs as root
  # here and matches by exact comm across all users, so it reaches the waybar the
  # session started under its own uid.
  services.udev.extraRules = ''
    SUBSYSTEM=="power_supply", ACTION=="change", RUN+="${pkgs.procps}/bin/pkill -RTMIN+10 -x .waybar-wrapped"
  '';

  # --- Lid / suspend / hibernate -------------------------------------------
  # Lid close stays at the default: suspend to RAM.
  #
  # Hibernation (suspend-to-disk) IS available here, unlike on a zram-only host:
  # this machine's hardware-configuration.nix declares a real swap partition that
  # is >= RAM (zram can't be a hibernation target — it lives in the very RAM the
  # image has to save). Point the resume logic at that swap device so the kernel
  # finds the image on the next boot; without resumeDevice, hibernate would write
  # an image but never resume from it. It's derived from the first declared
  # swapDevice, so a laptop with only zram (swapDevices = []) gets no resumeDevice
  # and simply won't hibernate — and the Waybar power menu (scripts/powermenu.sh)
  # offers Hibernate only when logind says it's possible, so the two stay in sync.
  #
  # NOTE: swap here is unencrypted, so the hibernation image (a copy of RAM) lands
  # on unencrypted disk — the same exposure class as ordinary swap on this
  # already-unencrypted machine, but worth knowing.
  boot.resumeDevice = lib.mkIf (config.swapDevices != [ ])
    (builtins.head config.swapDevices).device;
}
