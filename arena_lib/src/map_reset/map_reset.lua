local S = core.get_translator("arena_lib")

local function async_reset_map(mod, arena, nodes_to_process_list) end
local function reset_node_inventory(pos) end

local on_step = core.registered_entities["__builtin:item"].on_step
local get_staticdata = core.registered_entities["__builtin:item"].get_staticdata
local on_activate = core.registered_entities["__builtin:item"].on_activate

local get_position_from_hash = core.get_position_from_hash
local add_node = core.add_node
local get_inventory = core.get_inventory
local bulk_set_node = core.bulk_set_node

-- to associate each dropped item with the match it was dropped in
core.registered_entities["__builtin:item"]._matchID = -1
-- last checked age, in order to perform the check for the drop to be removed; once per sec
core.registered_entities["__builtin:item"]._last_age = 0



core.register_on_mods_loaded(function()
	-- resets all maps in case the server crashed during the last match
	core.after(0, function()
		for mod, mod_data in pairs(arena_lib.mods) do
			if mod_data.regenerate_map then
				for _, arena in pairs(mod_data.arenas) do
					arena.is_resetting = false
					arena_lib.reset_map(mod, arena)
				end
			end
		end
	end)
end)



function arena_lib.reset_map(mod, arena)
	if not arena.pos1 or arena.is_resetting then return end

	if not arena_lib.mods[mod].regenerate_map or not arena.enabled then return end

	async_reset_map(mod, arena)
end



function arena_lib.hard_reset_map(sender, mod, arena_name)
	local id, arena = arena_lib.get_arena_by_name(mod, arena_name)

	-- se l'arena non esiste
	if not arena then
		arena_lib.print_error(sender, S("This arena doesn't exist!"))
		return
	end

	local schem_path = core.get_worldpath() .. ("/arena_lib/Schematics/%s_%d.mts"):format(mod, id)
	local schem = io.open(schem_path, "r")

	-- se la schematica non esiste
	if not schem then
		arena_lib.print_error(sender, S("There is no schematic to paste!"))
		return
	end

	schem:close()

	-- se l'area non esiste
	if not arena.pos1 then
		arena_lib.print_error(sender, S("Region not declared!"))
		return
	end

	core.place_schematic(
		arena.pos1,
		("%s/arena_lib/Schematics/%s_%d.mts"):format(core.get_worldpath(), mod, id),
		"0",
		nil,
		true
	)

	arena_lib.print_info(sender, arena_lib.mods[mod].prefix .. S("Schematic of arena @1 successfully pasted", arena_name))
end



-- removing drops based on the match_id
core.registered_entities["__builtin:item"].on_step = function(self, dtime, moveresult)
	-- returning if it passed less than 1s from the last check
	if self.age - self._last_age < 1 then
		on_step(self, dtime, moveresult)
		return
	end

	local pos = self.object:get_pos()
	local arena = arena_lib.get_arena_by_pos(pos)
	local mod = arena_lib.get_mod_by_pos(pos)
	self._last_age = self.age

	if arena and arena_lib.mods[mod].regenerate_map and arena.matchID then
		-- if the drop has not been initializated yet
		if self._matchID == -1 then
			self._matchID = arena.matchID
		elseif self._matchID ~= arena.matchID then
			self.object:remove()
			return
		end
	elseif arena and arena_lib.mods[mod].regenerate_map then
		self.object:remove()
		return
	end

	on_step(self, dtime, moveresult)
end



core.registered_entities["__builtin:item"].get_staticdata = function(self)
	local original_staticdata = core.deserialize(get_staticdata(self))
	original_staticdata._matchID = self._matchID
	return core.serialize(original_staticdata)
end



core.registered_entities["__builtin:item"].on_activate = function(self, staticdata, dtime_s)
	local data = core.deserialize(staticdata) or {}
	self._matchID = data._matchID
	on_activate(self, staticdata, dtime_s)
end





----------------------------------------------
---------------FUNZIONI LOCALI----------------
----------------------------------------------

