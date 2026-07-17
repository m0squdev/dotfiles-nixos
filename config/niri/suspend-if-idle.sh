#!/usr/bin/env bash
# Guarded suspend for swayidle's 15-min idle timeout.
#
# WHY THIS EXISTS:
# niri buffers ext-idle-notify events while an ext-session-lock is held and
# flushes them the moment you UNLOCK. So swayidle's `timeout 900 systemctl
# suspend` is delivered the instant you type your password and unlock — the
# screen re-locks (before-sleep) and the machine suspends in your face, even
# though you just sat back down. (See niri idle/lock-boundary behaviour.)
#
# Guard against that: only suspend when the screen is *actually* locked AND the
# lock is old enough to be a real 10-min idle-lock rather than a stale flush
# that just re-locked. The genuine path locks at 10 min and suspends at 15 min,
# so at suspend time the locker has been up ~5 min; a spurious flush re-lock is
# only seconds old.

locker_pid=$(pgrep -x hyprlock | head -n1)
[ -z "$locker_pid" ] && locker_pid=$(pgrep -x swaylock | head -n1)

# Not locked -> this is a stale idle event flushed after you unlocked. Skip.
[ -z "$locker_pid" ] && exit 0

# Locked, but for how long? etimes = seconds since the locker started.
locked_secs=$(ps -o etimes= -p "$locker_pid" 2>/dev/null | tr -d ' ')
[ -z "$locked_secs" ] && exit 0

# Freshly (re)locked -> not a genuine 15-min idle. The real gap between the
# 10-min lock and the 15-min suspend is 300s, so anything under 120s is a flush.
[ "$locked_secs" -lt 120 ] && exit 0

exec systemctl suspend
