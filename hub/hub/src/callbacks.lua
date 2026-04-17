local function make_registration()
  local t = {}
  local registerfunc = function(func)
    t[#t+1] = func
  end
  return t, registerfunc
end



----------------------------------------------
--------------------GLOBAL--------------------
----------------------------------------------

hub.registered_on_set_items, hub.register_on_set_items = make_registration()