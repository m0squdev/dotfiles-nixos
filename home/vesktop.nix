# Vesktop (Discord) — Catppuccin Mocha (mauve accent) via Vencord.
#
# This earns its own module (rather than the one-line `vesktop` that used to
# sit in ../modules/apps/misc.nix) because it now carries config: Home Manager's
# `programs.vesktop` both installs the package AND lays down its settings. The
# old system-package line in misc.nix is gone — the package comes from here now.
#
# THEME — "online theming": Catppuccin publishes the Discord theme as a hosted
# stylesheet, and Vencord applies it by @import-ing that URL. We inject the
# import through QuickCSS (`vencord.extraQuickCss`) rather than Vencord's
# "Online Themes" list, on purpose:
#
#   * The Online-Themes list (`themeLinks`) and the enabled-plugin map both live
#     in the SAME file, ~/.config/vesktop/settings/settings.json. Having Home
#     Manager own that file would turn it into a read-only store symlink, so
#     every future plugin toggle from Vesktop's own UI would silently fail to
#     persist (the ../CLAUDE.md "config files an app writes back to" trap).
#   * QuickCSS lives in its own file (settings/quickCss.css) and is applied
#     whenever Vencord's `useQuickCss` is on — which is its default — so this
#     themes the client out of the box while leaving settings.json fully
#     app-writable. Visually identical to adding the same link under Online
#     Themes.
#
# `quickCss.css` becomes a read-only symlink, so Vesktop's in-app QuickCSS
# editor can't persist here — edit this file and rebuild instead. Mauve keeps it
# in step with the rest of the setup (see ../modules/desktop/theming.nix).
{ config, ... }:
{
  programs.vesktop = {
    enable = true;
    vencord.extraQuickCss = ''
      @import url("https://catppuccin.github.io/discord/dist/catppuccin-mocha-mauve.theme.css");
    '';
  };

  # Vesktop replaces the managed quickCss.css symlink with a real (usually empty)
  # file at runtime. Once Home Manager has taken a `.hm-bak` of that, the NEXT
  # switch can't back it up again and aborts the whole activation. Since this
  # file is ours to own anyway (in-app QuickCSS isn't meant to persist, per the
  # note above), force Home Manager to overwrite whatever Vesktop left, no backup
  # — the fix HM itself suggests for this. Key must match the path programs.vesktop
  # writes (home.file keyed by the absolute xdg.configHome path).
  home.file."${config.xdg.configHome}/vesktop/settings/quickCss.css".force = true;
}
