#!/usr/bin/env bash
# Waybar custom/window module — LIVE streaming producer. Prints the title of the
# window active on THIS bar's monitor, then RE-prints it on every niri
# focus/title/workspace change. Waybar runs one copy of the module's `exec` per
# bar and repaints the pill the instant a new line arrives on stdout — so the
# title is genuinely live, with no polling and no signals.
#
# This REPLACES the old design (one-shot script + "signal": 9 + a separate
# window-title-watch.sh that poked Waybar with SIGRTMIN+9). That poke path was
# fragile: it had to gate on Waybar's signal mask, RT signals could be dropped
# during event bursts, and it desynced across Waybar restarts. A streaming exec
# is the idiomatic Waybar pattern and has none of that — Waybar reads this stdout
# asynchronously on its own thread, so a long-lived child never blocks it.
#
# PER-MONITOR: Waybar hands each bar's `exec` the output it is on in
# $WAYBAR_OUTPUT_NAME (the wl_output connector, e.g. eDP-1 / HDMI-A-1 — the same
# string niri puts in a workspace's "output"). We scope to it so each bar shows
# the window focused on its own screen, not the globally focused one.
#
# We ask the WORKSPACE which window is active rather than which window holds
# keyboard focus: in the Overview nothing is focused, so `niri msg
# focused-window` answers "No window is focused" and the pill would drop to the
# hostname the moment the Overview opened. Workspaces keep reporting
# active_window_id throughout. On this monitor we prefer the globally focused
# workspace (so the pill follows the selection as it moves between workspaces in
# the Overview) and otherwise take the monitor's active (visible) workspace.
#
# Parsed with grep/sed/awk because jq isn't installed. Workspace objects are flat
# so splitting on {...} is safe; window objects nest a "layout" object, hence the
# plain-text `niri msg windows` for the title.

out="${WAYBAR_OUTPUT_NAME:-}"

emit() {
    local ws sel wid title

    # One workspace object per line, optionally restricted to this bar's monitor.
    # -F: the output name is a literal, never a regex.
    ws=$(niri msg --json workspaces 2>/dev/null | grep -o '{[^{}]*}')
    [ -n "$out" ] && ws=$(printf '%s\n' "$ws" | grep -F "\"output\":\"$out\"")

    # Prefer the focused workspace on this monitor, else its active (visible) one.
    sel=$(printf '%s\n' "$ws" | grep '"is_focused":true')
    [ -z "$sel" ] && sel=$(printf '%s\n' "$ws" | grep '"is_active":true')

    wid=$(printf '%s\n' "$sel" \
        | sed -n 's/.*"active_window_id":\([0-9]\+\).*/\1/p' | head -n1)

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
}

# Print once up front, then on every relevant niri event. If the stream ends
# (niri restarted), wait briefly and reconnect.
#
# WorkspaceActiveWindowChanged is what keeps the pill live while the Overview is
# open: moving between WINDOWS of one workspace in there fires ONLY that event —
# no WindowFocusChanged (nothing holds keyboard focus in the Overview). Note
# *WorkspaceActivated* does NOT cover it: this event reads "WorkspaceActive" +
# "WindowChanged".
while true; do
    emit
    niri msg --json event-stream 2>/dev/null | while IFS= read -r line; do
        case "$line" in
            *WindowFocusChanged*|*WindowOpenedOrChanged*|*WindowClosed*|*WindowsChanged*|\
            *WorkspaceActivated*|*WorkspacesChanged*|*WorkspaceActiveWindowChanged*|\
            *OverviewOpenedOrClosed*)
                emit ;;
        esac
    done
    sleep 1
done
