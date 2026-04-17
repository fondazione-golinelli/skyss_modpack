local settings = hub.settings
local storage = core.get_mod_storage()

if storage:get_string("celvault") ~= "" then
  hub.celestial_vault = core.deserialize(storage:get_string("celvault"))
end





----------------------------------------------
-----------------GETTERS----------------------
----------------------------------------------

function hub.get_hub_spawn_point()
  return settings.hub_spawn_point
end



function hub.get_additional_items()
  return settings.hotbar_items
end



function hub.get_players_in_hub(to_player)
  local in_hub = {}

  for _, pl in pairs(core.get_connected_players()) do
    local pl_name = pl:get_player_name()
    if not arena_lib.is_player_in_arena(pl_name) then
      if to_player then
        table.insert(in_hub, pl)
      else
        table.insert(in_hub, pl_name)
      end
    end
  end

  return in_hub
end





----------------------------------------------
-----------------SETTERS----------------------
----------------------------------------------

function hub.set_hub_physics(player)
  player:set_physics_override(settings.physics)
end



function hub.set_items(player)
  local inv = player:get_inventory()
  local hotbar_items = {
    nil,
    nil,
    nil,
    nil,
    nil,
    nil,
    nil,
    --TODO al momento è inutile
    --"hub:settings"
  }
  local additional_items = hub.get_additional_items()

  -- eventuali oggetti aggiuntivi
  for i = 1, #additional_items do
    if additional_items[i] ~= "" then
      hotbar_items[i] = additional_items[i]
    end
  end

  for _, callback in ipairs(hub.registered_on_set_items) do
    callback(player, hotbar_items)
  end

  inv:set_list("main", hotbar_items)
  inv:set_list("craft", {})
end



function hub.set_celestial_vault(celvault)
  for _, pl in pairs(hub.get_players_in_hub(true)) do
    -- TEMP: waiting for https://github.com/minetest/minetest/pull/12181 to make it simpler
    if not celvault then
      pl:set_sky()
      pl:set_sun()
      pl:set_moon()
      pl:set_stars()
      pl:set_clouds()
    else
      pl:set_sky(celvault.sky)
      pl:set_sun(celvault.sun)
      pl:set_moon(celvault.moon)
      pl:set_stars(celvault.stars)
      pl:set_clouds(celvault.clouds)
    end
  end

  hub.celestial_vault = celvault
  storage:set_string("celvault", core.serialize(celvault))
end