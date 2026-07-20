# Fonts. JetBrainsMono Nerd Font supplies the glyphs waybar/fuzzel icons need.
{ pkgs, ... }:
{
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
  ];
}
