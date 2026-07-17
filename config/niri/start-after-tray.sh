#!/usr/bin/env bash
# Wait until the StatusNotifier tray host (Waybar) is registered on the session
# bus, then exec the given command. Tray apps (e.g. vesktop) that launch before
# the watcher exists silently drop their tray icon and never retry — that login
# race is why vesktop started with no reachable tray icon. Usage:
#   start-after-tray.sh <command> [args...]

for _ in $(seq 1 100); do   # up to ~10s
    busctl --user list 2>/dev/null | grep -q 'org.kde.StatusNotifierWatcher' && break
    sleep 0.1
done
sleep 0.5   # small grace so the watcher is ready to accept registrations

exec "$@"
