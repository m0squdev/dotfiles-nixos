# Zen browser — not packaged in nixpkgs, so it is pulled from the community-
# maintained flake (which wraps Zen's official binary release).
#
# `.beta-unwrapped` is Zen's STABLE "Release build" (currently 1.21.6b, straight
# from zen-browser/desktop releases/latest). The flake confusingly names this
# variant "beta" and, via wrapFirefox, stamps "Zen Browser (Beta)" into the app
# name. We override applicationName back to plain "Zen Browser" and re-wrap using
# the flake's OWN nixpkgs (so wrapFirefox matches the unwrapped build — no skew).
# The actual nightly channel is `.twilight`; we do NOT use it.
#
# Pinned to a specific rev for reproducibility — bump this rev to update Zen,
# or drop the "/<rev>" suffix to auto-follow the flake's main branch.
#
# NOTE: the builtins.getFlake below runs at *evaluation* time. Because Zen lives
# in its own module, that flake fetch only happens on hosts that actually import
# this file — drop the import and there is zero Zen-related work.
{ pkgs, ... }:
let
  zenSystem = pkgs.stdenv.hostPlatform.system;
  zenFlake =
    builtins.getFlake
    "github:0xc000022070/zen-browser-flake/51602966429e8ccae61324e56b51c37308d1b64e";
  zen-browser =
    zenFlake.inputs.nixpkgs.legacyPackages.${zenSystem}.wrapFirefox
    (zenFlake.packages.${zenSystem}.beta-unwrapped.override {
      applicationName = "Zen Browser"; # drop the misleading "(Beta)" label
    })
    { icon = "zen-browser"; };
in
{
  environment.systemPackages = [ zen-browser ];
}
