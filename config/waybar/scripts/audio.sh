#!/usr/bin/env bash
# Output/volume module for waybar (PipeWire/wpctl) — the speaker pill.
#   status -> JSON {text, class, tooltip} for the default sink
#   toggle -> mute/unmute the default sink, then refresh the module
#
# This replaces the BUILT-IN "pulseaudio" module. The only reason: the built-in
# module's tooltip can show at most {desc} — the sink's port description, e.g.
# "Built-in Audio Analog Stereo" — which differs from the right-click output
# picker's card name "Built-in Audio". A custom module lets the tooltip reuse
# audio-switch.sh's card-name label, so the tooltip shows "Built-in Audio · 40%".
sink='@DEFAULT_AUDIO_SINK@'
ICON='󰕾'       # volume-high  (same glyph as the old format-icons default)
ICON_MUTED='󰸈' # volume-muted (same glyph as the old format-muted)

case "${1:-status}" in
  toggle)
    wpctl set-mute "$sink" toggle
    pkill -RTMIN+11 waybar 2>/dev/null   # instant refresh (module uses signal 11)
    ;;
  *)
    # Card name (the part before "·" in the output picker), e.g. "Built-in Audio".
    # Falls back to the sink's node.description, then a literal.
    desc=$(/home/valer/.config/waybar/scripts/audio-switch.sh label sink 2>/dev/null)
    [ -z "$desc" ] && desc=$(wpctl inspect "$sink" 2>/dev/null \
      | sed -n 's/.*node\.description = "\(.*\)"/\1/p' | head -1)
    [ -z "$desc" ] && desc=Speakers

    vol=$(wpctl get-volume "$sink" 2>/dev/null)   # "Volume: 0.45" [ MUTED ]
    if printf '%s' "$vol" | grep -q MUTED; then
      printf '{"text":"%s","class":"muted","tooltip":"%s  ·  muted"}\n' "$ICON_MUTED" "$desc"
    else
      pct=$(printf '%s' "$vol" | awk '{printf "%d", $2*100}')
      printf '{"text":"%s","tooltip":"%s  ·  %s%%"}\n' "$ICON" "$desc" "$pct"
    fi
    ;;
esac
