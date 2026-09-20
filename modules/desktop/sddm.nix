# SDDM — the login manager, themed Catppuccin Mocha (mauve accent).
#
# WHY NOT GDM, WHICH THIS REPLACED: GDM's greeter *is* gnome-shell, and its
# entire appearance lives inside `gnome-shell-theme.gresource` — a compiled
# binary blob. The only hook NixOS exposes declaratively is
# `programs.dconf.profiles.gdm.databases` (GDM's own module uses it for the
# banner and autoSuspend), and through it the greeter reads cursor theme, icon
# theme, font and `org/gnome/desktop/interface accent-color`. That accent is an
# ENUM — blue, teal, green, yellow, orange, red, pink, purple, slate — with no
# custom hex, so mauve is simply not expressible; there is no wallpaper key
# either, and no way to reach base/surface. Real Catppuccin would have meant
# repacking that gresource in an overlay, i.e. rebuilding gnome-shell and
# re-cutting the patch at every GNOME bump. ./theming.nix accepts exactly that
# cost for kgx, but only because kgx leaves no alternative. Here one exists.
#
# WHY THE THEME IS WRITTEN HERE AND NOT TAKEN FROM NIXPKGS: two packaged ones
# were tried first and both were rejected on looks. `catppuccin-sddm` is the
# obvious pick by name, but it draws a bare three-field form on an unblurred
# wallpaper and hardcodes the power buttons to Mocha RED in every accent
# variant, so two accents fight on one screen. `catppuccin-sddm-corners` is
# tidier and fully config-driven, but it is still someone else's layout. The
# rest of the field is thinner than it looks — nixpkgs has sddm-astronaut (ten
# illustrated variants, none Catppuccin), elegant-sddm, sddm-chili-theme,
# sddm-sugar-dark and where-is-my-sddm-theme, and none of them resembles this
# setup either.
#
# The design that was actually wanted already existed in this repo: the
# hyprlock screen. So ./sddm-theme/Main.qml is a login-screen twin of
# ../../config/hypr/hyprlock.conf — same blurred wallpaper, same clock hard
# against the top-right with the long-form date under it, same single centred
# field with a thick accent outline. Lock screen and login screen are now the
# same picture, which is the thing no third-party theme could give.
#
# GNOME ITSELF IS UNAFFECTED — ./gnome.nix still installs the GNOME session and
# its apps, and `services.displayManager.defaultSession = "niri"` still comes
# from ./niri.nix. Both sessions stay pickable from the greeter's session menu.
#
# gnome-keyring still unlocks at login: SDDM's PAM `auth` stack substacks
# `login`, and services.gnome.gnome-keyring sets
# `security.pam.services.login.enableGnomeKeyring = true`. Nothing to wire here.
#
# TO PREVIEW A CHANGE WITHOUT REBOOTING — the greeter runs standalone against a
# headless X server, which is how every value below was chosen and measured:
#
#   Xvfb :99 -screen 0 1920x1080x24 &
#   DISPLAY=:99 QT_QPA_PLATFORM=xcb sddm-greeter-qt6 --test-mode \
#     --theme /run/current-system/sw/share/sddm/themes/mocha-lock
#   DISPLAY=:99 import -window root /tmp/preview.png
#
# It also runs as a plain window inside a normal session, which is the quickest
# way to eyeball one:
#
#   sddm-greeter-qt6 --test-mode \
#     --theme /run/current-system/sw/share/sddm/themes/mocha-lock
#
# The LOCK screen can be rendered the same way, which is how the two were
# matched pixel for pixel: run a throwaway nested niri on the headless X server
# (it needs libXcursor/libXi/libXrandr on LD_LIBRARY_PATH for winit's X11
# backend) and point hyprlock at its WAYLAND_DISPLAY. That locks only the
# nested instance, never the real session.
{ lib, pkgs, ... }:
let
  # Catppuccin Mocha, mauve accent — the same palette the rest of the setup
  # names in ../../config/fuzzel/fuzzel.ini and ../../config/hypr/mocha.conf.
  mocha = {
    base = "#1e1e2e";
    surface0 = "#313244";
    subtext0 = "#a6adc8";
    text = "#cdd6f4";
    mauve = "#cba6f7";
    red = "#f38ba8";
    yellow = "#f9e2af";
  };

  # One source of truth for the pointer, used by all THREE mechanisms below.
  # Same values ../../config/niri/base.kdl and ../../config/gtk-3.0/settings.ini
  # name, so it keeps its shape across greeter, session and lock screen.
  cursor = {
    theme = "Bibata-Catppuccin-Mocha";
    size = 24;
  };

  # The X resource database fragment that actually does the theming — see the
  # setupCommands note further down for why this, and not the other two, is
  # what works.
  cursor-xresources = pkgs.writeText "sddm-xresources" ''
    Xcursor.theme: ${cursor.theme}
    Xcursor.size: ${toString cursor.size}
  '';

  # The greeter cannot read the user's wallpaper. ../../home/dotfiles.nix puts a
  # copy at ~/.local/share/backgrounds/wall.jpg, but the greeter runs as the
  # unprivileged `sddm` user, which has no access under /home/valer — so the
  # image has to come from the store, where it is world-readable.
  #
  # It is blurred on the way in, because the login screen is the one place the
  # wallpaper sits *behind text*. Unblurred, this particular image's bright
  # streaks cut straight through the clock; blurred it reads as a backdrop. Same
  # reason ../../config/hypr/hyprlock.conf sets blur_passes = 2 on the very same
  # picture, so the lock screen and the login screen now match.
  #
  # RADIUS IS TIED TO THE SOURCE RESOLUTION, not to any display: blurring scales
  # with pixel count, so a radius picked while looking at a downscaled 1080p
  # preview has to be doubled to look the same on this 3840x2160 original. 28 is
  # that doubled value. Keep the blur proportional to the source if the
  # wallpaper is ever swapped for one of a different size, and re-preview.
  blurred-wallpaper =
    pkgs.runCommand "wall-blurred.jpg"
      { nativeBuildInputs = [ pkgs.imagemagick ]; }
      ''
        magick ${../../assets/wallpapers/wall.jpg} -blur 0x28 -quality 92 "$out"
      '';

  # Every visual choice in the greeter, as data. ./sddm-theme/Main.qml reads
  # these and nothing else, so re-colouring or re-sizing the login screen is an
  # edit to this block — the QML never has to be touched.
  #
  # The numbers are hyprlock's, read straight off
  # ../../config/hypr/hyprlock.conf so the two screens line up: font_size 90 for
  # the time and 25 for the date, a 300x60 input field, outline_thickness 4, and
  # a 30px margin from the screen edge.
  theme-conf = pkgs.writeText "theme.conf" ''
    [General]
    Background="${blurred-wallpaper}"
    Font="JetBrainsMono Nerd Font"

    Base="${mocha.base}"
    Surface0="${mocha.surface0}"
    Text="${mocha.text}"
    Subtext0="${mocha.subtext0}"
    Accent="${mocha.mauve}"
    Red="${mocha.red}"
    Yellow="${mocha.yellow}"

    Margin="30"
    TimeSize="90"
    DateSize="25"

    # hyprlock's `size`, `position = 0, -20` and outline_thickness = 4,
    # verbatim — ../../config/hypr/hyprlock.conf carries the same 270x54.
    # The field's corner radius is NOT a key: hyprlock leaves `rounding` at -1,
    # which means min(w,h)/2, so Main.qml derives a pill from the height
    # instead of taking a number here.
    FieldWidth="270"
    FieldHeight="54"
    FieldOffsetY="20"
    OutlineWidth="4"

    # The placeholder line. hyprlock computes its placeholder at
    # (int)(size.y / 4) = 13, but that 13 is POINTS (see the note on TimeSize
    # below), so 13 * 4/3 = 17 pixels here.
    FieldFontSize="17"
    StatusFontSize="16"

    # The masking dots are drawn as CIRCLES by ./sddm-theme/Main.qml rather than
    # as font glyphs, so these are hyprlock's own numbers instead of font sizes
    # measured to imitate them. From PasswordInputField.cpp, with this config's
    # dots_size = dots_spacing = 0.2:
    #   DotSize      nearbyint(FieldHeight * 0.2 * 0.5) * 2 = 10 at height 54
    #   DotsSpacing  floor(DotSize * 0.2)                   = 2
    # Both derive from FieldHeight, so recompute them if the field is resized.
    DotSize="10"
    DotsSpacing="2"

    # How long the dot count takes to catch up with what has been typed.
    # hyprlock animates dots.currentAmount through its "inputFieldDots" node,
    # which inherits the global default (speed 8, "default" curve); Main.qml
    # animates the same quantity, which reproduces both the fade-in of the
    # newest dot and the row re-centring as it grows.
    DotsAnimationMs="150"

    # Qt's syntax for hyprlock's `date +"%A, %d %B %Y"` and its 24-hour $TIME.
    TimeFormat="HH:mm"
    DateFormat="dddd, d MMMM yyyy"
  '';

  sddm-theme =
    pkgs.runCommand "sddm-mocha-lock-theme" { }
      ''
        d="$out/share/sddm/themes/mocha-lock"
        mkdir -p "$d"
        cp ${./sddm-theme/Main.qml} "$d/Main.qml"
        cp ${./sddm-theme/metadata.desktop} "$d/metadata.desktop"
        cp ${theme-conf} "$d/theme.conf"
      '';
