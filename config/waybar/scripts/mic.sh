#!/usr/bin/env bash
# Microphone module for waybar (PipeWire/wpctl).
#   status -> JSON {text, class, tooltip} for the default source
#   toggle -> mute/unmute the default source, then refresh the module
#
# The pill only appears while something is actually recording, like GNOME's
# recording indicator — an idle mic is not worth a permanent slot on the bar.
MIC_ON=$(printf '\U000F036C')   # 󰍬 microphone
MIC_OFF=$(printf '\U000F036D')  # 󰍭 microphone-off
src='@DEFAULT_AUDIO_SOURCE@'

# PipeWire keeps a source node "suspended" until a client opens it for capture,
# and flips it to "running" for as long as one is reading. That is the closest
# thing to "an app is using the mic" that doesn't need a long-lived watcher —
# and this module must not spawn one, since a custom module that keeps a child
# alive hangs Waybar's main loop.
#
# Scoped to the DEFAULT source, matching the rest of this module (mute, volume
# and the right-click switcher all act on @DEFAULT_AUDIO_SOURCE@). An app
# recording from some other source won't light the pill.
mic_in_use() {
  local id state
  id=$(wpctl inspect "$src" 2>/dev/null | awk 'NR==1 {gsub(/,/, "", $2); print $2}')
  [ -n "$id" ] || return 1
  state=$(pw-cli info "$id" 2>/dev/null | awk -F'"' '/state:/ {print $2; exit}')
  [ "$state" = "running" ]
}

case "${1:-status}" in
  toggle)
    wpctl set-mute "$src" toggle
    pkill -RTMIN+8 waybar 2>/dev/null   # instant refresh (module uses signal 8)
    ;;
  *)
    # Nothing recording -> empty text, which hides the module entirely.
    if ! mic_in_use; then
      printf '{"text":""}\n'
      exit 0
    fi

    # Device name, mirroring {desc} on the volume pill. node.description is the
    # human-readable one ("USB Camera Mono"); fall back if it's ever missing.
    desc=$(wpctl inspect "$src" 2>/dev/null \
      | sed -n 's/.*node\.description = "\(.*\)"/\1/p' | head -1)
    [ -z "$desc" ] && desc=Microphone

    vol=$(wpctl get-volume "$src" 2>/dev/null)   # "Volume: 1.00" [ MUTED ]
    if printf '%s' "$vol" | grep -q MUTED; then
      printf '{"text":"%s","class":"muted","tooltip":"%s  ·  muted"}\n' "$MIC_OFF" "$desc"
    else
      pct=$(printf '%s' "$vol" | awk '{printf "%d", $2*100}')
      printf '{"text":"%s","class":"active","tooltip":"%s  ·  %s%%"}\n' "$MIC_ON" "$desc" "$pct"
    fi
    ;;
esac
