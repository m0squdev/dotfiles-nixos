#!/usr/bin/env bash
# The right-hand power pill — ONE module for both host types, so neither host
# carries an icon that means nothing to it:
#
#   desktop (no battery)  󰐥            no tooltip    right-click does nothing
#   laptop  (battery)     charge glyph  "72%  ·  Balanced"
#                                       right-click = power-mode picker
#
# Usage: power.sh {status|mode-menu}
#   status     -> Waybar JSON for the module (return-type: json)
#   mode-menu  -> fuzzel power-profile picker (on-click-right)
#
# Left-click stays powermenu.sh (lock/logout/suspend/reboot/shutdown) on both.
#
# TEST HOOK: export POWER_FAKE_CAPACITY (and optionally POWER_FAKE_STATUS) to
# make a desktop render the laptop branch. Kept deliberately — this machine has
# no battery, so it is the only way to exercise that path.

set -uo pipefail

# nf-md-battery ladders, 0..100 in tens. Same MDI family as the rest of the bar
# (the old built-in module used Font Awesome, which looked foreign next to it).
DISCHARGING=(󰂎 󰁺 󰁻 󰁼 󰁽 󰁾 󰁿 󰂀 󰂁 󰂂 󰁹)
# Charging is a single glyph, not a ladder: nf-md-battery-charging is the only
# one in this font with the bolt INSIDE the battery — the graded
# battery-charging-low/medium/high all hang the bolt off the right edge, which
# reads badly next to the other pills. Exact level is in the tooltip.
CHARGING=󰂄
POWER_GLYPH=󰐥

# --- battery discovery --------------------------------------------------------
# Skips peripheral batteries: a wireless mouse or headset also shows up under
# /sys/class/power_supply with type=Battery, but carries scope=Device.
find_battery() {
  local d
  for d in /sys/class/power_supply/*; do
    [ -r "$d/type" ] || continue
    [ "$(<"$d/type")" = "Battery" ] || continue
    [ -r "$d/scope" ] && [ "$(<"$d/scope")" = "Device" ] && continue
    printf '%s' "$d"
    return 0
  done
  return 1
}

# Echoes "<capacity> <status>", or returns 1 when there is no system battery.
read_battery() {
  if [ -n "${POWER_FAKE_CAPACITY:-}" ]; then
    printf '%s %s' "$POWER_FAKE_CAPACITY" "${POWER_FAKE_STATUS:-Discharging}"
    return 0
  fi

  local bat cap
  bat=$(find_battery) || return 1

  if [ -r "$bat/capacity" ]; then
    cap=$(<"$bat/capacity")
  elif [ -r "$bat/energy_now" ] && [ -r "$bat/energy_full" ]; then
    cap=$(( 100 * $(<"$bat/energy_now") / $(<"$bat/energy_full") ))
  elif [ -r "$bat/charge_now" ] && [ -r "$bat/charge_full" ]; then
    cap=$(( 100 * $(<"$bat/charge_now") / $(<"$bat/charge_full") ))
  else
    return 1
  fi

  local status=Unknown
  [ -r "$bat/status" ] && status=$(<"$bat/status")
  printf '%s %s' "$cap" "$status"
}

# Current profile as a human label, or empty if power-profiles-daemon is absent
# (better to drop the segment than to assert a profile that may not be active).
profile_label() {
  case "$(powerprofilesctl get 2>/dev/null)" in
    power-saver) printf 'Battery saver' ;;
    balanced)    printf 'Balanced' ;;
    performance) printf 'Performance' ;;
    '')          printf '' ;;
    *)           powerprofilesctl get 2>/dev/null ;;
  esac
}

# --- subcommands --------------------------------------------------------------
cmd_status() {
  local bat capacity status idx glyph class label tooltip
  if ! bat=$(read_battery); then
    # Desktop. No "tooltip" key at all — Waybar leaves tooltip_ empty and shows
    # nothing, rather than falling back to the glyph.
    printf '{"text":"%s","class":"power"}\n' "$POWER_GLYPH"
    return 0
  fi
  capacity=${bat% *}
  status=${bat#* }

  idx=$(( (capacity + 5) / 10 ))
  [ "$idx" -gt 10 ] && idx=10
  [ "$idx" -lt 0 ] && idx=0

  case "$status" in
    Charging)
      glyph=$CHARGING; class=charging ;;
    Full)
      glyph=${DISCHARGING[10]}; class=battery ;;
    *)
      # Discharging, "Not charging" (held at a charge limit), Unknown
      glyph=${DISCHARGING[$idx]}
      if   [ "$capacity" -le 15 ]; then class=critical
      elif [ "$capacity" -le 30 ]; then class=warning
      else                              class=battery
      fi ;;
  esac

  # "Balanced  ·  72%" — subject then value, matching every other pill. If
  # power-profiles-daemon isn't answering, say so outright rather than quietly
  # dropping the segment: a tooltip that reads "Unknown power mode" is a visible
  # signal that something is broken.
  label=$(profile_label)
  [ -z "$label" ] && label="Unknown power mode"
  tooltip="${label}  ·  ${capacity}%"

  printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' "$glyph" "$tooltip" "$class"
}

# Active profile is flagged with a leading "●  ", the others padded to match so
# the labels line up — same convention as bt-menu.sh and wifi-menu.sh.
cmd_mode_menu() {
  # Laptops only: on a desktop the pill is a plain power button.
  read_battery >/dev/null || exit 0

  local current chosen
  current=$(powerprofilesctl get 2>/dev/null) || exit 0

  row() { [ "$1" = "$current" ] && printf '●  %s\n' "$2" || printf '   %s\n' "$2"; }

  chosen=$( { row power-saver "Battery saver"
              row balanced    "Balanced"
              row performance "Performance"; } \
    | fuzzel --dmenu --prompt "Power mode > " --lines 3 --width 20)

  [ -z "$chosen" ] && exit 0

  # Strip the leading "●  " / "   " marker to recover the plain label.
  case "$(printf '%s' "$chosen" | sed -E 's/^● +//; s/^ +//')" in
    "Battery saver") powerprofilesctl set power-saver ;;
    "Balanced")      powerprofilesctl set balanced ;;
    "Performance")   powerprofilesctl set performance ;;
    *) exit 0 ;;
  esac

  # Repaint the pill now instead of waiting out the poll interval.
  pkill -RTMIN+10 -x .waybar-wrapped
}

case "${1:-status}" in
  status)    cmd_status ;;
  mode-menu) cmd_mode_menu ;;
  *) echo "usage: $0 {status|mode-menu}" >&2; exit 1 ;;
esac
