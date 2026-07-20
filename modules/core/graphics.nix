# GPU acceleration (OpenGL/Vulkan userspace). Vendor-specific kernel drivers
# live in ../hardware/* and are imported per-host.
{ ... }:
{
  hardware.graphics.enable = true;
}
