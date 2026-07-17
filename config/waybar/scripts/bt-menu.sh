#!/usr/bin/env bash
# Bluetooth device selector via fuzzel.
# fuzzel can't add rows to an already-open menu, so we run discovery FIRST and
# open as soon as a device is known: instant if you have paired devices, else a
# brief wait while it scans (breaks the moment a device appears, like wifi's
# rescan). Discovery keeps running in the background for subsequent opens.
# A "●" marks connected devices; pick one to connect (or disconnect).

bluetoothctl power on >/dev/null 2>&1
# Background discovery (don't stack scans if one is already running).
bluetoothctl show 2>/dev/null | grep -q "Discovering: yes" \
  || bluetoothctl --timeout 20 scan on >/dev/null 2>&1 &

# Open as soon as any device is visible (up to ~6s); paired devices appear at once.
for _ in $(seq 1 12); do
  [ -n "$(bluetoothctl devices 2>/dev/null)" ] && break
  sleep 0.5
done

mapfile -t connected < <(bluetoothctl devices Connected 2>/dev/null | awk '{print $2}')
is_connected() { local m; for m in "${connected[@]}"; do [ "$m" = "$1" ] && return 0; done; return 1; }

declare -A MAC
entries=()
while read -r _ mac name; do
  [ -z "$mac" ] && continue
  if is_connected "$mac"; then label="●  $name"; else label="   $name"; fi
  entries+=("$label"); MAC["$label"]="$mac"
done < <(bluetoothctl devices 2>/dev/null)

[ ${#entries[@]} -eq 0 ] && entries+=("(no devices found — put the device in pairing mode)")

chosen=$(printf '%s\n' "${entries[@]}" | fuzzel --dmenu --prompt "Bluetooth > " --lines 10 --width 44)
[ -z "$chosen" ] && exit 0
mac="${MAC[$chosen]}"
[ -z "$mac" ] && exit 0

if is_connected "$mac"; then
  bluetoothctl disconnect "$mac"
else
  bluetoothctl pair "$mac"  >/dev/null 2>&1
  bluetoothctl trust "$mac" >/dev/null 2>&1
  bluetoothctl connect "$mac"
fi
