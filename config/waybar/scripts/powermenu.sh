#!/usr/bin/env bash
# Power menu via fuzzel. Left-click the waybar power module runs this.

choice=$(printf '%s\n' "  Lock" "  Logout" "  Suspend" "  Reboot" "  Shutdown" \
  | fuzzel --dmenu --prompt "Power > " --lines 5 --width 16)

case "$choice" in
  *Lock)     /home/valer/.config/niri/lock.sh ;;
  *Logout)   niri msg action quit --skip-confirmation ;;
  *Suspend)  systemctl suspend ;;
  *Reboot)   systemctl reboot ;;
  *Shutdown) systemctl poweroff ;;
esac
