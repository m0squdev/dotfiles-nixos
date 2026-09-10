#!/usr/bin/env bash
# Waybar custom/window module — LIVE streaming producer. Prints the title of the
# window active on THIS bar's monitor, then RE-prints it on every niri
# focus/title/workspace change. Waybar runs one copy of the module's `exec` per
# bar and repaints the pill the instant a new line arrives on stdout — so the
# title is genuinely live, with no polling and no signals.
#
# This REPLACES the old design (one-shot script + "signal": 9 + a separate
# window-title-watch.sh that poked Waybar with SIGRTMIN+9). That poke path was
# fragile: it had to gate on Waybar's signal mask, RT signals could be dropped
# during event bursts, and it desynced across Waybar restarts. A streaming exec
# is the idiomatic Waybar pattern and has none of that — Waybar reads this stdout
# asynchronously on its own thread, so a long-lived child never blocks it.
#
# PER-MONITOR: Waybar hands each bar's `exec` the output it is on in
# $WAYBAR_OUTPUT_NAME (the wl_output connector, e.g. eDP-1 / HDMI-A-1 — the same
# string niri puts in a workspace's "output"). We scope to it so each bar shows
# the window focused on its own screen, not the globally focused one.
#
# We ask the WORKSPACE which window is active rather than which window holds
# keyboard focus: in the Overview nothing is focused, so `niri msg
# focused-window` answers "No window is focused" and the pill would drop to the
# hostname the moment the Overview opened. Workspaces keep reporting
# active_window_id throughout. On this monitor we prefer the globally focused
# workspace (so the pill follows the selection as it moves between workspaces in
# the Overview) and otherwise take the monitor's active (visible) workspace.
#
# The title is also TRUNCATED here rather than by Waybar's "max-length", which is
# one character count shared by every bar: 60 chars is the same physical width on
# every screen, so it fills a large share of the 1536-logical-px laptop panel but
# looks shrunken on the 1920px external monitor. Since we already know which
# output this bar is on — and which workspaces sit on it — we can compute the cap
# from this bar's actual geometry instead. See cap_for_layout.
#
# Parsed with grep/sed/awk because jq isn't installed. Workspace objects are flat
# so splitting on {...} is safe; window objects nest a "layout" object, hence the
# plain-text `niri msg windows` for the title.

out="${WAYBAR_OUTPUT_NAME:-}"

# --- Bar geometry, in LOGICAL px (the units Waybar lays out in — already divided
# by the output's scale, so a HiDPI panel isn't handed numbers meant for its
# native resolution). Every value below mirrors something in ../config.jsonc or
# ../style.css; if you change the padding/margins there, change them here too. ---
BAR_MARGIN=8      # config.jsonc margin-left / margin-right
BOX_SPACING=4     # config.jsonc "spacing" — the gap between modules in one box
PILL_PAD=24       # style.css module padding: 12px each side
PILL_MARGIN=6     # style.css module margin:  3px each side
WS_CHROME=14      # style.css #workspaces padding (4×2) + margin (3×2)
# One workspace dot. GTK3 applies min-width to the CONTENT box, so the button's
# own padding sits OUTSIDE the 32px, not inside it: 32 + 6×2 + margin 2×2 = 48.
# Reading it as a border-box width undercounts the left box by 12px per dot,
# which is enough to push the clock off centre once a few workspaces exist.
# 48 is deliberately 6×CHAR_W: see the note in style.css on why the pitch has to
# divide by the cell width, and change the two together.
WS_BUTTON=48
CLOCK_CHARS=5     # the clock renders "HH:MM"
CLOCK_GAP=48      # style.css .modules-center margin-left/right — see below
CHAR_W=8          # advance width of one JetBrainsMono glyph at font-size 13px

# THE POINT OF ALL THIS: the pill's right edge must not move when the workspace
# dots do. The clock is Waybar's centre widget, so it sits at the middle of the
# bar and the left box (workspaces + this pill) gets the half to its left. A cap
# that only scaled with the monitor therefore left a gap to the clock that shrank
# by one dot's width every time a workspace was added — the "dynamic boundary".
# Subtracting the dots here pins that edge instead: the cap is what's left of the
# left half once the dots, the inter-module gaps and the pill's own padding are
# taken out, so the pill ends in the same place whatever the workspace count.
#
# CLOCK_GAP is the reserved gutter either side of the clock PILL, and it is
# enforced twice over: style.css gives .modules-center that much horizontal
# MARGIN, which is what keeps the modules-right box out of it, and this cap is
# what keeps the title out of it from the left. The two numbers must agree, hence
# the constant here. It is on the centre BOX rather than on #clock so that the
# clock's clickable area stays the size of its pill; style.css says why.
#
# Clamped in case an output reports something absurd, and falling back to the old
# fixed 60 when we can't tell (no $WAYBAR_OUTPUT_NAME, or niri not answering).
WIDTH=0
CAP=60

