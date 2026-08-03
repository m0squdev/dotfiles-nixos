# Bibata cursors recolored to Catppuccin Mocha, BUILT FROM SOURCE.
#
# Why build it here instead of pulling a package: nixpkgs' `bibata-cursors`
# ships only the stock Amber/Classic/Ice variants, and the Catppuccin recolor
# (Treecase/bibata-cursor-catppuccin) publishes no release — so the only way to
# get `Bibata-Catppuccin-Mocha` is to run upstream's build. Doing that in the
# flake keeps the cursor reproducible and portable across both hosts: the store
# path is content-addressed by the pinned commit, so every machine that rebuilds
# gets a byte-identical theme with no manual install step.
#
# Upstream's build is two stages driven by a Node tool (`cbmp`) plus `ctgen`. We
# reproduce it WITHOUT Node, because both stages have a pure-Nix equivalent:
#
#   1. RENDER — recolor each Bibata SVG and rasterize it to a PNG. `cbmp`'s three
#      placeholder-colour swaps (from the repo's render.json) are a plain
#      case-insensitive text substitution, and cbmp's DEFAULT rasterizer is
#      resvg — so we do the swap with `sed` and render with the `resvg` CLI (the
#      same engine, minus the optional puppeteer path we never trigger).
#   2. ASSEMBLE — `ctgen` (clickgen, in nixpkgs) packs the PNGs into an XCursor
#      theme using the repo's own TOML: sizes, hotspots and the cursor-name
#      symlinks (`default`, `pointer`, `progress`, …) that apps look cursors up
#      by. We invoke it exactly as upstream's build.sh does.
#
# The SVG sources are self-contained 256×256 files (animated cursors are numbered
# frame files, e.g. wait-01.svg → wait-*.png). `svg/modern/*` are in-repo
# symlinks into `svg/groups`; `find -L` and `sed` follow them transparently.
{ lib, stdenvNoCC, fetchFromGitHub, resvg, clickgen }:

stdenvNoCC.mkDerivation {
  pname = "bibata-cursor-catppuccin";
  # No upstream release; pin the commit and date it (nixpkgs unstable convention).
  version = "0-unstable-2025-04-01";

  src = fetchFromGitHub {
    owner = "Treecase";
    repo = "bibata-cursor-catppuccin";
    rev = "f71a82fcaa623ad1940ae8925cee72d816f5cdcb";
    hash = "sha256-LmNWXGNfWyNXappPKk0WT7SEq0R2H95YQeusL9pUduk=";
  };

  nativeBuildInputs = [ resvg clickgen ];

  # render.json's colour map: Bibata's green/blue/red placeholders → Catppuccin
  # Mocha (base #181825 for fill + outline, text #cdd6f4 for the stroke). `sed`'s
  # `I` flag mirrors cbmp's case-insensitive regex replace.
  buildPhase = ''
    runHook preBuild

    mkdir -p bitmaps/Bibata-Catppuccin-Mocha
    while IFS= read -r -d "" svg; do
      name=$(basename "$svg" .svg)
      sed -e 's/#00FF00/#181825/Ig' \
          -e 's/#0000FF/#cdd6f4/Ig' \
          -e 's/#FF0000/#181825/Ig' \
          "$svg" > recolored.svg
      resvg recolored.svg "bitmaps/Bibata-Catppuccin-Mocha/$name.png"
    done < <(find -L svg/modern -type f -name '*.svg' -print0)
    rm -f recolored.svg

    # out_dir in the TOML is '../../themes' (relative to the config file), so this
    # writes themes/Bibata-Catppuccin-Mocha/ — same as upstream's build.sh.
    ctgen configs/normal/x.build.toml -p x11 \
      -d bitmaps/Bibata-Catppuccin-Mocha \
      -n 'Bibata-Catppuccin-Mocha' \
      -c 'Catppuccin Mocha flavored Bibata XCursors'

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -dm755 "$out/share/icons"
    cp -r themes/Bibata-Catppuccin-Mocha "$out/share/icons/"
    runHook postInstall
  '';

  meta = {
    description = "Bibata cursors recolored with the Catppuccin Mocha palette";
    homepage = "https://github.com/Treecase/bibata-cursor-catppuccin";
    license = lib.licenses.gpl3Only;   # inherited from ful1e5/Bibata_Cursor
    platforms = lib.platforms.linux;
  };
}
