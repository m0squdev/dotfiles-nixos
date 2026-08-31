#!/usr/bin/env bash
# Peek the Waybar bar over a fullscreen window by throwing the pointer at the
# top edge of the screen.
#
# niri draws a focused fullscreen window over the *top* layer-shell layer, which
# is where the bar lives — that is why the bar vanishes in fullscreen, and it is
# the behaviour we want to keep. Waybar can move itself to the *overlay* layer
# (which stays above fullscreen) at runtime, but only as part of hide/show, and
# it has no idea where the pointer is. This script supplies both halves: it runs
# top-edge-sensor to notice the pointer, and it decides which monitor's sensor
# should be listening at all.
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
# WHICH MONITOR. Waybar's signals are process-wide — waybar(5) is explicit that
# on-sigusr1/on-sigusr2 change "what happens when *bars* receive" them, and there
# is no per-bar signal and no IPC — so the peek styling still lands on every
# bar. What IS scoped here is the trigger: only the monitor whose bar is
# actually covered gets an armed sensor, so the top edge of the other screen no
# longer peeks a bar that was never hidden. (Making the styling per-monitor too
# needs one waybar process per output, or a multi-bar config that routes the two
# signals to different outputs; neither is done here.)
#
# DETECTING FULLSCREEN. niri's IPC has no is_fullscreen flag (window objects
# carry is_focused / is_floating / is_urgent and nothing else), so we infer it
# from geometry: a fullscreen window is handed the output's whole logical size,
# while a tiled one is always smaller — the bar's 40px exclusive zone and the
# 16px gaps are subtracted from it (1536x864 output -> 1504x792 tiles here).
#
# The comparison is against the window's OWN output, which is what needs the
# workspace bookkeeping below. Comparing against the set of all output sizes —
# as this used to — makes a merely-large window on one monitor look fullscreen
# the moment another monitor happens to be that size, and it cannot say which
# monitor to arm even when it is right.
#
# We track the FOCUSED window specifically because that is niri's own condition:
# "when a fullscreen window is focused and not animating, it will cover floating
# windows and the top layer-shell layer". An unfocused fullscreen window on
# another monitor leaves the bar alone, and so leaves every sensor disarmed.
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

# The sensor takes line commands on stdin, because arming now names a monitor
# and a signal cannot carry an argument; see top-edge-sensor.c. It also means
# there is no startup race to lose — the old SIGUSR1 interface defaulted to
# *terminate*, so this script had to watch for the sensor's layer surface before
# it dared signal, whereas a write to the fifo just waits in the buffer.
ctl="${XDG_RUNTIME_DIR:-/tmp}/bar-peek-ctl.$$"
mkfifo -m 600 "$ctl"
top-edge-sensor --trigger-height "$TRIGGER_HEIGHT" --reveal-offset "$REVEAL_OFFSET" \
    --enter 'pkill -USR1 waybar' \
    --leave 'pkill -USR2 waybar' < "$ctl" &
sensor=$!
# Read-write on purpose. Write-only would block until the sensor has opened its
# end (so a sensor that failed to start would hang us here instead of failing),
# and holding a writer open is what stops the sensor seeing EOF in the gaps
# between commands — EOF is its signal that we are gone and it should quit.
exec 9<>"$ctl"
trap 'kill "$sensor" 2>/dev/null; rm -f "$ctl"' EXIT   # widened below

# Hold the sensor while swaync's control center is on screen. The panel opens
# centred, i.e. inside the region a revealed sensor watches, so reaching down
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
#
# Hold/release stay on signals rather than joining the commands on fd 9, and
# both children get 9>&- so they do not inherit it at all. A command pipe with a
# second writer in it cannot report EOF when THIS shell dies, and EOF is how the
# sensor knows to put the bar back and follow us out — a watcher that outlived a
# `kill -9` here would otherwise hold the pipe open and strand it.
cc_fifo="${XDG_RUNTIME_DIR:-/tmp}/bar-peek-cc.$$"
mkfifo -m 600 "$cc_fifo"
swaync-client -s > "$cc_fifo" 2>/dev/null 9>&- &
cc_sub=$!
{
    while IFS= read -r state; do
        case $state in
        *'"visible": true'*)  kill -HUP   "$sensor" 2>/dev/null ;;
        *'"visible": false'*) kill -WINCH "$sensor" 2>/dev/null ;;
        esac
    done < "$cc_fifo"
    kill -WINCH "$sensor" 2>/dev/null
} 9>&- &
cc_watch=$!
trap 'kill "$sensor" "$cc_sub" "${cc_watch:-}" 2>/dev/null; rm -f "$ctl" "$cc_fifo"' EXIT

declare -A output_size   # "eDP-1" -> "1536x864", the output's logical size
declare -A output_pos    # "eDP-1" -> "0,0", how the sensor names that monitor
declare -A ws_output     # workspace id -> output name
focused_id=""
focused_ws=""
focused_size=""
overview=0
armed_at=""              # the position last sent, "" while disarmed

