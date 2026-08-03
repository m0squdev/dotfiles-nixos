# Zen browser — not packaged in nixpkgs, so it comes from the community flake
# (github:0xc000022070/zen-browser-flake, a real input; see flake.nix for why).
#
# We used to just drop the wrapped package into environment.systemPackages.
# Now we drive Zen through the flake's Home Manager module so three things are
# declarative and reproducible across hosts: the Catppuccin theme, the address
# bar on top, and the new-tab button at the bottom.
#
# Why the HM module and not a hand-written user.js / chrome symlink: Zen stores
# its profile in ~/.config/zen/<RANDOM-prefix>.<name>/, and that directory does
# not exist until the first launch — so nothing can hard-code the path. The HM
# module (built on Home Manager's own mkFirefoxModule) instead OWNS
# profiles.ini and gives the profile a fixed, name-derived path, which is what
# makes this config valid on a fresh host and before Zen has ever run.
#
# Consequences worth knowing:
#   * On first switch this replaces any pre-existing profiles.ini (Home Manager
#     backs the old one up as profiles.ini.hm-bak). A profile Zen created on its
#     own — e.g. the initial "Default Profile" — is left on disk but no longer
#     the default; move its data over if you had anything in it. Close Zen
#     before rebuilding so it doesn't rewrite prefs on exit.
#   * `settings` below land in user.js (defaults re-asserted each launch); you
#     can still change them live in Zen's UI for the session — same caveat as
#     config/fcitx5/profile. Edit them here to make a change stick.
#   * The app is labelled "Zen Browser (Beta)" again (the flake's branding). The
#     old module re-wrapped only to drop "(Beta)"; that cosmetic override isn't
#     worth reintroducing on top of the HM module.
#
# The theme is the upstream Catppuccin "Mocha / Mauve" port (mauve #cba6f7 to
# match the niri focus ring), vendored under config/zen/mocha-mauve/. Its
# userChrome keys off `prefers-color-scheme: dark`. Zen is left in its default
# "system" theme (auto); the desktop advertises dark through the
# `color-scheme = prefer-dark` gsettings key set in ../../home/gtk.nix — the GTK
# settings.ini dark flag alone does NOT reach the xdg portal that Zen reads.
{ inputs, ... }:
let
  # config/zen/mocha-mauve/{userChrome.css,userContent.css,zen-logo-mocha.svg}
  theme = ../../config/zen/mocha-mauve;
  # Fixed profile name → deterministic path ~/.config/zen/zen/ (see header).
  profile = "zen";
in
{
  home-manager.users.valer = {
    imports = [ inputs.zen-browser.homeModules.beta ];

    programs.zen-browser = {
      enable = true;

      # Nix owns updates; the in-app updater can't write to the read-only store
      # anyway, so silence it.
      policies.DisableAppUpdate = true;

      # Make Zen honour the profiles.ini we generate. Home Manager writes that
      # file as a read-only /nix/store symlink; Firefox's "dedicated profile per
      # install" feature wants to stamp an [Install<hash>] section into it, fails
      # on the read-only file, and reacts by DELETING our profiles.ini and
      # creating a fresh random profile of its own — so the themed profile below
      # is silently ignored. MOZ_LEGACY_PROFILES=1 turns that feature off (the
      # same switch Debian/Snap use), so Zen just uses the Default=1 profile from
      # profiles.ini. Injected into the launcher via makeWrapper --set.
      env.MOZ_LEGACY_PROFILES = "1";

      profiles.${profile} = {
        id = 0; # id 0 ⇒ isDefault, and Default=1 in profiles.ini
        settings = {
          "zen.view.use-single-toolbar" = true; # address bar across the top
          "zen.view.show-newtab-button-top" = false; # new-tab button at the bottom
          # Reveal the exact-hex text field in the per-workspace theming picker
          # (off by default). There is NO pref for a "default workspace colour" —
          # that's stored per workspace when you pick it — so #1e1e2e has to be
          # typed into this field once the toggle exposes it.
          "zen.theme.gradient.show-custom-colors" = true;
          # mkFirefoxModule does NOT enable this for us; userChrome/userContent
          # below are inert without it.
          "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        };
        userChrome = builtins.readFile (theme + "/userChrome.css");
        userContent = builtins.readFile (theme + "/userContent.css");
      };
    };

    # userContent.css paints the new-tab page with zen-logo-mocha.svg loaded
    # from the profile's chrome/ dir (it has a remote fallback, but keep it
    # offline). The HM module only writes userChrome/userContent, so drop the
    # logo in alongside them — the path is fixed because we named the profile.
    home.file.".config/zen/${profile}/chrome/zen-logo-mocha.svg".source =
      theme + "/zen-logo-mocha.svg";
  };
}
