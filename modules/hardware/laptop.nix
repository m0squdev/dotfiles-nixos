# Laptop-only bits: things that exist because the machine has a battery, a lid
# and a backlight. Nothing here is specific to one model — a second laptop
# imports the same file. Desktop hosts simply omit the import.
{ pkgs, lib, config, ... }:
let
  # One brightness-key press at the login screen, with the same arithmetic as
  # `swayosd-client --brightness ±10`, which is what the keys run inside niri
  # (config/niri/brightness.sh): a step of 10% of max_brightness, and never
  # below swayosd's built-in 5% floor. Matching both is what lets a level set
  # before login carry on in the same steps after it. brightnessctl's relative
  # "+10%" works out to that same step (brightnessctl.c calc_value), but its
  # --min-value takes a RAW value, not a percentage, so the 5% is computed from
  # the device's own max here rather than hardcoded for this panel.
  greeter-brightness = pkgs.writeShellScript "greeter-brightness" ''
    bctl=${pkgs.brightnessctl}/bin/brightnessctl
    max=$("$bctl" --class=backlight max) || exit 0
    floor=$(( (max * 5 + 50) / 100 ))
    case "''${1:-}" in
      up)   exec "$bctl" -q --class=backlight --min-value="$floor" set +10% ;;
      down) exec "$bctl" -q --class=backlight --min-value="$floor" set 10%- ;;
    esac
  '';

  greeter-sxhkdrc = pkgs.writeText "greeter-sxhkdrc" ''
    XF86MonBrightnessUp
      ${greeter-brightness} up
    XF86MonBrightnessDown
      ${greeter-brightness} down
  '';
in
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

  # --- Brightness keys at the login screen ----------------------------------
  # Everything above is for the niri session, where niri binds the keys. Before
  # login there is no niri: the SDDM greeter runs on its own X server, SDDM has
  # no key handling of its own, and ../desktop/sddm-theme/Main.qml catches no
  # keys — so XF86MonBrightness* reached the greeter and were dropped.
  #
  # sxhkd, started from the greeter's Xsetup script, picks them up. Hooking the
  # greeter's X SERVER rather than the input devices is what confines this to
  # the login screen with no bookkeeping. Xsetup runs as root every time SDDM
  # starts that server, so brightnessctl can write the backlight without the
  # `sddm` user joining `video`. And SDDM stops the server once you log in, which
  # takes sxhkd down with it, so it can never double-step niri's own binding. A
  # root evdev daemon (actkbd, triggerhappy) would instead read every keystroke
  # for the whole uptime and need an "is the greeter the active session?" check
  # on each press.
  #
  # Keys only, no on-screen popup. Volume keys are left alone on purpose: at the
  # login screen they could only reach the greeter user's PipeWire, not yours.
  #
  # TIED TO THE X11 GREETER. If ../desktop/sddm.nix ever turns on
  # `wayland.enable`, setupCommands stops running and these keys quietly go
  # dead again. Nothing is printed on success; a failed grab or a brightnessctl
  # error lands in `journalctl -b -t greeter-brightness-keys`. systemd-cat also
  # takes the place of the pipes SDDM hands Xsetup, so the backgrounded daemon
  # holds none of them open.
  services.xserver.displayManager.setupCommands = ''
    ${pkgs.systemd}/bin/systemd-cat -t greeter-brightness-keys \
      ${pkgs.sxhkd}/bin/sxhkd -c ${greeter-sxhkdrc} </dev/null &
  '';

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
