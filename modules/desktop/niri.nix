# niri: scrollable-tiling Wayland compositor + its ecosystem of helper tools
# (status bar, launcher, lockers, OSD, notifications, media/brightness keys,
# clipboard, emoji picker). The user-level config for all of these is laid down
# by Home Manager from this repo's config/* (see ../../home/).
{ pkgs, ... }:
{
  programs.niri.enable = true;
  services.displayManager.defaultSession = "niri";

  # Let the lockers authenticate against PAM so they can actually unlock.
  security.pam.services.swaylock = { };  # fallback locker
  security.pam.services.hyprlock = { };  # hyprlock: primary lock screen

  # niri, unlike the GNOME session, starts NO polkit authentication agent, so any
  # polkit action that needs interactive auth is refused outright with no prompt.
  # The one that bites here is fingerprint *enrolment*: fprintd's enroll defaults
  # to `auth_self_keep`, so `fprintd-enroll` dies with PermissionDenied until an
  # agent exists to ask for the password. (Fingerprint *verify* is `allow_active=
  # yes` and needs none — that is why unlocking works once a finger is enrolled.)
  # GUI mount / network / bluetooth helpers hit the same wall.
  #
  # polkit_gnome is a standalone GTK3 agent — not tied to gnome-shell — which is
  # the agent niri's own docs recommend first. GTK keeps the auth dialog on the
  # same toolkit and Catppuccin theming as the rest of the session, and GNOME
  # already pulls its deps into the closure; the Qt agents (hyprpolkitagent,
  # lxqt-policykit) would add a second toolkit for nothing.
  #
  # Bound to niri.service, NOT graphical-session.target: the GNOME session on this
  # same machine already has gnome-shell's built-in agent, and niri.service only
  # runs in a niri session, so this avoids two agents racing to register for one.
  systemd.user.services.niri-polkit-agent = {
    description = "polkit authentication agent for the niri session";
    wantedBy = [ "niri.service" ];
    partOf = [ "niri.service" ];
    after = [ "niri.service" ];
    serviceConfig = {
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = 1;
    };
  };

  environment.systemPackages = with pkgs; [
    waybar                    # status bar
    fuzzel                    # application launcher (Mod+D)
    swaybg                    # wallpaper
    # Screen lockers. hyprlock is the primary (minimal Catppuccin Mocha lock
    # screen, config in ~/.config/hypr/). swaylock-effects is the fallback that
    # lock.sh uses if hyprlock is ever unavailable.
    hyprlock                  # primary lock screen (Mod+L)
    swaylock-effects          # fallback locker (swaylock fork; binary is `swaylock`)
    swayidle
    playerctl                 # media keys
    brightnessctl             # brightness keys
    swaynotificationcenter    # notifications + quick-settings panel (swaync)
    swayosd
    sound-theme-freedesktop
    cliphist                  # clipboard history store (Mod+V picker via fuzzel)
    wl-clipboard              # wl-copy / wl-paste — used by cliphist + the picker
    rofimoji                  # emoji / character picker (Mod+. via fuzzel)
    wtype                     # synthetic typing on Wayland — rofimoji types the glyph
  ];
}
