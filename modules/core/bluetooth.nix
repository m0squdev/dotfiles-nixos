# Bluetooth.
#
# This module exists because Bluetooth was never actually configured here: no
# .nix file set hardware.bluetooth at all, and it was being switched on purely
# as a side effect of services.desktopManager.gnome.enable's mkDefault (see
# modules/desktop/gnome.nix). That was fine for the radio, but it also silently
# assumed GNOME's *session* — and gnome-shell is what normally supplies the
# org.bluez.Agent1 pairing agent. We log into niri, so nothing ever registered
# one.
#
# The symptom that caused: a headset works only for the session in which it was
# first paired (an interactive `bluetoothctl` registers an agent for as long as
# it is open), then never again. On the next reconnect the device asks to
# re-authenticate, no agent answers -->
#     bluetoothd: src/device.c:new_auth() No agent available for request type 2
#     bluetoothd: device_confirm_passkey: Operation not permitted
# and BlueZ drops the link key, leaving the device "Trusted: yes, Paired: no".
# Every profile connect then fails (Hands-Free first, then A2DP). It looked
# device-specific until a second headset did exactly the same thing.
{ pkgs, ... }:
{
  hardware.bluetooth = {
    enable = true;      # explicit now, rather than inherited from the GNOME module
    powerOnBoot = true;

    # Battery reporting (org.bluez.Battery1) is still gated behind BlueZ's
    # experimental flag. Without it a headset exposes no battery at all, and
    # waybar's {device_battery_percentage} has nothing to show.
    settings.General.Experimental = true;

    # Pin BlueZ to 5.80: 5.83+ cannot reconnect the Redmi Buds. VERIFIED — the
    # buds reconnect and hold on 5.80, and fail within ~8s on 5.86.
    #
    # bluez/bluez#1570 reports the same thing for Redmi Buds 5 and 6 Lite from
    # 5.83 onwards (last good: 5.80): HSP/HFP is attempted instead of A2DP, with
    # this line, which we saw here too:
    #     Unable to get io data for Hands-Free Voice gateway:
    #       getpeername: Transport endpoint is not connected
    # Only a *fresh pairing* worked, and only once; every automatic reconnect
    # died seconds in. Nothing regressed locally — every system generation on
    # this machine has shipped 5.86, so it simply never ran a good version.
    #
    # Don't be fooled by the downstream symptoms if this resurfaces. btmon shows
    # the buds opening an inbound RFCOMM channel, MITM being demanded, the
    # kernel refusing our own (unauthenticated, Type=4) link key, and a fresh
    # pairing that can't succeed against a NoInputNoOutput peer — after which
    # BlueZ closes the *working* A2DP stream and the buds drop the link (0x13).
    # All of that is downstream of the profile-connection bug. Disabling HFP,
    # obexd, USB autosuspend, or changing the agent's IO capability each look
    # plausible and each change nothing.
    #
    # Scoped here rather than as a nixpkgs.overlays override of pkgs.bluez: an
    # overlay swaps bluez for the whole closure and forces NetworkManager,
    # PipeWire, blueman and everything downstream to rebuild. The bug is in
    # bluetoothd, so only the daemon needs to change, and 5.86-linked clients
    # talk to a 5.80 daemon fine.
    #
    # COST: 5.80 is well behind on fixes, security ones included. Drop the pin
    # once #1570 is fixed upstream; 5.81/5.82 are untested here and would be a
    # newer baseline if either works. nixos-rebuild does NOT restart
    # bluetooth.service, so changing this needs `systemctl restart bluetooth`.
    package = pkgs.bluez.overrideAttrs (old: rec {
      version = "5.80";
      src = pkgs.fetchurl {
        url = "mirror://kernel/linux/bluetooth/bluez-${version}.tar.xz";
        sha256 = "16j5dgqnq73zmnq44v02lm8ll81q8s2knxyrbdnz14cn56ivrl54";
      };
      # 5.86-era patches in nixpkgs won't apply to a 5.80 tree.
      patches = [ ];
    });
  };

  # Supplies the pairing agent niri otherwise lacks, and re-authorises known
  # devices on reconnect. Prompts on screen rather than blindly accepting, so an
  # unexpected pair request is still visible. Its tray icon lands in waybar's
  # "⋯" drawer next to kdeconnect's — see the spawn-at-startup in niri/base.kdl.
  services.blueman.enable = true;

}
