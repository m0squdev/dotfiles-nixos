#!/usr/bin/env bash
# Emoji / character picker for niri — bound to Mod+. (Mod+Period).
#
# Opens rofimoji in fuzzel's dmenu mode (so it inherits the Catppuccin Mocha
# theme). The chosen glyph is TYPED into the focused window via wtype and the
# clipboard is left untouched. Note: a few apps ignore synthetic typing (wtype),
# in which case the pick simply does nothing — switch --action to `type copy` (or
# `copy`) if you'd rather it also land on the clipboard as a fallback.
#
# --files controls the character set: emoji, math/technical symbols, Japanese kana
# (hiragana/katakana + the small-kana blocks), CJK + general punctuation. NOTE:
# deliberately NO kanji — cjk_unified_ideographs is ~90k chars (slow, and Mozc via
# Mod+K already handles kanji). This set is ~5k chars and loads in a few ms. Widen
# further if you want (e.g. add `nerd_font`, or use `--files all` for everything).
# --skin-tone neutral skips the extra skin-tone prompt on people emoji.
#
# Needs the rofimoji, wtype, wl-clipboard and fuzzel packages.
exec rofimoji \
  --selector fuzzel \
  --prompt "Character > " \
  --files emojis math hiragana katakana katakana_phonetic_extensions small_kana_extension cjk_symbols_and_punctuation general_punctuation \
  --skin-tone neutral \
  --action type \
  --typer wtype \
  --clipboarder wl-copy
