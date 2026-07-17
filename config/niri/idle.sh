#!/usr/bin/env bash
# niri idle management (needs the `swayidle` package).
# Respects the waybar caffeine / idle-inhibitor toggle: while caffeine is ON,
# niri suppresses idle events, so none of these timers fire.
#   10 min -> lock the screen
#   ~10 min -> turn the display off (comes back on when you return)
#   15 min -> suspend (guarded — see suspend-if-idle.sh)
#
# The suspend is routed through suspend-if-idle.sh instead of a bare
# `systemctl suspend`: niri flushes buffered idle events on UNLOCK, so a plain
# suspend timeout fires the instant you unlock and the machine sleeps in your
# face. The guard only suspends when the screen is genuinely idle-locked.
exec swayidle -w \
  timeout 600 "$HOME/.config/niri/lock.sh" \
  timeout 610 'niri msg action power-off-monitors' \
    resume 'niri msg action power-on-monitors' \
  timeout 900 "$HOME/.config/niri/suspend-if-idle.sh" \
  before-sleep "$HOME/.config/niri/lock.sh"
