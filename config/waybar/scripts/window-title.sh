#!/usr/bin/env bash
# Waybar module (polled): print the title of the window the focused workspace
# considers active, or the live hostname when there is none. Runs once and exits
# — no long-lived child process, so Waybar never blocks waiting on it.
#
# This asks the WORKSPACE which window is active rather than asking which window
# holds keyboard focus. In the Overview nothing is focused, so
# `niri msg focused-window` answers "No window is focused" and the pill dropped
# back to the hostname the moment the Overview opened. Workspaces keep reporting
# active_window_id throughout, and moving between workspaces inside the Overview
# changes which workspace is focused — so the title follows the selection
# instead of blanking out.
#
# Parsed with grep/sed/awk because jq isn't installed. Workspace objects are
# flat, so splitting on `{...}` is safe; window objects are NOT (they nest a
# "layout" object), hence the plain-text `niri msg windows` for the title.

wid=$(niri msg --json workspaces 2>/dev/null \
    | grep -o '{[^{}]*}' \
    | grep '"is_focused":true' \
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
