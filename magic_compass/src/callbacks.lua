-- I had no idea how to do it, so, uhm... this is how Minetest handles callbacks
local function make_registration()
  local t = {}
  local registerfunc = function(func)
    t[#t+1] = func
  end
  return t, registerfunc
end

magic_compass.registered_on_use, magic_compass.register_on_use = make_registration()
magic_compass.registered_on_after_use, magic_compass.register_on_after_use = make_registration()
