local version = "2.0.1"
local modpath = core.get_modpath("audio_lib")
local srcpath = modpath .. "/src"

-- TODO: remove after https://github.com/minetest/modtools/issues/2
local S = core.get_translator("audio_lib")

S("Library to easily manage sounds (accessibility options!)")

audio_lib = {}

dofile(srcpath .. "/api.lua")
dofile(srcpath .. "/commands.lua")
dofile(srcpath .. "/items.lua")
dofile(srcpath .. "/player_manager.lua")
dofile(srcpath .. "/settings.lua")
dofile(srcpath .. "/HUD/hud_accessibility.lua")
dofile(srcpath .. "/GUI/gui_settings.lua")
dofile(srcpath .. "/tests/bgm.lua")
--dofile(srcpath .. "/tests/custom_types.lua")
dofile(srcpath .. "/tests/sfx.lua")

core.register_on_mods_loaded(function()
  dofile(srcpath .. "/register/MTG.lua")
end)

core.log("action", "[AUDIO_LIB] Mod initialised, running version " .. version)
