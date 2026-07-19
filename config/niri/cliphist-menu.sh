#!/usr/bin/env bash
# Clipboard history picker for niri — bound to Mod+V.
#
# Lists cliphist's stored history in fuzzel's dmenu mode and copies the chosen entry
# back onto the Wayland clipboard, ready to paste with Ctrl+V (Ctrl+Shift+V in a
# terminal). History is recorded by the `wl-paste --watch cliphist store` daemon
# started in config.kdl. Needs the cliphist and wl-clipboard packages.

# `cliphist list` emits "ID<tab>preview" columns; --with-nth=2 shows only the preview
# (hiding the numeric ID and the tab gap), while fuzzel still returns the FULL line on
# selection so `cliphist decode` can look the entry up by its ID.
#
# Cancelling fuzzel (Esc) or an empty pick must NOT reach wl-copy, or it would wipe
# the current clipboard.
sel="$(cliphist list | fuzzel --dmenu --with-nth=2 --prompt 'Clipboard > ')" || exit 0
[ -n "$sel" ] || exit 0
cliphist decode <<< "$sel" | wl-copy