function async_reset_map(mod, arena, nodes_to_process_list)
	local maps = arena_lib.maps
	local id = arena_lib.get_arena_by_name(mod, arena.name)
	local idx = mod .. "_" .. id

	local nodes_per_tick = arena_lib.RESET_NODES_PER_TICK

	arena.is_resetting = true

	if not maps[idx] then
		arena.is_resetting = false
        return
	end

	-- Inizializza la lista indicizzata e ordinata solo alla prima chiamata
	if not nodes_to_process_list then
		nodes_to_process_list = {}
		for hash_pos, node_data in pairs(maps[idx].changed_nodes) do
			table.insert(nodes_to_process_list, {hash_pos = hash_pos, node = node_data})
		end
		-- Ordina alfabeticamente per nome nodo
		table.sort(nodes_to_process_list, function(a, b)
			local name_a = a.node.name or (type(a.node) == "table" and a.node.node and a.node.node.name) or ""
			local name_b = b.node.name or (type(b.node) == "table" and b.node.node and b.node.node.name) or ""
			return name_a < name_b
		end)
	end

	local processed_this_tick = 0
	local buckets = {}
	local individual_nodes = {} -- list for nodes with param1/2

	while processed_this_tick < nodes_per_tick and #nodes_to_process_list > 0 do
		local entry = table.remove(nodes_to_process_list, 1)
		local hash_pos = entry.hash_pos
		local node = entry.node
		local pos = get_position_from_hash(hash_pos)

		if type(node) == "table" and node.is_liquid then
			if core.registered_nodes[node.node.name] then
				arena_lib.drain_source(pos)
				add_node(pos, node.node, false)
				reset_node_inventory(pos)
			else
				core.log("warning", "[arena_lib] Skipping unknown liquid node during map reset: " .. (node.node.name or "unknown"))
			end
			-- If a liquid drain occurs, we consider this tick's processing complete
			-- to allow the liquid to flow and be handled in subsequent ticks.
			processed_this_tick = nodes_per_tick
		else
			local node_to_set = node.node or node -- Get the actual node table if wrapped
			local node_name = node_to_set.name or ""

			-- Check if param1 or param2 are present and non-zero, or if it's a complex node
			if (node_to_set.param1 and node_to_set.param1 ~= 0) or (node_to_set.param2 and node_to_set.param2 ~= 0) then
				table.insert(individual_nodes, {pos = pos, node = node_to_set})
			else
				if not buckets[node_name] then
					buckets[node_name] = {positions = {}, node = node_to_set}
				end
				table.insert(buckets[node_name].positions, pos)
			end
			processed_this_tick = processed_this_tick + 1
		end
	end

	-- Bulk set per ogni bucket
	for _, bucket in pairs(buckets) do
		if core.registered_nodes[bucket.node.name] then
			bulk_set_node(bucket.positions, bucket.node, false)
			reset_node_inventory(bucket.positions) -- Reset inventory for bulk set nodes
		else
			core.log("warning", "[arena_lib] Skipping unknown node during map reset: " .. (bucket.node.name or "unknown"))
		end
	end

	-- Add nodes individually for those with param1/param2
	for _, entry in ipairs(individual_nodes) do
		if core.registered_nodes[entry.node.name] then
			add_node(entry.pos, entry.node, false)
			reset_node_inventory(entry.pos) -- Reset inventory for individually set nodes
		else
			core.log("warning", "[arena_lib] Skipping unknown node during map reset: " .. (entry.node.name or "unknown"))
		end
	end

	if #nodes_to_process_list > 0 or #individual_nodes > 0 then
		core.after(0, function()
			async_reset_map(mod, arena, nodes_to_process_list)
		end)
		return
	else
		arena.is_resetting = false
		maps[idx].changed_nodes = {}
		arena_lib.save_maps_onto_db(maps)
	end
end

function reset_node_inventory(pos)
	if type(pos) == "table" then
		for _, p in ipairs(pos) do
			reset_node_inventory(p)
		end
		return
	end

	local location = {type = "node", pos = pos}
	local inv = get_inventory(location)

	if not inv then return end

	for _, list in ipairs(inv:get_lists()) do
		inv:set_list(list, {})
	end
end