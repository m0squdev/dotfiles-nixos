#!/usr/bin/env bash
# Unified input cycle for niri: US-intl -> US -> Japanese (fcitx5/Mozc) -> US-intl.
# Ties niri's XKB layout switching together with fcitx5, so ONE control (Mod+K or
# the waybar language menu) rotates through all three — the same way Mod+K used to
# flip US-intl/US. Degrades to a plain 2-layout toggle if fcitx5 isn't running yet
# (e.g. before the i18n.inputMethod rebuild), so nothing breaks in the meantime.
#
# fcitx5-remote state: "2" = an engine (Mozc) is active (Japanese); "1"/empty = off.

fstate=$(fcitx5-remote 2>/dev/null)
idx=$(niri msg keyboard-layouts 2>/dev/null | awk '$1=="*"{print $2}')

if [ "$fstate" = "2" ]; then
    # Japanese -> back to English on the US-intl layout
    fcitx5-remote -c 2>/dev/null
    [ "${idx:-0}" != "0" ] && niri msg action switch-layout next
elif [ "${idx:-0}" = "0" ]; then
    # US-intl -> US
    niri msg action switch-layout next
elif [ "$fstate" = "1" ]; then
    # US, fcitx5 available -> Japanese (Mozc)
    fcitx5-remote -o 2>/dev/null
else
    # fcitx5 not up yet -> just toggle back to US-intl
    niri msg action switch-layout next
fi

# Poke the waybar custom/inputlang module to refresh now (signal 7 = SIGRTMIN+7).
# Needed because switching Japanese on/off is NOT a niri layout event. Safe only
# while a module declares "signal": 7 (else the RT signal would kill waybar).
pkill -RTMIN+7 waybar 2>/dev/null
