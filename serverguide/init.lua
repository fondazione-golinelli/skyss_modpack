local srcpath = minetest.get_modpath("serverguide") .. "/src"

serverguide = {}

dofile(srcpath .. "/rules.lua")
dofile(srcpath .. "/commands.lua")
dofile(srcpath .. "/first_steps.lua")
dofile(srcpath .. "/nodes.lua")
dofile(srcpath .. "/values.lua")
