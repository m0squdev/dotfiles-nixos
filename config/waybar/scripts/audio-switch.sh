#!/usr/bin/env bash
# Switch the default audio OUTPUT (sink) or INPUT (source) via fuzzel — PipeWire/wpctl.
# Usage: audio-switch.sh {sink|source}
kind="${1:-sink}"
case "$kind" in
  sink)   prompt="Output > " ;;
  source) prompt="Input > " ;;
  *) echo "usage: $0 {sink|source}" >&2; exit 1 ;;
esac

# Parse `wpctl status`, staying inside the top-level "Audio" section only
# (Video has its own Sinks/Sources we must not pick up). Emit "id<TAB>name".
mapfile -t entries < <(wpctl status | awk -v want="$kind" '
  /^Audio/    {aud=1; sec=0; next}
  /^Video/    {aud=0; sec=0; next}
  /^Settings/ {aud=0; sec=0; next}
  !aud        {next}
  /Sinks:/            {sec=(want=="sink");   next}
  /Sink endpoints:/   {sec=0; next}
  /Sources:/          {sec=(want=="source"); next}
  /Source endpoints:/ {sec=0; next}
  /Filters:/||/Streams:/||/Devices:/ {sec=0; next}
  sec && /[0-9]+\./ {
    line=$0; sub(/^[^0-9]*/,"",line)
    id=line;   sub(/\..*/,"",id)
    name=line; sub(/^[0-9]+\.[[:space:]]*/,"",name); sub(/[[:space:]]*\[vol:.*$/,"",name)
    gsub(/^[[:space:]]+|[[:space:]]+$/,"",name)
    if (name!="") print id "\t" name
  }')

[ ${#entries[@]} -eq 0 ] && exit 0

choice=$(printf '%s\n' "${entries[@]}" | cut -f2- | fuzzel --dmenu --prompt "$prompt" --lines 8 --width 42)
[ -z "$choice" ] && exit 0

id=""
for e in "${entries[@]}"; do
  if [ "${e#*$'\t'}" = "$choice" ]; then id="${e%%$'\t'*}"; break; fi
done
[ -n "$id" ] && wpctl set-default "$id"
