local MOD = "skyss_treegame"
local S = core.get_translator(MOD)
local TAG = "[" .. S("Forest") .. "] "

-- ============================================================
-- CONFIGURATION
-- ============================================================

-- Team goals for one player. With more players they grow as
-- players ^ GROUP_EXPONENT (a bit less than linear, because a crowd gets in
-- its own way), so a match lasts about as long for one player as for a
-- whole class. 30 players: about 21 times these numbers.
local SOLO_GOALS = {soil = 45, plants = 15, trees = 3}
local GROUP_EXPONENT = 0.9

local CAN_CAPACITY = 12       -- waterings per refill
local TOOL_COOLDOWN = 0.3     -- seconds between two uses of a tool
local TREE_GROW_TIME = 6      -- seconds from watering to a grown tree
local TREE_SPACING = 2        -- no other trunk or sapling this close
local SEED_RADIUS = 2
local SEED_PLANTS = 5         -- plants per handful of seeds, at most
local CELEBRATION_TIME = 15
-- Rain barrels placed by the game: {distance from the spawn pad, how many}
local BARREL_RINGS = {{6, 2}, {28, 6}}

local GRASS = "mcl_core:dirt_with_grass"
local FERTILE = MOD .. ":fertile_soil"
local BARREL = MOD .. ":water_barrel"
-- Palette indexes of the hub map (luanti-tools/hubgen): green "Forest" grass
-- and leaves; the felled forest's dry grass uses another index.
local GRASS_P2 = 13
local LEAVES_P2 = {oak = 13, birch = 15, spruce = 12}

local BARREN = {
	["mcl_core:coarse_dirt"] = true,
	["mcl_core:podzol"] = true,
	["mcl_core:dirt"] = true,
}
local BARREN_LIST = {"mcl_core:coarse_dirt", "mcl_core:podzol", "mcl_core:dirt", GRASS}
-- Dead plants that disappear when the soil is restored.
local DRY_PLANTS = {
	["mcl_core:deadbush"] = true,
	["mcl_flowers:short_dry_grass"] = true,
	["mcl_flowers:tall_dry_grass"] = true,
}
local SPECIES = {{"oak", 5}, {"birch", 3}, {"spruce", 2}}
local FLOWERS = {
	"mcl_flowers:dandelion", "mcl_flowers:poppy", "mcl_flowers:azure_bluet",
	"mcl_flowers:oxeye_daisy", "mcl_flowers:cornflower", "mcl_flowers:allium",
	"mcl_flowers:tulip_red", "mcl_flowers:tulip_orange", "mcl_flowers:tulip_white",
	"mcl_flowers:tulip_pink",
}

local GOALS = {
	soil = {label = S("Healthy soil"), icon = MOD .. "_hud_soil.png", color = "#7ccf5a", done = S("The soil is healthy again!")},
	plants = {label = S("Grass and flowers"), icon = MOD .. "_hud_plant.png", color = "#ff8fb8", done = S("The meadow is in bloom!")},
	trees = {label = S("Trees grown"), icon = MOD .. "_hud_tree.png", color = "#3fae5a", done = S("The trees are back!")},
}
local GOAL_ORDER = {"soil", "plants", "trees"}

local TOOLS = {
	compost = {
		item = MOD .. ":compost",
		hint = S("Compost: click bare soil to enrich it (3x3)"),
	},
	can = {
		item = MOD .. ":watering_can",
		hint = S("Watering can: water enriched soil or saplings. Refill it at the rain barrels"),
	},
	seeds = {
		item = MOD .. ":seeds",
		hint = S("Wildflower seeds: sow them on the restored grass to grow a meadow of grass and flowers"),
	},
	sapling = {
		item = MOD .. ":sapling",
		hint = S("Sapling: plant it on the restored grass, away from other trees, then water it"),
	},
}
local TOOL_ORDER = {"compost", "can", "seeds", "sapling"}

local hud_type = core.features.hud_def_type_field and "type" or "hud_elem_type"

-- ============================================================
-- STATE
-- ============================================================

-- Runtime state per arena name. `arena` below is the skyss_minigames match.
local matches = {}
local huds = {}
local cooldown = {}
local wield_seen = {}
local serial = 0

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

local function hash(pos)
	return core.hash_node_position(pos)
end

local function inside(match, pos)
	local p1, p2 = match.p1, match.p2
	return pos.x >= p1.x and pos.x <= p2.x and pos.y >= p1.y and pos.y <= p2.y
		and pos.z >= p1.z and pos.z <= p2.z
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
		core.chat_send_player(p_name, core.colorize("#9be26f", TAG) .. message)
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

local function healthy(node)
	return node.name == GRASS and node.param2 == GRASS_P2
end

-- Grass the team restored in this match (natural grass does not count).
local function restored(match, pos, node)
	return match.restored[core.hash_node_position(pos)] and healthy(node or core.get_node(pos))
end

local function barren(node)
	return BARREN[node.name] or (node.name == GRASS and node.param2 ~= GRASS_P2)
end

local function goal_count(match, key)
	return match.count[key] or 0
end

local function goals_done(match)
	for _, key in ipairs(GOAL_ORDER) do
		if goal_count(match, key) < match.goals[key] then return false end
	end
	return true
end

