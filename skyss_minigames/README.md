# skyss_minigames

Minigame manager for the Skyss hub. It replaces arena_lib for our own games
(`skyss_animalgame`, `skyss_cleanup`, `skyss_treegame`).

What it handles:

- arenas defined as data (`<world>/skyss_minigames/arenas.json`), written by
  `luanti-tools/hubgen` together with the map, so regenerating the map
  regenerates the arenas too;
- solo games (one player per match) and cooperative games (one shared team);
- minimum and maximum players, a time limit (3 minutes unless changed);
- several spawn points, assigned in turn (player 1 → spawn 1, …, and back to
  spawn 1 when there are more players than spawns);
- a play area players cannot leave, and that other players cannot enter during
  a match (`exclusive`);
- per-game or per-arena building rules (`can_dig`, `can_place`);
- the area is saved before every match and restored after it (nodes,
  metadata, dropped items). A crash mid-match is repaired at the next start;
- one global leaderboard per game, by time (lower is better) or by score
  (higher is better);
- one launcher per game in the hub's pavilions: anyone clicks it and plays or
  gets in line; the match runs in any free arena of the game (solo games run
  one player per arena in parallel, e.g. the six farm pens) and players come
  back to the pavilion afterwards;
- teachers can start a game for chosen players, in game (launcher menu) or
  from the class dashboard through `classrooms_bridge`;
- an in-game editor for admins (`/minigames edit`, or Edit in a launcher
  menu): game settings, arenas, spawns and launchers.

Players' inventories, hotbar, physics and HUD flags are saved in their player
metadata for the match and given back afterwards, also after a disconnect or a
crash.

## arenas.json

```json
{
  "version": 2,
  "launchers": {
    "skyss_animalgame": {"pos": [49, 7, 16], "yaw": 108,
                         "exit": {"pos": [46, 7, 15], "yaw": 288}}
  },
  "games": {
    "skyss_cleanup": {"time_limit": 240, "max_players": 12, "enabled": true}
  },
  "arenas": {
    "farm_1": {
      "game": "skyss_animalgame",
      "pos1": [225, 4, 213],
      "pos2": [241, 14, 227],
      "spawns": [{"pos": [239, 6, 220], "look": "west"}],
      "fixtures": [{"pos": [248, 5, -234], "node": "skyss_cleanup:bin_plastic", "param2": 0}],
      "params": {"waste_amount": 0},
      "exit": {"pos": [244, 6, 220], "yaw": 270},
      "exclusive": true
    }
  }
}
```

- A point is `[x, y, z]` or `{"pos": [x, y, z], "yaw": degrees}` or
  `{"pos": …, "look": "north|south|east|west"}`.
- `launchers`: one per game. The mod places the launcher node there (and puts
  it back if it disappears) with a floating label. Players come back to its
  `exit` after a match (default: two nodes in front of it).
- `games`: admin overrides of a game's settings (`enabled`, `time_limit`,
  `min_players`, `max_players`, `can_dig`, `can_place`); the editor writes
  them. Missing keys use the game's defaults.
- `arenas`: `fixtures` are nodes the game needs, placed like launchers;
  `params` are free for the game (`match.params`); `exit` overrides the
  launcher's return point for that arena.
- Arenas with an unknown game or no spawn are skipped with a warning in the log.

The editor writes the file at once. Launchers and arenas that come from hubgen
are overwritten the next time the map is generated, so permanent changes
belong in `hubgen.py` (`minigame_launchers`, `minigame_arenas`).

## Editor

`/minigames edit [game]` (admins), or **Edit** in a launcher menu:

- **Game**: on/off, time limit, min/max players, leaderboard by time or score,
  breaking/placing blocks, reset to the game's defaults, clear the leaderboard;
- **Arenas**: corners, spawn points and own return point from where you
  stand, show the area with particles, go there, create and delete arenas;
- **Launcher**: move the launcher or its return point to where you stand.

Arenas in use cannot change until their match ends.

**Edit tools** in the editor (or `/minigames tools`) puts you in *edit mode*:
your inventory is set aside and the hotbar holds one tool per job. They work
on the game and arena selected in the editor or with the Select tool. In edit
mode the arena's edges glow, and spawn points (green, numbered), corners
(yellow) and the launcher's return point (blue) show as markers only you see.
The tool in hand explains itself above the hotbar.

| Tool | Left-click | Right-click |
| --- | --- | --- |
| Select | an arena or a launcher: select it | open the editor |
| Corners | a block: corner 1 | a block: corner 2 |
| Spawn points | a spawn marker: remove it | a block: add a spawn point facing where you look |
| Launcher | a launcher, twice: destroy it | a block, twice: put the game's launcher there, facing you |
| Return point | | a block: players come back here after the match |
| Done | leave edit mode, inventory back | same |

