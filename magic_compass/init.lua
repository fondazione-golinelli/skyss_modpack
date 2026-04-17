local version = "2.4.1"
local srcpath = core.get_modpath("magic_compass") .. "/src"

-- TODO: remove after https://github.com/minetest/modtools/issues/2
local S = core.get_translator("magic_compass")

S("Magic Compass")
S("Item to teleport into server-side defined locations")

magic_compass = {}

dofile(srcpath .. "/_load.lua")
dofile(srcpath .. "/callbacks.lua")
dofile(srcpath .. "/deserializer.lua")
dofile(srcpath .. "/items.lua")
dofile(srcpath .. "/utils.lua")
dofile(srcpath .. "/GUI/gui_compass.lua")

core.log("action", "[MAGIC COMPASS] Mod initialised, running version " .. version)