local function pick_species()
	local total = 0
	for _, s in ipairs(SPECIES) do total = total + s[2] end
	local roll = math.random() * total
	for _, s in ipairs(SPECIES) do
		roll = roll - s[2]
		if roll <= 0 then return s[1] end
	end
	return SPECIES[1][1]
end

-- ============================================================
-- HUD
-- ============================================================

-- Top-right corner, clear of the chat, like the other Skyss minigames.
local PANEL_MARGIN, PANEL_Y, PANEL_W, PANEL_H = 16, 16, 340, 218
local BAR_X = 44
local BAR_W = PANEL_W - BAR_X - 14

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

local function hud_create(player)
	local p_name = player:get_player_name()
	if huds[p_name] then return huds[p_name] end
	local h = {all = {}, rows = {}}

	hud_add(player, h, "image", 0, 0, {text = fill("#0f1a0dd8"), scale = {x = PANEL_W, y = PANEL_H}, z_index = 899})
	hud_add(player, h, "image", 0, 0, {text = fill("#7ccf5a"), scale = {x = PANEL_W, y = 4}})
	hud_add(player, h, "text", 14, 14, {text = S("FOREST RESTORATION"), number = 0x9be26f, style = 1})
	h.timer = hud_add(player, h, "text", PANEL_W - 14, 14, {text = "00:00", number = 0xffffff, style = 5, alignment = {x = -1, y = 1}})

	for i, key in ipairs(GOAL_ORDER) do
		local goal = GOALS[key]
		local y = 40 + (i - 1) * 42
		local row = {}
		hud_add(player, h, "image", 12, y + 2, {text = goal.icon, scale = {x = 1.5, y = 1.5}})
		hud_add(player, h, "text", BAR_X, y, {text = goal.label, number = 0xdbe8d4})
		row.value = hud_add(player, h, "text", PANEL_W - 14, y, {text = "0 / 0", number = 0xffffff, style = 1, alignment = {x = -1, y = 1}})
		hud_add(player, h, "image", BAR_X, y + 22, {text = fill("#26361f"), scale = {x = BAR_W, y = 10}})
		row.bar = hud_add(player, h, "image", BAR_X, y + 22, {text = "", scale = {x = 1, y = 10}, z_index = 901})
		h.rows[key] = row
	end

	hud_add(player, h, "image", 14, 168, {text = fill("#ffffff30"), scale = {x = PANEL_W - 28, y = 1}})
	h.water_icon = hud_add(player, h, "image", 12, 176, {text = MOD .. "_hud_water.png", scale = {x = 1.5, y = 1.5}})
	h.water = hud_add(player, h, "text", BAR_X, 178, {text = "", number = 0xffffff})
	h.footer = hud_add(player, h, "text", PANEL_W - 14, 178, {text = "", number = 0x9fb398, alignment = {x = -1, y = 1}})
	h.footer2 = hud_add(player, h, "text", BAR_X, 198, {text = "", number = 0x9fb398})

	huds[p_name] = h
	return h
end

local function hud_clear_waypoint(player, h)
	if h.waypoint then
		player:hud_remove(h.waypoint)
		h.waypoint, h.waypoint_pos = nil, nil
	end
end

local function hud_remove(player)
	local p_name = player:get_player_name()
	local h = huds[p_name]
	if not h then return end
	for _, id in ipairs(h.all) do
		player:hud_remove(id)
	end
	hud_clear_waypoint(player, h)
	huds[p_name] = nil
end

local function best_time()
	local P = skyss_minigames._internal
	if not (P and P.get_board) then return end
	local board = P.get_board(MOD, "time")
	return board[1] and board[1].value
end

local function nearest_barrel(match, pos)
	local best, best_d
	for _, b in ipairs(match.barrels) do
		local d = vector.distance(b, pos)
		if not best_d or d < best_d then best, best_d = b, d end
	end
	return best
end

local function water_of(match, p_name)
	return match.water[p_name] or 0
end

local function hud_update_player(arena, match, p_name)
	local player = core.get_player_by_name(p_name)
	if not player then return end
	local h = hud_create(player)

	player:hud_change(h.timer, "text", format_time(elapsed(match)))
	for _, key in ipairs(GOAL_ORDER) do
		local row, goal = h.rows[key], match.goals[key]
		local n = math.min(goal_count(match, key), goal)
		local frac = goal > 0 and n / goal or 1
		player:hud_change(row.value, "text", n .. " / " .. goal)
		player:hud_change(row.value, "number", n >= goal and 0x9be26f or 0xffffff)
		if frac > 0 then
			player:hud_change(row.bar, "text", fill(n >= goal and "#9be26f" or GOALS[key].color))
			player:hud_change(row.bar, "scale", {x = math.max(1, math.floor(BAR_W * frac)), y = 10})
		else
			player:hud_change(row.bar, "text", "")
		end
	end

	local water = water_of(match, p_name)
	player:hud_change(h.water_icon, "text", MOD .. (water > 0 and "_hud_water.png" or "_hud_water_empty.png"))
	player:hud_change(h.water, "text", S("Watering can: @1 / @2", water, CAN_CAPACITY))
	player:hud_change(h.water, "number", water > 0 and 0xffffff or 0xff9a7a)
	local record = best_time()
	player:hud_change(h.footer, "text", S("Record: @1", record and format_time(record) or "--:--"))
	player:hud_change(h.footer2, "text", S("Your work: @1 soil, @2 plants, @3 trees",
		match.mine[p_name] and match.mine[p_name].soil or 0,
		match.mine[p_name] and match.mine[p_name].plants or 0,
		match.mine[p_name] and match.mine[p_name].trees or 0))

	-- An empty can points the way to the nearest rain barrel.
	local target = water == 0 and nearest_barrel(match, player:get_pos()) or nil
	if not target then
		hud_clear_waypoint(player, h)
	elseif not (h.waypoint_pos and vector.equals(h.waypoint_pos, target)) then
		hud_clear_waypoint(player, h)
		local wp = {
			name = S("Rain barrel"),
			text = " m",
			precision = 1,
			number = 0x4fa8ff,
			world_pos = vector.offset(target, 0, 1, 0),
			z_index = -300,
		}
		wp[hud_type] = "waypoint"
		h.waypoint = player:hud_add(wp)
		h.waypoint_pos = target
	end