# The sensor identifies a monitor by logical position, not by connector: GDK
# never exposes niri's connector name (gdk_monitor_get_model() gives the EDID
# model — "M2352D", "0x403D"), and position is the one property both sides can
# see. niri cannot put two outputs in the same place, so it is a key.
refresh_outputs() {
    local name="" key value
    output_size=()
    output_pos=()
    while read -r key value; do
        case $key in
        OUT)  name=$value ;;
        POS)  [[ -n $name ]] && output_pos["$name"]=$value ;;
        SIZE) [[ -n $name ]] && output_size["$name"]=$value ;;
        esac
    done < <(niri msg outputs 2>/dev/null | sed -nE '
        s/^Output .*\(([^)]+)\)$/OUT \1/p
        s/^ *Logical position: (-?[0-9]+), (-?[0-9]+)$/POS \1,\2/p
        s/^ *Logical size: ([0-9]+x[0-9]+).*/SIZE \1/p')
}

refresh_focused() {
    local info
    info=$(niri msg focused-window 2>/dev/null)
    focused_id=$(sed -n 's/^Window ID \([0-9]*\):.*/\1/p' <<<"$info")
    focused_ws=$(sed -n 's/^ *Workspace ID: \([0-9]*\).*/\1/p' <<<"$info")
    focused_size=$(sed -n 's/^ *Window size: \([0-9]*\) x \([0-9]*\).*/\1x\2/p' <<<"$info")
}

# `niri msg workspaces` prints the *index* within each output, never the id the
# window records carry, so the map can only come from the event — which is fine,
# because niri sends a full "Workspaces changed" the moment the stream opens.
refresh_workspaces() {
    local id out
    ws_output=()
    while read -r id out; do
        ws_output["$id"]=$out
    done < <(sed 's/Workspace { /\n/g' <<<"$1" \
             | sed -nE 's/^id: ([0-9]+),.*output: Some\("([^"]+)"\).*/\1 \2/p')
}

# Arm exactly the monitor whose bar is covered, and no other.
update() {
    local want="" out
    if ((!overview)) && [[ -n $focused_ws && -n $focused_size ]]; then
        out=${ws_output[$focused_ws]}
        [[ -n $out && $focused_size == "${output_size[$out]}" ]] && want=${output_pos[$out]}
    fi
    [[ $want == "$armed_at" ]] && return
    armed_at=$want
    kill -0 "$sensor" 2>/dev/null || exit 1
    if [[ -n $want ]]; then
        printf 'arm %s\n' "$want" >&9
    else
        printf 'disarm\n' >&9
    fi
}

refresh_outputs
refresh_focused
update

while IFS= read -r line; do
    case $line in
    "Window opened or changed: "*)
        # Carries every field needed, is_focused included, so never shell out —
        # this is the event that repeats on every title change. The fields are
        # walked in the order niri prints them (id, ..., workspace_id,
        # is_focused, ..., layout) so each cut starts after the previous one.
        [[ $line == *"is_focused: true"* ]] || continue
        rest=${line#*"Window { id: "}
        focused_id=${rest%%,*}
        [[ $rest == *"workspace_id: Some("* ]] || continue
        rest=${rest#*"workspace_id: Some("}
        focused_ws=${rest%%)*}
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
        # gone announce themselves properly: "Window closed" below, or the
        # workspace switch. (`niri msg focused-window` is no help here — with
        # the panel focused it reports nothing either.)
        [[ $line == *"None"* ]] && continue
        # Otherwise only the id is carried, so look the rest up — focus moves at
        # human speed, so the subprocess is affordable here.
        refresh_focused
        ;;
    "Workspace "*": focused" | "Workspace "*": activated")
        # Switching workspaces is the honest way to stop looking at a fullscreen
        # window, and it has to be handled here now that None is ignored. niri
        # prints this as "Workspace <id>: focused" — NOT "Workspace focused:",
        # which is what this used to match and therefore never fired on, leaving
        # the sensor armed after a switch to an empty workspace.
        refresh_focused
        ;;
    "Window closed: "*)
        [[ $line == *"$focused_id"* ]] && { focused_id=""; focused_ws=""; focused_size=""; }
        ;;
    "Overview toggled: "*)
        # The overview scales every window down, so nothing covers the bar there.
        [[ $line == *"true"* ]] && overview=1 || { overview=0; refresh_focused; }
        ;;
    "Workspaces changed: "*)
        # Bulk resync — also where a monitor being plugged in shows up, which
        # both moves workspaces between outputs and changes the sizes that count
        # as fullscreen.
        refresh_workspaces "$line"
        refresh_outputs
        refresh_focused
        ;;
    "Windows changed: "*)
        refresh_outputs
        refresh_focused
        ;;
    *)
        continue
        ;;
    esac
    update
done < <(niri msg event-stream 9>&-)
