#!/usr/bin/env bash
# Wi-Fi chooser via fuzzel. Left-click the waybar network module runs this.
# Lists nearby networks; connecting to a secured one prompts for a password.

nmcli radio wifi on 2>/dev/null
sleep 0.3

# Saved connection profiles — these are the "known" networks that get "○".
known=$(nmcli --terse --fields NAME connection show 2>/dev/null)

# One row per SSID. A dual-band AP broadcasts the same name on 2.4 and 5GHz, so
# the scan returns it once per BSSID; deduping on the formatted line (as this
# used to) kept both, because their signal percentages differ. Sort by priority
# first -- connected wins outright, otherwise strongest signal -- then keep the
# first row per SSID, so the survivor is the band actually worth showing.
chosen=$(nmcli --terse --fields IN-USE,SSID,SIGNAL,SECURITY device wifi list --rescan yes \
  | awk -F: -v known="$known" '
      # Shared marker convention with bt-menu.sh:
      #   ●  connected      ○  known (saved profile)      (blank)  unknown
      BEGIN { n = split(known, k, "\n"); for (i = 1; i <= n; i++) if (length(k[i])) saved[k[i]] = 1 }
      length($2) {
        if ($1 == "*")        mark = "●  "
        else if ($2 in saved) mark = "○  "
        else                  mark = "   "
        sec = ($4 == "" ? "" : ", " $4)
        pri = ($1 == "*") ? 1000 + $3 : $3
        printf "%d\t%s%s  (%s%%%s)\t%s\n", pri, mark, $2, $3, sec, $2
      }' \
  | sort -t"$(printf '\t')" -k1,1nr \
  | awk -F"$(printf '\t')" '!seen[$3]++ { print $2 }' \
  | fuzzel --dmenu --prompt "Wi-Fi > " --lines 12 --width 40)

[ -z "$chosen" ] && exit 0

# Strip the "●  "/"○  "/"   " marker and the trailing "  (NN%, SEC)" annotation
ssid=$(printf '%s' "$chosen" | sed -E 's/^[●○] +//; s/^ +//; s/  \([^)]*\)$//')
[ -z "$ssid" ] && exit 0

if nmcli -t -f NAME connection show | grep -qxF "$ssid"; then
  # Known network — just bring it up
  nmcli connection up id "$ssid"
else
  pass=$(fuzzel --dmenu --password --prompt "Password for $ssid > ")
  if [ -n "$pass" ]; then
    nmcli device wifi connect "$ssid" password "$pass"
  else
    nmcli device wifi connect "$ssid"
  fi
fi