end

local function hud_update_all(arena, match)
	for p_name in pairs(arena.players) do
		hud_update_player(arena, match, p_name)
	end
end

-- ============================================================
-- EFFECTS
-- ============================================================

local function particles(pos, texture, amount, def)
	def = def or {}
	local spread = def.spread or 0.5
	core.add_particlespawner({
		amount = amount,
		time = def.time or 0.15,
		minpos = vector.offset(pos, -spread, def.y0 or 0, -spread),
		maxpos = vector.offset(pos, spread, def.y1 or 0.4, spread),
		minvel = def.minvel or {x = -1, y = 1.5, z = -1},
		maxvel = def.maxvel or {x = 1, y = 3, z = 1},
		minacc = {x = 0, y = def.gravity or -6, z = 0},
		maxacc = {x = 0, y = def.gravity or -6, z = 0},
		minexptime = 0.5,
		maxexptime = def.life or 1.1,
		minsize = def.minsize or 1.5,
		maxsize = def.maxsize or 2.5,
		texture = texture,
		glow = def.glow or 0,
	})
end

local function sparkle(pos, color, amount)
	particles(pos, MOD .. "_sparkle.png^[multiply:" .. color, amount or 12, {glow = 12, gravity = -2})
end

local function rain(pos, amount)
	particles(vector.offset(pos, 0, 1.6, 0), MOD .. "_drop.png", amount or 20, {
		spread = 1.2, minvel = {x = 0, y = -2, z = 0}, maxvel = {x = 0, y = -1, z = 0},
		gravity = -8, life = 0.5, minsize = 1.5, maxsize = 2.2,
	})
end

