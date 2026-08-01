# Bundled fonts

The add-on's themed text normally uses the WoW client's own fonts
(`FRIZQT__.TTF`, `MORPHEUS.TTF`). Those only contain glyphs for the client's own
region, so when a player uses the **language override** to run Epithet in a
language whose script the client font doesn't cover — most commonly **Russian on
a Western (enUS/enGB) client** — that text would render as empty boxes ("tofu").

To fix that, Epithet loads a bundled Unicode font for those locales (see
`BUNDLED_FONT_LOCALES` in `Core/Theme.lua`). These files are **included**:

| File                | Font (family) | Covers           |
|---------------------|---------------|------------------|
| `Epithet-Sans.ttf`  | PT Sans       | Latin + Cyrillic |
| `Epithet-Serif.ttf` | PT Serif      | Latin + Cyrillic |

If a file is ever missing, `Core/Theme.lua` falls back to the client font (no
error — just the boxes again), so the add-on works with or without them.

## Attribution / license

PT Sans and PT Serif are © 2010 ParaType Ltd, released under the SIL Open Font
License 1.1. The full license (which lists the reserved names for both families)
travels with the fonts as `OFL.txt` in this folder — keep it in shipped builds.
Source: Google Fonts (`ofl/ptsans`, `ofl/ptserif`). The files here are the
upstream `PT_Sans-Web-Regular.ttf` / `PT_Serif-Web-Regular.ttf`, renamed.

## Which locales use the bundle

Currently just `ruRU`. Western-European locales (deDE, frFR, esES, itIT, ptBR)
render fine with the client fonts, which already cover Latin-1 accents. CJK
locales (koKR, zhCN, zhTW) need very large font files and are not bundled — they
render correctly only on a matching client. To add another script, extend
`BUNDLED_FONT_LOCALES` and make sure the bundled fonts cover it (PT Sans/Serif
do not include CJK).
