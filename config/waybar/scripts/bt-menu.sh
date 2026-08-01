#!/usr/bin/env bash
# Bluetooth device selector via fuzzel — STREAMING, like the Wi-Fi menu.
# fuzzel renders stdin asynchronously, so rather than scan-then-open we open the
# menu immediately and let devices appear as discovery finds them. A background
# producer polls `bluetoothctl devices` and streams each newly-seen device into
# the open picker; "●" marks connected devices, "○" paired ones, and unpaired
# ones carry no marker. MACs are kept OUT of the rows, so after a pick we
# re-resolve the chosen name back to its MAC.
# Pick a connected device to disconnect it, any other to pair+trust+connect.

bluetoothctl power on >/dev/null 2>&1
# Always start our OWN discovery, even when the adapter already reports
# "Discovering: yes". Discovery in BlueZ is per-client and reference counted, so
# that flag only means *somebody* is scanning — blueman holds a session
# permanently — and it does not mean we get the results. This used to be
# guarded with `grep -q "Discovering: yes" ||`, which silently skipped the scan
# and left the menu showing nothing but already-known devices. Verified: with
# the flag already yes, starting a scan anyway takes the list from 2 to 8.
bluetoothctl --timeout 30 scan on >/dev/null 2>&1 &

# Stream into fuzzel through a FIFO (not a plain pipe) so we can kill the
# producer the instant fuzzel closes — otherwise it would keep polling and the
# command substitution would hang until the loop's timeout.
# bluetoothctl colourises `devices` output even when it is piped, so escape
# sequences end up glued to the device names — they render as garbage in fuzzel,
# and the name we show has to match the name we look the MAC up by, so this must
# be applied everywhere the list is read.
strip_ansi() { sed 's/\x1b\[[0-9;]*m//g'; }

fifo=$(mktemp -u -p "${XDG_RUNTIME_DIR:-/tmp}" bt-menu.XXXXXX)
mkfifo "$fifo"
prod_pid=""
cleanup() { [ -n "$prod_pid" ] && kill "$prod_pid" 2>/dev/null; rm -f "$fifo"; }
trap cleanup EXIT

{
  # Is $1 in the space-separated MAC list $2? The lists below are flattened with
  # tr because the match needs a space on BOTH sides — with newline separators
  # every entry but a lone one has a "\n" on one side and silently never matches.
  has() { case " $2 " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

  # No availability filtering here, deliberately — BlueZ already does it. An
  # unpaired device only appears in `bluetoothctl devices` while discovery can
  # see it, and drops out of the cache afterwards, so the list is inherently
  # limited to what's reachable plus the paired devices.
  #
  # Filtering unpaired entries on RSSI was tried and reverted: it changed
  # nothing (every freshly discovered device has an RSSI anyway) and cost a
  # `bluetoothctl info` per unseen device per poll, which made devices take
  # seconds to appear.
  #
  # Don't try to hide paired-but-unavailable devices either. Measured on the
  # WH-XB910N: powered OFF and powered ON-but-idle both report no RSSI, because
  # a paired BR/EDR headset is *connectable* (page scan) without being
  # *discoverable* (inquiry) unless it is in pairing mode. Off, idle, and busy
  # with another host are indistinguishable over the air. There's no cheap
  # probe — hcitool name returns nothing here, l2ping needs root — and more to
  # the point, a headset already connected to a phone looks exactly the same,
  # so any such filter would hide the multipoint device precisely when you want
  # to steal it back onto this machine.

  declare -A seen
  for _ in $(seq 1 50); do
    conn=$(bluetoothctl devices Connected 2>/dev/null | awk '{print $2}' | tr '\n' ' ')
    paired=$(bluetoothctl devices Paired 2>/dev/null | awk '{print $2}' | tr '\n' ' ')
    # Connected devices first so they head the list, then everything else;
    # dedup on MAC keeps the first (connected) copy. Within a poll that fixes
    # the order, and since connected devices are known before discovery finds
    # anything, they land at the top of the stream.
    while read -r _ mac name; do
      [ -z "$mac" ] && continue
      [ -n "${seen[$mac]}" ] && continue
      # Skip devices BlueZ has no name for — it falls back to the address with
      # dashes ("4C-18-55-17-74-05"). Those are almost all random-address BLE
      # beacons (phones, watches, trackers) that there is no point connecting
      # to, and which a phone's own picker hides too.
      # Deliberately NOT marked as seen: BlueZ usually discovers the address
      # first and resolves the name a moment later, so a real device briefly
      # looks unnamed. Leaving it unseen lets a later poll pick it up properly.
      [ "$name" = "${mac//:/-}" ] && continue
      seen["$mac"]=1
      # Shared marker convention with wifi-menu.sh:
      #   ●  connected      ○  paired (known)      (blank)  unpaired
      if has "$mac" "$conn"; then
        printf '●  %s\n' "$name"
      elif has "$mac" "$paired"; then
        printf '○  %s\n' "$name"
      else
        printf '   %s\n' "$name"
      fi
    done < <({ bluetoothctl devices Connected; bluetoothctl devices; } 2>/dev/null \
             | strip_ansi | awk '!dup[$2]++')
    sleep 0.6
  done
} > "$fifo" &
prod_pid=$!

chosen=$(fuzzel --dmenu --prompt "Bluetooth > " --lines 10 --width 44 < "$fifo")
cleanup; trap - EXIT

[ -z "$chosen" ] && exit 0
# Strip the leading "●  " / "○  " / "   " marker to recover the device name.
name=$(printf '%s' "$chosen" | sed -E 's/^[●○] +//; s/^ +//')
[ -z "$name" ] && exit 0

# Re-resolve the display name back to a MAC (no IDs are shown in the rows).
# First exact-name match wins; duplicate names would be ambiguous.
mac=$(bluetoothctl devices 2>/dev/null | strip_ansi | while read -r _ m rest; do
  [ "$rest" = "$name" ] && { printf '%s' "$m"; break; }
done)
[ -z "$mac" ] && exit 0

if bluetoothctl devices Connected 2>/dev/null | grep -qF "$mac"; then
  bluetoothctl disconnect "$mac"
else
  bluetoothctl pair "$mac"  >/dev/null 2>&1
  bluetoothctl trust "$mac" >/dev/null 2>&1
  bluetoothctl connect "$mac"
fi