local function fireworks(pos)
	for i = 1, 3 do
		core.after(i * 0.45, function()
			local colors = {"#ff7aa8", "#ffd43b", "#9be26f", "#4fa8ff", "#d27cff"}
			local center = vector.offset(pos, math.random(-2, 2), 5 + math.random(0, 3), math.random(-2, 2))
			core.add_particlespawner({
				amount = 60, time = 0.05,
				minpos = center, maxpos = center,
				minvel = {x = -4, y = -4, z = -4}, maxvel = {x = 4, y = 4, z = 4},
				minacc = {x = 0, y = -2, z = 0}, maxacc = {x = 0, y = -2, z = 0},
				minexptime = 0.8, maxexptime = 1.6, minsize = 2, maxsize = 4,
				texture = MOD .. "_sparkle.png^[multiply:" .. colors[math.random(#colors)],
				glow = 14,
			})
			sound("mcl_bows_firework", {pos = center, gain = 0.5, max_hear_distance = 48})
		end)
	end
end

-- ============================================================
-- PROGRESS
-- ============================================================

local finish

local function add_progress(arena, match, p_name, key, amount)
	if amount <= 0 then return end
	local before = goal_count(match, key)
	match.count[key] = before + amount
	match.mine[p_name] = match.mine[p_name] or {soil = 0, plants = 0, trees = 0}
	match.mine[p_name][key] = match.mine[p_name][key] + amount

	local goal = match.goals[key]
	if before < goal and match.count[key] >= goal then
		chat(arena, core.colorize(GOALS[key].color, GOALS[key].done))
		skyss_minigames.title(arena, GOALS[key].done, 3, 0x9be26f)
		skyss_minigames.sound(arena, {name = "mcl_experience_level_up", gain = 0.5})
	else
		-- Milestones every quarter, so a class hears its progress.
		local quarter = math.max(1, math.floor(goal / 4))
		if before < goal and math.floor(before / quarter) < math.floor(match.count[key] / quarter) then
			for name in pairs(arena.players) do
				hint(name, S("@1: @2 / @3", GOALS[key].label, match.count[key], goal), 0x9be26f, 2)
			end
		end
	end
	if goals_done(match) then
		finish(arena, match, true)
	end
end

-- ============================================================
-- ACTIONS
-- ============================================================

-- The ground block the player meant: plants and saplings stand on it.
local function ground_of(pos)
	local node = core.get_node(pos)
	if DRY_PLANTS[node.name] or core.get_item_group(node.name, "plant") > 0
			or core.get_item_group(node.name, "flower") > 0 then
		return vector.offset(pos, 0, -1, 0)
	end
	return pos
end

-- Columns of a 3x3 square around `center` (any of the three heights).
local function each_surface(center, fn)
	for dx = -1, 1 do
		for dz = -1, 1 do
			for dy = 1, -1, -1 do
				local pos = vector.offset(center, dx, dy, dz)
				local node = core.get_node(pos)
				local above = core.get_node(vector.offset(pos, 0, 1, 0))
				if (above.name == "air" or DRY_PLANTS[above.name] or core.get_item_group(above.name, "plant") > 0)
						and fn(pos, node, above) then
					break
				end
			end
		end
	end
end

local function use_compost(arena, match, player, pos)
	local p_name = player:get_player_name()
	local center = ground_of(pos)
	local changed = 0
	each_surface(center, function(p, node, above)
		if not inside(match, p) or not barren(node) then return end
		if DRY_PLANTS[above.name] then
			core.remove_node(vector.offset(p, 0, 1, 0))
		end
		core.set_node(p, {name = FERTILE})
		changed = changed + 1
		return true
	end)
	if changed == 0 then
		local node = core.get_node(center)
		if node.name == FERTILE then
			hint(p_name, S("Already enriched: now water it!"), 0x8fd0ff)
		elseif healthy(node) then
			hint(p_name, S("This soil is already healthy."), 0x9be26f)
		else
			hint(p_name, S("Compost goes on bare soil."), 0xffd43b)
		end
		return
	end
	particles(vector.offset(center, 0, 0.6, 0), MOD .. "_crumb.png", 10 + changed * 2, {spread = 1.2})
	sound("default_dirt_footstep", {pos = center, gain = 0.8, max_hear_distance = 12})
end

local function water_soil(arena, match, player, center)
	local changed = 0
	each_surface(center, function(p, node)
		if not inside(match, p) or node.name ~= FERTILE then return end
		core.set_node(p, {name = GRASS, param2 = GRASS_P2})
		match.restored[hash(p)] = true
		changed = changed + 1
		return true
	end)
	return changed
end

local function grow_simple_tree(pos, species)
	-- Fallback when the schematic does not fit: a small round tree.
	local log = "mcl_trees:tree_" .. species
	local leaves = "mcl_trees:leaves_" .. species
	local height = math.random(4, 5)
	for y = 0, height - 1 do
		core.set_node(vector.offset(pos, 0, y, 0), {name = log})
	end
	for dx = -2, 2 do
		for dz = -2, 2 do
			for dy = height - 2, height + 1 do
				local r = dy >= height and 1 or 2
				if math.abs(dx) <= r and math.abs(dz) <= r and not (math.abs(dx) == 2 and math.abs(dz) == 2) then
					local p = vector.offset(pos, dx, dy, dz)
					if core.get_node(p).name == "air" then
						core.set_node(p, {name = leaves, param2 = 32 + (LEAVES_P2[species] or GRASS_P2)})
					end
				end
			end
		end
	end
end

local function recolor_leaves(pos, species)
	local lp = LEAVES_P2[species]
	if not lp then return end
	local found = core.find_nodes_in_area(vector.offset(pos, -4, 0, -4), vector.offset(pos, 4, 14, 4), {"group:leaves"})
	for _, p in ipairs(found) do
		local node = core.get_node(p)
		local want = math.floor(node.param2 / 32) * 32 + lp
		if node.param2 ~= want then
			node.param2 = want
			core.swap_node(p, node)
		end
	end
end

local function grow_tree(arena, match, key)
	local sap = match.saplings[key]
	if not sap or sap.grown then return end
	sap.grown = true
	local node = core.get_node(sap.pos)
	if node.name == "mcl_trees:sapling_" .. sap.species then
		if mcl_trees and mcl_trees.grow_tree then
			pcall(mcl_trees.grow_tree, sap.pos, node)
		end
		if core.get_item_group(core.get_node(sap.pos).name, "tree") == 0 then
			core.remove_node(sap.pos)
			grow_simple_tree(sap.pos, sap.species)
		end
	elseif core.get_item_group(node.name, "tree") == 0 then
		return -- gone (it can't be dug, but just in case)
	end
	recolor_leaves(sap.pos, sap.species)

	sparkle(vector.offset(sap.pos, 0, 2, 0), "#9be26f", 30)
	particles(vector.offset(sap.pos, 0, 3, 0), MOD .. "_leaf.png", 24, {spread = 2, gravity = -1.5, life = 1.8})
	sound("mcl_experience", {pos = sap.pos, gain = 0.5, max_hear_distance = 24})
	add_progress(arena, match, sap.by, "trees", 1)
	hud_update_all(arena, match)
end

local function water_sapling(arena, match, player, key)
	local sap = match.saplings[key]
	local p_name = player:get_player_name()
	if sap.watered then
		hint(p_name, S("Already watered: it is growing!"), 0x8fd0ff)
		return false
	end
	sap.watered = true
	sap.by = sap.by or p_name
	local token = match.token
	core.after(TREE_GROW_TIME, function()
		if matches[arena.name] == match and match.token == token and not match.finished then
			grow_tree(arena, match, key)
		end
	end)
	particles(vector.offset(sap.pos, 0, 0.5, 0), MOD .. "_leaf.png", 8, {spread = 0.3, gravity = -1, life = 1.5})
	hint(p_name, S("The sapling is growing..."), 0x9be26f)
	return true
end

local function sapling_key_at(match, pos)
	for _, p in ipairs({pos, vector.offset(pos, 0, 1, 0)}) do
		local key = hash(p)
		if match.saplings[key] then return key end
	end
end

-- Returns true when a watering was used.
local function use_can(arena, match, player, pos, node)
	local p_name = player:get_player_name()
	if node.name == BARREL or core.get_item_group(node.name, "water") > 0 then
		match.water[p_name] = CAN_CAPACITY
		sound("mcl_sounds_dug_water", {pos = pos, max_hear_distance = 12})
		rain(vector.offset(pos, 0, -0.6, 0), 8)
		hint(p_name, S("Watering can full!"), 0x4fa8ff)
		return false
	end
	if water_of(match, p_name) <= 0 then
		hint(p_name, S("The watering can is empty: refill it at a rain barrel!"), 0xff9a7a, 4)
		return false
	end

	local key = sapling_key_at(match, pos)
	if key then
		if not water_sapling(arena, match, player, key) then return false end
		rain(match.saplings[key].pos, 14)
		sound("mcl_sounds_place_node_water", {pos = pos, gain = 0.4, max_hear_distance = 12})
		return true
	end

	local center = ground_of(pos)
	local changed = water_soil(arena, match, player, center)
	if changed == 0 then
		local here = core.get_node(center)
		if barren(here) then
			hint(p_name, S("Too dry: spread compost here first!"), 0xffd43b)
		elseif healthy(here) then
			hint(p_name, S("This soil is already healthy."), 0x9be26f)
		else
			hint(p_name, S("Water enriched soil or a sapling."), 0xffd43b)
		end
		return false
	end
	rain(center, 10 + changed * 2)
	sparkle(vector.offset(center, 0, 0.6, 0), "#9be26f", 4 + changed)
	sound("mcl_sounds_place_node_water", {pos = center, gain = 0.4, max_hear_distance = 12})
	add_progress(arena, match, p_name, "soil", changed)
	return true
end

local function use_seeds(arena, match, player, pos)
	local p_name = player:get_player_name()
	if sapling_key_at(match, pos) then
		hint(p_name, S("Saplings only need water to grow."), 0x8fd0ff)
		return
	end

	local center = ground_of(pos)
	if not restored(match, center) then
		hint(p_name, S("Seeds only sprout on the grass you restored: compost and water the soil first!"), 0xffd43b, 4)
		return
	end
	local spots = {}
	for dx = -SEED_RADIUS, SEED_RADIUS do
		for dz = -SEED_RADIUS, SEED_RADIUS do
			for dy = -1, 1 do
				local p = vector.offset(center, dx, dy, dz)
				local up = vector.offset(p, 0, 1, 0)
				if inside(match, up) and restored(match, p) and core.get_node(up).name == "air" then
					spots[#spots + 1] = up
					break
				end
			end
		end
	end
	for i = #spots, 2, -1 do
		local j = math.random(i)
		spots[i], spots[j] = spots[j], spots[i]
	end
	local grown = 0
	for i = 1, math.min(SEED_PLANTS, #spots) do
		local p = spots[i]
		local roll = math.random()
		if roll < 0.4 then
			core.set_node(p, {name = FLOWERS[math.random(#FLOWERS)]})
		elseif roll < 0.5 and core.get_node(vector.offset(p, 0, 1, 0)).name == "air"
				and core.registered_nodes["mcl_flowers:double_grass"] then
			core.set_node(p, {name = "mcl_flowers:double_grass", param2 = GRASS_P2})
			core.set_node(vector.offset(p, 0, 1, 0), {name = "mcl_flowers:double_grass_top", param2 = GRASS_P2})
		else
			core.set_node(p, {name = "mcl_flowers:tallgrass", param2 = GRASS_P2})
		end
		grown = grown + 1
	end
	if grown == 0 then
		hint(p_name, S("No room here: try a patch of restored grass with nothing on it."), 0xffd43b)
		return
	end
	particles(vector.offset(center, 0, 1.4, 0), MOD .. "_seed.png", 24, {spread = 1.8, minvel = {x = -0.5, y = 0, z = -0.5},
		maxvel = {x = 0.5, y = 0.5, z = 0.5}, gravity = -5, life = 0.7, minsize = 1, maxsize = 1.6})
	sparkle(vector.offset(center, 0, 0.8, 0), "#ff8fb8", 6)
	sound("default_grass_footstep", {pos = center, gain = 0.8, max_hear_distance = 12})
	add_progress(arena, match, p_name, "plants", grown)
end

local function use_sapling(arena, match, player, pos)
	local p_name = player:get_player_name()
	local ground = ground_of(pos)
	local spot = vector.offset(ground, 0, 1, 0)
	local above = core.get_node(spot)
	if not restored(match, ground) then
		hint(p_name, S("Saplings only grow on the grass you restored: compost and water the soil first!"), 0xffd43b, 4)
		return
	end
	if not inside(match, spot) or not (above.name == "air" or core.get_item_group(above.name, "plant") > 0
			or core.get_item_group(above.name, "flower") > 0) then
		hint(p_name, S("There is no room for a tree here."), 0xffd43b)
		return
	end
	for y = 1, 4 do
		if core.get_node(vector.offset(spot, 0, y, 0)).name ~= "air" then
			hint(p_name, S("There is no room for a tree here."), 0xffd43b)
			return
		end
	end
	local near = core.find_nodes_in_area(vector.offset(spot, -TREE_SPACING, -1, -TREE_SPACING),
		vector.offset(spot, TREE_SPACING, 3, TREE_SPACING), {"group:tree", "group:sapling"})
	if #near > 0 then
		hint(p_name, S("Too close to another tree: trees need space to grow."), 0xffd43b)
		return
	end
	local species = pick_species()
	if above.name ~= "air" and core.get_item_group(above.name, "double_plant") > 0 then
		core.remove_node(vector.offset(spot, 0, 1, 0))
	end
	core.set_node(spot, {name = "mcl_trees:sapling_" .. species})
	match.saplings[hash(spot)] = {pos = vector.copy(spot), species = species, by = p_name}
	particles(vector.offset(spot, 0, 0.2, 0), MOD .. "_crumb.png", 8, {spread = 0.3})
	sound("default_grass_footstep", {pos = spot, gain = 0.9, max_hear_distance = 12})
	hint(p_name, S("Sapling planted: now water it!"), 0x8fd0ff)
end

-- ============================================================
-- ITEMS
-- ============================================================

local function ready(p_name)
	local now = core.get_us_time()
	if cooldown[p_name] and now - cooldown[p_name] < TOOL_COOLDOWN * 1000000 then return false end
	cooldown[p_name] = now
	return true
end

local function can_wear(water)
	if water >= CAN_CAPACITY then return 0 end
	return math.min(65534, math.floor(65535 * (1 - water / CAN_CAPACITY)))
end

local function tool_action(kind)
	return function(itemstack, user, pointed_thing)
		local match, arena = match_of_player(user)
		if not match then return end
		if pointed_thing.type ~= "node" then return end
		local p_name = user:get_player_name()
		if not ready(p_name) then return end
		local pos = pointed_thing.under
		local node = core.get_node(pos)
		if kind == "compost" then
			use_compost(arena, match, user, pos)
		elseif kind == "can" then
			if use_can(arena, match, user, pos, node) then
				match.water[p_name] = water_of(match, p_name) - 1
			end
		elseif kind == "seeds" then
			use_seeds(arena, match, user, pos)
		elseif kind == "sapling" then
			use_sapling(arena, match, user, pos)
		end
		if matches[arena.name] == match then
			hud_update_all(arena, match)
		end
		if kind == "can" then
			local water = water_of(match, p_name)
			itemstack:set_wear(can_wear(water))
			return itemstack
		end
	end
end

-- Kept on death and on Q: the game gives them back at the respawn anyway.
local function no_drop(itemstack)
	return itemstack
end

local item_defs = {
	compost = {description = S("Compost"), image = MOD .. "_compost.png"},
	seeds = {description = S("Wildflower seeds"), image = MOD .. "_seeds.png"},
	sapling = {description = S("Saplings"), image = MOD .. "_sapling.png"},
}
for kind, def in pairs(item_defs) do
	core.register_craftitem(TOOLS[kind].item, {
		description = def.description .. "\n" .. core.colorize("#9fb398", TOOLS[kind].hint),
		inventory_image = def.image,
		wield_image = def.image,
		wield_scale = {x = 1.4, y = 1.4, z = 1},
		stack_max = 1,
		range = 6,
		groups = {not_in_creative_inventory = 1},
		on_use = tool_action(kind),
		on_place = tool_action(kind),
		on_drop = no_drop,
	})
end

core.register_tool(TOOLS.can.item, {
	description = S("Watering can") .. "\n" .. core.colorize("#9fb398", TOOLS.can.hint),
	inventory_image = MOD .. "_watering_can.png",
	wield_image = MOD .. "_watering_can.png",
	wield_scale = {x = 1.4, y = 1.4, z = 1},
	range = 6,
	liquids_pointable = true,
	groups = {not_in_creative_inventory = 1, disable_repair = 1},
	wear_color = {color_stops = {[0.0] = "#ff8a7a", [0.3] = "#8fd0ff", [1.0] = "#4fa8ff"}},
	on_use = tool_action("can"),
	on_place = tool_action("can"),
	on_drop = no_drop,
})

local function give_tools(player, match)
	local inv = player:get_inventory()
	if not inv then return end
	for i, kind in ipairs(TOOL_ORDER) do
		local item = TOOLS[kind].item
		if not inv:contains_item("main", item) then
			local stack = ItemStack(item)
			if kind == "can" then
				local water = water_of(match, player:get_player_name())
				stack:set_wear(can_wear(water))
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

local dirt_sounds = mcl_sounds and mcl_sounds.node_sound_dirt_defaults and mcl_sounds.node_sound_dirt_defaults() or nil
local wood_sounds = mcl_sounds and mcl_sounds.node_sound_wood_defaults and mcl_sounds.node_sound_wood_defaults() or nil

core.register_node(FERTILE, {
	description = S("Enriched soil"),
	tiles = {"default_dirt.png^" .. MOD .. "_fertile_overlay.png"},
	groups = {crumbly = 3, shovely = 1, not_in_creative_inventory = 1},
	drop = "",
	sounds = dirt_sounds,
	_mcl_hardness = 0.5,
	is_ground_content = false,
})

core.register_node(BARREL, {
	description = S("Rain barrel"),
	drawtype = "nodebox",
	tiles = {MOD .. "_barrel_top.png", MOD .. "_barrel_bottom.png", MOD .. "_barrel_side.png"},
	paramtype = "light",
	node_box = {type = "fixed", fixed = {-0.4375, -0.5, -0.4375, 0.4375, 0.4375, 0.4375}},
	groups = {choppy = 2, axey = 1, not_in_creative_inventory = 1},
	drop = "",
	sounds = wood_sounds,
	_mcl_hardness = 2,
	is_ground_content = false,
	on_construct = function(pos)
		core.get_meta(pos):set_string("infotext", S("Rain barrel") .. "\n" .. S("Click it with the watering can"))
	end,
	on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
		if itemstack:get_name() == TOOLS.can.item then
			return tool_action("can")(itemstack, clicker, {type = "node", under = pos, above = pos})
		end
		return itemstack
	end,
})

-- ============================================================
-- ARENA SET-UP
-- ============================================================

local function surface_at(match, x, z)
	for y = match.p2.y - 1, match.p1.y, -1 do
		local pos = {x = x, y = y, z = z}
		local node = core.get_node(pos)
		local def = core.registered_nodes[node.name]
		if node.name == "ignore" or not def then return end
		if def.walkable then
			if (def.groups.leaves or 0) > 0 or (def.groups.tree or 0) > 0 then return end
			local up1 = core.get_node(vector.offset(pos, 0, 1, 0)).name
			local up2 = core.get_node(vector.offset(pos, 0, 2, 0)).name
			if (up1 == "air" or DRY_PLANTS[up1] or core.get_item_group(up1, "plant") > 0) and up2 == "air" then
				return vector.offset(pos, 0, 1, 0)
			end
			return
		end
	end
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

local function place_barrels(arena, match)
	local spec = arena.params and arena.params.barrels
	local spots = {}
	if type(spec) == "table" and #spec > 0 then
		for _, p in ipairs(spec) do
			spots[#spots + 1] = {x = p[1], z = p[3] or p[2]}
		end
	else
		local c = center_of(arena)
		for ring_i, ring in ipairs(BARREL_RINGS) do
			local r, n = ring[1], ring[2]
			for i = 0, n - 1 do
				local a = (i / n + ring_i * 0.13) * math.pi * 2
				spots[#spots + 1] = {x = math.floor(c.x + math.cos(a) * r + 0.5), z = math.floor(c.z + math.sin(a) * r + 0.5)}
			end
		end
	end
	for _, s in ipairs(spots) do
		-- Nudge around a little when a tree stump or a log pile is in the way.
		for attempt = 0, 12 do
			local x = s.x + (attempt > 0 and math.random(-3, 3) or 0)
			local z = s.z + (attempt > 0 and math.random(-3, 3) or 0)
			local pos = surface_at(match, x, z)
			if pos and inside(match, pos) then
				core.set_node(pos, {name = BARREL})
				match.barrels[#match.barrels + 1] = pos
				break
			end
		end
	end
end

local function goals_for(arena, players, available)
	local scale = math.max(1, players) ^ GROUP_EXPONENT
	local goals = {}
	for _, key in ipairs(GOAL_ORDER) do
		local fixed = tonumber(arena.params and arena.params[key .. "_goal"])
		goals[key] = fixed and fixed > 0 and math.floor(fixed) or math.ceil(SOLO_GOALS[key] * scale)
	end
	-- Never more soil than the area can give, with some to spare.
	goals.soil = math.max(1, math.min(goals.soil, math.floor(available * 0.7)))
	-- A tree needs room around it: about one per 12 blocks of grass.
	goals.trees = math.max(1, math.min(goals.trees, math.floor(goals.soil / 12)))
	goals.plants = math.max(1, math.min(goals.plants, goals.soil * 2))
	return goals
end

-- ============================================================
-- MINIGAME
-- ============================================================

-- Arena params (all optional): soil_goal, plants_goal, trees_goal (fixed
-- goals instead of the automatic ones) and barrels ([[x, y, z], …] where the
-- rain barrels go; the y is found on the ground).
local game_def = {
	title = S("Restore the Forest"),
	description = S("Bring the felled forest back to life: enrich and water the soil, grow grass and flowers, plant trees."),
	icon = MOD .. "_icon.png",
	color = "#3f8f4f",
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
		local msg = S("The forest is alive again! Time: @1", format_time(time))
		chat(arena, msg .. "  " .. (is_record and core.colorize("#ffd43b", S("NEW RECORD!"))
			or S("Record: @1", format_time(record))))
		skyss_minigames.title(arena, is_record and S("New record!") or S("The forest is alive again!"),
			CELEBRATION_TIME, is_record and 0xffd43b or 0x9be26f)
		chat(arena, S("Take a walk in your forest before going back."))
	elseif reason then
		chat(arena, core.colorize("#ff9a7a", reason))
	end

	-- The best gardeners of the match.
	local ranked = {}
	for name, work in pairs(match.mine) do
		ranked[#ranked + 1] = {name = name, score = work.soil + work.plants * 2 + work.trees * 10}
	end
	table.sort(ranked, function(a, b) return a.score > b.score end)
	if #ranked > 1 then
		local top = {}
		for i = 1, math.min(3, #ranked) do top[i] = ranked[i].name end
		chat(arena, S("Best gardeners: @1", table.concat(top, ", ")))
	end

	for p_name in pairs(arena.players) do
		hud_update_player(arena, match, p_name)
		local player = core.get_player_by_name(p_name)
		if player and huds[p_name] then hud_clear_waypoint(player, huds[p_name]) end
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
		count = {soil = 0, plants = 0, trees = 0},
		mine = {},
		water = {},
		restored = {},
		saplings = {},
		barrels = {},
	}
	matches[arena.name] = match
	core.load_area(p1, p2)

	local available = #core.find_nodes_in_area_under_air(p1, p2, BARREN_LIST)
	match.goals = goals_for(arena, skyss_minigames.player_count(arena), available)
	place_barrels(arena, match)
	if #match.barrels == 0 then
		core.log("warning", "[skyss_treegame] Arena " .. arena.name .. ": no room for the rain barrels")
	end

	for p_name, player in skyss_minigames.players(arena) do
		match.water[p_name] = CAN_CAPACITY
		match.mine[p_name] = {soil = 0, plants = 0, trees = 0}
		give_tools(player, match)
		hud_create(player)
	end
	hud_update_all(arena, match)

	skyss_minigames.title(arena, S("Bring the forest back to life!"), 3, 0x9be26f)
	chat(arena, S("Goals for the team: @1 blocks of healthy soil, @2 plants, @3 trees.",
		match.goals.soil, match.goals.plants, match.goals.trees))
	chat(arena, S("1. Compost on bare soil  2. Water it  3. Sow seeds on the grass  4. Plant saplings on the grass and water them. Refill the can at the rain barrels."))
end

function game_def.on_join(arena, p_name)
	local match = matches[arena.name]
	if not match or match.finished then return end
	match.water[p_name] = match.water[p_name] or CAN_CAPACITY
	match.mine[p_name] = match.mine[p_name] or {soil = 0, plants = 0, trees = 0}
	local player = core.get_player_by_name(p_name)
	if player then
		give_tools(player, match)
		hud_create(player)
	end
	hud_update_all(arena, match)
	chat(arena, S("@1 joins the gardeners!", p_name))
end

function game_def.on_respawn(arena, p_name)
	local match = matches[arena.name]
	local player = core.get_player_by_name(p_name)
	if match and not match.finished and player then
		give_tools(player, match)
	end
end

function game_def.on_leave(arena, p_name)
	local player = core.get_player_by_name(p_name)
	if player then
		hud_remove(player)
		remove_tools(player)
	end
	local match = matches[arena.name]
	if match and not match.finished then hud_update_all(arena, match) end
end

function game_def.on_timeout(arena)
	local match = matches[arena.name]
	if match and not match.finished then
		local parts = {}
		for _, key in ipairs(GOAL_ORDER) do
			parts[#parts + 1] = S("@1 @2/@3", GOALS[key].label, math.min(goal_count(match, key), match.goals[key]), match.goals[key])
		end
		finish(arena, match, false, S("Time is up! The forest needed more care: @1.", table.concat(parts, ", ")))
	end
end

function game_def.on_finish(arena, result)
	local match = matches[arena.name]
	if match and not match.finished then
		match.finished = true
		match.stopped_us = core.get_us_time()
	end
	if match and result and result.success then
		core.after(math.max(1, CELEBRATION_TIME - 10), function()
			if matches[arena.name] == match then
				chat(arena, "\xE2\x8F\xB1 " .. S("10 seconds left in the forest!"))
			end
		end)
	end
end

function game_def.on_end(arena)
	local match = matches[arena.name]
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

-- Twice a second: timer, and a hint about the tool just taken in hand.
local tick = 0
core.register_globalstep(function(dtime)
	tick = tick + dtime
	if tick < 0.5 then return end
	tick = 0
	for name, match in pairs(matches) do
		local arena = skyss_minigames.get_match(name)
		if arena and arena.state == "running" and not match.finished then
			for p_name in pairs(arena.players) do
				local player = core.get_player_by_name(p_name)
				local h = huds[p_name]
				if player and h then
					player:hud_change(h.timer, "text", format_time(elapsed(match)))
					local wielded = player:get_wielded_item():get_name()
					if wielded ~= wield_seen[p_name] then
						wield_seen[p_name] = wielded
						for _, kind in ipairs(TOOL_ORDER) do
							if TOOLS[kind].item == wielded then
								hint(p_name, TOOLS[kind].hint, 0xdbe8d4, 4)
							end
						end
					end
				end
			end
		end
	end
end)

core.register_on_leaveplayer(function(player)
	local p_name = player:get_player_name()
	huds[p_name] = nil
	cooldown[p_name] = nil
	wield_seen[p_name] = nil
end)

core.log("action", "[skyss_treegame] Game mod loaded")
