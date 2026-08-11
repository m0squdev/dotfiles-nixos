#!/usr/bin/env bash
# Peek the Waybar bar over a fullscreen window by throwing the pointer at the
# top edge of the screen.
#
# niri draws a focused fullscreen window over the *top* layer-shell layer, which
# is where the bar lives — that is why the bar vanishes in fullscreen, and it is
# the behaviour we want to keep. Waybar can move itself to the *overlay* layer
# (which stays above fullscreen) at runtime, but only as part of hide/show, and
# it has no idea where the pointer is. This script supplies both halves: it runs
# top-edge-sensor to notice the pointer, and it decides when that sensor should
# be listening at all.
#
# THE HIDE/SHOW INVERSION. Waybar has exactly two switchable states: the bar's
# own config (the "default" mode) and the "invisible" mode it drops into on
# hide. config.jsonc redefines "invisible" as a *peek* — overlay layer, still
# visible — so here:
#
#     pointer arrives  ->  SIGUSR1 = "hide"  ->  peek: overlay, above fullscreen
#     pointer leaves   ->  SIGUSR2 = "show"  ->  default: top layer, hidden again
#
# Reading backwards is worth it for the failure mode: the resting state is the
# ordinary bar, so if this script or the sensor ever dies, the bar is left
# exactly as it behaves without them rather than stuck invisible.
#
# DETECTING FULLSCREEN. niri's IPC has no is_fullscreen flag (window objects
# carry is_focused / is_floating / is_urgent and nothing else), so we infer it
# from geometry: a fullscreen window is handed the output's whole logical size,
# while a tiled one is always smaller — the bar's 40px exclusive zone and the
# 16px gaps are subtracted from it (1536x864 output -> 1504x792 tiles here). The
# only window that can be exactly output-sized is a fullscreen one.
#
# We track the FOCUSED window specifically because that is niri's own condition:
# "when a fullscreen window is focused and not animating, it will cover floating
# windows and the top layer-shell layer". An unfocused fullscreen window on
# another monitor leaves the bar alone, and so leaves the sensor disarmed.
#
# Events are parsed with shell builtins rather than `niri msg` round-trips
# because "Window opened or changed" also fires on every title change — several
# times a second for a terminal with a spinner in its title. Only the rare
# events (focus moved, workspaces/monitors changed) are worth a subprocess.

# Waiting, the sensor is a tripwire on the screen edge itself, so the bar only
# comes back if you actually throw the pointer at the top rather than drift near
# it. Revealed, it steps aside to watch everything below the bar's bottom edge
# (6px margin + 34px tall, +8px of slack) — off the bar, so the peeked bar stays
# clickable, and moving down off it is what puts the bar away again.
TRIGGER_HEIGHT=2
REVEAL_OFFSET=48

# The sensor is ours: owning it means signalling an exact pid instead of pattern
# matching, and it dies with this script.
top-edge-sensor --trigger-height "$TRIGGER_HEIGHT" --reveal-offset "$REVEAL_OFFSET" \
    --enter 'pkill -USR1 waybar' \
    --leave 'pkill -USR2 waybar' &
sensor=$!
trap 'kill "$sensor" 2>/dev/null' EXIT   # widened below, once the fifo exists

# SIGUSR1 and SIGHUP both default to *terminate*, so never signal the sensor
# until it is up and has replaced them. Its layer surface appearing is the proof.
for _ in $(seq 1 100); do   # up to ~5s
    niri msg layers 2>/dev/null | grep -q '"top-edge-sensor"' && break
    sleep 0.05
done

# Hold the sensor while swaync's control center is on screen. The panel opens
# centred, i.e. inside the region the revealed sensor watches, so reaching down
# for it would otherwise read as "moved off the bar" and take the bar away with
# it — while the pointer was on its way to the panel the bar itself opened.
# Holding makes the sensor click-through without disturbing the peek, so the
# panel is usable and the bar stays put behind it.
#
# `visible` in swaync's subscribe stream is the control center, not the
# notification popups. Releasing on stream end matters: if swaync restarts, the
# sensor must not be left held and deaf forever.
#
# The subscriber goes through a fifo rather than `< <(swaync-client -s)` so that
# it is a direct child with a pid we can kill. Behind process substitution it is
# a grandchild instead, and killing the reader leaves it running — restarting
# this script then left an orphan behind every time.
cc_fifo="${XDG_RUNTIME_DIR:-/tmp}/bar-peek-cc.$$"
mkfifo -m 600 "$cc_fifo"
swaync-client -s > "$cc_fifo" 2>/dev/null &
cc_sub=$!
{
    while IFS= read -r state; do
        case $state in
        *'"visible": true'*)  kill -HUP   "$sensor" 2>/dev/null ;;
        *'"visible": false'*) kill -WINCH "$sensor" 2>/dev/null ;;
        esac
    done < "$cc_fifo"
    kill -WINCH "$sensor" 2>/dev/null
} &
cc_watch=$!
trap 'kill "$sensor" "$cc_sub" "${cc_watch:-}" 2>/dev/null; rm -f "$cc_fifo"' EXIT

