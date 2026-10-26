# skyss_paintings

Pixel-art paintings for Skyss worlds.

## Playing

- **Painting frame** (`skyss_paintings:frame`, creative inventory; recipe: 8
  sticks around a paper): right click opens a panel to choose the size, 1×1 to
  3×3 blocks (square, horizontal or vertical), then the pixel editor.
- **Editor**: 32 fixed colours, pencil, line and rectangle (two clicks:
  formspecs report clicks only, so there is no dragging), fill, undo, clear,
  grid on/off, optional title. Buttons are boxes + icon + label under an invisible
  `image_button` whose pane is made transparent (Mineclonia's formspec
  prepend gives every `image_button` an opaque pane). The work in progress is kept as a draft in the
  player's meta (one per player): closing the editor does not lose it, the
  frame panel offers "Continue draft". Pixels per block: 16 for 1×1, 12 when
  the longest side is 2 blocks, 8 when it is 3 (at most 24 pixels a side).
- **Save** gives a painting item (`skyss_paintings:painting`) holding the
  pixels, the author and the title; its inventory icon is the picture. The
  multiserver proxy prefixes the whole `inventory_image` meta value with its
  media pool name, so the icon is `skyss_paintings_blank.png^[resize:..^([png:..)`;
  older items with a bare `[png` icon are rewritten when the player joins.
- **Hanging**: right click a wall with the painting. The clicked block is the
  bottom-left corner (as seen by the player); every block of the painting's
  size must be solid wall with a free, unprotected space in front of it.
  Cells that don't fit flash red.
- **Looking**: right click a hung painting shows it with title and author. The
  author and the class staff (`classrooms_bridge.is_staff`, or
  `protection_bypass`/`server` privilege without the bridge) can also edit it
  in place or remove it. The author gets the painting back on removal; staff
  removing someone else's painting delete it.

## In the world

- One `skyss_paintings:canvas` node per block, in front of the wall
  (invisible, not diggable, facedir towards the wall). The bottom-left one is
  the anchor and holds `w`, `h`, `px`, `owner`, `title`, `placer`, `uid`;
  the others store `anchor`.
- The picture is a non-saved `upright_sprite` entity with a generated `[png`
  texture (frame included), recreated by an LBM whenever its block loads.
- Mod storage `registry` lists hung paintings (anchor → owner, placer,
  time, uid) for the mission.

Pixels are stored one character per pixel, the palette index in
`0123456789abcdefghijklmnopqrstuv`.

## Special mission

With `classrooms_bridge` loaded, `mission.lua` registers the special mission
**Painting exhibition** (kind `paintings`, zone only, `dig` so the editor warns
about teachers-only zones): setting `per_student` (1-5, default 1); goal
`paintings_each` counts the participant who has hung the fewest of their own
paintings inside the zone since the mission started, so it is met when every
participant has hung `per_student`. Tool: `skyss_paintings:mission_frame`,
handed out in the zone and taken back outside it (the normal frame is not an
activity tool, so it stays in inventories). In the zone the frame panel shows
the student's own progress and how many students have finished, or every
participant for the staff; hanging a painting tells the student how many
classmates are still missing (the HUD goal stays 0/1 until all have). Paintings
stay on the walls when the mission is deleted.

## Textures

`python3 tools/make_textures.py` draws the item icons and UI textures.

## Translations

`locale/` has it, es, fr, de, pl, hu (written by Claude; pl and hu not yet
reviewed by a native speaker).
