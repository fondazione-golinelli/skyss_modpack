local version = "7.12.0-dev"
local srcpath = core.get_modpath("arena_lib") .. "/src"

-- TODO: remove after https://github.com/minetest/modtools/issues/2
local S = core.get_translator("arena_lib")

S("Library to easily create mini-games")

arena_lib = {}
arena_lib.mods = {}
arena_lib.entrances = {}

dofile(srcpath .. "/_load.lua")
dofile(srcpath .. "/utils/debug.lua")
dofile(srcpath .. "/utils/macros.lua")
dofile(srcpath .. "/utils/temp.lua")
dofile(srcpath .. "/utils/utils.lua")

dofile(srcpath .. "/admin_tools/entrances.lua")
dofile(srcpath .. "/admin_tools/minigame_settings.lua")
dofile(srcpath .. "/api/audio.lua")
dofile(srcpath .. "/api/core.lua")
dofile(srcpath .. "/api/in_game.lua")
dofile(srcpath .. "/api/in_queue.lua")
dofile(srcpath .. "/api/map.lua")
dofile(srcpath .. "/api/misc.lua")
dofile(srcpath .. "/api/teams.lua")
dofile(srcpath .. "/callbacks.lua")
dofile(srcpath .. "/chat.lua")
dofile(srcpath .. "/commands.lua")
dofile(srcpath .. "/nodes.lua")
dofile(srcpath .. "/player_manager.lua")
dofile(srcpath .. "/privs.lua")
dofile(srcpath .. "/deps/parties.lua")
dofile(srcpath .. "/editor/editor_main.lua")
dofile(srcpath .. "/editor/editor_icons.lua")
dofile(srcpath .. "/editor/tools_customise.lua")
dofile(srcpath .. "/editor/tools_customise_bgm.lua")
dofile(srcpath .. "/editor/tools_customise_lighting.lua")
dofile(srcpath .. "/editor/tools_customise_sky.lua")
dofile(srcpath .. "/editor/tools_customise_weather.lua")
dofile(srcpath .. "/editor/tools_map.lua")
dofile(srcpath .. "/editor/tools_players.lua")
dofile(srcpath .. "/editor/tools_settings.lua")
dofile(srcpath .. "/editor/tools_spawners.lua")
dofile(srcpath .. "/hud/hud_main.lua")
dofile(srcpath .. "/hud/hud_waypoints.lua")
dofile(srcpath .. "/map_reset/map_saving.lua")
dofile(srcpath .. "/map_reset/map_reset.lua") -- must be loaded after map_saving, or it won't work
dofile(srcpath .. "/map_reset/liquid_reset.lua")
dofile(srcpath .. "/signs/signs.lua")
dofile(srcpath .. "/signs/signs_editor.lua")
dofile(srcpath .. "/spectate/spectate_dummy.lua")
dofile(srcpath .. "/spectate/spectate_main.lua")
dofile(srcpath .. "/spectate/spectate_hand.lua")
dofile(srcpath .. "/spectate/spectate_tools.lua")


core.log("action", "[ARENA_LIB] Mod initialised, running version " .. version)
