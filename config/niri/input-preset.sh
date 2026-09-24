#!/usr/bin/env bash
# Input preset switcher for niri: US-intl / US / Japanese (Mozc).
#
#   cycle   Mod+K — advance to the next preset in PRESETS order (wraps).
#   menu    waybar click — fuzzel picker to jump straight to a preset.
#   set ID  apply one preset outright.
#   label   print the waybar indicator text for the current preset.
#
# Every preset is an ABSOLUTE (niri XKB layout index, fcitx5 group) pair applied
# by `set`, so each path lands on the same state regardless of what came before.
# The old script instead made relative moves (`switch-layout next` + toggle),
# which meant one missed step left the cycle out of phase.
#
# Why fcitx5 GROUPS and not `fcitx5-remote -o/-c`:
# activate/deactivate act on the *currently focused input context*. Right after
# login nothing owns a text-input context yet (waylandFrontend means apps reach
# fcitx5 only via text-input-v3), so `fcitx5-remote` reports "0" and -o is a
# silent no-op — which stranded the switcher on US. `-g`/`-q` are instance-global
# and work with no context at all, and apply to whatever gets focused next.
#
# This relies on config/fcitx5/profile giving each group exactly ONE engine: with
# a single engine fcitx5 always uses it, so the group name alone decides Japanese
# vs English and no context-dependent "active" flag is involved. Adding a second
# engine to a group would break that and reintroduce the login bug.

set -u

# id | niri layout index | fcitx5 group | waybar label | menu entry
PRESETS=(
    "us-intl|0|English|󰌌 us intl|US International (dead keys)"
    "us|1|English|󰌌 us|US"
    "jp|1|Japanese|󰌌 jp|Japanese (Mozc)"
)

# field <preset-id> <column> — column 2=layout index, 3=group, 4=label, 5=menu entry
field() {
    local p
    for p in "${PRESETS[@]}"; do
        if [ "${p%%|*}" = "$1" ]; then
            printf '%s' "$p" | cut -d'|' -f"$2"
            return 0
        fi
    done
    return 1
}

# Which preset are we in? The fcitx5 group answers Japanese without needing an
# input context; the niri layout index separates the two English ones.
current() {
    local group idx
    group=$(fcitx5-remote -q 2>/dev/null)
    if [ "$group" = "Japanese" ]; then
        printf 'jp'
        return
    fi
    idx=$(niri msg keyboard-layouts 2>/dev/null | awk '$1=="*"{print $2}')
    if [ "${idx:-0}" = "0" ]; then printf 'us-intl'; else printf 'us'; fi
}

apply() {
    local id=$1 idx group
    idx=$(field "$id" 2) || return 1
    group=$(field "$id" 3)
    niri msg action switch-layout "$idx" >/dev/null 2>&1
    fcitx5-remote -g "$group" >/dev/null 2>&1
    # Poke waybar's custom/inputlang module now rather than waiting out its 2s
    # poll. SIGRTMIN+7 is only safe while a module declares "signal": 7 — without
    # one the real-time signal kills waybar.
    pkill -RTMIN+7 waybar 2>/dev/null
    return 0
}

cycle() {
    local cur i n=${#PRESETS[@]}
    cur=$(current)
    for ((i = 0; i < n; i++)); do
        if [ "${PRESETS[i]%%|*}" = "$cur" ]; then
            apply "${PRESETS[((i + 1) % n)]%%|*}"
            return
        fi
    done
    apply "${PRESETS[0]%%|*}"
}

menu() {
    local cur p sel entries=()
    cur=$(current)
    for p in "${PRESETS[@]}"; do
        # Mark the active preset so the menu shows where you are, not just where
        # you can go. Leading spaces keep the labels aligned with the marked row.
        if [ "${p%%|*}" = "$cur" ]; then
            entries+=("● $(printf '%s' "$p" | cut -d'|' -f5)")
        else
            entries+=("  $(printf '%s' "$p" | cut -d'|' -f5)")
        fi
    done
    # --index returns the row number, so the visible text stays free to change
    # without the mapping back to a preset id depending on parsing it.
    sel=$(printf '%s\n' "${entries[@]}" | fuzzel --dmenu --index --prompt "Keyboard > ")
    [ -n "$sel" ] && apply "${PRESETS[sel]%%|*}"
}

case "${1:-cycle}" in
    cycle) cycle ;;
    menu)  menu ;;
    label) field "$(current)" 4; printf '\n' ;;
    set)   apply "${2:-}" || { echo "unknown preset: ${2:-}" >&2; exit 1; } ;;
    *)     echo "usage: ${0##*/} [cycle|menu|label|set <preset>]" >&2; exit 1 ;;
esac