width_for_output() {
    local width
    WIDTH=0
    [ -n "$out" ] || return

    # `niri msg outputs`, not --json: the JSON puts the whole modes array between
    # "name" and "logical", which is not parseable without jq.
    width=$(niri msg outputs 2>/dev/null | awk -v o="($out)" '
        index($0, o) { found = 1; next }
        found && /^  Logical size:/ { split($3, a, "x"); print a[1]; exit }
        /^Output /  { found = 0 }
    ')
    case "$width" in ''|*[!0-9]*) return ;; esac
    WIDTH=$width
}

# $1 = number of workspace dots this bar is drawing.
cap_for_layout() {
    local dots=$1 half px
    [ "$WIDTH" -gt 0 ] || { CAP=60; return; }
    [ "${dots:-0}" -ge 1 ] 2>/dev/null || dots=1

    # The clock's footprint at the centre: its own pill plus both gutters.
    # Halving what's left of the bar gives the space the left box may occupy.
    half=$(( (WIDTH - 2 * BAR_MARGIN
              - (CLOCK_CHARS * CHAR_W + PILL_PAD + 2 * CLOCK_GAP)) / 2 ))

    # Everything in that half that isn't title text.
    px=$(( half - (WS_CHROME + WS_BUTTON * dots) - BOX_SPACING - PILL_PAD - PILL_MARGIN ))

    CAP=$(( px / CHAR_W ))
    # The floor is 1, not a comfortable minimum: a floor that outruns the budget
    # is the very thing that shoves the clock off centre, so on an output with
    # enough workspaces to leave no room the title has to actually disappear
    # (down to a bare "…") rather than claim space it hasn't got. It takes 12
    # workspaces on the 1536px panel to get there.
    [ "$CAP" -lt 1 ] && CAP=1
    # The ceiling is the one place the right edge is allowed to drift: past ~2500
    # logical px it binds before the budget does, so the pill stops growing and
    # its edge starts tracking the dots again. Neither host is near that.
    [ "$CAP" -gt 120 ] && CAP=120
}

# Display COLUMNS of $1, into $COLS — not characters. The font is monospace, but
# "one character, one cell" is false for two groups that genuinely turn up in
# window titles, and both make the pill wider than the cap believes: CJK text, and
# Nerd Font icon glyphs in the Private Use Area (style.css asks for "JetBrainsMono
# Nerd Font", the DOUBLE-width build — the single-width one is "... Nerd Font
# Mono"). Overrunning the cap is what shoves the clock off centre, so those two
# count as a pair of cells.
#
# Everything else is one cell and must NOT be rounded up to two "to be safe":
# accented Latin, the ellipsis this script appends, box drawing, the braille
# spinner a terminal parks in its title. Over-counting them never moves the clock,
# but it shortens the pill by 8px for each one — and since the cap decides how
# much of the title survives, WHICH of them survive changes with the workspace
# count. That is the few pixels of drift, reintroduced by the fix for it.
#
# printf '%d' "'c" yields the CODEPOINT under this UTF-8 locale, and printf is a
# builtin, so despite the per-character loop this forks nothing.
# Inclusive "lo hi" codepoint pairs that occupy two cells. A table rather than one
# big (( ... )) test because `#` inside an arithmetic context is base-notation
# (2#1010), not a comment, so the ranges could not be labelled there.
WIDE_RANGES=(
    0x1100  0x115F      # Hangul Jamo
    0x2E80  0x303E      # CJK radicals, Kangxi, CJK symbols
    0x3041  0x33FF      # kana, Hangul compat, CJK compat
    0x3400  0x4DBF      # CJK ext A
    0x4E00  0x9FFF      # CJK unified ideographs
    0xA000  0xA4CF      # Yi
    0xAC00  0xD7A3      # Hangul syllables
    0xE000  0xF8FF      # private use — where the Nerd Font icons live
    0xF900  0xFAFF      # CJK compat ideographs
    0xFE30  0xFE6F      # CJK compat forms
    0xFF00  0xFF60      # fullwidth forms
    0xFFE0  0xFFE6      # fullwidth signs
    0x1F300 0x1F9FF     # emoji
    0x20000 0x10FFFF    # CJK ext B and beyond, PUA planes 15-16
)

