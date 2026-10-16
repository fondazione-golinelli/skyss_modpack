local MOD = "skyss_firegame"
local S = core.get_translator(MOD)
local TAG = "[" .. S("Fire crew") .. "] "

-- ============================================================
-- CONFIGURATION
-- ============================================================

-- The fire starts in a few spots ("fronts") and spreads over the grass and
-- the undergrowth. More players get more fronts and more animals, growing
-- as players ^ exponent (less than linear, because a crowd gets in its own
-- way), so a match lasts about as long for one player as for a class.
local FRONTS_SOLO, FRONTS_EXPONENT, FRONTS_MAX = 2, 0.55, 12
local FRONT_CELLS = 4            -- burning cells when a front starts
local ANIMALS_SOLO, ANIMALS_EXPONENT, ANIMALS_MAX = 2, 0.73, 24
local FIRE_CAP_BASE, FIRE_CAP_PER_FRONT = 30, 12   -- burning cells at most
local BURN_LIMIT_PER_FRONT = 30  -- burned-out cells before the forest is lost

local SPREAD_INTERVAL = 3        -- seconds between two spreading steps
local SPREAD_CHANCE = 0.15       -- chance per burning cell and step
local BURN_TIME_MIN, BURN_TIME_MAX = 45, 70   -- seconds before a cell burns out
local WET_TIME = 25              -- seconds wet ground cannot catch fire

local PUMP_CAPACITY = 13
local COOLDOWN = {flapper = 0.25, pump = 0.4, rake = 0.4, carrier = 0.3}
local CELEBRATION_TIME = 12
-- Water tanks placed by the game along the four main paths that cross at the
-- spawn pad (distances from the pad, beside the path). The rescue centre has
-- two more of its own.
local LANE_CISTERNS = {16, 32, 48}
local LANE_SIDE = 3
-- Leaves lower than this above the ground are pruned once, so players can
-- walk under every tree of the island.
local CLEARANCE = 3

local GRASS = "mcl_core:dirt_with_grass"
local GRASS_P2 = 13              -- green "Forest" grass of the hub map
local FIREBREAK = "mcl_core:grass_path"
local FIRE = MOD .. ":fire"
local SCORCHED = MOD .. ":scorched"
local CHARRED = MOD .. ":charred_log"
local CISTERN = MOD .. ":cistern"
local SIGN = MOD .. ":rescue_sign"

local FLAMMABLE_GROUND = {
	[GRASS] = true,
	["mcl_core:podzol"] = true,
}

-- Small animals of the forest. The entity borrows mesh, skin and animations
-- from the mob of that name when it is installed.
local ANIMALS = {
	{mob = "mobs_mc:rabbit", label = S("Rabbit"), weight = 4, scale = 1},
	{mob = "animalworld:hare", label = S("Hare"), weight = 2, scale = 1},
	{mob = "animalworld:fox", label = S("Fox"), weight = 1, scale = 0.8},
}

local TOOLS = {
	flapper = {
		item = MOD .. ":flapper",
		hint = S("Fire beater: hit a flame up close to beat it out"),
	},
	pump = {
		item = MOD .. ":pump",
		hint = S("Backpack pump: spray water from afar on a 3x3 area. Refill it at the water tanks or at the lake"),
	},
	rake = {
		item = MOD .. ":rake",
		hint = S("Fire rake: scrape the grass away to make a firebreak the fire cannot cross"),
	},
	carrier = {
		item = MOD .. ":carrier",
		hint = S("Animal carrier: click a trapped animal, then walk into the safe zone"),
	},
}
local TOOL_ORDER = {"flapper", "pump", "rake", "carrier"}

local hud_type = core.features.hud_def_type_field and "type" or "hud_elem_type"
local storage = core.get_mod_storage()

-- ============================================================
-- STATE
-- ============================================================

-- Runtime state per arena name. `arena` below is the skyss_minigames match.
local matches = {}
local huds = {}
local last_use = {}
local wield_seen = {}
local serial = 0
local fire_clusters

local function match_of_player(player)
	if not player or not player.is_player or not player:is_player() then return end
	local p_name = player:get_player_name()
	local arena = skyss_minigames.get_match_by_player(p_name)
	if not arena or arena.game.name ~= MOD then return end
	local match = matches[arena.name]
	if match and not match.finished and arena.state == "running" and arena.players[p_name] then
		return match, arena
	end
end

local hash = core.hash_node_position

local function key2d(pos)
	return pos.x .. "," .. pos.z
end

local function inside(match, pos)
	local p1, p2 = match.p1, match.p2
	return pos.x >= p1.x and pos.x <= p2.x and pos.y >= p1.y and pos.y <= p2.y
		and pos.z >= p1.z and pos.z <= p2.z
end

local function in_safe_zone(match, pos, margin)
	local safe = match.safe
	if not safe then return false end
	local dx, dz = pos.x - safe.pos.x, pos.z - safe.pos.z
	return dx * dx + dz * dz <= (safe.radius + (margin or 0)) ^ 2 and math.abs(pos.y - safe.pos.y) <= 6
end

local function format_time(seconds)
	seconds = math.max(0, math.floor(seconds + 0.5))
	return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function elapsed(match)
	local stop = match.stopped_us or core.get_us_time()
	return (stop - match.started_us) / 1000000
end

local function chat(arena, message)
	for p_name in pairs(arena.players) do
		core.chat_send_player(p_name, core.colorize("#ff9a5c", TAG) .. message)
	end
end

local function hint(p_name, text, color, seconds)
	skyss_minigames.hint_player(p_name, text, seconds or 3, color or 0xffffff)
end

local function sound(name, params)
	params = params or {}
	params.gain = params.gain or 0.6
	core.sound_play(name, params, true)
end

local function small_plant(name)
	if name == FIRE then return false end
	return core.get_item_group(name, "plant") > 0 or core.get_item_group(name, "flower") > 0
		or core.get_item_group(name, "double_plant") > 0
		or name == "mcl_core:deadbush" or name:find("^mcl_flowers:") ~= nil
end

local function count(t)
	local n = 0
	for _ in pairs(t) do n = n + 1 end
	return n
end

