#!/usr/bin/env bash
# Independent listener for the Waybar custom/window module. On every niri
# focus/title change it pokes Waybar (SIGRTMIN+9) so the title refreshes
# instantly. Runs as a child of niri (spawn-at-startup), never a child of Waybar,
# so Waybar never blocks waiting on it.
#
# CRITICAL: an RT signal delivered to Waybar BEFORE it installs its signal
# handlers (e.g. during the login event storm) hits the default action for
# SIGRTMIN+9 = TERMINATE, and kills the bar. So we only signal a Waybar process
# whose /proc/<pid>/status SigCgt mask shows it is already catching that signal
# (bit 42). During Waybar's brief startup the bit is unset and we simply skip.

SIG=9                     # module "signal": 9  ->  SIGRTMIN+9 = signal 43
BIT=$(( 34 + SIG - 1 ))   # 0-based bit index in the SigCgt hex mask = 42

# Single instance: hold an exclusive lock; if another copy already holds it, exit
# quietly. (Never pkill-by-name here — that can hit unrelated processes whose
# command line merely mentions this script, e.g. a shell inspecting it.) The lock
# releases automatically when the holder dies; the runtime dir is per-session.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/waybar-window-title-watch.lock" 2>/dev/null
flock -n 9 2>/dev/null || exit 0

# True only if pid $1 is currently catching SIGRTMIN+9 (handler installed).
catches_sig() {
    local cgt idx ch
    cgt=$(awk '/^SigCgt:/{print $2}' "/proc/$1/status" 2>/dev/null) || return 1
    [ -n "$cgt" ] || return 1
    idx=$(( ${#cgt} - 1 - BIT / 4 ))
    [ "$idx" -ge 0 ] || return 1
    ch=${cgt:idx:1}
    (( (16#$ch >> (BIT % 4)) & 1 ))
}

poke() {
    local p
    for p in $(pgrep waybar); do
        catches_sig "$p" && kill "-RTMIN+$SIG" "$p" 2>/dev/null
    done
}

while true; do
    poke
    niri msg --json event-stream 2>/dev/null | while IFS= read -r line; do
        case "$line" in
            *WindowFocusChanged*|*WindowOpenedOrChanged*|*WindowClosed*|*WindowsChanged*)
                poke ;;
        esac
    done
    # Stream ended (e.g. niri restarted) — wait briefly, then reconnect.
    sleep 2
done
