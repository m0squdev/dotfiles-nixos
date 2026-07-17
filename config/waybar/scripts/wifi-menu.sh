#!/usr/bin/env bash
# Wi-Fi chooser via fuzzel. Left-click the waybar network module runs this.
# Lists nearby networks; connecting to a secured one prompts for a password.

nmcli radio wifi on 2>/dev/null
sleep 0.3

chosen=$(nmcli --terse --fields IN-USE,SSID,SIGNAL,SECURITY device wifi list --rescan yes \
  | awk -F: 'length($2){ mark=($1=="*")?"* ":"  "; sec=($4==""?"":", "$4); printf "%s%s  (%s%%%s)\n", mark, $2, $3, sec }' \
  | awk '!seen[$0]++' \
  | fuzzel --dmenu --prompt "Wi-Fi > " --lines 12 --width 40)

[ -z "$chosen" ] && exit 0

# Strip the leading marker and the trailing "  (NN%, SEC)" annotation to get the SSID
ssid=$(printf '%s' "$chosen" | sed -E 's/^(\* |  )//; s/  \([^)]*\)$//')
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
