#!/usr/bin/env bash
# Waybar: right-click the window title (custom/window's on-click-right) to open a
# fuzzel menu of the FOCUSED app's desktop actions — the "jump-list" entries you'd
# get from right-clicking its icon on a dock (New Window, New Private Window, ...).
#
# Flow: focused app_id (niri IPC, same plain-text parse as window-title.sh)
#   -> its .desktop file (searched across the XDG data dirs)
#   -> the [Desktop Action *] Name/Exec pairs
#   -> fuzzel -> spawn the chosen action's command, detached, via niri.
# No jq needed: niri's text output and the desktop file are parsed with sed/awk.

set -u

menu() { fuzzel --dmenu "$@"; }   # Catppuccin Mocha look comes from fuzzel.ini

# 1. Focused window's app_id (empty when nothing is focused).
app_id=$(niri msg focused-window 2>/dev/null \
    | sed -n 's/^  App ID: "\(.*\)"$/\1/p' | head -n1)

if [ -z "$app_id" ]; then
    printf '%s\n' "(no window focused)" | menu --prompt "Actions > " --lines 1 --width 34 >/dev/null
    exit 0
fi

# 2. Locate the .desktop file for this app_id: exact id, then case-insensitive,
#    then a StartupWMClass match (covers apps whose id != desktop file name).
IFS=: read -r -a data_dirs <<< "${XDG_DATA_HOME:-$HOME/.local/share}:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

desktop=""
for d in "${data_dirs[@]}"; do
    [ -f "$d/applications/${app_id}.desktop" ] && { desktop="$d/applications/${app_id}.desktop"; break; }
done
if [ -z "$desktop" ]; then
    for d in "${data_dirs[@]}"; do
        desktop=$(find "$d/applications" -maxdepth 1 -iname "${app_id}.desktop" 2>/dev/null | head -n1)
        [ -n "$desktop" ] && break
    done
fi
if [ -z "$desktop" ]; then
    for d in "${data_dirs[@]}"; do
        desktop=$(grep -rils "^StartupWMClass=${app_id}$" "$d/applications" 2>/dev/null | head -n1)
        [ -n "$desktop" ] && break
    done
fi

if [ -z "$desktop" ]; then
    printf '%s\n' "(no .desktop file for $app_id)" | menu --prompt "$app_id > " --lines 1 --width 44 >/dev/null
    exit 0
fi

# 3. Human-readable app name (the [Desktop Entry] Name=, e.g. "Zen Browser" for
#    app_id zen-beta) for the prompt — same label fuzzel's launcher shows. The
#    main Name= comes before any [Desktop Action *] block; fall back to app_id.
app_name=$(awk '
    /^\[Desktop Entry\]/ { inentry=1; next }
    /^\[/                { inentry=0 }
    inentry && /^Name=/  { print substr($0, 6); exit }
' "$desktop")
[ -z "$app_name" ] && app_name="$app_id"

# 4. Collect the app's desktop actions as  Name<TAB>Exec  lines, in the ORDER the
#    [Desktop Entry] Actions= key declares (the spec's canonical order) — NOT the
#    order the [Desktop Action *] blocks happen to sit in the file. Name and Exec
#    can appear in either order within a block. Falls back to block order if the
#    file has no Actions= key.
actions=$(awk '
    /^\[Desktop Entry\]/ { sect="entry"; next }
    /^\[Desktop Action / {
        id=$0; sub(/^\[Desktop Action /, "", id); sub(/\][ \t]*$/, "", id)
        sect="action"; cur=id; blocks[++nb]=id; next
    }
    /^\[/ { sect="other"; next }
    sect=="entry"  && index($0, "Actions=")==1 { order=substr($0, 9) }   # after "Actions="
    sect=="action" && /^Name=/ { name[cur]=substr($0, 6) }
    sect=="action" && /^Exec=/ { exec[cur]=substr($0, 6) }
    END {
        if (order != "") n=split(order, ids, ";")
        else { n=nb; for (i=1; i<=nb; i++) ids[i]=blocks[i] }
        for (i=1; i<=n; i++) {
            id=ids[i]
            if (id != "" && (id in name) && name[id] != "" && exec[id] != "")
                print name[id] "\t" exec[id]
        }
    }
' "$desktop")

if [ -z "$actions" ]; then
    printf '%s\n' "(no actions for $app_name)" | menu --prompt "$app_name > " --lines 1 --width 44 >/dev/null
    exit 0
fi

# 5. Pick one. --with-nth 1 shows only the Name; fuzzel still returns the whole
#    Name<TAB>Exec line (see cliphist-menu.sh), so the command is field 2 onward.
lines=$(printf '%s\n' "$actions" | wc -l)
chosen=$(printf '%s\n' "$actions" | menu --with-nth 1 --prompt "$app_name > " --lines "$lines" --width 44)
[ -z "$chosen" ] && exit 0

# 6. Strip desktop-entry field codes (%u %U %f %F ...) and spawn detached via niri
#    (so the launched app is a child of niri, not of Waybar's click handler).
cmd=$(printf '%s' "$chosen" | cut -f2- | sed -E 's/ ?%[fFuUdDnNickvm]//g')
[ -z "$cmd" ] && exit 0
niri msg action spawn -- sh -c "$cmd" >/dev/null 2>&1
