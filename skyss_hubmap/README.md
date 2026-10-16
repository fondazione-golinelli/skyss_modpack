# skyss_hubmap

The map of the Skyss HUB lobby. It replaces the classrooms_bridge world map
in the HUB (that map turns itself off when this mod is enabled).

Every player carries the map in the fourth slot of the classrooms toolbar
(in the inventory when classrooms_bridge is not loaded); `/hubmap` opens it
too. The map shows the hub island with one pin per place; a pin, a list row
or the tag tabs select a place, **Teleport** / **Go** take the player there:
always to the same block, facing a fixed direction.
The player is a red triangle pointing where they look (8 directions),
drawn above the pins with the tooltip "You are here".

## Places and tags

| Tag | Places | Where the position comes from |
| --- | --- | --- |
| Spawn point | spawn | the hub mod's spawn point and `join_rotation_x` |
| Worlds portal | portal | on the terrace, 6 blocks in front of the portal |
| Minigames | the four pavilions | the return point (`exit`) of the game's launcher in skyss_minigames |
| Countries | Germany, Hungary, Italy, Poland, Spain | in each country garden, beside the flag, facing the countryside |

The list is in `places.lua` (ids, tags, names, default positions). Names are
translated through `S()` (`locale/`, it/es/fr/de/pl/hu); minigame names are
the games' own translated titles.

For the portal and the countries the position is, in order:

1. an admin's change (mod storage, key `place:<id>`);
2. the world's `skyss_hubmap/places.json`, written by luanti-tools/hubgen
   (`hub_places()`), format `{"version": 1, "places": {"<id>": {"pos": [x, y, z], "yaw": deg}}}`;
3. the default in `places.lua`.

Positions are feet positions (the block above the ground), yaw in degrees as
Luanti counts it (0 = north, 90 = west).

## Admins

Players with `server` or `hub_admin` see **Move here** on a selected place:
it puts the place where they stand, facing where they look (rounded to
15°). **Reset** removes the change. Moving the spawn point also moves the hub
mod's spawn (`hub.settings.hub_spawn_point`, changed in place) and its join
facing, and is re-applied at every start. Minigame places are moved with the
**Return point** tool of the minigames editor.

Players cannot teleport during a minigame or the minigames editor, while
frozen by a teacher, or more often than every 2 seconds (admins have no
cooldown).

## Textures

- `tools/make_ui.py` draws the board, buttons, badges, flags and the player
  arrow (reusing the drawing code of `skyss_minigames/tools/make_ui.py`) and
  writes `src/layout.lua`.
- `tools/make_map.py WORLD` renders `textures/skyss_hubmap_map.png` from a hub
  world with classrooms_bridge's `tools/render_maps.py`, X and Z from -170 to
  169 (`BOUNDS` in `init.lua`). Re-run it after regenerating the hub map:

      python3 tools/make_map.py ../../templates/hub/.luanti/worlds/world

## API

- `skyss_hubmap.show(player)` opens the map.
- `skyss_hubmap.teleport(player, id)` teleports with the same checks as the map.
- `skyss_hubmap.list_places()` returns `{ {id, tag, title, pos, yaw}, ... }`.

## Deploying

Enable the mod in the lobby world (`load_mod_skyss_hubmap = true` in
`world.mt`; hubgen's template has it) and copy `places.json` from a hubgen
run into `<world>/skyss_hubmap/`, then restart the lobby.
