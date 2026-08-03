# Intel integrated graphics (this repo: UHD 620 / Gen9.5, Whiskey Lake-U).
#
# The KERNEL side needs nothing — i915 is in-tree and binds at boot. What is
# missing out of the box is the VA-API userspace, so without this module every
# video decode runs on the CPU: a fan that never stops and visibly worse battery
# life on a laptop for something the GPU does for free.
#
# ../core/graphics.nix turns hardware.graphics on for every host; this module is
# the vendor half, imported only where an Intel iGPU is what's actually driving
# the display (see ./nvidia.nix for the other one).
{ pkgs, ... }:
{
  hardware.graphics.extraPackages = with pkgs; [
    # iHD — Intel's current VA-API driver, Broadwell and newer. Covers Gen9.5.
    # The older i965 driver (pkgs.intel-vaapi-driver) also supports this chip and
    # is the fallback if a specific codec misbehaves; it is unmaintained
    # upstream, so start with iHD.
    intel-media-driver
  ];

  # libva picks a driver from the DRI device name, and on some setups still
  # guesses i965 for Gen9.x. Say it outright so every app agrees. Check with
  # `vainfo` (pkgs.libva-utils) — it should print "iHD" and a codec list.
  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";
}
