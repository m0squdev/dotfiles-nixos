# Fingerprint reader — Elan `04f3:0c00`, reported by lsusb as "ELAN:ARM-M4".
#
# WHY THIS MODULE EXISTS AT ALL: upstream libfprint does not drive this sensor.
# It is a match-on-chip ("moc") reader, but NOT one of the models handled by
# libfprint's in-tree `elanmoc` driver — that one covers a different, older
# protocol. Stock libfprint therefore enumerates nothing, `fprintd-enroll` exits
# with "No devices available", and GDM shows no fingerprint option. This is the
# same reason the Arch install needed the AUR `libfprint-elanmoc2-git` instead of
# the repo `libfprint`; nothing changed except how the swap is expressed.
#
# THE FIX: Davide Depau's `elanmoc2` branch of libfprint, which adds a second
# Elan match-on-chip driver whose device table includes 0x0c00 (see
# libfprint/drivers/elanmoc2/elanmoc2.c). It is a work-in-progress branch that
# has never been merged upstream, so there is no released version to track —
# hence the pinned commit below.
#
# SCOPE OF THE SWAP: only fprintd is rebuilt against it, via `.override`, rather
# than an `nixpkgs.overlays` entry replacing libfprint for the whole closure.
# fprintd is libfprint's only real consumer here, so the overlay would buy
# nothing and would rebuild anything that ever grows a libfprint dependency.
# (Same reasoning as the bluez pin in ../core/bluetooth.nix.)
#
# The fetch below runs at EVALUATION time, so keeping it in its own module means
# a host without this reader pays nothing — drop the import and the fetch never
# happens (the rationale CONTRIBUTING.md gives for ../apps/zen.nix).
#
# TO CHECK WHETHER UPSTREAM HAS CAUGHT UP: comment out the `package` line and
# rebuild. If `fprintd-enroll` finds the reader with plain pkgs.fprintd, the
# driver landed upstream and this whole module can go.
{ pkgs, ... }:
let
  # Pinned to the elanmoc2 branch head as of 2025-07-27 ("WIP add 0c7c") — the
  # exact commit the working Arch build used. Bump the rev to update; there are
  # no tags on this branch.
  libfprint-elanmoc2 = pkgs.libfprint.overrideAttrs (old: {
    version = "1.94.0-elanmoc2-unstable-2025-07-27";
    src = builtins.fetchGit {
      url = "https://gitlab.freedesktop.org/Depau/libfprint.git";
      ref = "elanmoc2";
      rev = "11f0316d069cc90c154c8cb0e46478388c5e2a74";
    };
    # nixpkgs pins libfprint 1.94.10 and carries five fetchpatch'd upstream
    # commits that add newer device IDs (0c9c, 0c58, the Focal/Realtek ones).
    # They are cut against that tarball and do not apply to this older tree —
    # and none of them adds 0c00 anyway, which is exactly why the fork is here.
    patches = [ ];

    # nixpkgs runs libfprint's test suite AFTER install (it sets doCheck = false
    # and doInstallCheck = true), and two of its 124 tests fail on this branch.
    # Both are stale expectations in the branch, not broken code — the driver and
    # the library compile and link cleanly, all 152 targets:
    #
    #   * data+no-valgrind / udev-hwdb — tests/test-generated-hwdb.sh regenerates
    #     the autosuspend hwdb from the driver tables and diffs it against the
    #     copy committed in data/. The branch adds device IDs without
    #     regenerating that committed copy, so the diff is non-empty by
    #     construction. It is only the in-tree reference file that is stale: the
    #     hwdb actually INSTALLED is generated at build time and does list this
    #     sensor (verified — see below), so nothing is lost by skipping it.
    #
    #   * unit-tests / fpi-device — test_driver_initial_features_no_storage
    #     asserts FP_DEVICE_FEATURE_STORAGE stays unset for a fake device class
    #     with ->delete == NULL. The branch deliberately changed
    #     fpi_device_class_auto_initialize_features to infer STORAGE from the
    #     list/clear callbacks instead, which is what a match-on-chip reader like
    #     this one actually needs; the test was never updated to match.
    #
    # The AUR PKGBUILD this configuration replaces has no check() at all, so
    # the build that works on the Arch install never ran these either.
    #
    # This does NOT skip verifying the thing we care about. USB readers are
    # matched through the hwdb rather than 70-libfprint-2.rules (which carries
    # only the SPI rules), and the built package contains, generated straight
    # from the driver's device table:
    #
    #     $ grep -B1 0C00 lib/udev/hwdb.d/60-autosuspend-libfprint-2.hwdb
    #     # Supported by libfprint driver elanmoc2
    #     usb:v04F3p0C00*
    #
    # i.e. this exact sensor, bound to this exact driver. Re-run that check
    # after bumping the rev.
    doInstallCheck = false;

    # ...but the test env cannot simply go away with it. nixpkgs supplies
    # python3-with-pygobject3 via nativeInstallCheckInputs, which Nix only puts
    # in the build environment when doInstallCheck is true. tests/meson.build
    # runs tests/unittest_inspector.py (which imports gi) at CONFIGURE time to
    # enumerate the virtual-driver tests — it does that whether or not the suite
    # will later run — so dropping the input fails the build much earlier, at
    #     tests/meson.build:107: ERROR: Could not execute command
    #     `.../tests/unittest_inspector.py .../tests/virtual-image.py`
    # Carry the same inputs over into the build proper to keep configure working.
    nativeBuildInputs = old.nativeBuildInputs ++ old.nativeInstallCheckInputs;
  });