local function shuffle(list)
	for i = #list, 2, -1 do
		local j = math.random(i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

local function stats_of(match, p_name)
	match.stats[p_name] = match.stats[p_name] or {fires = 0, animals = 0, breaks = 0}
	return match.stats[p_name]
end

-- ============================================================
-- FIRE CELLS
-- ============================================================

-- A cell is the air (or small plant) node just above flammable ground.
local function burnable_cell(match, pos)
	if not inside(match, pos) or in_safe_zone(match, pos, 1) then return false end
	local node = core.get_node(pos)
	if node.name ~= "air" and not small_plant(node.name) then return false end
	local below = core.get_node(vector.offset(pos, 0, -1, 0))
	if not FLAMMABLE_GROUND[below.name] then return false end
	local wet = match.wet[key2d(pos)]
	if wet and wet > core.get_us_time() then return false end
	return true
end

-- The cell of column (x, z) close to height y, or nil.
local function cell_near(match, x, y, z)
	for _, dy in ipairs({0, 1, -1}) do
		local pos = {x = x, y = y + dy, z = z}
		if burnable_cell(match, pos) then return pos end
	end
end

local function fire_count(match)
	return match.nfires
end

local finish
local hud_update_all
local animals_flee

local function ignite(arena, match, pos)
	local key = hash(pos)
	if match.fires[key] then return false end
	local node = core.get_node(pos)
	if node.name ~= "air" then
		-- Tall plants have a top half: it burns too.
		local up = vector.offset(pos, 0, 1, 0)
		if core.get_node(up).name:find("_top$") then core.remove_node(up) end
	end
	core.set_node(pos, {name = FIRE})
	match.fires[key] = {
		pos = vector.copy(pos),
		out_at = core.get_us_time() + math.random(BURN_TIME_MIN, BURN_TIME_MAX) * 1000000,
	}
	match.nfires = match.nfires + 1
	match.fire_version = (match.fire_version or 0) + 1
	match.ignited = match.ignited + 1
	if match.nfires > match.peak then match.peak = match.nfires end
	return true
end

local function char_tree(match, pos)
	-- The trunk at pos turns black from its base up, the crown loses leaves.
	local base = vector.copy(pos)
	while core.get_item_group(core.get_node(vector.offset(base, 0, -1, 0)).name, "tree") > 0 do
		base.y = base.y - 1
	end
	local key = hash(base)
	if match.charred[key] then return end
	match.charred[key] = true
	local top = vector.copy(base)
	for _ = 1, 16 do
		local node = core.get_node(top)
		if core.get_item_group(node.name, "tree") == 0 then break end
		core.swap_node(top, {name = CHARRED, param2 = node.param2})
		top.y = top.y + 1
	end
	local leaves = core.find_nodes_in_area(vector.offset(top, -2, -3, -2), vector.offset(top, 2, 2, 2), {"group:leaves"})
	for _, p in ipairs(leaves) do
		if math.random() < 0.6 then core.remove_node(p) end
	end
end

local function burn_out(arena, match, key)
	local fire = match.fires[key]
	match.fires[key] = nil
	match.nfires = match.nfires - 1
	match.fire_version = (match.fire_version or 0) + 1
	local pos = fire.pos
	if core.get_node(pos).name == FIRE then core.remove_node(pos) end
	local ground = vector.offset(pos, 0, -1, 0)
	if FLAMMABLE_GROUND[core.get_node(ground).name] then
		core.set_node(ground, {name = SCORCHED})
	end
	for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
		for dy = 0, 1 do
			local p = vector.offset(pos, d[1], dy, d[2])
			if core.get_item_group(core.get_node(p).name, "tree") > 0 then
				char_tree(match, p)
				break
			end
		end
	end
	match.burned = match.burned + 1
	core.add_particlespawner({
		amount = 6, time = 0.3,
		minpos = vector.offset(pos, -0.4, -0.3, -0.4), maxpos = vector.offset(pos, 0.4, 0.3, 0.4),
		minvel = {x = -0.3, y = 0.8, z = -0.3}, maxvel = {x = 0.3, y = 1.6, z = 0.3},
		minexptime = 1.5, maxexptime = 3, minsize = 3, maxsize = 5,
		texture = MOD .. "_smoke.png^[multiply:#3a3a3a",
	})
end

local function extinguish(arena, match, key, p_name)
	local fire = match.fires[key]
	if not fire then return false end
	match.fires[key] = nil
	match.nfires = match.nfires - 1
	match.fire_version = (match.fire_version or 0) + 1
	match.extinguished = match.extinguished + 1
	if core.get_node(fire.pos).name == FIRE then core.remove_node(fire.pos) end
	match.wet[key2d(fire.pos)] = core.get_us_time() + WET_TIME * 1000000
	if p_name then
		local st = stats_of(match, p_name)
		st.fires = st.fires + 1
	end
	core.add_particlespawner({
		amount = 8, time = 0.2,
		minpos = vector.offset(fire.pos, -0.3, -0.3, -0.3), maxpos = vector.offset(fire.pos, 0.3, 0.2, 0.3),
		minvel = {x = -0.3, y = 1, z = -0.3}, maxvel = {x = 0.3, y = 2, z = 0.3},
		minexptime = 0.8, maxexptime = 1.6, minsize = 2, maxsize = 4,
		texture = MOD .. "_smoke.png^[multiply:#e8e8e8",
	})
	return true
end

-- Fire keys near a position (the pointed node and the cell above it).
local function fire_at(match, pos)
	for _, p in ipairs({pos, vector.offset(pos, 0, 1, 0)}) do
		local key = hash(p)
		if match.fires[key] then return key end
	end
end

-- ============================================================
-- HUD
-- ============================================================

local PANEL_MARGIN, PANEL_Y, PANEL_W, PANEL_H = 16, 16, 340, 238
local BAR_X = 44
local BAR_W = PANEL_W - BAR_X - 14
local MAX_WAYPOINTS = 8

local function fill(color)
	return "[fill:1x1:" .. color
end

local function hud_add(player, h, kind, x, y, def)
	def[hud_type] = kind
	def.position = {x = 1, y = 0}
	def.offset = {x = x - PANEL_W - PANEL_MARGIN, y = PANEL_Y + y}
	def.alignment = def.alignment or {x = 1, y = 1}
	def.z_index = def.z_index or 900
	local id = player:hud_add(def)
	h.all[#h.all + 1] = id
	return id
end

local ROWS = {
	{key = "fires", icon = MOD .. "_hud_fire.png", label = S("Fires burning")},
	{key = "animals", icon = MOD .. "_hud_paw.png", label = S("Animals rescued")},
	{key = "burned", icon = MOD .. "_hud_burned.png", label = S("Forest burned")},
}

local function hud_create(player)
	local p_name = player:get_player_name()
	if huds[p_name] then return huds[p_name] end
	local h = {all = {}, rows = {}, waypoints = {}, waypoint_sig = "", cache = {}}

	hud_add(player, h, "image", 0, 0, {text = fill("#1d110dd8"), scale = {x = PANEL_W, y = PANEL_H}, z_index = 899})
	hud_add(player, h, "image", 0, 0, {text = fill("#ff7a3c"), scale = {x = PANEL_W, y = 4}})
	hud_add(player, h, "text", 14, 14, {text = S("WILDFIRE CREW"), number = 0xffa060, style = 1})
	h.timer = hud_add(player, h, "text", PANEL_W - 14, 14, {text = "00:00", number = 0xffffff, style = 5, alignment = {x = -1, y = 1}})

	for i, row_def in ipairs(ROWS) do
		local y = 40 + (i - 1) * 42
		local row = {}
		hud_add(player, h, "image", 12, y + 2, {text = row_def.icon, scale = {x = 1.5, y = 1.5}})
		hud_add(player, h, "text", BAR_X, y, {text = row_def.label, number = 0xeadbd0})
		row.value = hud_add(player, h, "text", PANEL_W - 14, y, {text = "", number = 0xffffff, style = 1, alignment = {x = -1, y = 1}})
		hud_add(player, h, "image", BAR_X, y + 22, {text = fill("#3a2620"), scale = {x = BAR_W, y = 10}})
		row.bar = hud_add(player, h, "image", BAR_X, y + 22, {text = "", scale = {x = 1, y = 10}, z_index = 901})
		h.rows[row_def.key] = row
	end

	hud_add(player, h, "image", 14, 168, {text = fill("#ffffff30"), scale = {x = PANEL_W - 28, y = 1}})
	h.water_icon = hud_add(player, h, "image", 12, 176, {text = MOD .. "_hud_water.png", scale = {x = 1.5, y = 1.5}})
	h.water = hud_add(player, h, "text", BAR_X, 178, {text = "", number = 0xffffff})
	h.carry = hud_add(player, h, "text", PANEL_W - 14, 178, {text = "", number = 0x9be26f, alignment = {x = -1, y = 1}})
	h.mine = hud_add(player, h, "text", BAR_X, 198, {text = "", number = 0xb8a59a})
	h.footer = hud_add(player, h, "text", BAR_X, 218, {text = "", number = 0xb8a59a})

	huds[p_name] = h
	return h
end

local function hud_clear_waypoints(player, h)
	for _, id in ipairs(h.waypoints) do
		player:hud_remove(id)
	end
	h.waypoints = {}
	h.waypoint_sig = ""
end

local function hud_remove(player)
	local p_name = player:get_player_name()
	local h = huds[p_name]
	if not h then return end
	for _, id in ipairs(h.all) do
		player:hud_remove(id)
	end
	hud_clear_waypoints(player, h)
	huds[p_name] = nil
end

local function best_time()
	local P = skyss_minigames._internal
	if not (P and P.get_board) then return end
	local board = P.get_board(MOD, "time")
	return board[1] and board[1].value
end

-- Sends a HUD change only when the value is new: the HUD refreshes twice
-- a second for up to 30 players.
local function change(player, h, id, stat, value)
	local key = id .. stat
	local cached = h.cache[key]
	if type(value) == "table" then
		if cached and cached.x == value.x and cached.y == value.y then return end
	elseif cached == value then
		return
	end
	h.cache[key] = value
	player:hud_change(id, stat, value)
end

local function set_bar(player, h, row, frac, color)
	if frac > 0 then
		change(player, h, row.bar, "text", fill(color))
		change(player, h, row.bar, "scale", {x = math.max(1, math.floor(BAR_W * math.min(1, frac))), y = 10})
	else
		change(player, h, row.bar, "text", "")
	end
end

-- Burning areas: flames grouped on a 10x10 grid, with their count.
local FIRE_WAYPOINTS = 4
local CLUSTER_GRID = 10

fire_clusters = function(match)
	if match.clusters and match.clusters_n == match.nfires and match.clusters_v == match.fire_version then
		return table.copy(match.clusters)
	end
	local cells = {}
	for _, fire in pairs(match.fires) do
		local p = fire.pos
		local key = math.floor(p.x / CLUSTER_GRID) .. "," .. math.floor(p.z / CLUSTER_GRID)
		local c = cells[key]
		if not c then
			c = {x = 0, z = 0, y = p.y, n = 0}
			cells[key] = c
		end
		c.x, c.z, c.n = c.x + p.x, c.z + p.z, c.n + 1
		if p.y > c.y then c.y = p.y end
	end
	local list = {}
	for _, c in pairs(cells) do
		list[#list + 1] = {pos = vector.round({x = c.x / c.n, y = c.y + 1, z = c.z / c.n}), n = c.n}
	end
	match.clusters, match.clusters_n, match.clusters_v = list, match.nfires, match.fire_version
	return table.copy(list)
end

local function trapped_animals(match)
	local list = {}
	for id, rec in pairs(match.animals) do
		if rec.state == "trapped" then list[#list + 1] = rec end
	end
	return list
end

local function nearest(list, pos)
	local best, best_d
	for _, p in ipairs(list) do
		local d = vector.distance(p, pos)
		if not best_d or d < best_d then best, best_d = p, d end
	end
	return best
end

-- Waypoints: the safe zone while carrying an animal, a water tank when the
-- pump is empty, the last flames and the last trapped animals.
local function wanted_waypoints(match, p_name, player)
	local list = {}
	if match.carrying[p_name] and match.safe then
		list[#list + 1] = {name = S("Safe zone"), pos = vector.offset(match.safe.pos, 0, 1, 0), color = 0x9be26f}
	end
	if (match.water[p_name] or 0) <= 0 then
		local tank = nearest(match.cisterns, player:get_pos())
		if tank then
			list[#list + 1] = {name = S("Water tank"), pos = vector.offset(tank, 0, 1, 0), color = 0x4fa8ff}
		end
	end
	-- The nearest burning areas, always.
	local clusters = fire_clusters(match)
	local ppos = player:get_pos()
	table.sort(clusters, function(a, b) return vector.distance(a.pos, ppos) < vector.distance(b.pos, ppos) end)
	for i = 1, math.min(FIRE_WAYPOINTS, #clusters) do
		list[#list + 1] = {name = S("Fire (@1)", clusters[i].n), pos = clusters[i].pos, color = 0xff7a3c}
	end
	local trapped = trapped_animals(match)
	if #trapped > 0 and #trapped <= math.max(2, math.ceil(match.total_animals * 0.25)) then
		for _, rec in ipairs(trapped) do
			if #list >= MAX_WAYPOINTS then break end
			list[#list + 1] = {name = rec.label, pos = vector.offset(rec.pos, 0, 0.8, 0), color = 0xffd43b}
		end
	end
	return list
end

local function hud_update_waypoints(match, p_name, player, h)
	local list = match.finished and {} or wanted_waypoints(match, p_name, player)
	local sig = ""
	for _, wp in ipairs(list) do
		sig = sig .. wp.name .. core.pos_to_string(vector.round(wp.pos)) .. ";"
	end
	if sig == h.waypoint_sig then return end
	hud_clear_waypoints(player, h)
	h.waypoint_sig = sig
	for _, wp in ipairs(list) do
		local def = {name = wp.name, text = " m", precision = 1, number = wp.color,
			world_pos = wp.pos, z_index = -300}
		def[hud_type] = "waypoint"
		h.waypoints[#h.waypoints + 1] = player:hud_add(def)
	end
end

local function hud_update_player(arena, match, p_name)
	local player = core.get_player_by_name(p_name)
	if not player then return end
	local h = hud_create(player)
	local rows = h.rows

	change(player, h, h.timer, "text", format_time(elapsed(match)))

	change(player, h, rows.fires.value, "text", tostring(match.nfires))
	change(player, h, rows.fires.value, "number", match.nfires == 0 and 0x9be26f or 0xff9a5c)
	set_bar(player, h, rows.fires, match.nfires / math.max(1, match.fire_cap), "#ff7a3c")

	change(player, h, rows.animals.value, "text", match.rescued .. " / " .. match.total_animals)
	change(player, h, rows.animals.value, "number", match.rescued >= match.total_animals and 0x9be26f or 0xffffff)
	set_bar(player, h, rows.animals, match.rescued / math.max(1, match.total_animals), "#9be26f")

	local danger = match.burned / math.max(1, match.burn_limit)
	change(player, h, rows.burned.value, "text", match.burned .. " / " .. match.burn_limit)
	change(player, h, rows.burned.value, "number", danger >= 0.75 and 0xff5a4a or 0xffffff)
	set_bar(player, h, rows.burned, danger, danger >= 0.75 and "#ff5a4a" or "#c8783a")

	local water = match.water[p_name] or 0
	change(player, h, h.water_icon, "text", MOD .. (water > 0 and "_hud_water.png" or "_hud_water_empty.png"))
	change(player, h, h.water, "text", S("Pump: @1 / @2", water, PUMP_CAPACITY))
	change(player, h, h.water, "number", water > 0 and 0xffffff or 0xff9a7a)
	local carried = match.carrying[p_name] and match.animals[match.carrying[p_name]]
	change(player, h, h.carry, "text", carried and S("Carrying: @1", carried.label) or "")

	local st = stats_of(match, p_name)
	change(player, h, h.mine, "text", S("Your work: @1 flames, @2 animals, @3 firebreaks", st.fires, st.animals, st.breaks))
	local record = best_time()
	change(player, h, h.footer, "text", S("Record: @1", record and format_time(record) or "--:--"))

	hud_update_waypoints(match, p_name, player, h)
end

hud_update_all = function(arena, match)
	for p_name in pairs(arena.players) do
		hud_update_player(arena, match, p_name)
	end
end

-- ============================================================
-- ANIMALS
-- ============================================================

local models = {}

-- Mesh, skins and animations of a registered mob (see skyss_hub_fauna).
local function model_of(name)
	if models[name] ~= nil then return models[name] or nil end
	local def = core.registered_entities[name]
	local props = def and def.initial_properties or def
	local model = false
	if props and props.visual == "mesh" and props.mesh then
		local list = def.texture_list or props.textures
		local sets = {}
		if type(list) == "table" then
			if type(list[1]) == "table" then
				for _, set in ipairs(list) do
					if set[1] then sets[#sets + 1] = table.copy(set) end
				end
			elseif list[1] then
				sets[1] = table.copy(list)
			end
		end
		if sets[1] then
			local anim = def.animation or {}
			local stand = {x = anim.stand_start or 0, y = anim.stand_end or 0}
			local move = anim.walk_start and {x = anim.walk_start, y = anim.walk_end or anim.walk_start}
				or anim.jump_start and {x = anim.jump_start, y = anim.jump_end or anim.jump_start} or stand
			model = {
				mesh = props.mesh,
				sets = sets,
				visual_size = props.visual_size or {x = 1, y = 1},
				collisionbox = props.collisionbox or {-0.3, 0, -0.3, 0.3, 0.6, 0.3},
				stand = stand,
				stand_speed = anim.stand_speed or anim.speed_normal or 15,
				move = move,
				move_speed = anim.walk_speed or anim.jump_speed or anim.speed_normal or 20,
			}
		end
	end
	models[name] = model
	return model or nil
end

local function available_animals()
	local list = {}
	for _, a in ipairs(ANIMALS) do
		if model_of(a.mob) then list[#list + 1] = a end
	end
	return list
end

local function pick_animal(list)
	local total = 0
	for _, a in ipairs(list) do total = total + a.weight end
	local roll = math.random() * total
	for _, a in ipairs(list) do
		roll = roll - a.weight
		if roll <= 0 then return a end
	end
	return list[1]
end

local function animal_look(obj, rec)
	local model = model_of(rec.mob)
	if not model then return end
	local scale = rec.scale or 1
	local box = table.copy(model.collisionbox)
	for i = 1, 6 do box[i] = box[i] * scale end
	obj:set_properties({
		visual = "mesh",
		mesh = model.mesh,
		textures = model.sets[rec.skin] or model.sets[1],
		visual_size = {x = model.visual_size.x * scale, y = model.visual_size.y * scale,
			z = (model.visual_size.z or model.visual_size.x) * scale},
		selectionbox = {box[1] - 0.15, box[2], box[3] - 0.15, box[4] + 0.15, box[5] + 0.15, box[6] + 0.15},
		infotext = rec.state == "trapped" and S("@1: in danger among the flames! Use the carrier", rec.label) or rec.label,
	})
	if rec.state == "trapped" then
		obj:set_animation(model.move, model.move_speed * 1.5, 0, true)
	else
		obj:set_animation(model.stand, model.stand_speed, 0, true)
	end
end

local function alarm_spawner(obj)
	return core.add_particlespawner({
		amount = 2, time = 0, attached = obj,
		minpos = {x = 0, y = 1.1, z = 0}, maxpos = {x = 0, y = 1.1, z = 0},
		minvel = {x = 0, y = 0.6, z = 0}, maxvel = {x = 0, y = 0.6, z = 0},
		minexptime = 0.8, maxexptime = 0.8, minsize = 3, maxsize = 3,
		texture = MOD .. "_alarm.png", glow = 14,
	})
end

local pick_up

core.register_entity(MOD .. ":animal", {
	initial_properties = {
		physical = false,
		collide_with_objects = false,
		pointable = true,
		visual = "sprite",
		textures = {"blank.png"},
		glow = 3,
		static_save = true,
	},

	get_staticdata = function(self)
		return core.serialize({arena = self.arena_name, token = self.token, id = self.id})
	end,

	on_activate = function(self, staticdata)
		local data = core.deserialize(staticdata or "") or {}
		local match = matches[data.arena or ""]
		local rec = match and match.token == data.token and match.animals[data.id]
		if not rec then
			-- Leftover from a finished or crashed match.
			self.object:remove()
			return
		end
		self.arena_name, self.token, self.id = data.arena, data.token, data.id
		rec.obj = self.object
		self.object:set_armor_groups({immortal = 1})
		self.object:set_yaw(rec.yaw or 0)
		animal_look(self.object, rec)
		if rec.state == "trapped" then
			rec.spawner = alarm_spawner(self.object)
		end
	end,

	on_punch = function(self, puncher)
		pick_up(puncher, self)
		return true
	end,

	on_rightclick = function(self, clicker)
		pick_up(clicker, self)
	end,
})

local function spawn_animal(arena, match, rec)
	rec.obj = nil
	local obj = core.add_entity(vector.offset(rec.pos, 0, -0.5, 0), MOD .. ":animal",
		core.serialize({arena = arena.name, token = match.token, id = rec.id}))
	return obj
end

local function remove_animal_obj(rec)
	if rec.spawner then core.delete_particlespawner(rec.spawner) rec.spawner = nil end
	if rec.obj and rec.obj:get_pos() then rec.obj:remove() end
	rec.obj = nil
end

-- A free spot inside the safe zone, on its floor.
local function pen_spot(match)
	local safe = match.safe
	for _ = 1, 20 do
		local a = math.random() * math.pi * 2
		local r = math.random() * (safe.radius - 2)
		local pos = vector.round({x = safe.pos.x + math.cos(a) * r, y = safe.pos.y, z = safe.pos.z + math.sin(a) * r})
		if core.get_node(pos).name == "air" and core.get_node(vector.offset(pos, 0, 1, 0)).name == "air" then
			return pos
		end
	end
	return vector.copy(safe.pos)
end

local function release(arena, match, p_name, player)
	local id = match.carrying[p_name]
	local rec = id and match.animals[id]
	match.carrying[p_name] = nil
	if not rec then return end
	if rec.obj and rec.obj:get_pos() then pcall(rec.obj.set_detach, rec.obj) end
	rec.state = "safe"
	rec.pos = pen_spot(match)
	rec.yaw = math.random() * math.pi * 2
	if rec.obj and rec.obj:get_pos() then
		rec.obj:set_pos(vector.offset(rec.pos, 0, -0.5, 0))
		rec.obj:set_yaw(rec.yaw)
		animal_look(rec.obj, rec)
	else
		spawn_animal(arena, match, rec)
	end
	match.rescued = match.rescued + 1
	local st = stats_of(match, p_name)
	st.animals = st.animals + 1
	core.add_particlespawner({
		amount = 8, time = 0.4,
		minpos = vector.offset(rec.pos, -0.3, 0.3, -0.3), maxpos = vector.offset(rec.pos, 0.3, 0.8, 0.3),
		minvel = {x = -0.3, y = 1, z = -0.3}, maxvel = {x = 0.3, y = 1.8, z = 0.3},
		minexptime = 1, maxexptime = 1.6, minsize = 2, maxsize = 3,
		texture = MOD .. "_heart.png", glow = 10,
	})
	sound("mcl_experience", {pos = rec.pos, gain = 0.5, max_hear_distance = 24})
	for name in pairs(arena.players) do
		hint(name, S("Animal saved by @1: @2 (@3 / @4)", p_name, rec.label, match.rescued, match.total_animals), 0x9be26f, 3)
	end
end

-- Puts the animal a player carried back where the player stands.
local function drop_back(arena, match, p_name, pos)
	local id = match.carrying[p_name]
	match.carrying[p_name] = nil
	local rec = id and match.animals[id]
	if not rec then return end
	rec.state = "trapped"
	rec.carrier = nil
	if pos then rec.pos = vector.round(pos) end
	if rec.obj and rec.obj:get_pos() then
		pcall(rec.obj.set_detach, rec.obj)
		rec.obj:set_pos(vector.offset(rec.pos, 0, -0.5, 0))
		animal_look(rec.obj, rec)
		rec.spawner = alarm_spawner(rec.obj)
	else
		spawn_animal(arena, match, rec)
	end
end

pick_up = function(player, ent)
	local match, arena = match_of_player(player)
	if not match or ent.arena_name ~= arena.name or ent.token ~= match.token then return end
	local rec = match.animals[ent.id]
	if not rec or rec.state ~= "trapped" then return end
	local p_name = player:get_player_name()
	if player:get_wielded_item():get_name() ~= TOOLS.carrier.item then
		hint(p_name, S("Use the animal carrier to pick it up!"), 0xffd43b)
		return
	end
	if match.carrying[p_name] then
		hint(p_name, S("Your carrier is full: bring the animal to the safe zone first."), 0xffd43b)
		return
	end
	rec.state = "carried"
	rec.carrier = p_name
	match.carrying[p_name] = rec.id
	if rec.spawner then core.delete_particlespawner(rec.spawner) rec.spawner = nil end
	local obj = ent.object
	pcall(obj.set_attach, obj, player, "", {x = 0, y = 12, z = 4}, {x = 0, y = 0, z = 0})
	animal_look(obj, rec)
	sound("default_grass_footstep", {pos = player:get_pos(), gain = 0.8, max_hear_distance = 12})
	hint(p_name, S("In the carrier: @1. Now walk into the safe zone!", rec.label), 0x9be26f, 4)
	hud_update_all(arena, match)
end

-- Trapped animals run away from flames that come too close.
animals_flee = function(arena, match, fire_pos)
	for _, rec in pairs(match.animals) do
		if rec.state == "trapped" and vector.distance(rec.pos, fire_pos) < 1.8 then
			for _ = 1, 12 do
				local x = rec.pos.x + math.random(-5, 5)
				local z = rec.pos.z + math.random(-5, 5)
				local spot = cell_near(match, x, rec.pos.y, z)
				if spot and not match.fires[hash(spot)] and vector.distance(spot, fire_pos) > 3 then
					rec.pos = spot
					if rec.obj and rec.obj:get_pos() then
						rec.obj:move_to(vector.offset(spot, 0, -0.5, 0))
					end
					break
				end
			end
		end
	end
end

-- ============================================================
-- TOOLS
-- ============================================================

local function ready(p_name, kind)
	local now = core.get_us_time()
	local key = p_name .. ":" .. kind
	if last_use[key] and now - last_use[key] < COOLDOWN[kind] * 1000000 then return false end
	last_use[key] = now
	return true
end

local function pump_wear(water)
	if water >= PUMP_CAPACITY then return 0 end
	return math.min(65534, math.floor(65535 * (1 - water / PUMP_CAPACITY)))
end

local function use_flapper(arena, match, player, pos)
	local p_name = player:get_player_name()
	local key = fire_at(match, pos)
	if not key then
		hint(p_name, S("Hit the flames with the fire beater."), 0xffd43b)
		return
	end
	local fire_pos = match.fires[key].pos
	extinguish(arena, match, key, p_name)
	sound("fire_extinguish_flame", {pos = fire_pos, gain = 0.5, max_hear_distance = 16})
end

local function use_pump(arena, match, player, pos, node)
	local p_name = player:get_player_name()
	if node.name == CISTERN or core.get_item_group(node.name, "water") > 0 then
		match.water[p_name] = PUMP_CAPACITY
		sound("mcl_sounds_dug_water", {pos = pos, max_hear_distance = 12})
		hint(p_name, S("Pump full!"), 0x4fa8ff)
		return
	end
	if (match.water[p_name] or 0) <= 0 then
		hint(p_name, S("The pump is empty: refill it at a water tank or at the lake!"), 0xff9a7a, 4)
		return
	end
	match.water[p_name] = match.water[p_name] - 1
	local center = fire_at(match, pos) and match.fires[fire_at(match, pos)].pos or vector.offset(pos, 0, 1, 0)
	local put_out = 0
	for dx = -1, 1 do
		for dz = -1, 1 do
			for dy = -1, 1 do
				local key = hash(vector.offset(center, dx, dy, dz))
				if match.fires[key] and extinguish(arena, match, key, p_name) then
					put_out = put_out + 1
				end
			end
			match.wet[key2d(vector.offset(center, dx, 0, dz))] = core.get_us_time() + WET_TIME * 1000000
		end
	end
	core.add_particlespawner({
		amount = 30, time = 0.3,
		minpos = vector.offset(center, -1.4, 1, -1.4), maxpos = vector.offset(center, 1.4, 1.8, 1.4),
		minvel = {x = 0, y = -3, z = 0}, maxvel = {x = 0, y = -1.5, z = 0},
		minacc = {x = 0, y = -6, z = 0}, maxacc = {x = 0, y = -6, z = 0},
		minexptime = 0.3, maxexptime = 0.6, minsize = 1.5, maxsize = 2.2,
		texture = MOD .. "_drop.png",
	})
	sound(put_out > 0 and "fire_extinguish_flame" or "mcl_sounds_place_node_water",
		{pos = center, gain = 0.5, max_hear_distance = 16})
end

local function use_rake(arena, match, player, pos)
	local p_name = player:get_player_name()
	local ground = pos
	local here = core.get_node(pos)
	if here.name == FIRE or small_plant(here.name) then ground = vector.offset(pos, 0, -1, 0) end
	-- A line of three cells across the direction the player is looking.
	local dir = player:get_look_dir()
	local side = math.abs(dir.x) > math.abs(dir.z) and {x = 0, z = 1} or {x = 1, z = 0}
	local made, burning = 0, false
	for i = -1, 1 do
		local base = vector.offset(ground, side.x * i, 0, side.z * i)
		for _, dy in ipairs({0, 1, -1}) do
			local g = vector.offset(base, 0, dy, 0)
			local above = vector.offset(g, 0, 1, 0)
			local a = core.get_node(above).name
			if FLAMMABLE_GROUND[core.get_node(g).name] and (a == "air" or small_plant(a) or a == FIRE)
					and inside(match, g) then
				if a == FIRE then
					burning = true
				else
					if a ~= "air" then
						if core.get_node(vector.offset(above, 0, 1, 0)).name:find("_top$") then
							core.remove_node(vector.offset(above, 0, 1, 0))
						end
						core.remove_node(above)
					end
					core.set_node(g, {name = FIREBREAK})
					made = made + 1
				end
				break
			end
		end
	end
	if made == 0 then
		if burning then
			hint(p_name, S("It is burning here: put the fire out first."), 0xffd43b)
		else
			hint(p_name, S("Rake grass or forest floor to make a firebreak."), 0xffd43b)
		end
		return
	end
	local st = stats_of(match, p_name)
	st.breaks = st.breaks + made
	core.add_particlespawner({
		amount = 6 + made * 3, time = 0.15,
		minpos = vector.offset(ground, -1, 0.5, -1), maxpos = vector.offset(ground, 1, 0.7, 1),
		minvel = {x = -1, y = 1.5, z = -1}, maxvel = {x = 1, y = 3, z = 1},
		minacc = {x = 0, y = -8, z = 0}, maxacc = {x = 0, y = -8, z = 0},
		minexptime = 0.4, maxexptime = 0.8, minsize = 1.5, maxsize = 2.5,
		texture = MOD .. "_crumb.png",
	})
	sound("default_dirt_footstep", {pos = ground, gain = 0.9, max_hear_distance = 12})
end

local function tool_action(kind)
	return function(itemstack, user, pointed_thing)
		local match, arena = match_of_player(user)
		if not match then return end
		local p_name = user:get_player_name()
		if pointed_thing.type == "object" then
			local ent = pointed_thing.ref:get_luaentity()
			if ent and ent.name == MOD .. ":animal" then pick_up(user, ent) end
			return
		end
		if pointed_thing.type ~= "node" or not ready(p_name, kind) then return end
		local pos = pointed_thing.under
		local node = core.get_node(pos)
		if kind == "flapper" then
			use_flapper(arena, match, user, pos)
		elseif kind == "pump" then
			use_pump(arena, match, user, pos, node)
		elseif kind == "rake" then
			use_rake(arena, match, user, pos)
		elseif kind == "carrier" then
			hint(p_name, S("Click a trapped animal with the carrier."), 0xffd43b)
		end
		if matches[arena.name] == match then
			hud_update_all(arena, match)
			if match.nfires == 0 and match.rescued >= match.total_animals then
				finish(arena, match, true)
			end
		end
		if kind == "pump" then
			itemstack:set_wear(pump_wear(match.water[p_name] or 0))
			return itemstack
		end
	end
end

-- Kept on Q: the game gives them back at the respawn anyway.
local function no_drop(itemstack)
	return itemstack
end

local item_defs = {
	flapper = {description = S("Fire beater"), image = MOD .. "_flapper.png", range = 4},
	rake = {description = S("Fire rake"), image = MOD .. "_rake.png", range = 5},
	carrier = {description = S("Animal carrier"), image = MOD .. "_carrier.png", range = 4},
}
for kind, def in pairs(item_defs) do
	core.register_craftitem(TOOLS[kind].item, {
		description = def.description .. "\n" .. core.colorize("#b8a59a", TOOLS[kind].hint),
		inventory_image = def.image,
		wield_image = def.image,
		wield_scale = {x = 1.5, y = 1.5, z = 1},
		stack_max = 1,
		range = def.range,
		groups = {not_in_creative_inventory = 1},
		on_use = tool_action(kind),
		on_place = tool_action(kind),
		on_secondary_use = kind == "carrier" and tool_action(kind) or nil,
		on_drop = no_drop,
	})
end

core.register_tool(TOOLS.pump.item, {
	description = S("Backpack pump") .. "\n" .. core.colorize("#b8a59a", TOOLS.pump.hint),
	inventory_image = MOD .. "_pump.png",
	wield_image = MOD .. "_pump.png",
	wield_scale = {x = 1.5, y = 1.5, z = 1},
	range = 12,
	liquids_pointable = true,
	groups = {not_in_creative_inventory = 1, disable_repair = 1},
	wear_color = {color_stops = {[0.0] = "#ff8a7a", [0.3] = "#8fd0ff", [1.0] = "#4fa8ff"}},
	on_use = tool_action("pump"),
	on_place = tool_action("pump"),
	on_drop = no_drop,
})

local function give_tools(player, match)
	local inv = player:get_inventory()
	if not inv then return end
	for i, kind in ipairs(TOOL_ORDER) do
		local item = TOOLS[kind].item
		if not inv:contains_item("main", item) then
			local stack = ItemStack(item)
			if kind == "pump" then
				stack:set_wear(pump_wear(match.water[player:get_player_name()] or 0))
			end
			if inv:get_stack("main", i):is_empty() then
				inv:set_stack("main", i, stack)
			else
				inv:add_item("main", stack)
			end
		end
	end
end

local function remove_tools(player)
	local inv = player:get_inventory()
	if not inv then return end
	for i, stack in ipairs(inv:get_list("main") or {}) do
		if stack:get_name():sub(1, #MOD + 1) == MOD .. ":" then
			inv:set_stack("main", i, ItemStack(""))
		end
	end
end

-- ============================================================
-- NODES
-- ============================================================

local sounds = mcl_sounds or {}
local function snd(kind)
	return sounds["node_sound_" .. kind .. "_defaults"] and sounds["node_sound_" .. kind .. "_defaults"]() or nil
end

core.register_node(FIRE, {
	description = S("Wildfire"),
	drawtype = "firelike",
	tiles = {{
		name = "fire_basic_flame_animated.png",
		animation = {type = "vertical_frames", aspect_w = 16, aspect_h = 16, length = 1},
	}},
	inventory_image = "fire_basic_flame.png",
	paramtype = "light",
	light_source = 12,
	walkable = false,
	buildable_to = false,
	sunlight_propagates = true,
	damage_per_second = 0,
	selection_box = {type = "fixed", fixed = {-0.45, -0.5, -0.45, 0.45, 0.25, 0.45}},
	groups = {not_in_creative_inventory = 1, dig_immediate = 3},
	drop = "",
	is_ground_content = false,
	on_blast = function() end,
})

core.register_node(SCORCHED, {
	description = S("Scorched ground"),
	tiles = {MOD .. "_scorched_top.png", "default_dirt.png", MOD .. "_scorched_side.png"},
	groups = {crumbly = 3, shovely = 1, not_in_creative_inventory = 1},
	drop = "",
	sounds = snd("dirt"),
	_mcl_hardness = 0.5,
	is_ground_content = false,
})

core.register_node(CHARRED, {
	description = S("Charred trunk"),
	tiles = {MOD .. "_charred_top.png", MOD .. "_charred_top.png", MOD .. "_charred_side.png"},
	paramtype2 = "facedir",
	groups = {choppy = 2, axey = 1, not_in_creative_inventory = 1},
	drop = "",
	sounds = snd("wood"),
	_mcl_hardness = 2,
	is_ground_content = false,
})

core.register_node(CISTERN, {
	description = S("Water tank"),
	tiles = {MOD .. "_cistern_top.png", MOD .. "_cistern_top.png", MOD .. "_cistern_side.png"},
	paramtype2 = "facedir",
	groups = {cracky = 2, pickaxey = 1, not_in_creative_inventory = 1},
	drop = "",
	sounds = snd("metal"),
	_mcl_hardness = 3,
	is_ground_content = false,
	on_construct = function(pos)
		core.get_meta(pos):set_string("infotext", S("Water tank") .. "\n" .. S("Click it with the backpack pump"))
	end,
	on_rightclick = function(pos, node, clicker, itemstack)
		if itemstack:get_name() == TOOLS.pump.item then
			return tool_action("pump")(itemstack, clicker, {type = "node", under = pos, above = pos})
		end
		return itemstack
	end,
})

core.register_node(SIGN, {
	description = S("Wildlife rescue centre"),
	drawtype = "nodebox",
	tiles = {"mcl_core_planks_spruce.png", "mcl_core_planks_spruce.png", "mcl_core_planks_spruce.png",
		"mcl_core_planks_spruce.png", "mcl_core_planks_spruce.png", MOD .. "_sign.png"},
	paramtype = "light",
	paramtype2 = "facedir",
	node_box = {type = "fixed", fixed = {
		{-0.0625, -0.5, -0.0625, 0.0625, 0.0, 0.0625},   -- post
		{-0.5, -0.125, -0.0625, 0.5, 0.5, 0.0625},       -- board
	}},
	groups = {choppy = 2, axey = 1, not_in_creative_inventory = 1},
	drop = "",
	sounds = snd("wood"),
	_mcl_hardness = 1,
	is_ground_content = false,
	on_construct = function(pos)
		core.get_meta(pos):set_string("infotext", S("Wildlife rescue centre") .. "\n" ..
			S("Safe zone: bring the animals saved from the fire here"))
	end,
})

-- Flames left in the map by a crash are put out when their block loads.
core.register_lbm({
	label = "Remove stray wildfire",
	name = MOD .. ":stray_fire",
	nodenames = {FIRE},
	run_at_every_load = true,
	action = function(pos)
		local key = hash(pos)
		for _, match in pairs(matches) do
			if match.fires[key] then return end
		end
		core.remove_node(pos)
	end,
})

-- ============================================================
-- THE RESCUE CENTRE (safe zone)
-- ============================================================

-- Arena param safe_zone = {pos = [x, y, z], radius = r}. The mod builds a
-- fenced clearing there (shelter, hay, water trough, two water tanks, a
-- sign) the first time it finds the sign missing: it is part of the island,
-- not of a match, and comes back by itself after the map is regenerated.

local SAFE_VERSION = "3"
local remove_orphan_leaves

local function ground_at(x, z, y_hint)
	for y = y_hint + 20, y_hint - 20, -1 do
		local node = core.get_node({x = x, y = y, z = z})
		if node.name == "ignore" then return nil end
		local def = core.registered_nodes[node.name]
		if def and def.walkable and core.get_item_group(node.name, "leaves") == 0
				and core.get_item_group(node.name, "tree") == 0 and node.name ~= CHARRED
				and node.name ~= SIGN and node.name ~= CISTERN and not small_plant(node.name)
				and not node.name:find("fence") and not node.name:find("slab")
				and node.name ~= "mcl_farming:hay_block" then
			return y
		end
	end
end

local function safe_zone_spec(arena)
	local spec = arena.params and arena.params.safe_zone
	if type(spec) ~= "table" or type(spec.pos) ~= "table" then return end
	local pos = {x = tonumber(spec.pos[1]), y = tonumber(spec.pos[2]), z = tonumber(spec.pos[3])}
	if not (pos.x and pos.y and pos.z) then return end
	return {pos = vector.round(pos), radius = math.max(4, math.min(12, tonumber(spec.radius) or 7))}
end

-- Where the sign stands, from the stored layout.
local function stored_layout(spec)
	local raw = storage:get_string("safe:" .. spec.pos.x .. "," .. spec.pos.z)
	local data = raw ~= "" and core.deserialize(raw) or nil
	if data and data.version == SAFE_VERSION then return data end
end

local RAMP = 7  -- width of the earth ramp around the clearing

-- Removes the leaves with no trunk within 5 nodes around `center`.
remove_orphan_leaves = function(center, radius)
	local p1 = vector.offset(center, -radius, -6, -radius)
	local p2 = vector.offset(center, radius, 24, radius)
	local trunks = core.find_nodes_in_area(vector.offset(p1, -5, -5, -5), vector.offset(p2, 5, 5, 5), {"group:tree"})
	local removed = 0
	for _, p in ipairs(core.find_nodes_in_area(p1, p2, {"group:leaves"})) do
		local held = false
		for _, t in ipairs(trunks) do
			if math.abs(t.x - p.x) <= 5 and math.abs(t.y - p.y) <= 5 and math.abs(t.z - p.z) <= 5 then
				held = true
				break
			end
		end
		if not held then
			core.remove_node(p)
			removed = removed + 1
		end
	end
	return removed
end

-- Once per map: no leaves less than CLEARANCE nodes above the ground on the
-- whole island, so players can walk under every tree.
local TRIM_VERSION = "1"

local function trim_forest(arena)
	local key = "trim:" .. arena.name
	if storage:get_string(key) == TRIM_VERSION then return end
	local leaves, solid = {}, {}
	for name, def in pairs(core.registered_nodes) do
		local id = core.get_content_id(name)
		if (def.groups.leaves or 0) > 0 then
			leaves[id] = true
		elseif def.walkable and (def.groups.tree or 0) == 0 then
			solid[id] = true
		end
	end
	local air = core.get_content_id("air")
	local vm = core.get_voxel_manip()
	local e1, e2 = vm:read_from_map(arena.pos1, arena.pos2)
	local area = VoxelArea:new({MinEdge = e1, MaxEdge = e2})
	local data = vm:get_data()
	local p1, p2 = arena.pos1, arena.pos2
	local removed = 0
	for z = p1.z, p2.z do
		for x = p1.x, p2.x do
			for y = p2.y, p1.y, -1 do
				local id = data[area:index(x, y, z)]
				if solid[id] then
					for dy = 1, CLEARANCE do
						local i = area:index(x, y + dy, z)
						if y + dy <= e2.y and leaves[data[i]] then
							data[i] = air
							removed = removed + 1
						end
					end
					break
				end
			end
		end
	end
	vm:set_data(data)
	vm:write_to_map(true)
	storage:set_string(key, TRIM_VERSION)
	core.log("action", "[skyss_firegame] Pruned " .. removed .. " low leaves in " .. arena.name)
end

local function build_safe_zone(spec, toward)
	local cx, cz, r = spec.pos.x, spec.pos.z, spec.radius
	local outer = r + RAMP

	-- Ground height of every column, and the floor: the median of the clearing.
	local heights, inner = {}, {}
	for dx = -outer, outer do
		for dz = -outer, outer do
			local d = math.sqrt(dx * dx + dz * dz)
			if d <= outer + 0.5 then
				local g = ground_at(cx + dx, cz + dz, spec.pos.y)
				if g then
					heights[dx .. "," .. dz] = g
					if d <= r + 0.5 then inner[#inner + 1] = g end
				end
			end
		end
	end
	if #inner == 0 then return end
	table.sort(inner)
	local gy = inner[math.ceil(#inner / 2)]
	local floor_y = gy + 1  -- the air level animals and players stand in

	-- Flat green clearing, then an earth ramp back to the natural ground, so
	-- there is no wall or pit around the fence.
	for dx = -outer, outer do
		for dz = -outer, outer do
			local g = heights[dx .. "," .. dz]
			local d = math.sqrt(dx * dx + dz * dz)
			if g then
				local target = gy
				if d > r + 0.5 then
					target = math.floor(gy + (g - gy) * math.min(1, (d - r) / RAMP) + 0.5)
				end
				if target ~= g or d <= r + 0.5 then
					local x, z = cx + dx, cz + dz
					for y = target + 1, math.max(g, target) + 16 do
						local p = {x = x, y = y, z = z}
						if core.get_node(p).name ~= "air" then core.remove_node(p) end
					end
					for y = math.min(g, target - 3), target - 1 do
						local p = {x = x, y = y, z = z}
						local n = core.get_node(p).name
						if n == "air" or core.get_item_group(n, "leaves") > 0 or small_plant(n)
								or y > g then
							core.set_node(p, {name = "mcl_core:dirt"})
						end
					end
					core.set_node({x = x, y = target, z = z}, {name = GRASS, param2 = GRASS_P2})
				end
			end
		end
	end

	-- Fence ring with two openings: toward the arrival pad and the opposite side.
	local gate_a = math.atan2(toward.z - cz, toward.x - cx)
	local function near_gate(a)
		for _, g in ipairs({gate_a, gate_a + math.pi}) do
			local diff = math.abs((a - g + math.pi) % (2 * math.pi) - math.pi)
			if diff < 0.32 then return true end
		end
		return false
	end
	local fence = core.registered_nodes["mcl_fences:spruce_fence"] and "mcl_fences:spruce_fence" or "mcl_fences:oak_fence"
	for dx = -r, r do
		for dz = -r, r do
			local d = math.sqrt(dx * dx + dz * dz)
			if d > r - 0.5 and d <= r + 0.5 and not near_gate(math.atan2(dz, dx)) then
				core.set_node({x = cx + dx, y = floor_y, z = cz + dz}, {name = fence})
			end
		end
	end

	-- Gate posts with lanterns, the sign and two water tanks by the gate.
	local gx, gz = math.cos(gate_a), math.sin(gate_a)
	local px, pz = -gz, gx  -- along the fence
	local function at(along, out, dy)
		return vector.round({x = cx + gx * out + px * along, y = floor_y + (dy or 0), z = cz + gz * out + pz * along})
	end
	local sign_pos = at(0, r - 1.5, 0)
	local facedir = core.dir_to_facedir(vector.direction(vector.new(cx, 0, cz), vector.new(toward.x, 0, toward.z)))
	local sign_node_dir = (facedir + 2) % 4
	local post_l, post_r = at(-2.6, r, 0), at(2.6, r, 0)
	for _, p in ipairs({post_l, post_r}) do
		core.set_node(p, {name = fence})
		core.set_node(vector.offset(p, 0, 1, 0), {name = fence})
		core.set_node(vector.offset(p, 0, 2, 0), {name = "mcl_lanterns:lantern_floor"})
	end
	local tanks = {at(-2, r - 2, 0), at(2, r - 2, 0)}
	for _, p in ipairs(tanks) do
		core.set_node(p, {name = CISTERN, param2 = sign_node_dir})
	end

	-- Shelter on the far side: four posts and a spruce roof, hay inside.
	local sx, sz = cx - gx * (r - 3.5), cz - gz * (r - 3.5)
	for _, c in ipairs({{-1, -1}, {-1, 1}, {1, -1}, {1, 1}}) do
		local p = vector.round({x = sx + c[1] * 1.5, y = floor_y, z = sz + c[2] * 1.5})
		for y = 0, 2 do core.set_node(vector.offset(p, 0, y, 0), {name = fence}) end
	end
	for dx = -2, 2 do
		for dz = -2, 2 do
			core.set_node(vector.round({x = sx + dx, y = floor_y + 3, z = sz + dz}), {name = "mcl_stairs:slab_spruce"})
		end
	end
	core.set_node(vector.round({x = sx, y = floor_y, z = sz}), {name = "mcl_farming:hay_block"})
	core.set_node(vector.round({x = sx + px, y = floor_y, z = sz + pz}), {name = "mcl_farming:hay_block"})
	core.set_node(vector.round({x = sx + px * 3.5, y = floor_y, z = sz + pz * 3.5}), {name = "mcl_cauldrons:cauldron_3"})

	-- A few flowers, so it looks like a green refuge.
	for _ = 1, 10 do
		local a, d = math.random() * math.pi * 2, math.random() * (r - 1.5)
		local p = vector.round({x = cx + math.cos(a) * d, y = floor_y, z = cz + math.sin(a) * d})
		if core.get_node(p).name == "air" and vector.distance(p, sign_pos) > 1.5 then
			local flowers = {"mcl_flowers:dandelion", "mcl_flowers:poppy", "mcl_flowers:azure_bluet", "mcl_flowers:tallgrass"}
			local f = flowers[math.random(#flowers)]
			core.set_node(p, {name = f, param2 = f == "mcl_flowers:tallgrass" and GRASS_P2 or 0})
		end
	end

	core.set_node(sign_pos, {name = SIGN, param2 = sign_node_dir})

	-- Leaves of the trees whose trunk the clearing removed would float.
	remove_orphan_leaves(vector.new(cx, floor_y, cz), outer + 5)

	local layout = {version = SAFE_VERSION, sign = sign_pos, floor_y = floor_y, tanks = tanks}
	storage:set_string("safe:" .. cx .. "," .. cz, core.serialize(layout))
	core.log("action", "[skyss_firegame] Built the wildlife rescue centre at " .. core.pos_to_string(sign_pos))
	return layout
end

local function center_of(arena)
	local sum, n = vector.zero(), 0
	for _, spawn in ipairs(arena.spawns or {}) do
		sum = vector.add(sum, spawn.pos)
		n = n + 1
	end
	if n > 0 then return vector.round(vector.divide(sum, n)) end
	return vector.round(vector.divide(vector.add(arena.pos1, arena.pos2), 2))
end

-- Returns the layout, building the centre when it is missing.
local function ensure_safe_zone(arena)
	local spec = safe_zone_spec(arena)
	if not spec then return end
	local layout = stored_layout(spec)
	if layout and core.get_node(layout.sign).name == SIGN then return layout end
	local p1 = vector.offset(spec.pos, -spec.radius - 2, -22, -spec.radius - 2)
	local p2 = vector.offset(spec.pos, spec.radius + 2, 22, spec.radius + 2)
	core.load_area(p1, p2)
	return build_safe_zone(spec, center_of(arena))
end

-- Build the centres at start-up, before anyone plays.
core.register_on_mods_loaded(function()
	core.after(5, function()
		local P = skyss_minigames._internal
		if not (P and P.arenas) then return end
		for _, arena in pairs(P.arenas) do
			if arena.game == MOD and not arena.match and not arena.resetting then
				core.emerge_area(arena.pos1, arena.pos2, function(_, _, remaining)
					if remaining == 0 and not arena.match and not arena.resetting then
						trim_forest(arena)
						ensure_safe_zone(arena)
					end
				end)
			end
		end
	end)
end)

-- Label above the safe zone during a match.
core.register_entity(MOD .. ":label", {
	initial_properties = {
		physical = false, pointable = false, visual = "sprite",
		visual_size = {x = 0.01, y = 0.01}, textures = {"blank.png"}, static_save = true,
	},
	get_staticdata = function(self)
		return core.serialize({arena = self.arena_name, token = self.token})
	end,
	on_activate = function(self, staticdata)
		local data = core.deserialize(staticdata or "") or {}
		local match = matches[data.arena or ""]
		if not match or match.token ~= data.token then
			self.object:remove()
			return
		end
		self.arena_name, self.token = data.arena, data.token
		match.labels[#match.labels + 1] = self.object
		self.object:set_properties({
			nametag = S("SAFE ZONE - bring the animals here"),
			nametag_color = "#ffffff",
			nametag_bgcolor = "#3f8f4fe0",
		})
	end,
})

-- ============================================================
-- ARENA SET-UP
-- ============================================================

-- Ground cell of column (x, z) under any canopy, or nil.
local function surface_cell(match, x, z)
	for y = match.p2.y - 1, match.p1.y + 1, -1 do
		local node = core.get_node({x = x, y = y, z = z})
		if node.name == "ignore" then return end
		local def = core.registered_nodes[node.name]
		if def and def.walkable and core.get_item_group(node.name, "leaves") == 0
				and core.get_item_group(node.name, "tree") == 0 then
			local cell = {x = x, y = y + 1, z = z}
			return cell
		end
	end
end

local function free_spot(match, x, z)
	local cell = surface_cell(match, x, z)
	if cell and inside(match, cell) and not in_safe_zone(match, cell, 3)
			and core.get_node(cell).name == "air" and core.get_node(vector.offset(cell, 0, 1, 0)).name == "air"
			and core.get_item_group(core.get_node(vector.offset(cell, 0, -1, 0)).name, "water") == 0 then
		return cell
	end
end

local function place_cisterns(arena, match)
	local c = center_of(arena)
	for _, dir in ipairs({{0, 1}, {0, -1}, {1, 0}, {-1, 0}}) do
		local side = {dir[2], dir[1]}  -- across the path
		for i, d in ipairs(LANE_CISTERNS) do
			local sign = i % 2 == 0 and 1 or -1
			local placed
			for _, s_ in ipairs({sign, -sign}) do
				for off = LANE_SIDE, LANE_SIDE + 3 do
					for along = 0, 3 do
						local x = c.x + dir[1] * (d + along) + side[1] * off * s_
						local z = c.z + dir[2] * (d + along) + side[2] * off * s_
						placed = free_spot(match, x, z)
						if placed then break end
					end
					if placed then break end
				end
				if placed then break end
			end
			if placed then
				core.set_node(placed, {name = CISTERN})
				-- A little bare ring around it, so the fire does not hide it.
				for dx = -1, 1 do
					for dz = -1, 1 do
						local g = vector.offset(placed, dx, -1, dz)
						if FLAMMABLE_GROUND[core.get_node(g).name] and (dx ~= 0 or dz ~= 0) then
							core.set_node(g, {name = FIREBREAK})
							local up = vector.offset(g, 0, 1, 0)
							if small_plant(core.get_node(up).name) then core.remove_node(up) end
						end
					end
				end
			end
		end
	end
end

local function scaled(solo, exponent, max, players)
	return math.min(max, math.ceil(solo * math.max(1, players) ^ exponent))
end

-- Fronts: far enough from the spawn pad, from the safe zone and from each other.
local function start_fronts(arena, match, wanted)
	local c = center_of(arena)
	local fronts = {}
	for _ = 1, wanted * 60 do
		if #fronts >= wanted then break end
		local a = math.random() * math.pi * 2
		local d = math.random(18, 56)
		local x, z = math.floor(c.x + math.cos(a) * d + 0.5), math.floor(c.z + math.sin(a) * d + 0.5)
		local cell = surface_cell(match, x, z)
		if cell and burnable_cell(match, cell) and not in_safe_zone(match, cell, 10) then
			local ok = true
			for _, f in ipairs(fronts) do
				if vector.distance(f, cell) < 16 then ok = false break end
			end
			if ok then fronts[#fronts + 1] = cell end
		end
	end
	for _, f in ipairs(fronts) do
		ignite(arena, match, f)
		local lit = 1
		for _ = 1, 30 do
			if lit >= FRONT_CELLS then break end
			local cell = cell_near(match, f.x + math.random(-2, 2), f.y, f.z + math.random(-2, 2))
			if cell and ignite(arena, match, cell) then lit = lit + 1 end
		end
	end
	return fronts
end

local function place_animals(arena, match, fronts, wanted)
	local kinds = available_animals()
	if #kinds == 0 or #fronts == 0 then return end
	for i = 1, wanted do
		local f = fronts[(i - 1) % #fronts + 1]
		for _ = 1, 30 do
			local a, d = math.random() * math.pi * 2, math.random(3, 8)
			local x, z = math.floor(f.x + math.cos(a) * d + 0.5), math.floor(f.z + math.sin(a) * d + 0.5)
			local cell = cell_near(match, x, f.y, z)
			if cell and not match.fires[hash(cell)] and core.get_node(vector.offset(cell, 0, 1, 0)).name == "air" then
				local kind = pick_animal(kinds)
				local model = model_of(kind.mob)
				local id = #match.animal_list + 1
				local rec = {
					id = id, mob = kind.mob, label = kind.label, scale = kind.scale,
					skin = math.random(#model.sets), pos = cell, state = "trapped",
					yaw = math.random() * math.pi * 2,
				}
				match.animals[id] = rec
				match.animal_list[id] = rec
				spawn_animal(arena, match, rec)
				break
			end
		end
	end
end

-- ============================================================
-- MINIGAME
-- ============================================================

-- Arena params: safe_zone = {pos = [x, y, z], radius = r} (required),
-- fronts, animals (fixed amounts instead of the automatic ones).
local game_def = {
	title = S("Wildfire Crew"),
	description = S("A wildfire! Beat out the flames, spray water, rake firebreaks and carry the trapped animals to the safe zone."),
	icon = MOD .. "_icon.png",
	color = "#c8522f",
	mode = "coop",
	ranking = "time",
	min_players = 1,
	max_players = 30,
	join_in_progress = true,
	exclusive = false,
	can_dig = false,
	can_place = false,
	celebration_time = CELEBRATION_TIME,
}

local function fireworks(pos)
	for i = 1, 3 do
		core.after(i * 0.45, function()
			local colors = {"#ff7aa8", "#ffd43b", "#9be26f", "#4fa8ff", "#d27cff"}
			local center = vector.offset(pos, math.random(-2, 2), 5 + math.random(0, 3), math.random(-2, 2))
			core.add_particlespawner({
				amount = 60, time = 0.05, minpos = center, maxpos = center,
				minvel = {x = -4, y = -4, z = -4}, maxvel = {x = 4, y = 4, z = 4},
				minacc = {x = 0, y = -2, z = 0}, maxacc = {x = 0, y = -2, z = 0},
				minexptime = 0.8, maxexptime = 1.6, minsize = 2, maxsize = 4,
				texture = MOD .. "_sparkle.png^[multiply:" .. colors[math.random(#colors)], glow = 14,
			})
			sound("mcl_bows_firework", {pos = center, gain = 0.5, max_hear_distance = 48})
		end)
	end
end

finish = function(arena, match, success, reason)
	if match.finished then return end
	match.finished = true
	match.stopped_us = core.get_us_time()

	if success then
		local time = elapsed(match)
		for p_name in pairs(arena.players) do
			local player = core.get_player_by_name(p_name)
			if player then fireworks(player:get_pos()) end
		end
		skyss_minigames.sound(arena, {name = "mcl_experience_level_up", gain = 0.8})
		local record = best_time()
		local is_record = not record or time < record
		chat(arena, S("The fire is out and every animal is safe! Time: @1", format_time(time)) .. "  " ..
			(is_record and core.colorize("#ffd43b", S("NEW RECORD!")) or S("Record: @1", format_time(record))))
		skyss_minigames.title(arena, is_record and S("New record!") or S("The forest is safe!"),
			CELEBRATION_TIME, is_record and 0xffd43b or 0x9be26f)
	elseif reason then
		chat(arena, core.colorize("#ff9a7a", reason))
	end
	chat(arena, S("Flames put out: @1. Animals saved: @2 / @3. Forest burned: @4 blocks.",
		match.extinguished, match.rescued, match.total_animals, match.burned))

	local ranked = {}
	for name, st in pairs(match.stats) do
		ranked[#ranked + 1] = {name = name, score = st.fires + st.animals * 8 + st.breaks}
	end
	table.sort(ranked, function(a, b) return a.score > b.score end)
	if #ranked > 1 then
		local top = {}
		for i = 1, math.min(3, #ranked) do top[i] = ranked[i].name end
		chat(arena, S("Best firefighters: @1", table.concat(top, ", ")))
	end

	for p_name in pairs(arena.players) do
		hud_update_player(arena, match, p_name)
	end
	skyss_minigames.finish(arena, {success = success, time = elapsed(match),
		celebration_time = success and CELEBRATION_TIME or 6})
end

function game_def.on_start(arena)
	serial = serial + 1
	local p1, p2 = vector.sort(arena.pos1, arena.pos2)
	local match = {
		token = tostring(core.get_us_time()) .. ":" .. serial,
		started_us = core.get_us_time(),
		p1 = p1, p2 = p2,
		fires = {}, nfires = 0, ignited = 0, peak = 0, extinguished = 0, burned = 0,
		wet = {}, charred = {},
		animals = {}, animal_list = {}, carrying = {}, rescued = 0, total_animals = 0,
		water = {}, stats = {}, cisterns = {}, labels = {},
		spread_timer = 0,
	}
	matches[arena.name] = match
	core.load_area(p1, p2)

	local spec = safe_zone_spec(arena)
	local layout = ensure_safe_zone(arena)
	if spec and layout then
		match.safe = {pos = {x = spec.pos.x, y = layout.floor_y, z = spec.pos.z}, radius = spec.radius}
		core.add_entity(vector.offset(match.safe.pos, 0, 3.5, 0), MOD .. ":label",
			core.serialize({arena = arena.name, token = match.token}))
	else
		core.log("warning", "[skyss_firegame] Arena " .. arena.name .. " has no safe_zone param: animals are left out")
	end

	local players = skyss_minigames.player_count(arena)
	local fronts_wanted = tonumber(arena.params.fronts) or scaled(FRONTS_SOLO, FRONTS_EXPONENT, FRONTS_MAX, players)
	local animals_wanted = match.safe and (tonumber(arena.params.animals)
		or scaled(ANIMALS_SOLO, ANIMALS_EXPONENT, ANIMALS_MAX, players)) or 0

	place_cisterns(arena, match)
	match.cisterns = core.find_nodes_in_area(p1, p2, {CISTERN})
	local fronts = start_fronts(arena, match, fronts_wanted)
	match.fire_cap = FIRE_CAP_BASE + FIRE_CAP_PER_FRONT * #fronts
	match.burn_limit = BURN_LIMIT_PER_FRONT * math.max(1, #fronts)
	place_animals(arena, match, fronts, animals_wanted)
	match.total_animals = #match.animal_list

	if match.nfires == 0 then
		core.log("warning", "[skyss_firegame] Arena " .. arena.name .. ": nowhere to start the fire")
		finish(arena, match, false, S("The fire could not start here: tell your teacher."))
		return
	end

	for p_name, player in skyss_minigames.players(arena) do
		match.water[p_name] = PUMP_CAPACITY
		stats_of(match, p_name)
		give_tools(player, match)
		hud_create(player)
	end
	hud_update_all(arena, match)

	skyss_minigames.title(arena, S("Wildfire! Put it out together!"), 3, 0xff9a5c)
	chat(arena, S("@1 fire fronts are burning and @2 animals are trapped. Put out every flame before the fire burns @3 blocks of forest!",
		#fronts, match.total_animals, match.burn_limit))
	chat(arena, S("1. Fire beater on the flames up close  2. Backpack pump from afar (refill at the red tanks or the lake)  3. Fire rake to make firebreaks  4. Carrier: bring the animals to the safe zone by the lake."))
end

function game_def.on_join(arena, p_name)
	local match = matches[arena.name]
	if not match or match.finished then return end
	match.water[p_name] = match.water[p_name] or PUMP_CAPACITY
	stats_of(match, p_name)
	local player = core.get_player_by_name(p_name)
	if player then
		give_tools(player, match)
		hud_create(player)
	end
	hud_update_all(arena, match)
	chat(arena, S("@1 joins the fire crew!", p_name))
end

function game_def.on_respawn(arena, p_name)
	local match = matches[arena.name]
	local player = core.get_player_by_name(p_name)
	if match and not match.finished and player then
		give_tools(player, match)
	end
end

function game_def.on_leave(arena, p_name)
	local match = matches[arena.name]
	local player = core.get_player_by_name(p_name)
	if match and match.carrying[p_name] then
		drop_back(arena, match, p_name, player and player:get_pos())
	end
	if player then
		hud_remove(player)
		remove_tools(player)
	end
	if match and not match.finished then hud_update_all(arena, match) end
end

function game_def.on_timeout(arena)
	local match = matches[arena.name]
	if match and not match.finished then
		finish(arena, match, false, S("Time is up! @1 flames are still burning and @2 animals are still trapped.",
			match.nfires, match.total_animals - match.rescued))
	end
end

function game_def.on_finish(arena, result)
	local match = matches[arena.name]
	if not match then return end
	if not match.finished then
		match.finished = true
		match.stopped_us = core.get_us_time()
	end
	-- Whatever still burns goes out (the area is restored afterwards anyway).
	for key, fire in pairs(match.fires) do
		if core.get_node(fire.pos).name == FIRE then core.remove_node(fire.pos) end
		match.fires[key] = nil
	end
	match.nfires = 0
	for p_name in pairs(arena.players) do
		if match.carrying[p_name] then
			local id = match.carrying[p_name]
			local rec = match.animals[id]
			if rec then remove_animal_obj(rec) end
			match.carrying[p_name] = nil
		end
		local player = core.get_player_by_name(p_name)
		if player and huds[p_name] then hud_clear_waypoints(player, huds[p_name]) end
	end
	for _, rec in pairs(match.animals) do
		if rec.spawner then core.delete_particlespawner(rec.spawner) rec.spawner = nil end
	end
	if result and result.success then
		core.after(math.max(1, CELEBRATION_TIME - 10), function()
			if matches[arena.name] == match then
				chat(arena, "\xE2\x8F\xB1 " .. S("10 seconds left: say goodbye to the animals!"))
			end
		end)
	end
end

function game_def.on_end(arena)
	local match = matches[arena.name]
	if match then
		for _, rec in pairs(match.animals) do remove_animal_obj(rec) end
		for _, obj in ipairs(match.labels) do
			if obj:get_pos() then obj:remove() end
		end
	end
	for p_name in pairs(arena.players or {}) do
		local player = core.get_player_by_name(p_name)
		if player then
			hud_remove(player)
			remove_tools(player)
		end
		wield_seen[p_name] = nil
	end
	matches[arena.name] = nil
end

skyss_minigames.register_game(MOD, game_def)

-- ============================================================
-- THE FIRE, STEP BY STEP
-- ============================================================

local NEIGHBOURS = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}, {1, 1}, {1, -1}, {-1, 1}, {-1, -1}}

local function spread_step(arena, match)
	-- Fronts far from every player must keep burning: keep the island
	-- loaded (blocks nobody uses are unloaded after about 30 seconds).
	core.load_area(match.p1, match.p2)
	local now = core.get_us_time()
	local keys = {}
	for key in pairs(match.fires) do keys[#keys + 1] = key end
	for _, key in ipairs(keys) do
		local fire = match.fires[key]
		if fire then
			if core.get_node(fire.pos).name ~= FIRE then
				-- Gone some other way: forget it.
				match.fires[key] = nil
				match.nfires = match.nfires - 1
			elseif now >= fire.out_at then
				burn_out(arena, match, key)
			elseif match.nfires < match.fire_cap and math.random() < SPREAD_CHANCE then
				local d = NEIGHBOURS[math.random(#NEIGHBOURS)]
				local cell = cell_near(match, fire.pos.x + d[1], fire.pos.y, fire.pos.z + d[2])
				if cell and ignite(arena, match, cell) then
					animals_flee(arena, match, cell)
				end
			end
		end
	end

	-- A tall smoke column over every burning area, seen from far away and
	-- above the trees, then smoke and embers from some of the flames.
	for _, c in ipairs(fire_clusters(match)) do
		local spread = math.min(3, 1 + c.n / 8)
		core.add_particlespawner({
			amount = 5 + math.min(10, c.n), time = SPREAD_INTERVAL,
			minpos = vector.offset(c.pos, -spread, 0, -spread), maxpos = vector.offset(c.pos, spread, 1, spread),
			minvel = {x = -0.3, y = 3, z = -0.3}, maxvel = {x = 0.6, y = 5, z = 0.6},
			minexptime = 6, maxexptime = 9, minsize = 10, maxsize = 18,
			texture = MOD .. "_smoke.png^[multiply:#505050",
		})
	end
	shuffle(keys)
	for i = 1, math.min(8, #keys) do
		local fire = match.fires[keys[i]]
		if fire then
			core.add_particlespawner({
				amount = 3, time = SPREAD_INTERVAL,
				minpos = vector.offset(fire.pos, -0.3, 0.3, -0.3), maxpos = vector.offset(fire.pos, 0.3, 0.6, 0.3),
				minvel = {x = -0.2, y = 1.2, z = -0.2}, maxvel = {x = 0.4, y = 2.2, z = 0.4},
				minexptime = 3, maxexptime = 5, minsize = 5, maxsize = 9,
				texture = MOD .. "_smoke.png^[multiply:#6a6a6a",
			})
			core.add_particlespawner({
				amount = 4, time = SPREAD_INTERVAL,
				minpos = vector.offset(fire.pos, -0.3, 0, -0.3), maxpos = vector.offset(fire.pos, 0.3, 0.4, 0.3),
				minvel = {x = -0.4, y = 1.5, z = -0.4}, maxvel = {x = 0.4, y = 3, z = 0.4},
				minexptime = 0.6, maxexptime = 1.2, minsize = 1, maxsize = 1.6,
				texture = MOD .. "_ember.png", glow = 14,
			})
		end
	end

	-- Crackling for the players close to a flame.
	for p_name, player in skyss_minigames.players(arena) do
		local ppos = player:get_pos()
		local best, best_d
		for _, fire in pairs(match.fires) do
			local d = vector.distance(ppos, fire.pos)
			if d < 16 and (not best_d or d < best_d) then best, best_d = fire, d end
		end
		if best then
			sound("fire_fire", {pos = best.pos, to_player = p_name, gain = 0.4, max_hear_distance = 16})
		end
	end

	if match.burned >= match.burn_limit then
		finish(arena, match, false, S("The fire burned too much of the forest! Next time make firebreaks and work together."))
	end
end

-- Every half second: carried animals that reach the safe zone, timer,
-- waypoints, a hint for the tool in hand; every SPREAD_INTERVAL the fire.
local tick = 0
core.register_globalstep(function(dtime)
	tick = tick + dtime
	if tick < 0.5 then return end
	local step = tick
	tick = 0
	for name, match in pairs(matches) do
		local arena = skyss_minigames.get_match(name)
		if arena and arena.state == "running" and not match.finished then
			match.spread_timer = match.spread_timer + step
			if match.spread_timer >= SPREAD_INTERVAL then
				match.spread_timer = 0
				spread_step(arena, match)
			end
			if not match.finished then
				for p_name, player in skyss_minigames.players(arena) do
					if match.carrying[p_name] and in_safe_zone(match, player:get_pos(), 0) then
						release(arena, match, p_name, player)
					end
					local wielded = player:get_wielded_item():get_name()
					if wielded ~= wield_seen[p_name] then
						wield_seen[p_name] = wielded
						for _, kind in ipairs(TOOL_ORDER) do
							if TOOLS[kind].item == wielded then
								hint(p_name, TOOLS[kind].hint, 0xeadbd0, 4)
							end
						end
					end
				end
				hud_update_all(arena, match)
				if match.nfires == 0 and match.rescued >= match.total_animals then
					finish(arena, match, true)
				end
			end
		end
	end
end)

core.register_on_leaveplayer(function(player)
	local p_name = player:get_player_name()
	huds[p_name] = nil
	wield_seen[p_name] = nil
	for key in pairs(last_use) do
		if key:sub(1, #p_name + 1) == p_name .. ":" then last_use[key] = nil end
	end
end)

-- For tests and debugging.
skyss_firegame = {_internal = {matches = matches, model_of = model_of, ensure_safe_zone = ensure_safe_zone}}

core.log("action", "[skyss_firegame] Game mod loaded")
