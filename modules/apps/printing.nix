# Printing: CUPS, plus the mDNS resolution that network printers depend on.
#
# `services.printing.enable` used to be a one-liner in ./misc.nix. It now needs
# a driver list and an Avahi block, so per THE RULE it earned its own module.
#
# What was actually missing for the HP ENVY 6400 on this network: *not* a
# driver. Its DNS-SD record advertises `URF=…`, `application/PCLm` and
# `mopria-certified=2.0` — i.e. AirPrint / IPP Everywhere — so CUPS can drive it
# with no vendor code at all. avahi-daemon was already running (GNOME pulls it
# in), but `nssmdns4` defaults to false, so glibc had no `mdns4` entry in
# nsswitch.conf and never resolved the printer's `HP….local` name. That is the
# fix; hplip below is only for HP models that are *not* driverless.
{ pkgs, ... }:
{
  services.printing = {
    enable = true; # CUPS

    # HP's own driver suite — the equivalent of Arch's `hplip` package. Only
    # older/non-AirPrint HP devices need it; it also brings `hp-setup` and
    # ink-level reporting. Drop this line to save the closure if every HP
    # printer you use is driverless.
    drivers = [ pkgs.hplip ];
  };

  # DNS-SD/mDNS. `enable` is redundant while GNOME is imported (it enables Avahi
  # itself), but printing depends on this being on, so it is declared here
  # rather than inherited by accident.
  services.avahi = {
    enable = true;
    nssmdns4 = true; # put `mdns4` in nsswitch.conf so `*.local` resolves
    openFirewall = true; # UDP 5353
  };
}
