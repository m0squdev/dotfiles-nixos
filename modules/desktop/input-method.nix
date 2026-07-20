# Japanese (and any) input method via fcitx5 + Mozc. fcitx5 is the smoother
# choice than ibus on Wayland/niri; waylandFrontend makes it use niri's
# text-input protocol. Mozc gives kanji conversion + prediction and hiragana/
# katakana modes. fcitx5 is autostarted from ~/.config/niri/config.kdl; the
# input methods + toggle key live in ~/.config/fcitx5/. NOTE: do NOT also add
# fcitx5 to environment.systemPackages — that breaks Mozc addon detection.
{ pkgs, ... }:
{
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
}
