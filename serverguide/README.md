# Server Guide

In-game guides for the Skyss hub, derived from the A.E.S. server guide mod:
* `/rules` command
* "first steps" formspec + `/tutorial` command
* "Biophilia values" formspec
* two pedestals (`serverguide:pedestal_rules`, `serverguide:pedestal_values`) that open the rules and the values

Rules text can be overridden with the `serverguide.rules_text` setting (one rule per line).
Use `\n` in the setting value for line breaks. `serverguide.rules_title` overrides the title.
Text set this way is shown as is, it is not translated.

## Assets

The pedestal model (`serverguide_pedestal.obj`), its two textures and the formspec backgrounds
(`serverguide_board_bg.png`, `serverguide_values_bg.png`) are original Skyss assets.

Formspec coordinates assume 15 background pixels per formspec unit: the values panel is 180x261 px
(`size[12,17.4]`), the board shared by rules and first steps is 210x262 px (`size[14,17.47]`). Redraw a
background at the same size, or update the coordinates in `src/values.lua` and `src/board.lua`.

## Localization

Text goes through `S()` (text domain `serverguide`) and is translated from `locale/serverguide.<lang>.tr`
for `it`, `es`, `fr`, `de`, `pl`, `hu`; English is the source. Add every new string to `locale/template.txt`
and to each language file. The `.po` files of other languages come from the upstream mod and only cover the
first steps and commands.
