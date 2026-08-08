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
# TEST HOOK: export POWER_FAKE_CAPACITY (and optionally POWER_FAKE_STATUS /
# POWER_FAKE_AC, the latter 1 / 0 / none) to make a desktop render the laptop branch,
# and to drive plugged/unplugged without touching a cable. Kept deliberately — a
# desktop has no battery, so it is the only way to exercise that path, and the
# awkward states (full-but-unplugged, plugged-but-"Not charging") are impractical
# to reproduce by hand.

set -uo pipefail

# nf-md-battery ladders, 0..100 in tens. Same MDI family as the rest of the bar
# (the old built-in module used Font Awesome, which looked foreign next to it).
DISCHARGING=(󰂎 󰁺 󰁻 󰁼 󰁽 󰁾 󰁿 󰂀 󰂁 󰂂 󰁹)

# A small glyph PRECEDES the level ladder to signal state, instead of a dedicated
# combined icon. The old charging glyph (nf-md-battery-charging, 󰂄) crammed the
# bolt inside the battery and read poorly, so the level is always drawn from the
# ladder above and the state rides in front of it:
#   charging                 -> bolt      (BOLT)
#   discharging, Battery saver -> leaf    (LEAF)
#   discharging, Performance   -> rocket  (ROCKET)
#   discharging, Balanced      -> nothing (just the level)
# All nf-md, so they sit in the same family as the ladder. Exact % is in the
# tooltip either way.
BOLT=󱐋       # nf-md-lightning-bolt
LEAF=󰌪       # nf-md-leaf
ROCKET=󱓞     # nf-md-rocket-launch
POWER_GLYPH=󰐥

# Low-charge colours for the LEVEL glyph only (see cmd_status). These live here,
# not in style.css, because only part of the pill is tinted and a CSS class would
# reach the whole label — prefix included. Mirror the Catppuccin peach/red there.
COL_WARN='#fab387'   # <=30%
COL_CRIT='#f38ba8'   # <=15%

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