in
{
  services.fprintd = {
    enable = true;
    package = pkgs.fprintd.override { libfprint = libfprint-elanmoc2; };
  };

  # Keep the reader powered — do NOT let USB runtime-suspend it. libfprint ships
  # an autosuspend hwdb (60-autosuspend-libfprint-2.hwdb) that tags this sensor
  # ID_AUTOSUSPEND=1, so after ~2s idle the kernel suspends it and has to reset
  # it on the next access (visible as repeated `usb 1-7: reset full-speed USB
  # device … xhci_hcd` in dmesg). With this match-on-chip driver the reset lands
  # on the first swipe(s), which then read as "finger not recognized" — the exact
  # "works first try sometimes, fails many retries other times" flakiness. Pinning
  # power/control to "on" for just this device (04f3:0c00) stops the suspend, and
  # with it the reset-on-wake; the cost is a sliver of idle power. `add|change`
  # so it re-asserts if a bus reset re-emits a uevent.
  services.udev.extraRules = ''
    ACTION=="add|change", SUBSYSTEM=="usb", ATTR{idVendor}=="04f3", ATTR{idProduct}=="0c00", ATTR{power/control}="on"
  '';

  # Enrol a finger AFTER the first switch — the templates live on the sensor and
  # in /var/lib/fprint, neither of which this repo manages:
  #     fprintd-enroll        (repeat with -f for more fingers)
  #     fprintd-verify        (check it before relying on it to log in)
  #
  # PAM: enabling fprintd is enough. The NixOS PAM module defaults each service's
  # `fprintAuth` to services.fprintd.enable, so sudo and the lockers
  # (security.pam.services.hyprlock in ../desktop/niri.nix) all gain the finger
  # as an alternative to the password — never as a replacement, so a failed or
  # missing swipe still falls through to typing it.
  #
  # ...EXCEPT AT THE GREETER, where it has to be taken back out. This block used
  # to claim SDDM never saw pam_fprintd at all. It did, and it cost ten seconds
  # on every single login:
  #
  #   20:22:10.933  sddm: Message received from greeter: Login
  #   20:22:11.262  sddm: "Place your right index finger on the fingerprint reader"
  #   20:22:11.579  sddm: Message received from greeter: Login
  #   20:22:11.579  sddm: Existing authentication ongoing, aborting
  #   20:22:21.358  sddm-helper: [PAM] Preparing to converse...     <- 10.1s later
  #   20:22:21.638  sddm: Authentication for user "valer" successful
  #
  # The password was typed and Enter pressed at :10.9; PAM opened with
  # pam_fprintd, which waits out its whole verification timeout before failing
  # over to pam_unix, and only then was the password — already sitting in
  # sddm-helper's conversation buffer the entire time — actually checked. The
  # greeter went on taking input throughout (that second Login at :11.5 is a
  # user pressing Enter again because nothing had happened), and SDDM discards a
  # second Login while the first is outstanding, so that attempt was dropped on
  # the floor. Every symptom of "the login screen takes a while and isn't
  # frozen" is in those six lines, and none of it is niri or the session
  # starting: the greeter is stopped 0.1s after the password lands and the
  # session is up 0.9s after that.
  #
  # WHY IT REACHES SDDM AT ALL, since nothing here or in ../desktop/sddm.nix
  # mentions fingerprints: the NixOS sddm module does not write an auth stack of
  # its own. It sets `useDefaultRules = false` and exactly one rule, `auth
  # substack login` — so /etc/pam.d/sddm is whatever /etc/pam.d/login is,
  # fprintd included. That also makes `security.pam.services.sddm.fprintAuth =
  # false` a no-op: there is no fprintd rule in sddm's own rule set to turn off.
  # login's is the knob that works, hence the one below.
  #
  # NOTHING OF VALUE IS LOST, which is why this is a removal and not a reorder.
  # A fingerprint could never have logged you in here anyway: the greeter only
  # starts a PAM conversation when it sends Login, and ../desktop/sddm-theme/
  # Main.qml refuses to send that with an empty field — so reaching the finger
  # prompt required typing the password first. Even if a swipe had succeeded it
  # would have left the keyring locked, since pam_gnome_keyring needs the
  # password itself to decrypt it.
  #
  # The cost is that a bare tty login (agetty -> /etc/pam.d/login) loses the
  # finger too — and it would have hung for the same ten seconds. Everywhere the
  # finger actually pays off is untouched: sudo, polkit, and hyprlock, which has
  # its own PAM service and in any case drives fprintd over D-Bus directly (see
  # ../../config/hypr/hyprlock.conf).
  security.pam.services.login.fprintAuth = false;
}