declare -A output_size   # "1536x864" -> 1, the logical size of every output
focused_id=""
focused_size=""
overview=0
armed=0

refresh_outputs() {
    output_size=()
    local size
    while read -r size; do
        output_size["$size"]=1
    done < <(niri msg outputs | sed -n 's/^ *Logical size: \([0-9]*x[0-9]*\).*/\1/p')
}

refresh_focused() {
    local info
    info=$(niri msg focused-window 2>/dev/null)
    focused_id=$(sed -n 's/^Window ID \([0-9]*\):.*/\1/p' <<<"$info")
    focused_size=$(sed -n 's/^ *Window size: \([0-9]*\) x \([0-9]*\).*/\1x\2/p' <<<"$info")
}

# Arm the sensor exactly while something is covering the bar.
update() {
    local want=0
    if ((!overview)) && [[ -n $focused_size && -n ${output_size[$focused_size]} ]]; then
        want=1
    fi
    ((want == armed)) && return
    armed=$want
    kill -0 "$sensor" 2>/dev/null || exit 1
    if ((armed)); then
        kill -USR1 "$sensor"
    else
        kill -USR2 "$sensor"
    fi
}

refresh_outputs
refresh_focused
update

while IFS= read -r line; do
    case $line in
    "Window opened or changed: "*)
        # Carries every field needed, is_focused included, so never shell out —
        # this is the event that repeats on every title change.
        [[ $line == *"is_focused: true"* ]] || continue
        rest=${line#*"Window { id: "}
        focused_id=${rest%%,*}
        rest=${rest#*"is_focused: true"}
        [[ $rest == *"window_size: ("* ]] || continue
        rest=${rest#*"window_size: ("}
        focused_size=${rest%%)*}
        focused_size=${focused_size/, /x}
        ;;
    "Window layouts changed: "*)
        # A batch of (id, layout) pairs; only the focused window's entry matters.
        # The "(" in the pattern keeps id 4 from matching id 14.
        [[ -n $focused_id ]] || continue
        rest=${line#*"($focused_id, WindowLayout {"}
        [[ $rest != "$line" && $rest == *"window_size: ("* ]] || continue
        rest=${rest#*"window_size: ("}
        focused_size=${rest%%)*}
        focused_size=${focused_size/, /x}
        ;;
    "Window focus changed: "*)
        # None does NOT mean the fullscreen window went away — it also fires
        # whenever a layer-shell panel takes keyboard focus, which is exactly
        # what swaync's control center and fuzzel's menus do. Acting on it tore
        # the peek down the instant you opened a panel from the bar, which is
        # the one moment the bar has to stay. The cases where a window really is
        # gone announce themselves properly: "Window closed" below, or
        # "Workspace focused" when you switch away. (`niri msg focused-window`
        # is no help here — with the panel focused it reports nothing either.)
        [[ $line == *"None"* ]] && continue
        # Otherwise only the id is carried, so look the size up — focus moves at
        # human speed, so the subprocess is affordable here.
        refresh_focused
        ;;
    "Workspace focused: "*)
        # Switching workspaces is the honest way to stop looking at a fullscreen
        # window, and it has to be handled here now that None is ignored.
        refresh_focused
        ;;
    "Window closed: "*)
        [[ $line == *"$focused_id"* ]] && { focused_id=""; focused_size=""; }
        ;;
    "Overview toggled: "*)
        # The overview scales every window down, so nothing covers the bar there.
        [[ $line == *"true"* ]] && overview=1 || { overview=0; refresh_focused; }
        ;;
    "Windows changed: "* | "Workspaces changed: "*)
        # Bulk resyncs — also where a monitor being plugged in shows up, which
        # changes the set of sizes that count as fullscreen.
        refresh_outputs
        refresh_focused
        ;;
    *)
        continue
        ;;
    esac
    update
done < <(niri msg event-stream)
