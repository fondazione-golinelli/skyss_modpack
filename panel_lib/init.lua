panel_lib = {}
local version = "3.2.2"
local srcpath = minetest.get_modpath("panel_lib") .. "/src"

dofile(srcpath .. "/api.lua")
dofile(srcpath .. "/player_manager.lua")

minetest.log("action", "[PANEL_LIB] Mod initialised, running version " .. version)
