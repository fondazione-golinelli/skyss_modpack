local MOD = "skyss_cleanup"
local S = core.get_translator(MOD)
local TAG = "[Eco-CleanUp] "

-- ============================================================
-- CONFIGURATION
-- ============================================================

local CARRY_LIMIT = 8            -- waste a single player can carry at once
local WRONG_BIN_PENALTY = 10     -- seconds added to the team time per wrong bin
local WASTE_BASE = 10            -- automatic amount: base + per player, capped
local WASTE_PER_PLAYER = 4
local WASTE_MAX = 40
local HINT_THRESHOLD = 3         -- show waypoints when this many are left on the ground
local CELEBRATION_TIME = 10

local hud_type = core.features.hud_def_type_field and "type" or "hud_elem_type"
local storage = core.get_mod_storage()

local BINS = {
	plastic = {label = S("Plastic & Metal"), short = S("Plastic"), color = "#f2c230", hex = 0xf2c230, colour_name = S("yellow")},
	glass = {label = S("Glass"), short = S("Glass"), color = "#3f9b4e", hex = 0x5fc46e, colour_name = S("green")},
	general = {label = S("General Waste"), short = S("General"), color = "#8a9298", hex = 0xb8c0c6, colour_name = S("grey")},
}
local BIN_ORDER = {"plastic", "glass", "general"}

-- Meshes are authored in node units, so the entity scale is 10 (1 node = 10 units).
local WASTE = {
	bottle = {
		label = S("Plastic bottle"), bin = "plastic", weight = 3,
		box = {-0.28, 0, -0.28, 0.28, 0.25, 0.28},
		fact = S("A plastic bottle left in nature can last for hundreds of years."),
	},
	can = {
		label = S("Drink can"), bin = "plastic", weight = 2,
		box = {-0.2, 0, -0.2, 0.2, 0.2, 0.2},
		fact = S("Recycling aluminium takes about 95% less energy than making it from scratch."),
	},
	jar = {
		label = S("Glass bottle"), bin = "glass", weight = 2,
		box = {-0.3, 0, -0.3, 0.3, 0.25, 0.3},
		fact = S("Glass can be recycled endlessly without losing quality."),
	},
	bag = {
		label = S("Garbage bag"), bin = "general", weight = 2,
		box = {-0.35, 0, -0.35, 0.35, 0.55, 0.35},
		fact = S("At sea, turtles mistake plastic bags for jellyfish."),
	},
	barrel = {
		label = S("Old barrel"), bin = "general", weight = 1,
		box = {-0.35, 0, -0.35, 0.35, 0.85, 0.35},
		fact = S("Abandoned barrels can leak pollutants into the soil and water."),
	},
}
local WASTE_ORDER = {"bottle", "can", "jar", "bag", "barrel"}

local WATER_SOURCES = {"mcl_core:water_source", "default:water_source"}

-- ============================================================
-- STATE
-- ============================================================

-- Runtime match state, keyed by arena name: arena_lib hands on_end a copy of
-- the arena table, and entities must not be stored in persisted arena fields.
local matches = {}
local huds = {}
local serial = 0

local function get_match(arena)
	return arena and matches[arena.name]
end

local function match_of_player(player)
	if not player or not player:is_player() then return end
	local p_name = player:get_player_name()
	if arena_lib.get_mod_by_player(p_name) ~= MOD then return end
	local arena = arena_lib.get_arena_by_player(p_name)
	local match = get_match(arena)
	if match and arena.in_game and arena.players[p_name] then
		return match, arena
	end
end

local function playing(match)
	return match and not match.finished
end

local function waste_kind(stack, token)
	local kind = stack:get_name():match("^" .. MOD .. ":(.+)$")
	if WASTE[kind or ""] and (not token or stack:get_meta():get_string("token") == token) then
		return kind
	end
end

local function format_time(seconds)
	seconds = math.max(0, math.floor(seconds + 0.5))
	return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function elapsed(match)
	local stop = match.stopped_us or core.get_us_time()
	return (stop - match.started_us) / 1000000 + match.penalty
end

local function carried_total(match, p_name)
	local total = 0
	for _, count in pairs(match.carried[p_name] or {}) do
		total = total + count
	end
	return total
end

local function count_ground(match)
	local n = 0
	for _ in pairs(match.waste) do n = n + 1 end
	return n
end

local function record_key(arena)
	return "record:" .. arena.name
end

local function chat(arena, message)
	for p_name in pairs(arena.players) do
		core.chat_send_player(p_name, core.colorize("#8fe388", TAG) .. message)
	end
end

local function sound(name, params)
	params = params or {}
	params.gain = params.gain or 0.7
	core.sound_play(name, params, true)
end

local function sound_all(arena, name, params)
	for p_name in pairs(arena.players) do
		local p = table.copy(params or {})
		p.to_player = p_name
		sound(name, p)
	end
end

-- ============================================================
-- HUD
-- ============================================================

-- Anchored to the top-right corner, clear of the chat on the left.
local PANEL_MARGIN, PANEL_Y, PANEL_W, PANEL_H = 16, 16, 340, 196
local BAR_W = PANEL_W - 28

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

