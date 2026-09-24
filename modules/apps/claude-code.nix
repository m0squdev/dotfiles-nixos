# Claude Code — the terminal CLI (`claude`).
#
# This used to be a one-liner in ./misc.nix, but nixpkgs is pinned (see
# ../../flake.nix) and its claude-code lags well behind upstream: the pinned
# tree ships 2.1.187, which the app itself now refuses to run against the newer
# models with an "update required" notice (this is what surfaced once Opus 4.8
# shipped). Rather than bump the whole nixpkgs — rebuilding the world — override
# just this one package's version and the prebuilt binary it fetches. Per THE
# RULE in CONTRIBUTING.md, that's more than a line, so it earns its own module.
#
# claude-code in nixpkgs is a single fetched binary keyed by version + a
# per-platform checksum baked into the derivation's manifest.json. Everything
# else in that derivation (the wrapper, the ripgrep/bubblewrap/socat PATH,
# autoPatchelf) is version-independent, so replacing `version` + `src` is all
# that's needed to move it forward.
#
# To bump: read the latest version from
#   curl -fsSL https://downloads.claude.ai/claude-code-releases/latest
# then take the linux-x64 `checksum` (a hex sha256) from that version's
#   https://downloads.claude.ai/claude-code-releases/<version>/manifest.json
# and drop both in below.
#
# x86_64-linux only, matching this flake (see `system` in ../../flake.nix).
{ pkgs, ... }:
let
  version = "2.1.281";
  claude-code = pkgs.claude-code.overrideAttrs (old: {
    inherit version;
    src = pkgs.fetchurl {
      url = "https://downloads.claude.ai/claude-code-releases/${version}/linux-x64/claude";
      sha256 = "56fe3da88458465fb27d7e9299dddb3fead55750fb9c2de795f233b5eea6dce1";
    };
  });
in
{
  environment.systemPackages = [ claude-code ];
}
