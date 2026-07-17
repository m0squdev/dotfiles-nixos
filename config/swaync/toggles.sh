#!/usr/bin/env bash
# Quick Settings toggle helpers, called by the swaync control-center buttons.
# Usage: toggles.sh {wifi|bt|dark} {state|toggle}
#   state  -> prints "true"/"false" so swaync can show the button as on/off
#   toggle -> flips the setting

case "${1:-}:${2:-}" in
  wifi:state)
    if nmcli -t radio wifi | grep -q '^enabled$'; then echo true; else echo false; fi ;;
  wifi:toggle)
    if nmcli -t radio wifi | grep -q '^enabled$'; then nmcli radio wifi off; else nmcli radio wifi on; fi ;;

  bt:state)
    if bluetoothctl show 2>/dev/null | grep -q 'Powered: yes'; then echo true; else echo false; fi ;;
  bt:toggle)
    if bluetoothctl show 2>/dev/null | grep -q 'Powered: yes'; then
      bluetoothctl power off
    else
      rfkill unblock bluetooth 2>/dev/null
      bluetoothctl power on
    fi ;;

  dark:state)
    if [ "$(gsettings get org.gnome.desktop.interface color-scheme)" = "'prefer-dark'" ]; then
      echo true; else echo false; fi ;;
  dark:toggle)
    if [ "$(gsettings get org.gnome.desktop.interface color-scheme)" = "'prefer-dark'" ]; then
      gsettings set org.gnome.desktop.interface color-scheme default
    else
      gsettings set org.gnome.desktop.interface color-scheme prefer-dark
    fi ;;

  *)
    echo "usage: $0 {wifi|bt|dark} {state|toggle}" >&2; exit 1 ;;
esac