local function fill(color)
	return "[fill:1x1:" .. color
end

local function hud_create(player)
	local p_name = player:get_player_name()
	if huds[p_name] then return huds[p_name] end
	local h = {all = {}, waypoints = {}, waypoint_sig = ""}

	hud_add(player, h, "image", 0, 0, {text = fill("#0d1a15d8"), scale = {x = PANEL_W, y = PANEL_H}, z_index = 899})
	hud_add(player, h, "image", 0, 0, {text = fill("#5fd36a"), scale = {x = PANEL_W, y = 4}})
	hud_add(player, h, "text", 14, 14, {text = "ECO-CLEANUP", number = 0x8fe388, style = 1})
	h.timer = hud_add(player, h, "text", PANEL_W - 14, 14, {text = "00:00", number = 0xffffff, style = 5, alignment = {x = -1, y = 1}})

	hud_add(player, h, "text", 14, 42, {text = S("Waste sorted"), number = 0xd8e6de})
	h.progress = hud_add(player, h, "text", PANEL_W - 14, 42, {text = "0 / 0", number = 0xffffff, style = 1, alignment = {x = -1, y = 1}})
	hud_add(player, h, "image", 14, 66, {text = fill("#26362f"), scale = {x = BAR_W, y = 12}})
	h.bar = hud_add(player, h, "image", 14, 66, {text = "", scale = {x = 1, y = 12}, z_index = 901})
	h.ground = hud_add(player, h, "text", 14, 84, {text = "", number = 0x9fb3a8})

	hud_add(player, h, "image", 14, 108, {text = fill("#ffffff30"), scale = {x = BAR_W, y = 1}})
	h.bag = hud_add(player, h, "text", 14, 116, {text = "", number = 0xffffff})
	h.chips = {}
	for i, bin_id in ipairs(BIN_ORDER) do
		local x = 14 + (i - 1) * 106
		hud_add(player, h, "image", x, 143, {text = fill(BINS[bin_id].color), scale = {x = 14, y = 14}})
		h.chips[bin_id] = hud_add(player, h, "text", x + 20, 140, {text = "", number = 0xffffff})
	end
	h.footer = hud_add(player, h, "text", 14, 168, {text = "", number = 0x9fb3a8})

	huds[p_name] = h
	return h
end

local function hud_remove(player)
	local p_name = player:get_player_name()
	local h = huds[p_name]
	if not h then return end
	for _, id in ipairs(h.all) do
		player:hud_remove(id)
	end
	for _, id in ipairs(h.waypoints) do
		player:hud_remove(id)
	end
	huds[p_name] = nil
end

local function hud_update_player(arena, match, p_name)
	local player = core.get_player_by_name(p_name)
	if not player then return end
	local h = hud_create(player)

	player:hud_change(h.timer, "text", format_time(elapsed(match)))

	local frac = match.total > 0 and match.deposited / match.total or 0
	player:hud_change(h.progress, "text", match.deposited .. " / " .. match.total)
	if frac > 0 then
		player:hud_change(h.bar, "text", fill("#5fd36a"))
		player:hud_change(h.bar, "scale", {x = math.max(1, math.floor(BAR_W * frac)), y = 12})
	else
		player:hud_change(h.bar, "text", "")
	end

	local carried_by_team = 0
	for name in pairs(match.carried) do
		carried_by_team = carried_by_team + carried_total(match, name)
	end
	player:hud_change(h.ground, "text", S("On the ground: @1    In bags: @2", count_ground(match), carried_by_team))

	local mine = match.carried[p_name] or {}
	local total = carried_total(match, p_name)
	player:hud_change(h.bag, "text", S("Your bag  @1 / @2", total, CARRY_LIMIT))
	player:hud_change(h.bag, "number", total >= CARRY_LIMIT and 0xff8a5c or 0xffffff)
	for _, bin_id in ipairs(BIN_ORDER) do
		local n = 0
		for kind, count in pairs(mine) do
			if WASTE[kind].bin == bin_id then n = n + count end
		end
		player:hud_change(h.chips[bin_id], "text", BINS[bin_id].short .. " " .. n)
		player:hud_change(h.chips[bin_id], "number", n > 0 and 0xffffff or 0x7d8c84)
	end

	local footer = match.errors > 0 and S("Mistakes: @1 (+@2s)", match.errors, match.penalty)
		or S("Mistakes: @1", 0)
	local record = storage:get_float(record_key(arena))
	footer = footer .. "     " .. S("Record: @1", record > 0 and format_time(record) or "--:--")
	player:hud_change(h.footer, "text", footer)
	player:hud_change(h.footer, "number", match.errors > 0 and 0xffa38a or 0x9fb3a8)
end

