local S = core.get_translator("arena_lib")

----------------------------------------------
-----------------WORLD FOLDER-----------------
----------------------------------------------
local function load_world_folder()
  local wrld_dir = core.get_worldpath() .. "/arena_lib"
  local content = core.get_dir_list(wrld_dir)

  if not next(content) then
    local modpath = core.get_modpath("arena_lib")
    local src_dir = modpath .. "/IGNOREME"

    core.cpdir(src_dir, wrld_dir)
    os.remove(wrld_dir .. "/README.md")
    os.remove(wrld_dir .. "/BGM/.gitkeep")
    os.remove(wrld_dir .. "/Schematics/.gitkeep")
    os.remove(wrld_dir .. "/Thumbnails/.gitkeep")

  else
    --v------------------ LEGACY UPDATE, to remove in 9.0 -------------------v
    if not os.rename(wrld_dir .. "/Schematics/", wrld_dir .. "/Schematics") then
      local instructions = io.open(core.get_modpath("arena_lib") .. "/IGNOREME/instructions.txt", "r")
      local txt = instructions:read("*all")

      instructions:close()
      core.mkdir(wrld_dir .. "/Schematics/")
      core.safe_file_write(wrld_dir .. "/instructions.txt", txt)
    end

    local wrld_instr = io.open(wrld_dir .. "/instructions.txt", "r")
    local wrld_txt = wrld_instr:read("*all")

    wrld_instr:close()

    if not wrld_txt:find("Tracks can also be manually registered") then
      local instructions = io.open(core.get_modpath("arena_lib") .. "/IGNOREME/instructions.txt", "r")
      local txt = instructions:read("*all")

      instructions:close()
      core.safe_file_write(wrld_dir .. "/instructions.txt", txt)
    end
    --^------------------ LEGACY UPDATE, to remove in 9.0 -------------------^

    -- aggiungi musiche come contenuti dinamici per non appesantire il server
    local function iterate_dirs(dir)
      for _, f_name in pairs(core.get_dir_list(dir, false)) do
        -- NOT REALLY DYNAMIC MEDIA, since it's run when the server launches and there are no players online
        -- it's just to load these tracks from the world folder (so that `sound_play` recognises them without the full path)
        core.dynamic_add_media({filepath = dir .. "/" .. f_name})
      end
      for _, subdir in pairs(core.get_dir_list(dir, true)) do
        iterate_dirs(dir .. "/" .. subdir)
      end
    end

    iterate_dirs(wrld_dir .. "/BGM")
    iterate_dirs(wrld_dir .. "/Thumbnails")
  end
end

load_world_folder()





----------------------------------------------
-------------------SETTINGS-------------------
----------------------------------------------
dofile(core.get_worldpath() .. "/arena_lib/SETTINGS.lua")

local function add_new_parameter(name, desc)
  if not arena_lib[name] then
      local settings = io.open(core.get_worldpath() .. "/arena_lib/SETTINGS.lua", "r")
      local txt = settings:read("*all") .. "\n" .. table.concat(desc, "\n")

      settings:close()
      core.safe_file_write(core.get_worldpath() .. "/arena_lib/SETTINGS.lua", txt)

      core.log("action", "[ARENA_LIB] Settings: `arena_lib." .. name .. "` was missing. Successfully added at the end of the file")
      dofile(core.get_worldpath() .. "/arena_lib/SETTINGS.lua")
  end
end



--v------------------ LEGACY UPDATE, to remove in 8.0 -------------------v
-- rename PALETTE `_default` into `___`
if arena_lib.PALETTE._default then
  local file_content = {}
  local settings = io.open(core.get_worldpath() .. "/arena_lib/SETTINGS.lua", "r")

  for line in settings:lines() do
    if string.match(line, "_default") then
      line = line:gsub("_default", "___")
    end
    table.insert(file_content, line)
  end

  settings:close()

  settings = io.open(core.get_worldpath() .. "/arena_lib/SETTINGS.lua", "w")
  for _, v in ipairs(file_content) do
    settings:write(v .. "\n")
  end

  settings:close()
end
--^------------------ LEGACY UPDATE, to remove in 8.0 -------------------^

