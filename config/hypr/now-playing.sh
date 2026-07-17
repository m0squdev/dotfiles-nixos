#!/usr/bin/env bash
# Feeds the hyprlock now-playing label (see ~/.config/hypr/hyprlock.conf).
#
# hyprlock renders its built-in "Sample Text" placeholder whenever a label's
# resolved text is empty OR whitespace-only. A bare " " therefore doesn't help
# (it gets trimmed back to empty). So when nothing is playing we print a
# zero-width space (U+200B): non-empty and not whitespace, but invisible.
line=$(playerctl metadata --format '󰝚 {{markup_escape(artist)}} — {{markup_escape(title)}}' 2>/dev/null)
if [ -n "$line" ]; then
  printf '%s' "$line"
else
  printf '​'
fi