If you disconnect in edit mode your inventory comes back at the next join.

Every change can be undone: **Undo** at the top of the editor, or
`/minigames undo` (the last 30 changes since the server started). A launcher
that is moved or destroyed leaves no node behind, also across restarts
(`stale_launchers` in arenas.json lists the spots still to clean).

## Look of the menus

The menus are drawn on pixel-art backgrounds in the style of the serverguide
books. `tools/make_ui.py` draws them (and the buttons, medals, icons and the
edit tools) and writes `src/ui_layout.lua` with the position of every panel, so
after changing a layout run `python3 tools/make_ui.py` and keep the Lua text
positions in `src/forms.lua` / `src/editor.lua` in line.

## Commands

| Command | Who | Effect |
| --- | --- | --- |
| `/minigames` or `/minigames list` | everyone | Arenas and their state |
| `/minigames leave` | everyone | Leave the match or the line |
| `/minigames board <game>` | everyone | Leaderboard |
| `/minigames start <game> <player> [player…]` | teachers, admins | Start the game for those players in its free arenas |
| `/minigames stop <arena>` | teachers, admins | Stop a match without results |
| `/minigames edit [game]` | admins | Open the editor |
| `/minigames tools` | admins | Enter or leave edit mode (the edit tools) |
| `/minigames undo` | admins | Undo the last change to arenas.json |
| `/minigames reload` | admins | Reload `arenas.json` |

Admins are players with `minigames_admin`, `server` or `hub_admin`. Teachers
are recognised through `classrooms_bridge`.

## Game API

```lua
skyss_minigames.register_game("my_game", {
    title = S("My game"),
    description = S("What to do."),
    mode = "coop",           -- "solo" or "coop"
    min_players = 1,
    max_players = 8,
    icon = "my_game_icon.png",  -- shown in the launcher menu
    color = "#3f6fb0",       -- header colour of the menu
    time_limit = 180,        -- seconds, 0 = none (default 180)
    ranking = "time",        -- "time" or "score"
    can_dig = false,
    can_place = false,
    exclusive = true,        -- keep other players out during a match
    join_in_progress = false,
    countdown = 3,           -- seconds, players frozen at their spawn
    celebration_time = 5,    -- seconds between the result and the end
    hotbar_slots = 9,
    hotbar_image = nil,
    hud_flags = nil,         -- e.g. {minimap = false}, restored afterwards
    leave_item = true,       -- "leave" item in the last hotbar slot
    show_timer = true,       -- timer at the top of the screen

    on_start = function(match) end,               -- after the countdown
    on_join = function(match, name) end,          -- join_in_progress only
    on_leave = function(match, name, reason) end, -- "quit" | "disconnect"
    on_respawn = function(match, name) end,       -- already back at the spawn
    on_timeout = function(match) return {success = false} end,
    on_finish = function(match, result) end,      -- result known, celebration starts
    on_end = function(match, result) end,         -- before players leave the area
})
```

The `match` table: `players` (set of names), `player_list`, `name` (arena
name), `pos1`, `pos2`, `spawns`, `params`, `game`, `state` (`loading`,
`countdown`, `running`, `ending`, `done`), `data` (free for the game),
`time_limit`, `started_by`.

End a match with `skyss_minigames.finish(match, {success = bool, score = n,
time = seconds, celebration_time = seconds})`. `time` defaults to the time
since the start. With ranking `time` only successful matches enter the
leaderboard; with `score` any score above 0 does.

Helpers: `get_match_by_player(name)`, `get_match(arena_name)`,
`is_playing(name)`, `players(match)` (iterator of name, player),
`player_count(match)`, `elapsed(match)`, `time_left(match)`,
`chat(match, msg)`, `title(match, text, seconds, color)`,
`title_player(name, …)`, `hint_player(name, …)` (above the hotbar),
`sound(match, spec, params)`, `spawn_of(match, name)`, `respawn(match, name)`,
`leave(name)`.

For other mods: `start(arena_name, names, {time_limit, by})`,
`start_game(game, names, {time_limit, by})` (returns ok, message, started,
waiting, left_out), `stop(arena_name)`, `list_arenas()`,
`set_staff_check(fn)`.

The map is restored from a snapshot, so games may change nodes freely with
`core.set_node`; they only have to remove their own entities in `on_end`.

## Deploying on the hub

1. Enable the mod in the lobby world (`load_mod_skyss_minigames = true` in
   `world.mt`; hubgen's template already has it).
2. Put `arenas.json` in `<world>/skyss_minigames/` (hubgen writes it to the
   template world).
3. Restart the lobby server and check the log for
   `[skyss_minigames] N arena(s) loaded`.

`hub` still depends on arena_lib, so arena_lib stays loaded until it is removed
from `hub` as well.
