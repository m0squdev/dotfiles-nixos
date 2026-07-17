#!/usr/bin/env bash
# Volume control for the media keys, with on-screen + audible feedback.
#
# Primary path: SwayOSD (needs the `swayosd` package and `swayosd-server`
# running — spawned at niri startup). swayosd-client changes the volume AND
# draws the centered overlay in one call. If swayosd isn't available yet
# (e.g. before the nixos-rebuild that installs it) we fall back to the raw
# `wpctl` behaviour so the keys never stop working — same pattern as lock.sh.
#
# It also plays the freedesktop "volume-change" tick when the sound theme
# (sound-theme-freedesktop) is installed; silently skips it otherwise.
#
# Usage: volume.sh up | down | mute
set -u

SINK="@DEFAULT_AUDIO_SINK@"
STEP=5                  # percent per key press
TICK="/run/current-system/sw/share/sounds/freedesktop/stereo/audio-volume-change.oga"

have_osd() { command -v swayosd-client >/dev/null 2>&1; }
play_tick() { [ -f "$TICK" ] && pw-play --volume 0.4 "$TICK" >/dev/null 2>&1 & }

case "${1:-}" in
  up)
    if have_osd; then
      swayosd-client --output-volume "+${STEP}" --max-volume 100
    else
      wpctl set-volume "$SINK" 0.05+ -l 1.0
    fi
    play_tick
    ;;
  down)
    if have_osd; then
      swayosd-client --output-volume "-${STEP}"
    else
      wpctl set-volume "$SINK" 0.05-
    fi
    play_tick
    ;;
  mute)
    # Mute toggles the overlay's icon; no tick (a "muted" tick is contradictory).
    if have_osd; then
      swayosd-client --output-volume mute-toggle
    else
      wpctl set-mute "$SINK" toggle
    fi
    ;;
  *)
    echo "usage: $0 up|down|mute" >&2
    exit 2
    ;;
esac
