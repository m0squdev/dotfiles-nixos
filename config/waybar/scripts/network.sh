#!/usr/bin/env bash
# Waybar custom/network module — replaces the built-in "network" module.
#
# WHY A SCRIPT: Waybar's built-in network module (v0.15) has no
# internet-reachability check — its "linked" state only means "carrier up, no
# IP", NOT "has an IP but no working internet" — and it has no "connecting"
# state at all. NetworkManager knows both, so we drive the pill from nmcli:
#   * `nmcli networking connectivity`  → full | limited | portal | none | unknown
#   * the Wi-Fi device STATE           → connected | connecting | disconnected | …
#
# STATE → icon / CSS class (colours + the connecting blink live in style.css):
#   ethernet connected     $ICON_ETH    .ethernet
#   Wi-Fi radio off        $ICON_OFF    .disabled      (grey)
#   Wi-Fi connecting       $ICON_WIFI   .connecting    (blinks white/grey)
#   Wi-Fi up, internet ok  $ICON_WIFI   .connected
#   Wi-Fi up, no internet  $ICON_ALERT  .no-internet
#   Wi-Fi up, no network   $ICON_OFF    .disconnected  (same glyph as radio-off,
#                                                        told apart by colour)
#
# The glyphs below are the only knobs — swap them freely. Emitted as one JSON
# object (return-type "json"); Waybar re-runs this on its `interval`. The blink
# is pure CSS, so it animates regardless of how often we poll.
set -u

ICON_ETH="󰈀"     # ethernet
ICON_OFF="󰖪"     # md-wifi_off — radio off AND on-but-not-connected (colour separates them)
ICON_WIFI="󰖩"    # md-wifi — connected / connecting
ICON_ALERT="󱚵"   # md-wifi_alert — joined a network but no internet

# Minimal JSON string escaper (backslash, quote, newline).
esc() { local s=${1//\\/\\\\}; s=${s//\"/\\\"}; s=${s//$'\n'/\\n}; printf '%s' "$s"; }
emit() { printf '{"text":"%s","class":"%s","tooltip":"%s"}\n' "$1" "$2" "$(esc "$3")"; }

# 1) Ethernet up? (any ethernet device in the 'connected' state wins outright)
eth=$(nmcli -t -f DEVICE,TYPE,STATE device 2>/dev/null \
        | awk -F: '$2=="ethernet" && $3=="connected" { print $1; exit }')
if [ -n "$eth" ]; then
  emit "$ICON_ETH" "ethernet" "Ethernet  ·  $eth"
  exit 0
fi

# 2) Wi-Fi radio off?
if ! nmcli -t radio wifi 2>/dev/null | grep -q '^enabled$'; then
  emit "$ICON_OFF" "disabled" "Wi-Fi  ·  off"
  exit 0
fi

# 3) Wi-Fi device state
wstate=$(nmcli -t -f TYPE,STATE device 2>/dev/null | awk -F: '$1=="wifi" { print $2; exit }')
case "$wstate" in
  connecting*)
    emit "$ICON_WIFI" "connecting" "Wi-Fi  ·  connecting…"
    ;;
  connected)
    active=$(nmcli -t -f ACTIVE,SSID,SIGNAL device wifi 2>/dev/null | awk -F: '$1=="yes"{print; exit}')
    ssid=$(printf '%s' "$active" | cut -d: -f2); ssid=${ssid//\\:/:}   # un-escape nmcli's \: in SSIDs
    sig=$(printf '%s' "$active" | awk -F: '{print $NF}')
    case "$(nmcli networking connectivity 2>/dev/null)" in
      full|unknown|"")   # reachable, or NM can't check → assume OK, don't nag
        emit "$ICON_WIFI" "connected" "${ssid:-Wi-Fi}  ·  ${sig}%"
        ;;
      *)                 # limited | portal | none → joined but no usable internet
        emit "$ICON_ALERT" "no-internet" "${ssid:-Wi-Fi}  ·  no internet"
        ;;
    esac
    ;;
  *)  # disconnected / unavailable-but-radio-on → on, nothing joined
    emit "$ICON_OFF" "disconnected" "Wi-Fi  ·  not connected"
    ;;
esac
