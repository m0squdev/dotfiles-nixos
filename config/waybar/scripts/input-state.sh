#!/usr/bin/env bash
# Waybar input indicator. Matches the old niri/language look for the keyboard
# layouts (󰌌 us intl / 󰌌 us) and shows "󰌌 jp" when fcitx5/Mozc is active.
# One-shot: prints once and exits. Refreshed on a 2s interval AND instantly by
# cycle-input.sh via SIGRTMIN+7. fcitx5-remote returns "2" when Mozc is active.
if [ "$(fcitx5-remote 2>/dev/null)" = "2" ]; then
    printf '󰌌 jp\n'
else
    lay=$(niri msg keyboard-layouts 2>/dev/null | awk '$1=="*"{print}')
    case "$lay" in
        *intl*) printf '󰌌 us intl\n' ;;
        *)      printf '󰌌 us\n' ;;
    esac
fi
