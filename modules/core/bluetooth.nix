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
{ ... }:
{
  hardware.bluetooth = {
    enable = true;      # explicit now, rather than inherited from the GNOME module
    powerOnBoot = true;

    # Battery reporting (org.bluez.Battery1) is still gated behind BlueZ's
    # experimental flag. Without it a headset exposes no battery at all, and
    # waybar's {device_battery_percentage} has nothing to show.
    settings.General.Experimental = true;
  };

  # Supplies the pairing agent niri otherwise lacks, and re-authorises known
  # devices on reconnect. Prompts on screen rather than blindly accepting, so an
  # unexpected pair request is still visible. Its tray icon lands in waybar's
  # "⋯" drawer next to kdeconnect's — see the spawn-at-startup in niri/config.kdl.
  services.blueman.enable = true;
}
