#!/usr/bin/env bash
# Wi-Fi chooser via fuzzel — STREAMING, like the Bluetooth menu.
# Lists nearby networks; connecting to a secured one prompts for a password.
#
# `nmcli device wifi list --rescan yes` blocks for ~6s while it scans, and since
# fuzzel sat at the end of that pipeline it opened instantly and then showed an
# EMPTY menu for the entire scan. The cached list costs ~11ms, so render that
# immediately and stream in whatever a background rescan turns up.

nmcli radio wifi on 2>/dev/null

# Saved connection profiles that get "○ known" — but ONLY those that have
# actually connected at least once (TIMESTAMP != 0). `nmcli device wifi connect`
# writes a profile BEFORE it authenticates, so a wrong password or a cancelled
# attempt leaves a never-connected profile (timestamp 0) behind; counting those
# as "known" made a network you never joined show as ○ (and, worse, skip the
# password prompt on the next try). The connect logic below deletes such stale
# profiles, so this is belt-and-suspenders.
known=$(nmcli --terse --fields NAME,TIMESTAMP connection show 2>/dev/null \
        | awk -F: '$2 != 0 && $2 != "" { print $1 }')

# One row per SSID, as "ssid<TAB>display". A dual-band AP broadcasts the same
# name on 2.4 and 5GHz, so the scan returns it once per BSSID; deduping on the
# formatted line (as this used to) kept both, because their signal percentages
# differ. Sort by priority -- connected wins outright, otherwise strongest
# signal -- so the row that survives is the band actually worth showing.
rows() {
  nmcli --terse --fields IN-USE,SSID,SIGNAL,SECURITY device wifi list --rescan no 2>/dev/null \
  | awk -F: -v known="$known" '
      # Shared marker convention with bt-menu.sh:
      #   ●  connected      ○  known (saved profile)      (blank)  unknown
      BEGIN { n = split(known, k, "\n"); for (i = 1; i <= n; i++) if (length(k[i])) saved[k[i]] = 1 }
      # Signal and security are still read — signal drives the ordering — but
      # deliberately not shown; the row is just marker + SSID.
      length($2) {
        if ($1 == "*")        mark = "●  "
        else if ($2 in saved) mark = "○  "
        else                  mark = "   "
        pri = ($1 == "*") ? 1000 + $3 : $3
        printf "%d\t%s\t%s%s\n", pri, $2, mark, $2
      }' \
  | sort -t"$(printf '\t')" -k1,1nr \
  | cut -f2-
}

# Stream into fuzzel through a FIFO (not a plain pipe) so the producer can be
# killed the instant fuzzel closes, instead of polling out its full run.
fifo=$(mktemp -u -p "${XDG_RUNTIME_DIR:-/tmp}" wifi-menu.XXXXXX)
mkfifo "$fifo"
prod_pid=""
cleanup() { [ -n "$prod_pid" ] && kill "$prod_pid" 2>/dev/null; rm -f "$fifo"; }
trap cleanup EXIT

{
  declare -A seen
  flush() {
    while IFS=$'\t' read -r ssid display; do
      [ -z "$ssid" ] && continue
      [ -n "${seen[$ssid]}" ] && continue
      seen["$ssid"]=1
      printf '%s\n' "$display"
    done < <(rows)
  }

  flush                                        # cached results, immediately
  nmcli device wifi rescan >/dev/null 2>&1 &   # then look for anything new
  for _ in $(seq 1 14); do
    sleep 0.7
    flush
  done
} > "$fifo" &
prod_pid=$!

chosen=$(fuzzel --dmenu --prompt "Wi-Fi > " --lines 12 --width 40 < "$fifo")
cleanup; trap - EXIT

[ -z "$chosen" ] && exit 0

# Strip the leading "●  "/"○  "/"   " marker to recover the SSID. Nothing is
# appended to the row any more, so an SSID that ends in "(...)" survives intact.
ssid=$(printf '%s' "$chosen" | sed -E 's/^[●○] +//; s/^ +//')
[ -z "$ssid" ] && exit 0

# Branch on the SAME "known" set the list showed (timestamp-filtered), so the
# behaviour matches the marker: a ○ network is brought up from its saved profile;
# anything else — new, or a stale phantom from an earlier failed attempt — is
# connected fresh with a password prompt.
if printf '%s\n' "$known" | grep -qxF "$ssid"; then
  # Known network — just bring it up
  nmcli connection up id "$ssid"
else
  # Drop any leftover profile of this name first (a never-connected phantom from
  # a previous failed/cancelled attempt), so we always start clean and don't end
  # up with a "$ssid 1" duplicate.
  nmcli connection delete id "$ssid" 2>/dev/null
  # SSID on its own row above the input (--mesg), the prompt is just "> ", and
  # --lines 0 drops the match list (there's nothing to autocomplete). </dev/null
  # gives dmenu an immediate EOF so it doesn't wait on stdin for entries.
  pass=$(fuzzel --dmenu --password --prompt "> " --mesg "Password for $ssid" --lines 0 </dev/null)
  # On failure `nmcli device wifi connect` still leaves the half-created profile;
  # delete it so a bad password / cancel doesn't reappear as a ○ known network.
  if [ -n "$pass" ]; then
    nmcli device wifi connect "$ssid" password "$pass" || nmcli connection delete id "$ssid" 2>/dev/null
  else
    nmcli device wifi connect "$ssid" || nmcli connection delete id "$ssid" 2>/dev/null
  fi
fi
