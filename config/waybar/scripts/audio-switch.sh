#!/usr/bin/env bash
# Switch the default audio OUTPUT or INPUT via fuzzel — PipeWire/wpctl, modelled
# on GNOME's Sound panel.
#
# OUTPUT: GNOME does not list "live sinks" — it lists each card's available output
# PORTS/ROUTES (Speakers, HDMI / DisplayPort, Headphones, Bluetooth
# Headphones/Handsfree). This matters because PipeWire only creates a sink for a
# card's ACTIVE profile, so a port on an INACTIVE profile — HDMI while the card is
# on analog, or a headset's A2DP while it is on HSP/HFP — has no sink to list, and
# a plain sink list silently omits it. We therefore enumerate the routes and, on
# selection, switch the card to a profile that provides the chosen route (or, when
# the route is already in the active profile, just switch the route), then make
# that card's sink the default. Labels are the routes' own PipeWire descriptions —
# the same strings GNOME shows.
#
# INPUT: sources don't have that problem — the analog mic is always present, and a
# Bluetooth mic is exposed by WirePlumber as an always-on loopback source
# (bluez5.loopback=true) that auto-engages HSP/HFP only while something records.
# So the input picker lists the real source nodes — including those loopback ones,
# which wpctl files under "Filters" — labelled "Card · Port" like the output
# picker, and just sets the default. No profile switching (that would needlessly
# drop Bluetooth playback to call quality), and a Bluetooth card's raw per-profile
# source is suppressed in favour of its loopback so the mic appears only once.
kind="${1:-sink}"
case "$kind" in
  sink)   prompt="Output > " ;;
  source) prompt="Input > "  ;;
  *) echo "usage: $0 {sink|source}" >&2; exit 1 ;;
esac

# --- PipeWire helpers -----------------------------------------------------

# Active profile index of device $1 (first top-level Int of its Profile param).
active_profile_of() {
  pw-cli enum-params "$1" Profile 2>/dev/null | awk '/^      Int/{print $2; exit}'
}

# Emit "index<TAB>name<TAB>description<TAB>availability<TAB>priority" per profile
# of device $1. Parsed by FIELD name (the "Prop: key ...:Profile:<field>" line
# names the next value), so field order doesn't matter.
profiles_of() {
  pw-cli enum-params "$1" EnumProfile 2>/dev/null | awk '
    function emit() { if (idx!="") printf "%s\t%s\t%s\t%s\t%s\n", idx, name, desc, avail, prio }
    /type Spa:Pod:Object:Param:Profile/ { emit(); idx=name=desc=avail=prio=field=""; next }
    /Prop: key .*:Profile:index/       { field="index"; next }
    /Prop: key .*:Profile:name/        { field="name";  next }
    /Prop: key .*:Profile:description/ { field="desc";  next }
    /Prop: key .*:Profile:available/   { field="avail"; next }
    /Prop: key .*:Profile:priority/    { field="prio";  next }
    /Prop: key .*:Profile:/            { field="";      next }
    field!="" {
      if      (field=="index") idx=$2
      else if (field=="prio")  prio=$2
      else if (field=="avail"){ a=$0; sub(/.*ParamAvailability:/,"",a); sub(/[)].*/,"",a); avail=a }
      else { s=$0; sub(/^[[:space:]]*String[[:space:]]*/,"",s); gsub(/^"|"$/,"",s)
             if (field=="name") name=s; else desc=s }
      field=""
    }
    END { emit() }'
}

# Emit "direction<TAB>index<TAB>description<TAB>availability<TAB>profiles" per
# route (port) of device $1, where profiles is the space-joined list of profile
# indices that expose the route. The description ("Speakers", "HDMI / DisplayPort",
# "Headphones", "Handsfree", …) is the human name GNOME shows.
routes_of() {
  pw-cli enum-params "$1" EnumRoute 2>/dev/null | awk '
    function emit(  p) { if (idx!="") { p=profs; sub(/^ /,"",p)
                         printf "%s\t%s\t%s\t%s\t%s\n", rdir, idx, desc, avail, p } }
    /type Spa:Pod:Object:Param:Route/ { emit(); rdir=idx=desc=avail=profs=""; field=""; next }
    /Prop: key .*:Route:index/       { field="idx";   next }
    /Prop: key .*:Route:direction/   { field="dir";   next }
    /Prop: key .*:Route:description/ { field="desc";  next }
    /Prop: key .*:Route:available/   { field="avail"; next }
    /Prop: key .*:Route:profiles/    { field="prof";  next }
    /Prop: key .*:Route:/            { field="other"; next }
    {
      if      (field=="idx"  && /Int /)   idx=$2
      else if (field=="dir"  && /Id /)    rdir=($0 ~ /Output/) ? "Output" : "Input"
      else if (field=="desc" && /String/){ s=$0; sub(/.*String[[:space:]]*/,"",s); gsub(/^"|"$/,"",s); desc=s }
      else if (field=="avail"&& /Id /)  { a=$0; sub(/.*ParamAvailability:/,"",a); sub(/[)].*/,"",a); avail=a }
      else if (field=="prof" && /Int /)   profs=profs " " $2
    }
    END { emit() }'
}

