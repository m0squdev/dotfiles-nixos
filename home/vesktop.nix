# Vesktop (Discord) — Catppuccin Mocha (mauve accent) via Vencord.
#
# This earns its own module (rather than the one-line `vesktop` that used to
# sit in ../modules/apps/misc.nix) because it now carries config: Home Manager's
# `programs.vesktop` both installs the package AND lays down its settings. The
# old system-package line in misc.nix is gone — the package comes from here now.
#
# THEME — Catppuccin publishes the Discord theme as a hosted stylesheet. We
# apply it through QuickCSS (`vencord.extraQuickCss`) rather than Vencord's
# "Online Themes" list, on purpose:
#
#   * The Online-Themes list (`themeLinks`) and the enabled-plugin map both live
#     in the SAME file, ~/.config/vesktop/settings/settings.json. Having Home
#     Manager own that file would turn it into a read-only store symlink, so
#     every future plugin toggle from Vesktop's own UI would silently fail to
#     persist (the ../CLAUDE.md "config files an app writes back to" trap).
#   * QuickCSS lives in its own file (settings/quickCss.css) and is applied
#     whenever Vencord's `useQuickCss` is on — which is its default — so this
#     themes the client out of the box while leaving settings.json app-writable.
#
# But we INLINE the theme text; we do NOT `@import` the URL. QuickCSS runs in
# Discord's renderer, under its Content-Security-Policy, and the CSP does not
# whitelist the catppuccin.github.io (or raw.githubusercontent.com) origin — so
# a remote `@import` is silently CSP-blocked and the client stays unthemed. That
# was the original bug. Fetching the stylesheet at BUILD time and pasting its
# rules straight into QuickCSS means there is no runtime fetch for the CSP to
# block: the CSS is already there. Pinned by rev+hash per ../CLAUDE.md; bump both
# to update (the github.io/dist tree is built onto the gh-pages branch).
#
# `quickCss.css` becomes a read-only symlink, so Vesktop's in-app QuickCSS
# editor can't persist here — edit this file and rebuild instead. Mauve keeps it
# in step with the rest of the setup (see ../modules/desktop/theming.nix).
{ config, pkgs, ... }:
let
  # catppuccin/discord @ gh-pages, the built stylesheet for the Mocha/Mauve flavour.
  catppuccinMochaMauve = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/catppuccin/discord/0d8c7aaea33c655bb9e4c93d352a28f3baa69a75/dist/catppuccin-mocha-mauve.theme.css";
    hash = "sha256-kX6O2wxQpZvCF2RjsP4yH+Ojvijd8KJ/uCVu/VObTOg=";
  };
in
{
  programs.vesktop = {
    enable = true;
    vencord.extraQuickCss = builtins.readFile catppuccinMochaMauve;
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
