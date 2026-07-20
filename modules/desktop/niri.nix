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