# Active route index of device $1 in direction $2 (Output|Input).
active_route_of() {
  pw-cli enum-params "$1" Route 2>/dev/null | awk -v want="$2" '
    /type Spa:Pod:Object:Param:Route/ { i=""; f=""; next }
    /Prop: key .*:Route:index/     { f="i"; next }
    /Prop: key .*:Route:direction/ { f="d"; next }
    /Prop: key .*:Route:/          { f="";  next }
    f=="i" && /Int /{ i=$2 }
    f=="d" && /Id / { if (($0 ~ /Output/ ? "Output" : "Input")==want) { print i; exit } }'
}

# Input port description of card $1 — its active input route, else the first
# available one (e.g. "Internal Microphone", "Handsfree").
input_port() {
  local act; act="$(active_route_of "$1" Input)"
  routes_of "$1" | awk -F'\t' -v act="$act" '
    $1=="Input" && $4!="no" {
      if ($2==act) { print $3; found=1; exit }
      if (first=="") first=$3
    }
    END { if (!found && first!="") print first }'
}

# device.id property of node $1 (which card a sink/source belongs to).
node_device() { wpctl inspect "$1" 2>/dev/null | awk -F'"' '/device\.id/{print $2; exit}'; }

# Id of the default sink|source (the one wpctl marks with "*").
default_node() {
  wpctl status | awk -v k="$1" '
    /^Audio/{a=1}/^Video/{a=0}
    a&&/Sinks:/{s=(k=="sink");next}
    a&&/Sources:/{s=(k=="source")}
    a&&(/Sink endpoints:/||/Filters:/){s=0}
    s&&/\*/{ l=$0; sub(/^[^0-9]*/,"",l); sub(/\..*/,"",l); print l; exit }'
}

