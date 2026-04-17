local version = "2.2.3"
local srcpath = minetest.get_modpath("parties") .. "/src"

-- TODO: remove after https://github.com/minetest/modtools/issues/2
local S = minetest.get_translator("parties")

S("Parties")
S("Team up with your friends and create a party!")

parties = {}
parties.settings = {}

dofile(srcpath .. "/_load.lua")
dofile(minetest.get_worldpath() .. "/parties/SETTINGS.lua")

dofile(srcpath .. "/api.lua")
dofile(srcpath .. "/callbacks.lua")
dofile(srcpath .. "/commands.lua")
dofile(srcpath .. "/player_manager.lua")
dofile(srcpath .. "/utils.lua")

minetest.log("action", "[PARTIES] Mod initialised, running version " .. version)
