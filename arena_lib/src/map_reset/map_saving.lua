local S = core.get_translator("arena_lib")

local function backup_node() end

local hash_node_position = core.hash_node_position
local get_node = core.get_node
local set_node = core.set_node
local swap_node = core.swap_node
local bulk_set_node = core.bulk_set_node
local bulk_swap_node = core.bulk_swap_node

arena_lib.maps = arena_lib.load_maps_from_db()



function arena_lib.save_map_schematic(sender, mod, arena_name)
  local id, arena = arena_lib.get_arena_by_name(mod, arena_name)

  -- non uso la macro perché posso usarla anche al di fuori dell'editor e non è
  -- nella sezione CLI dell'API, bensì fuori;
  -- se non esiste l'arena, annullo
  if arena == nil then
    arena_lib.print_error(sender, S("This arena doesn't exist!"))
    return end

  -- se non è disabilitata, annullo
  if arena.enabled then
    arena_lib.print_error(sender, S("You must disable the arena first!"))
    return end

  -- se non ha la regione, annullo
  if not arena.pos1 then
    arena_lib.print_error(sender, S("Region not declared!"))
    return end

  -- se si sta rigenerando, annullo
  if arena.is_resetting then
    arena_lib.print_error(sender, S("The map is resetting, try again in a few seconds!"))
    return end

  arena_lib.update_waypoints(sender, mod, arena)
  core.create_schematic(arena.pos1, arena.pos2, nil, ("%s/arena_lib/Schematics/%s_%d.mts"):format(core.get_worldpath(), mod, id))
  arena_lib.print_info(sender, arena_lib.mods[mod].prefix .. S("Schematic of arena @1 successfully saved", arena.name))
end



core.register_on_placenode(function(pos, newnode, player, oldnode)
  local mod = arena_lib.get_mod_by_pos(pos)
  if not mod or not arena_lib.mods[mod].regenerate_map then return end

  local arena = arena_lib.get_arena_by_pos(pos)
  if arena and arena.enabled then
    local id = arena_lib.get_arena_by_name(mod, arena.name)
    backup_node(mod, id, pos, oldnode)
  end
end)



core.register_on_dignode(function(pos, oldnode, player)
  local mod = arena_lib.get_mod_by_pos(pos)
  if not mod or not arena_lib.mods[mod].regenerate_map then return end

  local arena = arena_lib.get_arena_by_pos(pos)
  if arena and arena.enabled then
    local id = arena_lib.get_arena_by_name(mod, arena.name)
    backup_node(mod, id, pos, oldnode)
  end
end)



-- marking nodes whose inventory changed as to reset
core.register_on_player_inventory_action(function(player, action, inventory, inventory_action)
  if arena_lib.is_player_in_edit_mode(player:get_player_name()) then return end

  -- TODO: serve un modo per beccare l'inventario aperto senza tracciare un raggio,
  -- ma al momento MT non lo permette. Perché se si usa il tocco, non per forza si
  -- sta guardando al nodo aperto
  local head_pos = vector.add(player:get_pos(), vector.new(0, 1.5, 0))
  local look_dir = player:get_look_dir()
  local p1 = vector.add(head_pos, vector.divide(look_dir, 2)) -- evita che si prenda da solə
  local p2 = vector.add(head_pos, vector.multiply(look_dir, 10))
  local p_thing = core.raycast(p1, p2):next()

  if not p_thing or p_thing.type ~= "node" then return end

  local pos = p_thing.under
  local arena = arena_lib.get_arena_by_pos(pos)
  local mod = arena_lib.get_mod_by_pos(pos)

  if not arena or not arena_lib.mods[mod].regenerate_map then return end

  local mod = arena_lib.get_mod_by_pos(pos)
  local id = arena_lib.get_arena_by_name(mod, arena.name)

  backup_node(mod, id, pos, get_node(pos))
end)





----------------------------------------------
-----------------OVERRIDES--------------------
----------------------------------------------

