local S = core.get_translator("arena_lib")

----------------------------------------------
-----------------OVERRIDES--------------------
----------------------------------------------

-- arena_lib deve avere la priorità su tutto il resto (es. poter costruire in un
-- minigioco che lo permette, anche quando ha un'arena piazzata in un'area dove
-- normalmente non si può costruire). Da qui l'after
core.after(0.1, function()
  local old_is_protected = core.is_protected

  function core.is_protected(pos, name)
    -- se lə giocante è in arena e il minigioco non permette di costruire, annulla
    if arena_lib.is_player_in_arena(name) then
      local arena = arena_lib.get_arena_by_player(name)

      if arena.in_game then
        local mod_ref = arena_lib.mods[arena_lib.get_mod_by_player(name)]
        if not mod_ref.can_build then
          return true
        elseif arena.pos1 then
          if vector.in_area(pos, arena.pos1, arena.pos2) then
            return false
          else
            arena_lib.print_error(name, S("You can't build outside the game region!"))
            return true
          end
        else
          return false
        end
      end
    end

    local arena = arena_lib.get_arena_by_pos(pos)

    -- evita che l'arena venga modificata fuori dall'editor se si rigenera
    if arena and arena.is_resetting ~= nil and arena.enabled and not arena.matchID then
      arena_lib.print_error(name, S("You can't modify the map whilst enabled!"))
      return true
    end

    return old_is_protected(pos, name)
  end
end)



-- stop people from dropping items if can_drop is false
local old_item_drop = core.item_drop

core.item_drop = function(itemstack, player, pos)
  if player then
    local p_name = player:get_player_name()
    if arena_lib.is_player_in_arena(p_name) then
      local mod = arena_lib.get_mod_by_player(p_name)
      if not arena_lib.mods[mod].can_drop then
        return itemstack
      end
    end
  end

  return old_item_drop(itemstack, player, pos)
end





----------------------------------------------
-----------------GETTERS----------------------
----------------------------------------------

function arena_lib.get_mod_by_pos(pos)
  for mod, mg_data in pairs(arena_lib.mods) do
    for _, arena in pairs(mg_data.arenas) do
      if arena.pos1 then
        if vector.in_area(pos, arena.pos1, arena.pos2) then
          return mod
        end
      end
    end
  end
end



function arena_lib.get_arena_by_pos(pos, minigame)
  if minigame then
    for _, arena in pairs(arena_lib.mods[minigame].arenas) do
      if arena.pos1 then
        if vector.in_area(pos, arena.pos1, arena.pos2) then
          return arena
        end
      end
    end

  else
    for _, mg_data in pairs(arena_lib.mods) do
      for _, arena in pairs(mg_data.arenas) do
        if arena.pos1 then
          if vector.in_area(pos, arena.pos1, arena.pos2) then
            return arena
          end
        end
      end
    end
  end
end





----------------------------------------------
--------------------UTILS---------------------
----------------------------------------------

function arena_lib.is_player_in_region(arena, p_name)
    if not arena then return end

    if not arena.pos1 then
      core.log("[ARENA_LIB] Attempt to check whether a player is inside an arena region (" .. arena.name .. "), when the arena has got no region declared")
      return end

    local p_pos = core.get_player_by_name(p_name):get_pos()

    return vector.in_area(p_pos, arena.pos1, arena.pos2)
  end
