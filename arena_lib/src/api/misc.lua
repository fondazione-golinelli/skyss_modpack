----------------------------------------------
--------------------UTILS---------------------
----------------------------------------------

-- channel: "players", "spectators", "both"
function arena_lib.send_message_in_arena(arena, channel, msg, teamID, except_teamID)

  if channel == "players" then
    if teamID then
      if except_teamID then
        for pl_name, pl_stats in pairs(arena.players) do
          if pl_stats.teamID ~= teamID then
            core.chat_send_player(pl_name, msg)
          end
        end
      else
        for pl_name, pl_stats in pairs(arena.players) do
          if pl_stats.teamID == teamID then
            core.chat_send_player(pl_name, msg)
          end
        end
      end
    else
      for pl_name, _ in pairs(arena.players) do
        core.chat_send_player(pl_name, msg)
      end
    end

  elseif channel == "spectators" then
    for sp_name, _ in pairs(arena.spectators) do
      core.chat_send_player(sp_name, msg)
    end

  elseif channel == "both" then
    for psp_name, _ in pairs(arena.players_and_spectators) do
      core.chat_send_player(psp_name, msg)
    end
  end
end



function arena_lib.teleport_onto_spawner(player, arena, spawner_id)
  local p_name = player:get_player_name()

  if not arena.in_game or not arena.players[p_name] then return end

  local spawner

  if spawner_id then
    if arena.teams_enabled then
      spawner = arena.spawn_points[arena.players[p_name].teamID][spawner_id]
    else
      spawner = arena.spawn_points[spawner_id]
    end

  else

    if arena.teams_enabled then
      spawner = arena_lib.get_random_spawner(arena, arena.players[p_name].teamID, true)
    else
      spawner = arena_lib.get_random_spawner(arena, nil, true)
    end
  end

  player:set_pos(spawner.pos)
  player:set_look_horizontal(math.rad(spawner.rot.x))
  player:set_look_vertical(math.rad(spawner.rot.y))
end





----------------------------------------------
-----------------GETTERS----------------------
----------------------------------------------

function arena_lib.get_arena_by_name(mod, arena_name)
  if not arena_lib.mods[mod] then return end

  for id, arena in pairs(arena_lib.mods[mod].arenas) do
    if arena.name == arena_name then
      return id, arena end
  end
end



function arena_lib.get_arena_spawners_count(arena, team_ID)
  if team_ID and arena.teams_enabled then
    return #arena.spawn_points[team_ID]
  else
    if arena.teams_enabled then
      local count = 0
      for i = 1, #arena.teams do
        count = count + #arena.spawn_points[i]
      end
      return count
    else
      return #arena.spawn_points
    end
  end
end



function arena_lib.get_random_spawner(arena, team_ID, pos_and_rot)
  local spawner

  if arena.teams_enabled then
    team_ID = team_ID or math.random(1, #arena.teams)
    spawner = arena.spawn_points[team_ID][math.random(1, table.maxn(arena.spawn_points[team_ID]))]
  else
    spawner = arena.spawn_points[math.random(1,table.maxn(arena.spawn_points))]
  end

  -- to remove in 8.0
  -- una volta deprecato, metti avviso da rimuovere in 9.0 che non c'è più bisogno
  -- di pos_and_rot true perché ritornerà direttamente il punto di rinascita in toto
  if not pos_and_rot then
    local mod = arena_lib.get_mod_by_matchID(arena.matchID) or arena.name
    core.log("warning", "[ARENA_LIB] (" .. mod .. ") get_random_spawner(arena, <team_ID>) is deprecated. Please check the DOCS and use the new format '(arena, <team_ID>, true)' instead, or the new function 'teleport_onto_spawner(..)'")
  end

  return pos_and_rot and spawner or spawner.pos
end