function core.set_node(pos, node, track_operation)
  local mod = arena_lib.get_mod_by_pos(pos)

  if track_operation == false then
    return set_node(pos, node)
  end

  if mod and arena_lib.mods[mod].regenerate_map then
    local arena = arena_lib.get_arena_by_pos(pos)

    if arena and arena.enabled then
      core.load_area(pos) -- so that the system doesn't save CONTENT_IGNORE
      local id = arena_lib.get_arena_by_name(mod, arena.name)
      local oldnode = get_node(pos)

      -- controlla se il nuovo nodo è un liquido
      local nodedef = core.registered_nodes[node.name]
      local is_liquid = nodedef and nodedef.liquidtype and nodedef.liquidtype ~= "none"

      backup_node(mod, id, pos, oldnode, is_liquid)
    end
  end

  return set_node(pos, node)
end

function core.add_node(pos, node, track_operation)
  core.set_node(pos, node, track_operation)
end

function core.remove_node(pos, track_operation)
  if track_operation == false then
    set_node(pos, {name="air"})
  else
    core.set_node(pos, {name="air"})
  end
end

function core.swap_node(pos, node)
  local mod = arena_lib.get_mod_by_pos(pos)

  if mod and arena_lib.mods[mod].regenerate_map then
    local arena = arena_lib.get_arena_by_pos(pos)

    if arena and arena.enabled then
      core.load_area(pos) -- so that the system doesn't save CONTENT_IGNORE
      local id = arena_lib.get_arena_by_name(mod, arena.name)
      local oldnode = get_node(pos)
      backup_node(mod, id, pos, oldnode)
    end
  end

  return swap_node(pos, node)
end

function core.bulk_set_node(positions, node, track_operation)
  if track_operation == false then
    return bulk_set_node(positions, node)
  end

  for i, pos in ipairs(positions) do
    local mod = arena_lib.get_mod_by_pos(pos)

    if mod and arena_lib.mods[mod].regenerate_map then
      local arena = arena_lib.get_arena_by_pos(pos)

      if arena then
        core.load_area(pos) -- so that the system doesn't save CONTENT_IGNORE
        local id = arena_lib.get_arena_by_name(mod, arena.name)
        local oldnode = get_node(pos)
        -- save onto db only if it's the last position to avoid huge overhead
        if i == #positions then backup_node(mod, id, pos, oldnode)
        else backup_node(mod, id, pos, oldnode, false, false) end
      end
    end
  end

  return bulk_set_node(positions, node)
end

function core.bulk_swap_node(positions, node)
  for i, pos in ipairs(positions) do
    local mod = arena_lib.get_mod_by_pos(pos)

    if mod and arena_lib.mods[mod].regenerate_map then
      local arena = arena_lib.get_arena_by_pos(pos)

      if arena then
        core.load_area(pos) -- so that the system doesn't save CONTENT_IGNORE
        local id = arena_lib.get_arena_by_name(mod, arena.name)
        local oldnode = get_node(pos)
        -- save onto db only if it's the last position to avoid huge overhead
        if i == #positions then backup_node(mod, id, pos, oldnode)
        else backup_node(mod, id, pos, oldnode, false, false) end
      end
    end
  end

  return bulk_swap_node(positions, node)
end




----------------------------------------------
---------------FUNZIONI LOCALI----------------
----------------------------------------------

function backup_node(mod, arena_id, pos, node, is_liquid, save_in_db)
  local hash_pos = hash_node_position(vector.round(pos))
  local idx = mod .. "_" .. arena_id

  -- in case the map has never been enabled
  if not arena_lib.maps[idx] or not arena_lib.maps[idx].changed_nodes then
    return
  end

  -- if this node has not been changed yet then save it
  if not arena_lib.maps[idx].changed_nodes[hash_pos] then
    if is_liquid then
      arena_lib.maps[idx].changed_nodes[hash_pos] = {node = node, is_liquid = true}
    else
      arena_lib.maps[idx].changed_nodes[hash_pos] = node
    end
  end

  if save_in_db ~= false then
    arena_lib.save_maps_onto_db(arena_lib.maps)
  end
end
