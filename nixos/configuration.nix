# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

let
  # Zen browser is not packaged in nixpkgs, so it is pulled from the
  # community-maintained flake (which wraps Zen's official binary release).
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
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "valerios-nix"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Rome";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_GB.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_GB.UTF-8";
    LC_IDENTIFICATION = "en_GB.UTF-8";
    LC_MEASUREMENT = "en_GB.UTF-8";
    LC_MONETARY = "en_GB.UTF-8";
    LC_NAME = "en_GB.UTF-8";
    LC_NUMERIC = "en_GB.UTF-8";
    LC_PAPER = "en_GB.UTF-8";
    LC_TELEPHONE = "en_GB.UTF-8";
    LC_TIME = "en_GB.UTF-8";
  };

  # Japanese (and any) input method via fcitx5 + Mozc. fcitx5 is the smoother
  # choice than ibus on Wayland/niri; waylandFrontend makes it use niri's
  # text-input protocol. Mozc gives kanji conversion + prediction and hiragana/
  # katakana modes. fcitx5 is autostarted from ~/.config/niri/config.kdl; the
  # input methods + toggle key live in ~/.config/fcitx5/. NOTE: do NOT also add
  # fcitx5 to environment.systemPackages — that breaks Mozc addon detection.
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.waylandFrontend = true;
    fcitx5.addons = with pkgs; [
      fcitx5-mozc                    # Japanese: Mozc engine (kanji, prediction, kana)
      fcitx5-gtk                     # GTK app integration
      kdePackages.fcitx5-configtool  # GUI to tweak fcitx5 / Mozc
    ];
  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "intl";
  };

  # Configure console keymap
  console.keyMap = "us-acentos";

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users."valer" = {
    isNormalUser = true;
    description = "Valerio";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
    #  thunderbird
    ];
  };

  # Install firefox.
  programs.firefox.enable = true;

  # Install KDE Connect
  programs.kdeconnect.enable = true;

  # Syncthing: continuous file sync, run as a systemd service under `valer`.
  # The SERVICE is fully declarative (this block); the actual devices and folders
  # are paired in the Web GUI at http://127.0.0.1:8384 and stored in
  # ~/.config/syncthing (which holds this machine's PRIVATE key, a per-machine
  # secret that's never committed). overrideDevices/overrideFolders are false so
  # a rebuild never wipes what you set up in the GUI.
  services.syncthing = {
    enable = true;
    user = "valer";
    group = "users";
    dataDir = "/home/valer";                      # default "~/Sync" folder lives here
    configDir = "/home/valer/.config/syncthing";  # config + keys where you'd expect them
    openDefaultPorts = true;                       # 22000/tcp+udp (sync) + 21027/udp (discovery)
    overrideDevices = false;                       # let the GUI own device pairing
    overrideFolders = false;                       # let the GUI own folder config
  };

  # Theme Qt/KDE apps (kdeconnect-app, etc.) with Catppuccin Mocha via Kvantum.
  # This installs qt5ct + qt6ct AND the Kvantum style engine for BOTH Qt5 & Qt6,
  # and — crucially on NixOS — wires QT_PLUGIN_PATH so those plugins are actually
  # found (a bare environment.systemPackages install does not). It also sets
  # QT_STYLE_OVERRIDE=kvantum. The Kvantum *theme* itself (catppuccin-kvantum) is
  # added in environment.systemPackages below and selected in
  # ~/.config/Kvantum/kvantum.kvconfig; ~/.config/niri/config.kdl overrides
  # QT_QPA_PLATFORMTHEME to qt6ct so Qt6 apps use qt6ct for icons/fonts.
  qt = {
    enable = true;
    platformTheme = "qt5ct";   # installs qt5ct + qt6ct, wires QT_PLUGIN_PATH
    style = "kvantum";         # installs Kvantum (Qt5 + Qt6) + sets QT_STYLE_OVERRIDE
  };

  # Install Niri
  programs.niri.enable = true;
  services.displayManager.defaultSession = "niri";

  # --- niri desktop: fonts + swaylock PAM (added to match the niri README look) ---

  # Nerd Font so waybar/fuzzel icons (glyphs) render correctly.
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
  ];

  # Let the lockers authenticate against PAM so they can actually unlock the session.
  security.pam.services.swaylock = { };  # fallback locker
  security.pam.services.hyprlock = { };  # hyprlock: primary lock screen

  # --- NVIDIA GTX 1650 (TU117, Turing): use the proprietary driver, not nouveau ---
  # Nouveau can't reliably resume this card from S3 suspend — it hangs the compositor
  # on wake, leaving a frozen wallpaper + dead cursor (the freeze that forced the hard
  # reboot). The proprietary driver + powerManagement (which sets
  # NVreg_PreserveVideoMemoryAllocations and enables the nvidia-suspend/resume services
  # to save & restore VRAM across suspend) makes resume reliable.
  hardware.graphics.enable = true;

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;      # required for Wayland / niri
    powerManagement.enable = true;  # preserve VRAM across suspend -> reliable resume
    open = false;                   # proprietary kernel module (most-tested on Turing)
    nvidiaSettings = true;          # provides the nvidia-settings GUI
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # --- GNOME Console (kgx): Catppuccin Mocha terminal palette ---
  # kgx 50 has no UI or config key for the terminal colour palette; the palette is
  # hardcoded in its C source as "liveries". Its custom-livery loader is also broken
  # on this system's GLib 2.88: it iterates the a{sv} custom-liveries dict with the
  # tuple format string "(&sv)" instead of the dict-entry "{&sv}", which modern GLib
  # rejects — so user liveries set via GSettings/dconf never load and kgx always falls
  # back to its built-in palette. We therefore patch the built-in fallback livery to
  # Catppuccin Mocha (and fix the loader bug) so kgx renders Mocha out of the box.
  # Patch file: ./kgx-catppuccin-mocha.patch (keep it next to this configuration.nix).
  nixpkgs.overlays = [
    (final: prev: {
      gnome-console = prev.gnome-console.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ./kgx-catppuccin-mocha.patch ];
      });
    })
  ];

  # Enable Nix flakes (required to pull the Zen browser flake in the let-binding above).
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
  #  wget
    claude-code
    git

    zen-browser     # Zen browser (from the flake pinned in the let-binding above)
    vesktop
    stremio-linux-shell   # Stremio media center (native GTK/webkit shell; old qt5 `stremio` was removed from nixpkgs 2026-02)
    geary
    obsidian        # Markdown knowledge base / notes
    libreoffice     # office suite (GTK build, follows the Catppuccin GTK theme)

    # --- niri desktop helpers ---
    waybar          # status bar
    fuzzel          # application launcher (Mod+D)
    swaybg          # wallpaper
    # Screen lockers. hyprlock is the primary (minimal Catppuccin Mocha lock screen,
    # config in ~/.config/hypr/). swaylock-effects is kept as a fallback that
    # `lock.sh` falls back to if hyprlock is ever unavailable.
    hyprlock                  # primary lock screen (Mod+L)
    swaylock-effects          # fallback locker (swaylock fork; binary is `swaylock`)
    swayidle
    playerctl       # media keys
    brightnessctl   # brightness keys
    swaynotificationcenter  # notifications + quick-settings panel (swaync)
    swayosd
    sound-theme-freedesktop
    cliphist        # clipboard history store (Mod+V picker via fuzzel)
    wl-clipboard    # wl-copy / wl-paste — used by cliphist + the picker script

    # --- Catppuccin Mocha theming ---
    (catppuccin-gtk.override {
      accents = [ "mauve" ];   # accent used across the whole setup
      variant = "mocha";
      size = "standard";
      tweaks = [ "normal" ];
    })
    adw-gtk3                    # lets GTK3 apps follow the theme cleanly
    papirus-icon-theme         # Papirus-Dark icons (pairs well with Catppuccin)
    catppuccin-cursors.mochaDark
    # Kvantum theme for Qt/KDE apps (matches the mauve accent). The Kvantum ENGINE
    # + qt5ct/qt6ct come from the `qt = { … }` block above; this is just the theme
    # it renders. Provides "catppuccin-mocha-mauve", selected in ~/.config/Kvantum/.
    (catppuccin-kvantum.override { accent = "mauve"; variant = "mocha"; })
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "26.05"; # Did you read the comment?

}
