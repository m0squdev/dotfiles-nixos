#!/usr/bin/env bash
# Power menu via fuzzel. Left-click the waybar power module runs this.

# Hibernate is offered only when logind reports suspend-to-disk is actually
# possible (kernel support + an on-disk swap >= RAM; zram doesn't count). So it
# shows on the laptop, which has a swap partition, and not on the zram-only
# desktop — kept in sync with boot.resumeDevice in modules/hardware/laptop.nix.
entries=("  Lock" "  Logout" "  Suspend")
busctl --system call org.freedesktop.login1 /org/freedesktop/login1 \
       org.freedesktop.login1.Manager CanHibernate 2>/dev/null | grep -q '"yes"' \
  && entries+=("  Hibernate")
entries+=("  Shutdown" "  Reboot")

choice=$(printf '%s\n' "${entries[@]}" \
  | fuzzel --dmenu --prompt "Power > " --lines "${#entries[@]}" --width 16)

case "$choice" in
  *Lock)      /home/valer/.config/niri/lock.sh ;;
  *Logout)    niri msg action quit --skip-confirmation ;;
  *Suspend)   systemctl suspend ;;
  *Hibernate) systemctl hibernate ;;
  *Shutdown)  systemctl poweroff ;;
  *Reboot)    systemctl reboot ;;
esac
