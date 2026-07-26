#!/usr/bin/env bash
# Lock the screen once, and do NOT return until the lock has actually taken hold.
# Primary locker is hyprlock (Catppuccin Mocha theme via ~/.config/hypr/hyprlock.conf).
# If hyprlock isn't available yet (e.g. before the nixos-rebuild that installs it),
# fall back to swaylock so the screen still locks. Never stack lockers.
#
# WHY THE WAIT EXISTS — this is the fix for "wakes to an unlocked desktop":
# swayidle runs `before-sleep` with -w, holding a logind delay inhibitor until this
# script exits. The old version launched `hyprlock &` and returned instantly, so
# logind began suspending in the SAME MILLISECOND that hyprlock was still bringing
# up its EGL context and lock surfaces:
#   15:15:19.363  niri: locking session      <- hyprlock grabbed the lock
#   15:15:19      PM: suspend entry (deep)   <- same second, still initialising
# On resume hyprlock met a DRM page flip it couldn't satisfy ("Page flip commit
# failed ... Permission denied") and bailed out. Rather than leave you locked out of
# a session it couldn't draw on, it sent unlock_and_destroy, and niri unlocked
# 30 microseconds after that page-flip error, with no password ever entered
# (zero PAM auth events in the journal for the whole boot).
#
# Note niri was NOT at fault and must not be "fixed" here: per ext-session-lock-v1
# and niri's own security model, a locker that merely DIES leaves the session locked
# behind a solid red screen. niri only unlocks when the locker explicitly asks, so
# the unlock request came from hyprlock giving up.
#
# Hence: block until logind's LockedHint flips to yes, which niri sets once the
# ext-session-lock is genuinely in effect. That's a real state signal, not a sleep,
# and it means the machine physically cannot enter S3 before the screen is locked.
# The wait is bounded (~3s) to stay under logind's InhibitDelayMaxSec (5s default),
# so this can never be the reason a suspend stalls.
set -u

LOG="${XDG_CACHE_HOME:-$HOME/.cache}/niri/hyprlock.log"

# hyprlock's own output is otherwise lost: niri's spawn-at-startup discards stdout
# for the children it spawns, so everything hyprlock logged through
# niri -> idle.sh(swayidle) -> lock.sh went to /dev/null. Keep it on disk so the
# next lock failure is diagnosable instead of invisible.
mkdir -p "$(dirname "$LOG")"

locked() {
  [ "$(loginctl show-session "${XDG_SESSION_ID:-}" -p LockedHint --value 2>/dev/null)" = "yes" ]
}

# Already locked? Nothing to do — and don't stack a second locker on top.
locked && exit 0

if ! pgrep -x hyprlock >/dev/null && ! pgrep -x swaylock >/dev/null; then
  printf '\n===== %s : lock.sh starting locker =====\n' "$(date -Is)" >>"$LOG"
  if command -v hyprlock >/dev/null 2>&1; then
    # --immediate-render paints the background without waiting on resources, which
    # shrinks the half-initialised window this whole script exists to close.
    hyprlock --immediate-render >>"$LOG" 2>&1 &
  else
    swaylock -f >>"$LOG" 2>&1 &
  fi
  disown 2>/dev/null || true
fi

# Bounded wait for the lock to genuinely take effect (3s max, 50ms granularity).
for _ in $(seq 1 60); do
  locked && exit 0
  sleep 0.05
done

printf '%s : WARNING lock.sh gave up waiting — LockedHint never became yes\n' \
  "$(date -Is)" >>"$LOG"
exit 0
