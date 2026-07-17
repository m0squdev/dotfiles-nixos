#!/usr/bin/env bash
# Waybar module (polled): print the focused window's title, or the live hostname
# when nothing is focused / the title is empty. Runs once and exits — no
# long-lived child process, so Waybar never blocks waiting on it.

title=$(niri msg focused-window 2>/dev/null \
    | sed -n 's/^  Title: "\(.*\)"$/\1/p' | head -n1)

[ -z "$title" ] && title=$(cat /proc/sys/kernel/hostname 2>/dev/null)

printf '%s\n' "$title"
