-- spawn point
hub.settings.hub_spawn_point = vector.new(5, 10, 5)

-- custom viewing rotation in degrees when joining the server, to force a certain direction
--hub.settings.join_rotation_x = 90
--hub.settings.join_rotation_y = 0

-- if players in the hub go lower than this coordinate, they get teleported back to the spawn point
hub.settings.y_limit = -100

-- music to reproduce whilst inside the hub
-- `params` are for tweaking the track, as in Minetest sound parameter tables (e.g. gain = 1.2). Some won't work (e.g. exclude_player)
hub.settings.music = {
  --track = "",
  --description = "",
  --params = {}
}

-- hotbar additional items
hub.settings.hotbar_items = {
  "",
  "",
  "magic_compass:compass",
  "",
  "",
  "",
  ""
}

-- physics whilst in the lobby
hub.settings.physics = {
  speed = 1,
  speed_walk = 1,
  speed_fast = 1,
  speed_climb = 1,
  speed_crouch = 1,
  jump = 1,
  gravity = 1,
  liquid_fluidity = 1,
  liquid_fluidity_smooth = 1,
  liquid_sink = 1,
  acceleration_default = 1,
  acceleration_air = 1,
  acceleration_fast = 1,
  sneak = true,
  sneak_glitch = false,
  new_move = true
}

-- commands that players won't be able to use whilst in the hub. Having the `hub_admin`
-- privilege bypasses the block
hub.settings.blocked_cmds = {
  "clearinv",
  "me",
  "pulverize"
}

-- how many arenas to display in the arenas status panel (on the right)
hub.settings.MAX_ARENAS_IN_STATUS = 4

-- tests to debug the mod
hub.settings.run_unit_tests = false



-----------------
---- METRICS ----
-----------------

-- assign minigames to IDs. These IDs are then used to create a histogram through the monitoring mod.
-- To group more minigames in the same value, just use the same ID.
-- If a minigame is not listed in here, no metrics will be collected regarding such minigame
hub.settings.metrics_minigames = {
  --block_league = 1,
  --fantasy_brawl = 2,
  --colour_jump = 3,
  --sumo = 3,
  --tntrun = 3
}

-- these arenas won't be taken in consideration when generating the histogram
hub.settings.metrics_exclude = {
  --block_league = {Tutorial = true}
}



----------------
-- PLAYERLIST --
----------------

-- max slots in the playerlist table. If there are more players, it'll say "...and much more!" on the last slot
hub.settings.plist_max_slots = 36

-- max players per column in the playerlist table. When N +1 players are reached, a new column is generated, recalculating the position of the previous slots
hub.settings.plist_p_per_column = 12

-- name colours according to privs. Priority is given to what's declared first.
-- Don't remove `__default`
hub.settings.plist_name_colours = {
  {server = 0xFFCB4D},
  {kick = 0x8AEBF1},
  {__default = 0xFFFFFF}
}