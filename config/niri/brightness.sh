#!/usr/bin/env bash
# Backlight control for the media keys, with on-screen feedback.
#
# Primary path: SwayOSD (needs the `swayosd` package and `swayosd-server`
# running — spawned at niri startup). swayosd-client changes the brightness AND
# draws the centered overlay in one call. If swayosd isn't available yet
# (e.g. before the nixos-rebuild that installs it) we fall back to the raw
# `brightnessctl` behaviour so the keys never stop working — same pattern as
# volume.sh.
#
# Usage: brightness.sh up | down
set -u

STEP=10                  # percent per key press

have_osd() { command -v swayosd-client >/dev/null 2>&1; }

case "${1:-}" in
  up)
    if have_osd; then
      swayosd-client --brightness "+${STEP}"
    else
      brightnessctl --class=backlight set "+${STEP}%"
    fi
    ;;
  down)
    if have_osd; then
      swayosd-client --brightness "-${STEP}"
    else
      brightnessctl --class=backlight set "${STEP}%-"
    fi
    ;;
  *)
    echo "usage: $0 up|down" >&2
    exit 2
    ;;
esac