in
{
  # SDDM's NixOS module writes `Theme.ThemeDir =
  # "/run/current-system/sw/share/sddm/themes"` and `Theme.Current = <the string
  # below>`, so the theme is selected BY NAME and the package has to be in
  # environment.systemPackages for that directory to contain it. Installing the
  # package without setting `theme`, or setting `theme` without installing the
  # package, both leave you on the stock greeter.
  environment.systemPackages = [ sddm-theme ];

  services.displayManager.sddm = {
    enable = true;
    theme = "mocha-lock";   # dir name created by the derivation above

    # DELIBERATELY NO `extraPackages` HERE, and it is worth knowing why, because
    # the failure it guards against is silent. A theme whose QML imports a
    # module missing from the greeter's import path is simply "unavailable", and
    # SDDM falls back to its stock greeter with nothing in the journal but a QML
    # warning — no failed unit, just the wrong login screen. The packaged
    # catppuccin-sddm-corners tripped exactly this on `import
    # Qt5Compat.GraphicalEffects`, and `propagatedBuildInputs` does not help:
    # propagation reaches the system profile, not the greeter's QML path.
    #
    # ./sddm-theme/Main.qml imports only QtQuick, QtQuick.Window and
    # QtQuick.Controls — all in qtdeclarative, which SDDM already carries. Its
    # wallpaper is pre-blurred by Nix instead of by Qt5Compat, and its icons are
    # Nerd Font glyphs rather than SVGs needing qtsvg's image plugin. So there
    # is nothing to add. RE-ADD `extraPackages` the moment the QML gains an
    # import outside that set, or the greeter will quietly revert.

    # The GREETER runs on X11 — the module default. The sessions it launches,
    # niri and GNOME, are Wayland regardless; this is only the login screen.
    #
    # TRIED AND REVERTED, worth revisiting: `wayland.enable = true` works — the
    # greeter came up under Weston, the theme loaded, and login and keyring
    # unlock both succeeded. It was backed out for one reason: the mouse pointer
    # was INVISIBLE under Weston's kiosk shell.
    #
    # That is a known upstream bug, https://github.com/sddm/sddm/issues/1996,
    # and note that the cursor fix below CANNOT carry over — there is no
    # RESOURCE_MANAGER property under Wayland, so the xrdb approach simply does
    # nothing there and the pointer needs solving another way. That is the thing
    # to check first if this is ever switched back on.
  };

  # XCURSOR_PATH is what lets libXcursor FIND the theme; the name it looks for
  # comes from the X resource set in setupCommands below. Both halves are
  # needed. A systemd service inherits none of /etc/pam/environment — its unit
  # env is just PATH, TZDIR and LOCALE_ARCHIVE — and libXcursor's compiled-in
  # fallbacks (/usr/share/icons, ~/.icons) do not exist on NixOS, so without
  # this the theme is unreachable under any name. The daemon passes this
  # environment down to the greeter it spawns.
  systemd.services.display-manager.environment = {
    XCURSOR_PATH = "/run/current-system/sw/share/icons";
    XCURSOR_THEME = cursor.theme;
    XCURSOR_SIZE = toString cursor.size;

    # WITHOUT THIS THE GREETER SILENTLY RUNS AN OLD THEME. Qt compiles QML to
    # .qmlc bytecode and caches it under the greeter's home (/var/lib/sddm),
    # then validates the cache by comparing the SOURCE FILE'S MTIME against the
    # one recorded in the cache. Every file in the Nix store has mtime
    # 1970-01-01 01:00:01, so every version of ./sddm-theme/Main.qml looks
    # identical to that check and the first cached compile is reused forever.
    #
    # The failure is invisible and deeply confusing, because theme.conf is
    # parsed by SDDM's own C++ and never cached: sizes, colours and formats all
    # update on rebuild while everything structural in the QML — a new widget,
    # an animation, a changed property — silently does not. Worse, the stale
    # QML goes on reading theme.conf keys that have since been removed, so it
    # also starts rendering subtly wrong.
    #
    # Disabling the disk cache costs a recompile of one ~500-line file at each
    # greeter start, which is nothing, and makes a rebuild mean what it says.
    QML_DISABLE_DISK_CACHE = "1";
  };

  # THE ONE THAT ACTUALLY THEMES THE POINTER, and not an obvious one. Two other
  # mechanisms look like they should and do not: sddm.conf's Theme.CursorTheme
  # is only consulted by themes that read `config.CursorTheme` in their own QML
  # (Breeze does, this one does not), and XCURSOR_THEME is not what Qt's xcb
  # backend resolves against. That backend goes through libXcursor, which takes
  # the theme NAME from the `Xcursor.theme` X RESOURCE — read out of the
  # server's RESOURCE_MANAGER property, which is empty unless something loads
  # it. Nothing did, so the greeter fell back to the X core cursor font: an
  # unthemed 10x16 arrow, and an unthemed I-beam over the password field that is
  # very easy to mistake for a text caret.
  #
  # setupCommands runs on the greeter's display before the greeter starts, which
  # is the one place this can be set. Confirmed as the fix on NixOS Discourse:
  # https://discourse.nixos.org/t/sddm-ignoring-cursor-theming/71645
  #
  # (xrdb needs a preprocessor, but nixpkgs bakes an mcpp path into the binary,
  # so it does not depend on cpp being on the unit's PATH.)
  services.xserver.displayManager.setupCommands = ''
    ${pkgs.xrdb}/bin/xrdb -merge ${cursor-xresources}
  '';

  # xsetroot, for the root window cursor specifically. SDDM does not set that
  # through a library call — XorgDisplayServer.cpp runs `xsetroot -cursor_name
  # left_ptr` as a SUBPROCESS. The display-manager unit's PATH is only
  # coreutils, findutils, gnugrep, gnused and systemd, so the binary was never
  # found, QProcess failed to start it, and the journal logged "Could not setup
  # default cursor" on every boot. That covers the moments before the greeter's
  # own window is up, and anywhere its QML sets no cursor shape.
  systemd.services.display-manager.path = [ pkgs.xsetroot ];

  # SDDM asserts that either services.xserver.enable or its own wayland.enable
  # is on. ./gnome.nix already enables the X server for the GNOME session, so
  # this is normally redundant — mkDefault makes it a safety net that keeps this
  # module standing on its own if that import is ever dropped, without
  # conflicting with gnome.nix's own definition.
  services.xserver.enable = lib.mkDefault true;
}
