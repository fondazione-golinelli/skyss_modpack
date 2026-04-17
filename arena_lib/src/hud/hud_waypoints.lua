local S = core.get_translator("arena_lib")

local waypoints = {} -- KEY: player name; VALUE: {Waypoints IDs}
local hud_type = core.features.hud_def_type_field and "type" or "hud_elem_type"



function arena_lib.show_waypoints(p_name, mod, arena)
  local player = core.get_player_by_name(p_name)

  -- se sto aggiornando, devo prima rimuovere i vecchi
  if waypoints[p_name] then
    arena_lib.remove_waypoints(p_name)
  end

  waypoints[p_name] = {}

  core.after(0.1, function()
    -- punti rinascita
    if not arena.teams_enabled then
      for ID, spwn in pairs(arena.spawn_points) do
        local HUD_ID = player:hud_add({
          [hud_type]  = "waypoint",
          name        = "#" .. ID,
          precision   = 0,
          world_pos   = spwn.pos
        })

        table.insert(waypoints[p_name], HUD_ID)
      end
    else
      for i = 1, #arena.teams do
        for ID, spwn in pairs(arena.spawn_points[i]) do
          local HUD_ID = player:hud_add({
            [hud_type]  = "waypoint",
            name        = "#" .. ID .. ", " .. arena.teams[i].name,
            precision   = 0,
            world_pos   = spwn.pos
          })

          table.insert(waypoints[p_name], HUD_ID)
        end
      end
    end

    -- punto di ritorno
    local HUD_ID = player:hud_add({
      [hud_type]  = "waypoint",
      name        = arena.custom_return_point and S("Return point (custom)") or S("Return point"),
      precision   = 0,
      world_pos   = arena.custom_return_point and arena.custom_return_point.pos or arena_lib.mods[mod].settings.return_point.pos
    })

    table.insert(waypoints[p_name], HUD_ID)

    -- eventuale regione
    -- TODO: si potrebbe usare https://github.com/minetest/minetest/pull/13020 in
    -- futuro per renderizzare i bordi della regione. Questo renderebbe tuttavia
    -- impossibile fare catture senza avere i bordi renderizzati; per ovviare,
    -- si è ipotizzato di nascondere la regione al premere E su qualsiasi casella,
    -- anche se sarebbe un po' un'esagerazione dato che non penso ci sarebbero altri
    -- elementi grafici da nascondere (i marcatori già spariscono con F2). Un'altra
    -- opzione è aggiungere /arenas tp <arena>, ma questo non appplicherebbe le
    -- personalizzazioni grafiche dell'arena (quindi prob anche peggio)
    if arena.pos1 then
      local pos1 = player:hud_add({
        [hud_type]  = "waypoint",
        name        = "Pos1",
        precision   = 0,
        world_pos   = arena.pos1
      })

      local pos2 = player:hud_add({
        [hud_type]  = "waypoint",
        name        = "Pos2",
        precision   = 0,
        world_pos   = arena.pos2
      })

      table.insert(waypoints[p_name], pos1)
      table.insert(waypoints[p_name], pos2)
    end
  end)
end



function arena_lib.remove_waypoints(p_name)
  local player = core.get_player_by_name(p_name)

  -- potrebbe essersi disconnesso. Evito di computare in caso
  if player then
    for _, waypoint_ID in pairs(waypoints[p_name]) do
      player:hud_remove(waypoint_ID)
    end
  end

  waypoints[p_name] = nil
end



function arena_lib.update_waypoints(p_name, mod, arena)
  if waypoints[p_name] then
    arena_lib.show_waypoints(p_name, mod, arena)
  end
end
