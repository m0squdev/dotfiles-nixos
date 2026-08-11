# top-edge-sensor — the pointer-at-the-top-of-the-screen trigger behind the
# "peek the bar over a fullscreen window" gesture. See ./top-edge-sensor.c for
# why a whole (if tiny) Wayland client is needed for something that looks like
# it should be a line of CSS, and config/niri/bar-peek.sh for the policy that
# drives it.
#
# Single .c file, so `dontUnpack` and compile it straight out of the store. gtk3
# and gtk-layer-shell are already in this host's closure — Waybar pulls both —
# so this adds a few kilobytes and no new dependencies.
{ lib, stdenv, pkg-config, gtk3, gtk-layer-shell }:

stdenv.mkDerivation {
  pname = "top-edge-sensor";
  version = "1.0";

  src = ./top-edge-sensor.c;
  dontUnpack = true;

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ gtk3 gtk-layer-shell ];

  buildPhase = ''
    runHook preBuild
    $CC -O2 -Wall -Wextra -o top-edge-sensor $src \
      $(pkg-config --cflags --libs gtk+-3.0 gtk-layer-shell-0)
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 top-edge-sensor "$out/bin/top-edge-sensor"
    runHook postInstall
  '';

  meta = {
    description = "Layer-shell strip that runs a command when the pointer reaches the top of the screen";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "top-edge-sensor";
  };
}
