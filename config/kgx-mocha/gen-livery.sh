#!/usr/bin/env bash
# Generate a GNOME Console (kgx 50) "livery" for Catppuccin Mocha.
# Emits:
#   - mocha.ini            : human-readable livery file (importable via kgx UI)
#   - custom-liveries.gv   : GVariant a{sv} text for `gsettings set`
set -euo pipefail

UUID="d7b8f0a2-6c3e-4a1f-9b5d-2e4f6a8c0e11"
NAME="Catppuccin Mocha"

# Catppuccin Mocha — official terminal ANSI mapping
BG="1e1e2e"   # base
FG="cdd6f4"   # text
# 16 ANSI colours, index 0..15
COLS=(
  45475a  # 0  black        surface1
  f38ba8  # 1  red          red
  a6e3a1  # 2  green        green
  f9e2af  # 3  yellow       yellow
  89b4fa  # 4  blue         blue
  f5c2e7  # 5  magenta      pink
  94e2d5  # 6  cyan         teal
  bac2de  # 7  white        subtext1
  585b70  # 8  br black     surface2
  f38ba8  # 9  br red       red
  a6e3a1  # 10 br green     green
  f9e2af  # 11 br yellow    yellow
  89b4fa  # 12 br blue      blue
  f5c2e7  # 13 br magenta   pink
  94e2d5  # 14 br cyan      teal
  a6adc8  # 15 br white     subtext0
)

# hex "rrggbb" -> "r.rrr, g.ggg, b.bbb" doubles (0..1), 8 dp
rgb_tuple() {
  local h=$1
  awk -v h="$h" 'BEGIN{
    r=strtonum("0x" substr(h,1,2))/255.0;
    g=strtonum("0x" substr(h,3,2))/255.0;
    b=strtonum("0x" substr(h,5,2))/255.0;
    printf "(%.8f, %.8f, %.8f)", r, g, b;
  }'
}

# ---- build palette GVariant text (a{sv}) ----
cols_arr=""
for c in "${COLS[@]}"; do
  cols_arr+="$(rgb_tuple "$c"), "
done
cols_arr="[${cols_arr%, }]"
fg_t=$(rgb_tuple "$FG")
bg_t=$(rgb_tuple "$BG")

palette="{'colours': <${cols_arr}>, 'foreground': <${fg_t}>, 'background': <${bg_t}>, 'transparency': <0.0>}"

livery="{'uuid': <'${UUID}'>, 'name': <'${NAME}'>, 'night': <${palette}>, 'day': <${palette}>}"

custom_liveries="{'${UUID}': <${livery}>}"

printf '%s' "$custom_liveries" > custom-liveries.gv
echo "UUID=$UUID"
echo "wrote custom-liveries.gv ($(wc -c < custom-liveries.gv) bytes)"

# ---- build reference .ini (kgx UI-importable) ----
{
  echo "[Livery]"
  echo "UUID=$UUID"
  echo "Name=$NAME"
  echo
  for grp in Night Day; do
    echo "[$grp]"
    echo "Foreground=#$FG"
    echo "Background=#$BG"
    echo "Transparency=0"
    printf "Colours="
    for c in "${COLS[@]}"; do printf "#%s;" "$c"; done
    echo
    echo
  done
} > mocha.ini
echo "wrote mocha.ini"