COLS=0
count_cols() {
    local s=$1 n=${#1} i=0 cp j w
    COLS=0
    while [ "$i" -lt "$n" ]; do
        printf -v cp '%d' "'${s:i:1}"
        w=1
        for (( j = 0; j < ${#WIDE_RANGES[@]}; j += 2 )); do
            if (( cp >= WIDE_RANGES[j] && cp <= WIDE_RANGES[j+1] )); then w=2; break; fi
        done
        COLS=$(( COLS + w ))
        i=$(( i + 1 ))
    done
}

emit() {
    local ws sel wid title

    # One workspace object per line, optionally restricted to this bar's monitor.
    # -F: the output name is a literal, never a regex.
    ws=$(niri msg --json workspaces 2>/dev/null | grep -o '{[^{}]*}')
    [ -n "$out" ] && ws=$(printf '%s\n' "$ws" | grep -F "\"output\":\"$out\"")

    # One object per line, and niri/workspaces draws one dot per workspace of
    # THIS output (the module is per-output unless "all-outputs" is set) — so the
    # row count is exactly the button count the cap has to make room for. Costs
    # nothing extra: we already have the list. Only meaningful once filtered by
    # output, which is also the only case where cap_for_layout does anything.
    cap_for_layout "$(printf '%s\n' "$ws" | grep -c '{')"

    # Prefer the focused workspace on this monitor, else its active (visible) one.
    sel=$(printf '%s\n' "$ws" | grep '"is_focused":true')
    [ -z "$sel" ] && sel=$(printf '%s\n' "$ws" | grep '"is_active":true')

    wid=$(printf '%s\n' "$sel" \
        | sed -n 's/.*"active_window_id":\([0-9]\+\).*/\1/p' | head -n1)

    title=""
    if [ -n "$wid" ]; then
        title=$(niri msg windows 2>/dev/null | awk -v id="$wid" '
            # No end anchor: the focused entry is "Window ID 3: (focused)". The
            # trailing colon still prevents 3 from matching 30.
            $0 ~ "^Window ID " id ":" { found = 1; next }
            found && /^  Title: "/ {
                sub(/^  Title: "/, ""); sub(/"$/, "")
                print; exit
            }
            /^Window ID / { found = 0 }
        ')
    fi

    # Empty workspace, or niri not answering — fall back to the hostname.
    [ -z "$title" ] && title=$(cat /proc/sys/kernel/hostname 2>/dev/null)

    # Cut to this bar's budget, with an ellipsis so a clipped title reads as
    # clipped. Trimmed one CHARACTER at a time — ${title%?} is multibyte-aware in
    # this locale, so a CJK title is never cut mid-glyph — and re-measured with
    # the ellipsis already attached, so the result lands inside the cap whatever
    # mix of widths the title happens to hold. Pure parameter expansion: this runs
    # on every focus change and forks nothing.
    count_cols "$title"
    if [ "$COLS" -gt "$CAP" ]; then
        while [ -n "$title" ]; do
            title=${title%?}
            count_cols "$title…"
            [ "$COLS" -le "$CAP" ] && break
        done
        title="$title…"
    fi

    printf '%s\n' "$title"
}

# Print once up front, then on every relevant niri event. If the stream ends
# (niri restarted), wait briefly and reconnect.
#
# WorkspaceActiveWindowChanged is what keeps the pill live while the Overview is
# open: moving between WINDOWS of one workspace in there fires ONLY that event —
# no WindowFocusChanged (nothing holds keyboard focus in the Overview). Note
# *WorkspaceActivated* does NOT cover it: this event reads "WorkspaceActive" +
# "WindowChanged".
#
# The monitor WIDTH is re-read on WorkspacesChanged / ConfigLoaded rather than on
# every repaint: niri has no output event, but both of those fire when a monitor
# is plugged, unplugged or rescaled — the only times the logical width can move.
# (The workspace COUNT half of the cap needs no such gating: emit already has the
# list in hand, so cap_for_layout is just arithmetic on every repaint.)
while true; do
    width_for_output
    emit
    niri msg --json event-stream 2>/dev/null | while IFS= read -r line; do
        case "$line" in
            *WorkspacesChanged*|*ConfigLoaded*) width_for_output ;;
        esac
        case "$line" in
            *WindowFocusChanged*|*WindowOpenedOrChanged*|*WindowClosed*|*WindowsChanged*|\
            *WorkspaceActivated*|*WorkspacesChanged*|*WorkspaceActiveWindowChanged*|\
            *OverviewOpenedOrClosed*)
                emit ;;
        esac
    done
    sleep 1
done