--v------------------ LEGACY UPDATE, to remove in 9.0 -------------------v
-- add new physics parameters (checking 2 fields just to be sure)
if not arena_lib.SERVER_PHYSICS.speed_climb and not arena_lib.SERVER_PHYSICS.acceleration_default then
  local settings = io.open(core.get_worldpath() .. "/arena_lib/SETTINGS.lua", "r")
  local txt = settings:read("*all")

  settings:close()

  txt = txt:gsub("sneak = ", "speed_climb = 1,\n  speed_crouch = 1,\n  liquid_fluidity = 1,\n  liquid_fluidity_smooth = 1,\n  liquid_sink = 1,\n  " ..
  "acceleration_default = 1,\n  acceleration_air = 1,\n  sneak = ")

  core.safe_file_write(core.get_worldpath() .. "/arena_lib/SETTINGS.lua", txt)
  core.log("action", "[ARENA_LIB] Settings: SERVER_PHYSICS has been updated with the new Luanti physics parameters")
end

-- same as above
if not arena_lib.SERVER_PHYSICS.speed_fast and not arena_lib.SERVER_PHYSICS.acceleration_fast then
  local settings = io.open(core.get_worldpath() .. "/arena_lib/SETTINGS.lua", "r")
  local txt = settings:read("*all")

  settings:close()

  txt = txt:gsub("speed_climb = ", "speed_walk = 1,\n  speed_fast = 1,\n  speed_climb = ")
  txt = txt:gsub("sneak = ", "acceleration_fast = 1,\n  sneak = ")

  core.safe_file_write(core.get_worldpath() .. "/arena_lib/SETTINGS.lua", txt)
  core.log("action", "[ARENA_LIB] Settings: SERVER_PHYSICS has been updated with the new Luanti physics parameters")
end

add_new_parameter("RESET_NODES_PER_TICK", {
  "-- For minigames with map regeneration enabled. The amount of nodes to reset on",
  "-- each step. The higher you set it the faster it'll go, but it'll also increase lag",
  "arena_lib.RESET_NODES_PER_TICK = 40"
})

add_new_parameter("SHOW_REJOIN_DIALOG", {
  "-- When true, if a player crashes inside an arena, and the minigame they were",
  "-- playing in allows to join whilst in progress, arena_lib will ask them if they",
  "-- want to rejoin as soon as they reconnect (the match still has to be in progress).",
  "-- The dialog is shown after 0.1s from the login",
  "arena_lib.SHOW_REJOIN_DIALOG = true"
})

add_new_parameter("BLOCKED_CMDS", {
  "-- Commands that players (admins included) won't be able to use during a match",
  "arena_lib.BLOCKED_CMDS = {",
  "  \"clearinv\",",
  "  \"pulverize\"",
  "}"
})
--^------------------ LEGACY UPDATE, to remove in 9.0 -------------------^





----------------------------------------------
------------------AUDIO_LIB-------------------
----------------------------------------------

audio_lib.register_type("arena_lib", "notifications", {mod = "arena_lib", type = S("Notifications")})

audio_lib.register_sound("sfx", "arenalib_countdown", S("Countdown ticks"))
audio_lib.register_sound("notifications", "arenalib_match_elim", S("Someone is eliminated"))
audio_lib.register_sound("notifications", "arenalib_match_join", S("Someone joins"))
audio_lib.register_sound("notifications", "arenalib_match_leave", S("Someone leaves"))
audio_lib.register_sound("notifications", "arenalib_queue_join", S("Someone joins (queue)"), {gain = 0.7, pitch = 1.25})
audio_lib.register_sound("notifications", "arenalib_queue_leave", S("Someone leaves (queue)"), {gain = 2.0})

local function register_bgm(dir)
  for _, f_name in pairs(core.get_dir_list(dir, false)) do
    audio_lib.register_sound("bgm", f_name:sub(1, -5), S("-- missing description --"))

    for _, subdir in pairs(core.get_dir_list(dir, true)) do
      register_bgm(dir .. "/" .. subdir)
    end
  end
end

register_bgm(core.get_worldpath() .. "/arena_lib/BGM")