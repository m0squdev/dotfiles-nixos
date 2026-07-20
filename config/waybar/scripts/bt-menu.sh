#!/usr/bin/env bash
# Bluetooth device selector via fuzzel — STREAMING, like the Wi-Fi menu.
# fuzzel renders stdin asynchronously, so rather than scan-then-open we open the
# menu immediately and let devices appear as discovery finds them. A background
# producer polls `bluetoothctl devices` and streams each newly-seen device into
# the open picker; "●" marks connected ones. MACs are kept OUT of the rows, so
# after a pick we re-resolve the chosen name back to its MAC.
# Pick a connected device to disconnect it, any other to pair+trust+connect.

bluetoothctl power on >/dev/null 2>&1
# Background discovery (don't stack scans if one is already running).
bluetoothctl show 2>/dev/null | grep -q "Discovering: yes" \
  || bluetoothctl --timeout 30 scan on >/dev/null 2>&1 &

# Stream into fuzzel through a FIFO (not a plain pipe) so we can kill the
# producer the instant fuzzel closes — otherwise it would keep polling and the
# command substitution would hang until the loop's timeout.
fifo=$(mktemp -u -p "${XDG_RUNTIME_DIR:-/tmp}" bt-menu.XXXXXX)
mkfifo "$fifo"
prod_pid=""
cleanup() { [ -n "$prod_pid" ] && kill "$prod_pid" 2>/dev/null; rm -f "$fifo"; }
trap cleanup EXIT

{
  declare -A seen
  for _ in $(seq 1 50); do
    conn=$(bluetoothctl devices Connected 2>/dev/null | awk '{print $2}')
    while read -r _ mac name; do
      [ -z "$mac" ] && continue
      [ -n "${seen[$mac]}" ] && continue
      seen["$mac"]=1
      case " $conn " in
        *" $mac "*) printf '●  %s\n' "$name" ;;
        *)          printf '   %s\n' "$name" ;;
      esac
    done < <(bluetoothctl devices 2>/dev/null)
    sleep 0.6
  done
} > "$fifo" &
prod_pid=$!

chosen=$(fuzzel --dmenu --prompt "Bluetooth > " --lines 10 --width 44 < "$fifo")
cleanup; trap - EXIT

[ -z "$chosen" ] && exit 0
# Strip the "●  " / "   " marker to recover the plain device name.
name=$(printf '%s' "$chosen" | sed -E 's/^● +//; s/^ +//')
[ -z "$name" ] && exit 0

# Re-resolve the display name back to a MAC (no IDs are shown in the rows).
# First exact-name match wins; duplicate names would be ambiguous.
mac=$(bluetoothctl devices 2>/dev/null | while read -r _ m rest; do
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
