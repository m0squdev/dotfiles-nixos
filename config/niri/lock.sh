#!/usr/bin/env bash
# Lock the screen once. Primary locker is hyprlock (minimal Catppuccin Mocha theme
# via ~/.config/hypr/hyprlock.conf). If hyprlock isn't available yet (e.g. before
# the nixos-rebuild that installs it), fall back to swaylock so the screen still
# locks. Never stack lockers.
#
# The locker is launched in the BACKGROUND and this script returns immediately.
# That matters for swayidle's `before-sleep` hook (run with -w): hyprlock, unlike
# `swaylock -f`, never forks once it's locked, so `exec hyprlock` would block the
# hook forever and logind would force-suspend only after its delay-inhibitor
# times out (~5s), re-locking in your face on the way down. Returning promptly
# lets logind lock-then-sleep cleanly.
pgrep -x hyprlock >/dev/null && exit 0
pgrep -x swaylock >/dev/null && exit 0

if command -v hyprlock >/dev/null 2>&1; then
  hyprlock &
else
  swaylock -f &
fi
disown 2>/dev/null || true