# --- AC adapter ---------------------------------------------------------------
# Echoes 1 (cable in), 0 (cable out), or nothing when the host exposes no mains
# adapter at all — is_plugged then falls back to the battery's own status.
read_ac() {
  # "none" fakes a host with no adapter at all — the fallback below is otherwise
  # unreachable on any machine that has one, cable in or out.
  if [ -n "${POWER_FAKE_AC:-}" ]; then
    [ "$POWER_FAKE_AC" = none ] || printf '%s' "$POWER_FAKE_AC"
    return 0
  fi

  local d kind found=''
  for d in /sys/class/power_supply/*; do
    [ -r "$d/type" ] && [ -r "$d/online" ] || continue
    kind=$(<"$d/type")
    # A USB-C / dock-charged laptop exposes its charging port as type=USB rather
    # than Mains, so both count — on those machines a Mains-only scan would find
    # no adapter and the cable would always look absent.
    [ "$kind" = "Mains" ] || [ "$kind" = "USB" ] || continue
    found=1
    [ "$(<"$d/online")" = "1" ] && { printf '1'; return 0; }
  done
  [ -n "$found" ] && printf '0'
  return 0
}

# Is the cable in? Takes the battery status ($1) only as a fallback.
#
# The battery's own status CANNOT answer this, which is what makes the adapter
# authoritative here rather than merely tidier:
#   - plugged and topped off  -> "Full", not "Charging"
#   - just UNplugged at 100%  -> still "Full", until the capacity ticks off 100
#   - plugged, held at a charge limit -> "Not charging"
# Keying the bolt off the status alone therefore drops it while it is still
# plugged, or strands it on after the cable is pulled. The adapter's online flag
# flips the instant the cable moves, so it wins whenever the host has one.
is_plugged() {
  local ac
  ac=$(read_ac)
  case "$ac" in
    1) return 0 ;;
    0) return 1 ;;
  esac

  # No adapter exposed — best effort from the status.
  case "$1" in
    Charging|Full|"Not charging") return 0 ;;
  esac
  return 1
}

# Active profile, or empty if power-profiles-daemon is absent. Read straight off
# D-Bus with busctl (a C tool from systemd, ~25ms) instead of `powerprofilesctl
# get` — the latter is a Python CLI that spends ~0.9s importing GLib and opening
# D-Bus on EVERY call. That delay is invisible on the 30s tooltip poll but very
# visible on the right-click menu, which called it before it could open fuzzel:
# the picker just hung for the best part of a second. net.hadess.PowerProfiles is
# PPD's long-standing well-known name (it now also claims the freedesktop.UPower
# one; either works). Output is `s "balanced"`, stripped to `balanced`.
active_profile() {
  busctl --system get-property net.hadess.PowerProfiles /net/hadess/PowerProfiles \
    net.hadess.PowerProfiles ActiveProfile 2>/dev/null \
    | sed -n 's/^s "\(.*\)"$/\1/p'
}

# Human label for a raw profile ($1), or empty for none — so cmd_status can read
# the profile once (it also needs the raw value to pick the discharging prefix)
# and pass it here instead of paying for a second active_profile call.
profile_label() {
  case "$1" in
    power-saver) printf 'Battery saver' ;;
    balanced)    printf 'Balanced' ;;
    performance) printf 'Performance' ;;
    '')          printf '' ;;
    *)           printf '%s' "$1" ;;
  esac
}

# --- subcommands --------------------------------------------------------------
cmd_status() {
  local bat capacity status idx glyph class label tooltip prof prefix lvl
  if ! bat=$(read_battery); then
    # Desktop. No "tooltip" key at all — Waybar leaves tooltip_ empty and shows
    # nothing, rather than falling back to the glyph.
    printf '{"text":"%s","class":"power"}\n' "$POWER_GLYPH"
    return 0
  fi
  # Split on the FIRST space only: the status can itself be two words ("Not
  # charging", reported when the battery is held at a charge limit), so a
  # single-% strip would leave "Not" glued to the capacity and the arithmetic
  # below would blow up under `set -u`.
  capacity=${bat%% *}
  status=${bat#* }

  idx=$(( (capacity + 5) / 10 ))
  [ "$idx" -gt 10 ] && idx=10
  [ "$idx" -lt 0 ] && idx=0

  # Read the profile once — it drives both the discharging prefix and the tooltip.
  prof=$(active_profile)

  if is_plugged "$status"; then
    # Bolt in front of the current level, instead of the cramped combined glyph.
    # Cable in is cable in whether the pack is filling or already full, so the
    # bolt stays put at 100% rather than vanishing the moment it tops off.
    glyph="${BOLT} ${DISCHARGING[$idx]}"
    class=charging
  else
    # On battery. Front the level with the profile's glyph (trailing space folded
    # in so Balanced — empty prefix — draws the bare level with no stray leading
    # space).
    case "$prof" in
      power-saver) prefix="$LEAF " ;;
      performance) prefix="$ROCKET " ;;
      *)           prefix="" ;;
    esac
    # Tint ONLY the level glyph on a low charge — never the mode prefix, so a
    # red battery still reads as "low" while the leaf/rocket keeps its meaning.
    # CSS can't colour half a label, so it rides inline as a Pango span; the
    # single-quoted attribute keeps the JSON below valid without escaping.
    lvl=${DISCHARGING[$idx]}
    if   [ "$capacity" -le 15 ]; then lvl="<span foreground='$COL_CRIT'>$lvl</span>"
    elif [ "$capacity" -le 30 ]; then lvl="<span foreground='$COL_WARN'>$lvl</span>"
    fi
    glyph="${prefix}${lvl}"
    class=battery
  fi

  # "Balanced  ·  72%" — subject then value, matching every other pill. If
  # power-profiles-daemon isn't answering, say so outright rather than quietly
  # dropping the segment: a tooltip that reads "Unknown power mode" is a visible
  # signal that something is broken.
  label=$(profile_label "$prof")
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
  current=$(active_profile)
  [ -z "$current" ] && exit 0

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
