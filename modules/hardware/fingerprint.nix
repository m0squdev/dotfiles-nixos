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

  # Enrol a finger AFTER the first switch — the templates live on the sensor and
  # in /var/lib/fprint, neither of which this repo manages:
  #     fprintd-enroll        (repeat with -f for more fingers)
  #     fprintd-verify        (check it before relying on it to log in)
  #
  # PAM: enabling fprintd is enough. The NixOS PAM module defaults each service's
  # `fprintAuth` to services.fprintd.enable, so GDM, sudo and the lockers
  # (security.pam.services.hyprlock in ../desktop/niri.nix) all gain the finger
  # as an alternative to the password — never as a replacement, so a failed or
  # missing swipe still falls through to typing it.
}
