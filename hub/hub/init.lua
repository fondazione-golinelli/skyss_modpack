local version = "0.1.0-dev"
local srcpath = core.get_modpath("hub") .. "/src/"
hub = {}
hub.settings = {}



dofile(srcpath .. "/_load.lua")
dofile(core.get_worldpath() .. "/hub/SETTINGS.lua")

dofile(srcpath .. "/api.lua")
dofile(srcpath .. "/callbacks.lua")
dofile(srcpath .. "/celestial_vault.lua")
dofile(srcpath .. "/chat.lua")
dofile(srcpath .. "/commands.lua")
dofile(srcpath .. "/inventory.lua")
dofile(srcpath .. "/items.lua")
dofile(srcpath .. "/player_manager.lua")
dofile(srcpath .. "/privs.lua")
dofile(srcpath .. "/unit_tests.lua")
dofile(srcpath .. "/utils.lua")
dofile(srcpath .. "/y_check.lua")
dofile(srcpath .. "/deps/arena_lib.lua")
dofile(srcpath .. "/HUD/hud_arenastatus.lua")


core.log("action", "[HUB] Mod initialised, running version " .. version)