-- Waypoints guide the team to the last few pieces of waste.
local function hud_update_waypoints(match, p_name)
	local player = core.get_player_by_name(p_name)
	local h = huds[p_name]
	if not player or not h then return end

	local targets, sig = {}, ""
	if playing(match) and count_ground(match) <= HINT_THRESHOLD then
		for id, rec in pairs(match.waste) do
			targets[#targets + 1] = rec
			sig = sig .. id .. ";"
		end
	end
	if sig == h.waypoint_sig then return end

	for _, id in ipairs(h.waypoints) do
		player:hud_remove(id)
	end
	h.waypoints = {}
	h.waypoint_sig = sig
	for _, rec in ipairs(targets) do
		local wp = {
			name = WASTE[rec.kind].label,
			text = " m",
			precision = 1,
			number = 0x8fe388,
			world_pos = vector.offset(rec.pos, 0, 0.8, 0),
			z_index = -300,
		}
		wp[hud_type] = "waypoint"
		h.waypoints[#h.waypoints + 1] = player:hud_add(wp)
	end
end

local function hud_clear_waypoints(p_name)
	local player = core.get_player_by_name(p_name)
	local h = huds[p_name]
	if not player or not h then return end
	for _, id in ipairs(h.waypoints) do
		player:hud_remove(id)
	end
	h.waypoints = {}
	h.waypoint_sig = ""
end

local function hud_update_all(arena, match)
	for p_name in pairs(arena.players) do
		hud_update_player(arena, match, p_name)
		hud_update_waypoints(match, p_name)
	end
end

local function hotbar_msg(p_name, text, color, duration)
	arena_lib.HUD_send_msg("hotbar", p_name, text, duration or 3, nil, color or 0xffffff)
end

-- ============================================================
-- EFFECTS
-- ============================================================

local function burst(pos, color, amount, spread)
	spread = spread or 0.4
	core.add_particlespawner({
		amount = amount or 16,
		time = 0.1,
		minpos = vector.offset(pos, -spread, 0, -spread),
		maxpos = vector.offset(pos, spread, spread, spread),
		minvel = {x = -1.5, y = 1.5, z = -1.5},
		maxvel = {x = 1.5, y = 3.5, z = 1.5},
		minacc = {x = 0, y = -6, z = 0},
		maxacc = {x = 0, y = -6, z = 0},
		minexptime = 0.4,
		maxexptime = 0.9,
		minsize = 1.5,
		maxsize = 3,
		texture = MOD .. "_sparkle.png^[multiply:" .. color,
		glow = 12,
	})
end

local function fireworks(pos)
	for i = 1, 3 do
		core.after(i * 0.45, function()
			local colors = {"#ff5a5a", "#ffd43b", "#5fd36a", "#4fb3ff", "#d27cff"}
			local center = vector.offset(pos, math.random(-2, 2), 5 + math.random(0, 3), math.random(-2, 2))
			core.add_particlespawner({
				amount = 60,
				time = 0.05,
				minpos = center,
				maxpos = center,
				minvel = {x = -4, y = -4, z = -4},
				maxvel = {x = 4, y = 4, z = 4},
				minacc = {x = 0, y = -2, z = 0},
				maxacc = {x = 0, y = -2, z = 0},
				minexptime = 0.8,
				maxexptime = 1.6,
				minsize = 2,
				maxsize = 4,
				texture = MOD .. "_sparkle.png^[multiply:" .. colors[math.random(#colors)],
				glow = 14,
			})
			sound("mcl_bows_firework", {pos = center, gain = 0.5, max_hear_distance = 48})
		end)
	end
end

-- ============================================================
-- ITEMS
-- ============================================================

local function respawn_drop(itemstack, dropper)
	-- Mineclonia calls on_drop for every stack it scatters on death: keep the
	-- waste with the match instead of littering the arena with item entities.
	if dropper and dropper:is_player() and dropper:get_hp() <= 0 then
		local match = match_of_player(dropper)
		if match and waste_kind(itemstack, match.token) then
			local saved = match.death_items[dropper:get_player_name()] or {}
			saved[#saved + 1] = ItemStack(itemstack)
			match.death_items[dropper:get_player_name()] = saved
		end
		return ItemStack("")
	end
	return itemstack
end

local collect_waste

core.register_tool(MOD .. ":fork", {
	description = S("Eco-CleanUp Pitchfork") .. "\n" .. core.colorize("#9fb3a8", S("Hit a piece of waste to pick it up")),
	inventory_image = MOD .. "_fork.png",
	wield_scale = {x = 1.6, y = 1.6, z = 1},
	range = 6,
	groups = {not_in_creative_inventory = 1},
	tool_capabilities = {full_punch_interval = 0.25, damage_groups = {fleshy = 0}},
	on_use = function(itemstack, user, pointed_thing)
		if pointed_thing.type ~= "object" then return end
		local ent = pointed_thing.ref:get_luaentity()
		if ent and ent.name == MOD .. ":waste" then
			collect_waste(user, ent)
		end
	end,
	on_drop = respawn_drop,
})

for kind, def in pairs(WASTE) do
	local bin = BINS[def.bin]
	core.register_craftitem(MOD .. ":" .. kind, {
		description = def.label .. "\n" .. core.colorize(bin.color, S("Bin: @1", bin.label)),
		inventory_image = MOD .. "_" .. kind .. ".png",
		stack_max = CARRY_LIMIT,
		groups = {not_in_creative_inventory = 1},
		on_drop = respawn_drop,
	})
end

local function remove_round_items(player, token)
	local inv = player:get_inventory()
	if not inv then return end
	for i, stack in ipairs(inv:get_list("main") or {}) do
		if stack:get_name() == MOD .. ":fork" or waste_kind(stack, token) then
			inv:set_stack("main", i, ItemStack(""))
		end
	end
end

local function give_fork(player)
	local inv = player:get_inventory()
	if inv and not inv:contains_item("main", MOD .. ":fork") then
		local first = inv:get_stack("main", 1)
		if first:is_empty() then
			inv:set_stack("main", 1, ItemStack(MOD .. ":fork"))
		else
			inv:add_item("main", MOD .. ":fork")
		end
	end
end

-- ============================================================
-- WASTE ENTITY
-- ============================================================

local spawn_waste

core.register_entity(MOD .. ":waste", {
	initial_properties = {
		physical = false,
		collide_with_objects = false,
		pointable = true,
		visual = "mesh",
		mesh = MOD .. "_bag.obj",
		textures = {MOD .. "_bag_model.png"},
		visual_size = {x = 10, y = 10, z = 10},
		backface_culling = false,
		use_texture_alpha = true,
		glow = 3,
		selectionbox = {-0.3, 0, -0.3, 0.3, 0.5, 0.3},
		static_save = true,
	},

	get_staticdata = function(self)
		return core.serialize({arena = self.arena_name, token = self.token, id = self.id})
	end,

	on_activate = function(self, staticdata)
		local data = core.deserialize(staticdata or "") or {}
		local match = matches[data.arena or ""]
		local rec = match and match.token == data.token and match.waste[data.id]
		if not rec or match.finished then
			-- Leftover from a finished or crashed match.
			self.object:remove()
			return
		end
		self.arena_name, self.token, self.id = data.arena, data.token, data.id
		rec.obj = self.object

		local def = WASTE[rec.kind]
		local box = table.copy(def.box)
		box.rotate = true -- follows the yaw and the fallen barrels
		self.object:set_properties({
			mesh = MOD .. "_" .. rec.kind .. ".obj",
			textures = {MOD .. "_" .. rec.kind .. "_model.png"},
			visual_size = {x = rec.scale, y = rec.scale, z = rec.scale},
			selectionbox = box,
			infotext = def.label,
		})
		self.object:set_rotation(rec.rotation)
		self.object:set_armor_groups({immortal = 1})

		-- A gentle shimmer makes waste easy to spot, bubbles when underwater.
		core.add_particlespawner({
			amount = rec.water and 3 or 2,
			time = 0,
			attached = self.object,
			minpos = {x = -0.3, y = 0.1, z = -0.3},
			maxpos = {x = 0.3, y = 0.5, z = 0.3},
			minvel = {x = 0, y = rec.water and 0.8 or 0.3, z = 0},
			maxvel = {x = 0, y = rec.water and 1.4 or 0.6, z = 0},
			minexptime = 0.8,
			maxexptime = 1.6,
			minsize = 1,
			maxsize = 2,
			texture = rec.water and (MOD .. "_bubble.png") or (MOD .. "_sparkle.png^[multiply:#c8ffd0"),
			glow = 8,
		})
	end,

	on_punch = function(self, puncher)
		local match = match_of_player(puncher)
		if match and puncher:get_wielded_item():get_name() ~= MOD .. ":fork" then
			hotbar_msg(puncher:get_player_name(), S("Use the pitchfork to pick up waste!"), 0xffd43b)
		end
		return true
	end,
})

collect_waste = function(player, ent)
	local match, arena = match_of_player(player)
	if not playing(match) or ent.arena_name ~= arena.name or ent.token ~= match.token then return end
	local rec = match.waste[ent.id]
	if not rec then return end

	local p_name = player:get_player_name()
	if carried_total(match, p_name) >= CARRY_LIMIT then
		hotbar_msg(p_name, S("Your bag is full! Empty it into the bins."), 0xff8a5c)
		return
	end

	local def = WASTE[rec.kind]
	local stack = ItemStack(MOD .. ":" .. rec.kind)
	stack:get_meta():set_string("token", match.token)
	local inv = player:get_inventory()
	if not inv:room_for_item("main", stack) then
		hotbar_msg(p_name, S("Your inventory is full! Empty it into the bins."), 0xff8a5c)
		return
	end
	inv:add_item("main", stack)

	match.waste[ent.id] = nil
	local carried = match.carried[p_name]
	carried[rec.kind] = (carried[rec.kind] or 0) + 1

	local pos = ent.object:get_pos()
	ent.object:remove()
	burst(vector.offset(pos, 0, 0.2, 0), "#c8ffd0", 14)
	sound("item_drop_pickup", {pos = pos, max_hear_distance = 16})

	local bin = BINS[def.bin]
	hotbar_msg(p_name, S("@1  ->  @2 bin (@3)", def.label, bin.label, bin.colour_name), bin.hex, 4)

	match.seen_facts[p_name] = match.seen_facts[p_name] or {}
	if not match.seen_facts[p_name][rec.kind] then
		match.seen_facts[p_name][rec.kind] = true
		core.chat_send_player(p_name, core.colorize("#8fe388", S("Did you know?")) .. " " .. def.fact)
	end

	hud_update_all(arena, match)
end

-- Place one piece of waste of the given kind at a spawn spot.
spawn_waste = function(arena, match, spot, kind)
	match.next_id = match.next_id + 1
	local id = match.next_id
	local fallen = kind == "barrel" and math.random() < 0.4
	local pos = {
		x = spot.pos.x + (math.random() - 0.5) * 0.4,
		y = spot.pos.y - 0.5 + (fallen and 0.3 or 0),
		z = spot.pos.z + (math.random() - 0.5) * 0.4,
	}
	local rec = {
		kind = kind,
		pos = pos,
		water = spot.water,
		fallen = fallen,
		scale = 10 * (0.9 + math.random() * 0.25),
		rotation = {
			x = fallen and math.pi / 2 or 0,
			y = math.random() * math.pi * 2,
			z = (kind ~= "barrel" and kind ~= "bag") and (math.random() - 0.5) * 0.25 or 0,
		},
	}
	match.waste[id] = rec
	local obj = core.add_entity(pos, MOD .. ":waste",
		core.serialize({arena = arena.name, token = match.token, id = id}))
	if not obj then
		match.waste[id] = nil
		return false
	end
	return true
end

local function pick_kind()
	local total = 0
	for _, kind in ipairs(WASTE_ORDER) do total = total + WASTE[kind].weight end
	local roll = math.random() * total
	for _, kind in ipairs(WASTE_ORDER) do
		roll = roll - WASTE[kind].weight
		if roll <= 0 then return kind end
	end
	return WASTE_ORDER[1]
end

-- ============================================================
-- BIN LABELS
-- ============================================================

core.register_entity(MOD .. ":bin_label", {
	initial_properties = {
		physical = false,
		pointable = false,
		visual = "sprite",
		visual_size = {x = 0.01, y = 0.01},
		textures = {"blank.png^[opacity:0"},
		static_save = true,
	},

	get_staticdata = function(self)
		return core.serialize({arena = self.arena_name, token = self.token, bin = self.bin})
	end,

	on_activate = function(self, staticdata)
		local data = core.deserialize(staticdata or "") or {}
		local match = matches[data.arena or ""]
		local bin = BINS[data.bin or ""]
		if not match or match.token ~= data.token or not bin then
			self.object:remove()
			return
		end
		self.arena_name, self.token, self.bin = data.arena, data.token, data.bin
		match.labels[#match.labels + 1] = self.object
		self.object:set_properties({
			nametag = bin.label,
			nametag_color = "#ffffff",
			nametag_bgcolor = bin.color .. "e0",
		})
	end,
})

-- ============================================================
-- NODES: bins and spawn markers
-- ============================================================

local function bin_rightclick(bin_id)
	return function(pos, node, clicker, itemstack)
		local match, arena = match_of_player(clicker)
		if not playing(match) then return itemstack end
		local p_name = clicker:get_player_name()
		local bin = BINS[bin_id]
		local kind = waste_kind(itemstack, match.token)

		if not kind then
			if carried_total(match, p_name) > 0 then
				hotbar_msg(p_name, S("Hold a piece of waste and right-click the right bin."), 0xffd43b, 4)
			else
				local accepted = {}
				for _, k in ipairs(WASTE_ORDER) do
					if WASTE[k].bin == bin_id then accepted[#accepted + 1] = WASTE[k].label end
				end
				hotbar_msg(p_name, S("@1: @2", bin.label, table.concat(accepted, ", ")), bin.hex, 4)
			end
			return itemstack
		end

		local def = WASTE[kind]
		local top = vector.offset(pos, 0, 0.6, 0)
		if def.bin ~= bin_id then
			match.errors = match.errors + 1
			match.penalty = match.penalty + WRONG_BIN_PENALTY
			local right = BINS[def.bin]
			arena_lib.HUD_send_msg("title", p_name, S("Wrong bin!  +@1s", WRONG_BIN_PENALTY), 2, nil, 0xff6b5a)
			core.chat_send_player(p_name, core.colorize("#ff8a7a", TAG) .. S("@1 goes in the @2 bin (@3), not in @4.",
				def.label, core.colorize(right.color, right.label), right.colour_name, bin.label))
			sound("default_place_node_hard", {pos = top, pitch = 0.6, max_hear_distance = 16})
			hud_update_all(arena, match)
			return itemstack
		end

		local count = itemstack:get_count()
		match.deposited = match.deposited + count
		local carried = match.carried[p_name]
		carried[kind] = math.max(0, (carried[kind] or 0) - count)

		burst(top, bin.color, 10 + count * 4, 0.3)
		sound("mcl_barrels_default_barrel_close", {pos = top, max_hear_distance = 16})
		sound("mcl_experience", {to_player = p_name, gain = 0.4})
		local what = count > 1 and S("@1x @2", count, def.label) or def.label
		for name in pairs(arena.players) do
			hotbar_msg(name, S("@1 sorted: @2", p_name, what), bin.hex, 3)
		end

		hud_update_all(arena, match)
		if match.deposited >= match.total then
			match.finish(true)
		end
		return ItemStack("")
	end
end

for _, bin_id in ipairs(BIN_ORDER) do
	local bin = BINS[bin_id]
	core.register_node(MOD .. ":bin_" .. bin_id, {
		description = S("Eco-CleanUp: @1 bin", bin.label),
		drawtype = "mesh",
		mesh = MOD .. "_bin.obj",
		tiles = {{name = MOD .. "_bin_" .. bin_id .. ".png", backface_culling = false}},
		use_texture_alpha = "clip",
		paramtype = "light",
		paramtype2 = "facedir",
		sunlight_propagates = true,
		selection_box = {type = "fixed", fixed = {-0.47, -0.5, -0.47, 0.47, 0.4, 0.47}},
		collision_box = {type = "fixed", fixed = {-0.45, -0.5, -0.42, 0.45, 0.38, 0.42}},
		groups = {cracky = 2, pickaxey = 1, not_in_creative_inventory = 0},
		_mcl_hardness = 1,
		_mcl_blast_resistance = 6,
		is_ground_content = false,
		on_construct = function(pos)
			core.get_meta(pos):set_string("infotext", S("@1 bin", bin.label) .. "\n" .. S("Right-click while holding the waste"))
		end,
		on_rightclick = bin_rightclick(bin_id),
	})
end

for _, kind in ipairs({"land", "water"}) do
	core.register_node(MOD .. ":" .. kind .. "_marker", {
		description = kind == "land" and S("Eco-CleanUp: land waste spot")
			or S("Eco-CleanUp: underwater waste spot"),
		drawtype = "nodebox",
		tiles = {MOD .. "_marker_" .. kind .. ".png"},
		use_texture_alpha = "clip",
		inventory_image = MOD .. "_marker_" .. kind .. ".png",
		wield_image = MOD .. "_marker_" .. kind .. ".png",
		paramtype = "light",
		node_box = {type = "fixed", fixed = {-0.45, -0.5, -0.45, 0.45, -0.47, 0.45}},
		selection_box = {type = "fixed", fixed = {-0.45, -0.5, -0.45, 0.45, -0.35, 0.45}},
		walkable = false,
		sunlight_propagates = true,
		buildable_to = false,
		groups = {cracky = 3, pickaxey = 1, dig_immediate = 3},
		is_ground_content = false,
	})
end

-- ============================================================
-- SPAWN SPOTS
-- ============================================================

local function water_node(above)
	local def = core.registered_nodes[above.name]
	if def and def.liquidtype == "source" then return above.name end
	for _, name in ipairs(WATER_SOURCES) do
		if core.registered_nodes[name] then return name end
	end
	return "air"
end

local function sorted_region(arena)
	return vector.sort(arena.pos1, arena.pos2)
end

-- Collects the editor-placed markers and hides them for the match. arena_lib
-- tracks the set_node calls and restores the markers when the map resets.
local function take_markers(arena)
	local p1, p2 = sorted_region(arena)
	local spots = {}
	for _, kind in ipairs({"land", "water"}) do
		for _, pos in ipairs(core.find_nodes_in_area(p1, p2, {MOD .. ":" .. kind .. "_marker"})) do
			local water = kind == "water"
			spots[#spots + 1] = {pos = pos, water = water}
			core.set_node(pos, {name = water and water_node(core.get_node(vector.offset(pos, 0, 1, 0))) or "air"})
		end
	end
	return spots
end

-- Fallback when an arena has no markers: scatter on the topmost walkable
-- surface of random columns (on land or on the sea floor).
local function column_spot(x, z, y_min, y_max)
	for y = y_max - 1, y_min, -1 do
		local node = core.get_node({x = x, y = y, z = z})
		local def = core.registered_nodes[node.name]
		if node.name == "ignore" or not def then return end
		if def.walkable then
			if (def.groups.leaves or 0) > 0 or (def.groups.tree or 0) > 0 then return end
			local above_pos = {x = x, y = y + 1, z = z}
			local above = core.registered_nodes[core.get_node(above_pos).name]
			if not above then return end
			if above.name == "air" then return {pos = above_pos, water = false} end
			if above.liquidtype == "source" or above.liquidtype == "flowing" then
				return {pos = above_pos, water = true}
			end
			return
		end
	end
end

local function scatter_spots(arena, wanted, avoid)
	local p1, p2 = sorted_region(arena)
	local spots, used = {}, {}
	for _ = 1, wanted * 40 do
		if #spots >= wanted then break end
		local x, z = math.random(p1.x, p2.x), math.random(p1.z, p2.z)
		local key = x .. "," .. z
		if not used[key] then
			used[key] = true
			local spot = column_spot(x, z, p1.y, p2.y)
			if spot then
				for _, pos in ipairs(avoid) do
					if vector.distance(pos, spot.pos) < 3 then spot = nil break end
				end
			end
			if spot then spots[#spots + 1] = spot end
		end
	end
	return spots
end

local function shuffle(list)
	for i = #list, 2, -1 do
		local j = math.random(i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

-- ============================================================
-- MINIGAME
-- ============================================================

arena_lib.register_minigame(MOD, {
	name = "Eco-CleanUp",
	description = S("Collect all the waste, on land and underwater, and sort it into the right bins."),
	icon = MOD .. "_bottle.png",
	min_players = 1,
	max_players = 16,
	join_while_in_progress = true,
	keep_inventory = false,
	can_build = false,
	can_drop = false,
	regenerate_map = true,
	eliminate_on_death = false,
	end_when_too_few = false,
	disabled_damage_types = {"drown", "fall"},
	celebration_time = CELEBRATION_TIME,
	properties = {
		waste_amount = 0, -- 0 = automatic (scales with the number of players)
	},
	custom_messages = {
		-- arena_lib translates these with this mod's textdomain.
		celebration_one_player = "Area cleaned up by @1!",
		celebration_more_players = "Area cleaned up by @1!",
		celebration_nobody = "Match over",
	},
	hud_flags = {
		minimap = false,
	},
})

local function finish(arena, match, success, reason)
	if match.finished then return end
	match.finished = true
	match.stopped_us = core.get_us_time()

	local winners = {}
	if success then
		local time = elapsed(match)
		local key = record_key(arena)
		local old = storage:get_float(key)
		local is_record = old <= 0 or time < old
		if is_record then storage:set_float(key, time) end

		for p_name in pairs(arena.players) do
			winners[#winners + 1] = p_name
			local player = core.get_player_by_name(p_name)
			if player then fireworks(player:get_pos()) end
		end
		for _, pos in ipairs(match.bins) do fireworks(pos) end
		sound_all(arena, "mcl_experience_level_up", {gain = 0.8})

		local msg = S("Area 100% clean in @1", format_time(time))
		if match.errors > 0 then
			msg = msg .. "  " .. S("(@1 mistakes, +@2s)", match.errors, match.penalty)
		end
		chat(arena, msg .. "  " .. (is_record and core.colorize("#ffd43b", S("NEW RECORD!")) or
			S("Record: @1", format_time(old))))
		arena_lib.HUD_send_msg_all("broadcast", arena, is_record and S("New arena record!") or msg,
			CELEBRATION_TIME, nil, is_record and 0xffd43b or 0x8fe388)
	elseif reason then
		chat(arena, core.colorize("#ff8a7a", reason))
	end

	for p_name in pairs(arena.players) do
		hud_update_player(arena, match, p_name)
		hud_clear_waypoints(p_name)
	end
	arena_lib.load_celebration(MOD, arena, winners)
end

arena_lib.on_start(MOD, function(arena)
	serial = serial + 1
	local match = {
		token = tostring(core.get_us_time()) .. ":" .. serial,
		started_us = core.get_us_time(),
		penalty = 0,
		errors = 0,
		total = 0,
		deposited = 0,
		next_id = 0,
		waste = {},
		labels = {},
		bins = {},
		spots = {},
		carried = {},
		death_items = {},
		seen_facts = {},
	}
	match.finish = function(success, reason) finish(arena, match, success, reason) end
	matches[arena.name] = match

	for p_name in pairs(arena.players) do
		match.carried[p_name] = {}
	end

	if not arena.pos1 or not arena.pos2 then
		core.log("warning", "[skyss_cleanup] Arena " .. arena.name .. " has no region")
		match.finish(false, S("The arena has no region: tell your teacher."))
		return
	end

	local p1, p2 = sorted_region(arena)
	core.load_area(p1, p2)

	-- Bins: one of each kind is required, each gets a floating label.
	local missing = {}
	for _, bin_id in ipairs(BIN_ORDER) do
		local found = core.find_nodes_in_area(p1, p2, {MOD .. ":bin_" .. bin_id})
		if #found == 0 then missing[#missing + 1] = BINS[bin_id].label end
		for _, pos in ipairs(found) do
			match.bins[#match.bins + 1] = pos
			core.add_entity(vector.offset(pos, 0, 0.9, 0), MOD .. ":bin_label",
				core.serialize({arena = arena.name, token = match.token, bin = bin_id}))
		end
	end
	if #missing > 0 then
		core.log("warning", "[skyss_cleanup] Arena " .. arena.name .. " is missing bins: " .. table.concat(missing, ", "))
		match.finish(false, S("Bins are missing from the arena (@1): tell your teacher.", table.concat(missing, ", ")))
		return
	end

	local players = 0
	for _ in pairs(arena.players) do players = players + 1 end
	local wanted = arena.waste_amount and arena.waste_amount > 0 and arena.waste_amount
		or math.min(WASTE_MAX, WASTE_BASE + WASTE_PER_PLAYER * players)

	match.spots = take_markers(arena)
	if #match.spots == 0 then
		match.spots = scatter_spots(arena, wanted, match.bins)
	end
	shuffle(match.spots)

	for i = 1, math.min(wanted, #match.spots) do
		spawn_waste(arena, match, match.spots[i], pick_kind())
	end
	match.total = count_ground(match)
	if match.total == 0 then
		core.log("warning", "[skyss_cleanup] Arena " .. arena.name .. " has no usable spawn spots")
		match.finish(false, S("There is nowhere to scatter the waste: tell your teacher."))
		return
	end

	for p_name in pairs(arena.players) do
		local player = core.get_player_by_name(p_name)
		if player then
			give_fork(player)
			hud_create(player)
		end
	end
	hud_update_all(arena, match)

	arena_lib.HUD_send_msg_all("title", arena, S("Clean up the area!"), 3, nil, 0x8fe388)
	local bin_names = {}
	for _, bin_id in ipairs(BIN_ORDER) do
		local bin = BINS[bin_id]
		bin_names[#bin_names + 1] = core.colorize(bin.color, S("@1 = @2", bin.colour_name, bin.label))
	end
	chat(arena, S("There are @1 pieces of waste around. Hit them with the pitchfork, then hold them and right-click the right bin: @2. Every mistake costs +@3 seconds!",
		match.total, table.concat(bin_names, ", "), WRONG_BIN_PENALTY))
end)

arena_lib.on_join(MOD, function(p_name, arena, as_spectator)
	local match = get_match(arena)
	if as_spectator or not playing(match) then return end
	match.carried[p_name] = match.carried[p_name] or {}
	local player = core.get_player_by_name(p_name)
	if player then
		give_fork(player)
		hud_create(player)
	end
	hud_update_all(arena, match)
	chat(arena, S("@1 joins the clean-up crew!", p_name))
end)

arena_lib.on_respawn(MOD, function(arena, p_name)
	local match = get_match(arena)
	local player = core.get_player_by_name(p_name)
	if not playing(match) or not player then return end
	local inv = player:get_inventory()
	give_fork(player)
	for _, stack in ipairs(match.death_items[p_name] or {}) do
		inv:add_item("main", stack)
	end
	match.death_items[p_name] = nil
end)

arena_lib.on_quit(MOD, function(arena, p_name, is_spectator)
	local match = get_match(arena)
	local player = core.get_player_by_name(p_name)
	if player then
		hud_remove(player)
		if match then remove_round_items(player, match.token) end
	end
	if is_spectator or not playing(match) then return end

	-- Whatever the player carried goes back into the world.
	local respawned = 0
	for kind, count in pairs(match.carried[p_name] or {}) do
		for _ = 1, count do
			if #match.spots > 0 and spawn_waste(arena, match, match.spots[math.random(#match.spots)], kind) then
				respawned = respawned + 1
			end
		end
	end
	match.carried[p_name] = nil
	match.death_items[p_name] = nil
	if respawned > 0 then
		chat(arena, S("@1 left the match: @2 pieces of waste are back on the ground.", p_name, respawned))
	end
	hud_update_all(arena, match)
end)

arena_lib.on_celebration(MOD, function(arena)
	local match = get_match(arena)
	if not match then return end
	if not match.finished then
		match.finished = true
		match.stopped_us = core.get_us_time()
	end
	for _, rec in pairs(match.waste) do
		if rec.obj and rec.obj:get_pos() then rec.obj:remove() end
	end
	for p_name in pairs(arena.players) do
		hud_clear_waypoints(p_name)
		local player = core.get_player_by_name(p_name)
		if player then remove_round_items(player, match.token) end
	end
end)

arena_lib.on_end(MOD, function(arena, winners, is_forced)
	local match = matches[arena.name]
	if not match then return end
	for _, rec in pairs(match.waste) do
		if rec.obj and rec.obj:get_pos() then rec.obj:remove() end
	end
	for _, obj in ipairs(match.labels) do
		if obj:get_pos() then obj:remove() end
	end
	for p_name in pairs(arena.players or {}) do
		local player = core.get_player_by_name(p_name)
		if player then
			hud_remove(player)
			remove_round_items(player, match.token)
		end
	end
	matches[arena.name] = nil
end)

-- Once per second: timer, waypoints and full breath for underwater arenas.
local tick = 0
core.register_globalstep(function(dtime)
	tick = tick + dtime
	if tick < 1 then return end
	tick = 0
	for name, match in pairs(matches) do
		local _, arena = arena_lib.get_arena_by_name(MOD, name)
		if arena and arena.in_game and playing(match) then
			for p_name in pairs(arena.players) do
				local player = core.get_player_by_name(p_name)
				if player then
					player:set_breath(player:get_properties().breath_max or 10)
					local h = huds[p_name]
					if h then player:hud_change(h.timer, "text", format_time(elapsed(match))) end
				end
			end
		end
	end
end)

core.register_on_leaveplayer(function(player)
	huds[player:get_player_name()] = nil
end)

core.log("action", "[skyss_cleanup] Game mod loaded")
