#!/usr/bin/env bash
# Waybar drawer handle: show the collapse "dots" icon only when the tray actually
# has items (background apps with a StatusNotifier/appindicator icon). Otherwise
# print nothing so Waybar hides the handle. Polled, so it follows apps coming and
# going. Waybar is the StatusNotifierWatcher, so we read the item count off D-Bus.

items=$(busctl --user get-property \
    org.kde.StatusNotifierWatcher /StatusNotifierWatcher \
    org.kde.StatusNotifierWatcher RegisteredStatusNotifierItems 2>/dev/null)

# Format is: as <count> "item1" "item2" ...   (e.g. "as 0" when empty)
count=$(printf '%s' "$items" | awk '{print $2}')

if [ "${count:-0}" -gt 0 ] 2>/dev/null; then
    printf '\U000F01D8\n'   # dots-horizontal glyph
else
    printf '\n'            # empty -> Waybar hides the module
fi