# Id of the sink|source node belonging to card $2 (used after a profile switch).
node_of_card() {
  local card="$1" want="$2" nid
  while read -r nid; do
    [ "$(node_device "$nid")" = "$card" ] && { echo "$nid"; return; }
  done < <(wpctl status | awk -v k="$want" '
    /^Audio/{a=1}/^Video/{a=0}
    a&&/Sinks:/  {s=(k=="sink");   next}
    a&&/Sources:/{s=(k=="source"); next}
    a&&(/endpoints:/||/Filters:/||/Streams:/||/Devices:/){s=0}
    s&&/[0-9]+\./{ l=$0; sub(/^[^0-9]*/,"",l); sub(/\..*/,"",l); print l }')
}

# --- build the picker -----------------------------------------------------

declare -a labels actions

# All audio cards: id -> name (strip the trailing "[alsa]"/"[bluez5]" tag).
declare -A cardname
while IFS=$'\t' read -r cid cnm; do
  [ -n "$cid" ] && cardname["$cid"]="$cnm"
done < <(wpctl status | awk '
  /^Audio/{a=1}/^Video/{a=0}
  a&&/Devices:/{d=1;next} a&&/Sinks:/{d=0}
  d&&/[0-9]+\./{
    l=$0; sub(/^[^0-9]*/,"",l)
    id=l; sub(/\..*/,"",id)
    nm=l; sub(/^[0-9]+\.[[:space:]]*/,"",nm); sub(/[[:space:]]*\[[^]]*\][[:space:]]*$/,"",nm)
    gsub(/^[[:space:]]+|[[:space:]]+$/,"",nm)
    print id "\t" nm
  }')

if [ "$kind" = sink ]; then
  defcard="$(node_device "$(default_node sink)")"
  for cid in "${!cardname[@]}"; do
    cname="${cardname[$cid]}"
    active="$(active_profile_of "$cid")"
    actroute="$(active_route_of "$cid" Output)"
    unset ppri pav; declare -A ppri pav
    while IFS=$'\t' read -r pidx pname pdesc pavl pprio; do
      [ -n "$pidx" ] && { ppri["$pidx"]="${pprio:-0}"; pav["$pidx"]="$pavl"; }
    done < <(profiles_of "$cid")
    while IFS=$'\t' read -r rdir ridx rdesc ravl rprofs; do
      [ "$rdir" = Output ] || continue
      [ "$ravl" = no ] || [ -z "$rdesc" ] && continue
      # Target profile for this route: the active one if it already provides the
      # route (so no needless switch), else the highest-priority available one.
      target=""
      for p in $rprofs; do [ "$p" = "$active" ] && { target="$active"; break; }; done
      if [ -z "$target" ]; then
        bestpri=-1
        for p in $rprofs; do
          [ "${pav[$p]:-yes}" = no ] && continue
          pr="${ppri[$p]:-0}"
          [ "$pr" -gt "$bestpri" ] 2>/dev/null && { bestpri="$pr"; target="$p"; }
        done
      fi
      [ -z "$target" ] && continue
      # Active mark: this card owns the default sink AND this is its active route.
      if [ "$cid" = "$defcard" ] && [ "$ridx" = "$actroute" ]; then m="●  "; else m="   "; fi
      labels+=("${m}${cname} · ${rdesc}")
      actions+=("out:${cid}:${ridx}:${target}")
    done < <(routes_of "$cid")
  done
else
  defsrc="$(default_node source)"
  # bluez5 cards: on HSP/HFP their raw profile source appears in "Sources" AND the
  # always-on loopback appears in "Filters", both described by the device name —
  # two identical entries. Suppress the raw one; the loopback is the stable pick.
  declare -A bt_card
  while read -r bid; do [ -n "$bid" ] && bt_card["$bid"]=1; done < <(wpctl status | awk '
    /^Audio/{a=1}/^Video/{a=0} a&&/Devices:/{d=1;next} a&&/Sinks:/{d=0}
    d&&/\[bluez5\]/{ l=$0; sub(/^[^0-9]*/,"",l); sub(/\..*/,"",l); print l }')

  # Emit one source as "Card · Port" (matching the output picker), e.g.
  # "Built-in Audio · Internal Microphone", "WH-XB910N · Handsfree".
  add_source() {   # $1=node id  $2=fallback label
    local nid="$1" fb="$2" card port lbl
    card="$(node_device "$nid")"
    port="$(input_port "$card")"
    if [ -n "${cardname[$card]:-}" ] && [ -n "$port" ]; then lbl="${cardname[$card]} · ${port}"; else lbl="$fb"; fi
    [ "$nid" = "$defsrc" ] && m="●  " || m="   "
    labels+=("${m}${lbl}"); actions+=("def:${nid}")
  }

  # Real sources (Sources section), skipping the Bluetooth cards' raw source.
  while IFS=$'\t' read -r nid nname; do
    [ -z "$nid" ] && continue
    [ -n "${bt_card[$(node_device "$nid")]:-}" ] && continue
    add_source "$nid" "$nname"
  done < <(wpctl status | awk '
    /^Audio/{a=1}/^Video/{a=0}
    a&&/Sources:/{s=1;next} a&&(/Source endpoints:/||/Filters:/||/Streams:/||/Sinks:/){s=0}
    s&&/[0-9]+\./{
      l=$0; sub(/^[^0-9]*/,"",l); id=l; sub(/\..*/,"",id)
      nm=l; sub(/^[0-9]+\.[[:space:]]*/,"",nm); sub(/[[:space:]]*\[vol:.*$/,"",nm)
      gsub(/^[[:space:]]+|[[:space:]]+$/,"",nm)
      print id "\t" nm }')

  # Loopback mics (Bluetooth), which wpctl files under "Filters".
  while read -r nid; do
    [ -z "$nid" ] && continue
    nn="$(wpctl inspect "$nid" 2>/dev/null | awk -F'"' '/node\.description/{print $2; exit}')"
    add_source "$nid" "${nn:-mic}"
  done < <(wpctl status | awk '
    /^Audio/{a=1}/^Video/{a=0}
    a&&/Filters:/{s=1;next} a&&(/Streams:/||/Sinks:/||/Sources:/){s=0}
    s&&/\[Audio\/Source\]/{ l=$0; sub(/^[^0-9]*/,"",l); sub(/\..*/,"",l); print l }')
fi

[ ${#labels[@]} -eq 0 ] && exit 0

choice=$(printf '%s\n' "${labels[@]}" | fuzzel --dmenu --prompt "$prompt" --lines 8 --width 42)
[ -z "$choice" ] && exit 0

action=""
for i in "${!labels[@]}"; do
  if [ "${labels[$i]}" = "$choice" ]; then action="${actions[$i]}"; break; fi
done
[ -z "$action" ] && exit 0

case "$action" in
  def:*)
    wpctl set-default "${action#def:}"
    ;;
  out:*)
    rest="${action#out:}"; cid="${rest%%:*}"; rest="${rest#*:}"
    ridx="${rest%%:*}"; target="${rest#*:}"
    # Cross-profile port (HDMI, Bluetooth A2DP<->HFP): switch the whole profile.
    # Same-profile port (analog Speakers<->Headphones): target==active, so only
    # the route below moves.
    if [ "$target" != "$(active_profile_of "$cid")" ]; then
      wpctl set-profile "$cid" "$target"
      for _ in 1 2 3 4 5 6 7 8; do
        [ "$(active_profile_of "$cid")" = "$target" ] && break; sleep 0.2
      done
    fi
    wpctl set-route "$cid" "$ridx" 2>/dev/null
    # Promote the card's (possibly just-created) sink to default.
    for _ in 1 2 3 4 5 6 7 8; do
      sid="$(node_of_card "$cid" sink)"
      [ -n "$sid" ] && { wpctl set-default "$sid"; break; }
      sleep 0.2
    done
    ;;
esac
