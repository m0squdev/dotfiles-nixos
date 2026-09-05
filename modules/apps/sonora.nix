# Sonora — a native music streaming client (Rust + GPUI, the same UI framework
# Zed uses). Streams Spotify and YouTube Music and plays local files from one
# app. Not in nixpkgs, so it comes from upstream's own flake.
#
# WHY `builtins.getFlake` AND NOT A FLAKE INPUT: upstream's flake.lock is
# COMPLETE (it pins both of its inputs, nixpkgs and rust-overlay), so pure
# evaluation resolves it without help — the failure mode that forced
# ./claude-desktop.nix into ../../flake.nix does not apply here. That keeps the
# fetch lazy: a host that doesn't import this module never pulls Sonora. See
# ../../CLAUDE.md for the rule.
#
# We consume upstream's Home Manager module too (`programs.sonora`), and unlike
# ./zen.nix that does NOT drag in a version-skew problem: this module touches no
# Home Manager internals beyond `lib.hm.dag`, so it does not need to resolve to
# the same Home Manager that evaluates our user config. Hence no `follows`, and
# hence getFlake is still enough.
#
# WHAT THE PIN BUYS: upstream's flake does not build the Rust source — it
# fetchurl's the tagged RELEASE BINARY and patchelf's it against Nix libraries.
# So the rev below selects a Sonora version (currently 0.30.0) and nothing else.
# Bump it to upgrade. Note the rev is a MAIN commit, not the v0.30.0 tag:
# upstream tags the release first and bumps the version+hash in flake.nix just
# after, so the tag itself still packages the previous release.
#
# Audio: the binary talks ALSA, and upstream's HM module points ALSA_PLUGIN_DIR
# at a pipewire + alsa-plugins symlinkJoin built from OUR pkgs — so it routes
# through the PipeWire in ../core/audio.nix rather than a second copy.
{ ... }:
let
  sonora = builtins.getFlake
    "github:nolight132/sonora/be62f73ee44cf4955ebedfdb25780f82248c9c33";

  # Catppuccin Mocha. Sonora ships no Catppuccin theme and none of its nine
  # built-ins is close, but `appearance.theme_overrides` exposes every colour
  # role the renderer has, so the palette can be mapped on wholesale.
  mocha = {
    base = "#1e1e2e";
    mantle = "#181825";
    crust = "#11111b";
    surface0 = "#313244";
    surface1 = "#45475a";
    surface2 = "#585b70";
    overlay0 = "#6c7086";
    overlay1 = "#7f849c";
    text = "#cdd6f4";
    red = "#f38ba8";
    maroon = "#eba0ac";
    mauve = "#cba6f7"; # the repo's accent — niri's focus ring, Zen's theme
  };
in
{
  home-manager.users.valer = {
    imports = [ sonora.homeManagerModules.default ];

    programs.sonora.enable = true;

    # ONLY theme_overrides is pinned here, deliberately. Upstream's module
    # merges whatever `settings` names into ~/.config/sonora/settings.json on
    # every switch AND re-merges it on every launch, so any key set here stops
    # sticking when changed in Sonora's own settings screen (the same trap as
    # config/fcitx5/profile, except opt-in). Keeping the block down to the
    # palette leaves every other preference — provider, gapless, font, startup
    # screen, volume — live and editable in the UI. Add a key only when you want
    # it re-asserted; `provider` ("spotify" by default, or "youtube") is the one
    # most likely to be worth pinning.
    #
    # Nothing else needs pinning to hold the theme, because overrides are the
    # LAST word in Theme::for_look: the base theme is built from the selected
    # kind, the album-art tint is washed over it, and only then are these
    # colours stamped on top (upstream even tests that — `overrides_win_over_
    # the_tint`). Since all 30 colour roles are covered below, the theme picker
    # and the adaptive-theme toggle keep working but have nothing left to
    # repaint. That is why neither `theme` nor `adaptive_theme` is set.
    #
    # Also left unpinned: theme_overrides.radius and .font_size, which would
    # otherwise freeze the rounding and font-size controls.
    #
    # Colours parse as #rrggbb or #rrggbbaa (theme.rs parse_color); the 8-digit
    # ones below carry alpha that the stock dark theme also uses. Roles are
    # mapped against Theme::dark() — e.g. its `primary` is white, the CTA
    # colour, so it becomes mauve rather than anything literally white.
    programs.sonora.settings.appearance.theme_overrides = with mocha; {
      background = base;
      foreground = text;
      border = surface0;
      muted = surface0;
      overlay = "${crust}8c"; # scrim; 0x8c alpha kept from the dark theme
      overlay_foreground = text;
      muted_foreground = overlay1;

      # Buttons and other raised surfaces, resting → hover → pressed.
      secondary = surface0;
      secondary_hover = surface1;
      secondary_active = surface2;

      # The accent. primary_foreground is what sits ON it, hence a dark crust
      # rather than the light text used everywhere else. primary_hover is the
      # one colour here that is off-palette: Catppuccin has no second mauve, so
      # it is mauve lightened just enough to register as a hover.
      primary = mauve;
      primary_foreground = crust;
      primary_hover = "#d5b3f9";

      # Destructive actions. The stock theme uses a dark red plate with pale
      # text; Catppuccin inverts that — a light red plate with dark text.
      danger = red;
      danger_foreground = crust;
      danger_hover = maroon;

      popover = mantle;
      popover_foreground = text;
      progress_bar = mauve;
      selection = "${mauve}4d"; # ~30% mauve behind selected text

      sidebar = mantle; # recessed against the base-coloured content area
      sidebar_accent = surface0;
      sidebar_border = surface0;
      title_bar_border = surface0;

      table_head = "${mantle}cc";
      table_head_foreground = overlay0; # dimmer than muted_foreground, as stock
      table_row_border = "${surface0}b3";
      table_hover = surface0;
      table_active = "${mauve}33";
      table_active_border = mauve;
    };

    # Sonora declares itself a handler for spotify: links (its desktop entry
    # carries MimeType=x-scheme-handler/spotify). Register it so those open
    # here. Lives in this module, not ../../home/xdg-mime.nix — see that file.
    xdg.mimeApps.defaultApplications."x-scheme-handler/spotify" = [ "sonora.desktop" ];
  };
}
