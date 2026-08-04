#!/usr/bin/env bash
# Waybar module (polled): print the title of the window that THIS bar's monitor
# considers active, or the live hostname when there is none. Runs once and exits
# — no long-lived child process, so Waybar never blocks waiting on it.
#
# PER-MONITOR: Waybar runs one copy of a custom module per bar and hands its
# `exec` the monitor it is on in $WAYBAR_OUTPUT_NAME (the wl_output connector
# name, e.g. eDP-1 / HDMI-A-1 — the same string niri puts in a workspace's
# "output"). We scope to that monitor so each bar shows the window focused on its
# own screen, not the one globally focused. window-title-watch.sh pokes every bar
# (SIGRTMIN+9) on any focus/title change, so all monitors refresh together.
#
# This asks the WORKSPACE which window is active rather than asking which window
# holds keyboard focus. In the Overview nothing is focused, so
# `niri msg focused-window` answers "No window is focused" and the pill dropped
# back to the hostname the moment the Overview opened. Workspaces keep reporting
# active_window_id throughout. On this monitor we prefer the globally focused
# workspace (so the pill still follows the selection as it moves between
# workspaces inside the Overview) and otherwise take the monitor's active
# (visible) workspace — which is what the non-focused monitors always use.
#
# Parsed with grep/sed/awk because jq isn't installed. Workspace objects are
# flat, so splitting on `{...}` is safe; window objects are NOT (they nest a
# "layout" object), hence the plain-text `niri msg windows` for the title.

out="${WAYBAR_OUTPUT_NAME:-}"

# One workspace object per line.
ws=$(niri msg --json workspaces 2>/dev/null | grep -o '{[^{}]*}')

# Restrict to this bar's monitor when Waybar told us which one it is. -F: the
# output name is a literal, never a regex.
[ -n "$out" ] && ws=$(printf '%s\n' "$ws" | grep -F "\"output\":\"$out\"")

# Prefer the focused workspace on this monitor, else its active (visible) one.
sel=$(printf '%s\n' "$ws" | grep '"is_focused":true')
[ -z "$sel" ] && sel=$(printf '%s\n' "$ws" | grep '"is_active":true')

wid=$(printf '%s\n' "$sel" \
    | sed -n 's/.*"active_window_id":\([0-9]\+\).*/\1/p' \
    | head -n1)

title=""
if [ -n "$wid" ]; then
    title=$(niri msg windows 2>/dev/null | awk -v id="$wid" '
        # No end anchor: the focused entry is "Window ID 3: (focused)". The
        # trailing colon still prevents 3 from matching 30.
        $0 ~ "^Window ID " id ":" { found = 1; next }
        found && /^  Title: "/ {
            sub(/^  Title: "/, ""); sub(/"$/, "")
            print; exit
        }
        /^Window ID / { found = 0 }
    ')
fi

# Empty workspace, or niri not answering — fall back to the hostname.
[ -z "$title" ] && title=$(cat /proc/sys/kernel/hostname 2>/dev/null)

printf '%s\n' "$title"
