# Swap — zram (compressed swap in RAM), not a disk swapfile.
#
# This machine ran with NO swap at all (`swapDevices = [ ]` in the generated
# hardware-configuration.nix, which this does not touch). With 15 GiB and zero
# swap there is no cushion: once allocations approach physical RAM the kernel has
# nothing to evict but page cache, and the desktop stalls hard before the OOM
# killer ever gets a turn.
#
# WHY zram AND NOT A SWAPFILE:
#   * It is RAM backed by compression (zstd, typically ~3:1 on anonymous pages),
#     so paging out costs microseconds instead of an SSD round trip. Cold pages
#     get squeezed rather than thrown away.
#   * No SSD write wear.
#   * The one thing it cannot do is hibernate (suspend-to-DISK needs a real swap
#     area >= RAM). This host only ever suspends to RAM, which is unaffected —
#     and given its history of NVIDIA resume trouble, hibernation is not a road
#     worth going down anyway.
# If hibernation is ever wanted, this needs a real swap partition/file instead.
{ ... }:
{
  zramSwap = {
    enable = true;

    # Share of RAM zram may claim as its (compressed) swap device. 50% of 15 GiB
    # is ~7.5 GiB of swap that in practice holds well over that once compressed.
    # This is a ceiling, not a reservation: unused zram costs nothing.
    memoryPercent = 50;
  };

  boot.kernel.sysctl = {
    # Swap readahead is a pessimisation when "swap" is RAM: there is no seek to
    # amortise, so pulling in neighbouring pages just wastes cycles and space.
    # 0 = fault in exactly one page. This is the setting that matters most for
    # zram, and the default (3 = 8 pages) is tuned for spinning disks.
    "vm.page-cluster" = 0;

    # With disk swap a low swappiness avoids stalls; with zram the tradeoff
    # inverts, because evicting a cold anonymous page is far cheaper than
    # dropping hot page cache. 180 (of a 200 max) is the usual zram-only value.
    "vm.swappiness" = 180;
  };
}
