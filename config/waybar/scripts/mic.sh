#!/usr/bin/env bash
# Microphone module for waybar (PipeWire/wpctl).
#   status -> JSON {text, class, tooltip} for the default source
#   toggle -> mute/unmute the default source, then refresh the module
MIC_ON=$(printf '\U000F036C')   # 󰍬 microphone
MIC_OFF=$(printf '\U000F036D')  # 󰍭 microphone-off
src='@DEFAULT_AUDIO_SOURCE@'

case "${1:-status}" in
  toggle)
    wpctl set-mute "$src" toggle
    pkill -RTMIN+8 waybar 2>/dev/null   # instant refresh (module uses signal 8)
    ;;
  *)
    vol=$(wpctl get-volume "$src" 2>/dev/null)   # "Volume: 1.00" [ MUTED ]
    if printf '%s' "$vol" | grep -q MUTED; then
      printf '{"text":"%s","class":"muted","tooltip":"Microphone muted"}\n' "$MIC_OFF"
    else
      pct=$(printf '%s' "$vol" | awk '{printf "%d", $2*100}')
      printf '{"text":"%s","class":"active","tooltip":"Microphone %s%%"}\n' "$MIC_ON" "$pct"
    fi
    ;;
esac
