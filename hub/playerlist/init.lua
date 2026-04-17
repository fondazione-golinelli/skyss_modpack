local modpath = core.get_modpath("playerlist")
local srcpath = modpath .. "/src"
playerlist = {}

dofile(srcpath .. "/deps/arena_lib.lua")
dofile(srcpath .. "/deps/collectible_skins.lua")

dofile(srcpath .. "/api.lua")
dofile(srcpath .. "/HUD.lua")
dofile(srcpath .. "/input_manager.lua")
dofile(srcpath .. "/player_manager.lua")

