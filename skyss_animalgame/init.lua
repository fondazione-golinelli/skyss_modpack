local MOD = "skyss_animalgame"
local S = core.get_translator(MOD)
local TAG = "[Animal Sounds] "

-- ============================================================
-- CONFIGURATION
-- ============================================================

local LIVES = 3                  -- mistakes (wrong answers or timeouts) allowed
local INITIAL_TIME = 10          -- seconds to answer, shrinking as the score grows
local MIN_TIME = 4
local SCORE_PER_SECOND = 2       -- one second less every this many points
local LISTEN_TIME = 3            -- listening moment before the countdown
local SOUND_DELAY = 0.5
local NEXT_DELAY = 1.5           -- pause after a correct answer
local REVEAL_TIME = 3            -- pause showing the right animal after a mistake
local CELEBRATION_TIME = 8

-- Stage layout, relative to the first spawn point and its facing.
local STAGE_DISTANCE = 5
local STATION_OFFSETS = {-5, -2, 2, 5}
local ANIMAL_MAX_HEIGHT = 1.3    -- big animals are shrunk to this height
local ANIMAL_MIN_HEIGHT = 0.45   -- tiny ones are enlarged up to this height
local ANIMAL_MAX_SCALE = 2

local hud_type = core.features.hud_def_type_field and "type" or "hud_elem_type"
local storage = core.get_mod_storage()
local has_mcl_bells = core.get_modpath("mcl_bells") ~= nil

-- Quiz-show colours, one per answer podium.
local STATIONS = {
	{color = "#e5484d", hex = 0xe5484d},
	{color = "#3e8ed0", hex = 0x3e8ed0},
	{color = "#f2c230", hex = 0xf2c230},
	{color = "#46a758", hex = 0x46a758},
}

-- `entity` provides the 3D model; `textures` overrides mobs whose skin is
-- picked at runtime; `icon` is the flat fallback when the model is missing.
-- `height` is the real model height in nodes, measured with
-- tools/measure_models.py: animalworld collision boxes are often far smaller
-- than the mesh (koala 0.2 vs 0.74). Without it the collision box is used.
local ANIMALS = {
	{id = "pig", name = S("Pig"), entity = "mobs_mc:pig", sound = "mobs_pig", icon = "mobs_mc_spawn_icon_pig.png"},
	{id = "cow", name = S("Cow"), entity = "mobs_mc:cow", sound = "mobs_mc_cow", icon = "mobs_mc_spawn_icon_cow.png"},
	{id = "sheep", name = S("Sheep"), entity = "mobs_mc:sheep", sound = "mobs_sheep", icon = "mobs_mc_spawn_icon_sheep.png"},
	{id = "chicken", name = S("Chicken"), entity = "mobs_mc:chicken", sound = "mobs_mc_chicken_buck", icon = "mobs_mc_spawn_icon_chicken.png"},
	{id = "horse", name = S("Horse"), entity = "mobs_mc:horse", sound = "mobs_mc_horse_random", icon = "mobs_mc_spawn_icon_horse.png"},
	{id = "cat", name = S("Cat"), entity = "mobs_mc:cat", sound = "mobs_mc_cat_idle", icon = "mobs_mc_spawn_icon_cat.png",
		textures = {"mobs_mc_cat_tabby.png"}},
	{id = "wolf", name = S("Wolf"), entity = "mobs_mc:wolf", sound = "mobs_mc_wolf_bark", icon = "mobs_mc_spawn_icon_wolf.png",
		textures = {"mobs_mc_wolf.png", "blank.png", "blank.png"}},
	{id = "bear", name = S("Bear"), entity = "animalworld:bear", sound = "animalworld_bear", icon = "abear.png", height = 1.21},
	{id = "boar", name = S("Boar"), entity = "animalworld:boar", sound = "animalworld_boar", icon = "aboar.png", height = 1.20},
	{id = "camel", name = S("Camel"), entity = "animalworld:camel", sound = "animalworld_camel", icon = "acamel.png", height = 2.19},
	{id = "crocodile", name = S("Crocodile"), entity = "animalworld:crocodile", sound = "animalworld_crocodile", icon = "acrocodile.png", height = 0.41},
	{id = "elephant", name = S("Elephant"), entity = "animalworld:elephant", sound = "animalworld_elephant", icon = "aelephant.png", height = 2.64},
	{id = "fox", name = S("Fox"), entity = "animalworld:fox", sound = "animalworld_fox", icon = "afox.png", height = 0.80},
	{id = "frog", name = S("Frog"), entity = "animalworld:frog", sound = "animalworld_frog", icon = "afrog.png", height = 0.27},
	{id = "goose", name = S("Goose"), entity = "animalworld:goose", sound = "animalworld_goose", icon = "agoose.png", height = 0.76},
	{id = "hyena", name = S("Hyena"), entity = "animalworld:hyena", sound = "animalworld_hyena", icon = "ahyena.png", height = 0.90},
	{id = "koala", name = S("Koala"), entity = "animalworld:koala", sound = "animalworld_koala", icon = "akoala.png", height = 0.74},
	{id = "marmot", name = S("Marmot"), entity = "animalworld:marmot", sound = "animalworld_marmot", icon = "amarmot.png", height = 0.38},
	{id = "monkey", name = S("Monkey"), entity = "animalworld:monkey", sound = "animalworld_monkey", icon = "amonkey.png", height = 0.85},
	{id = "moose", name = S("Moose"), entity = "animalworld:moose", sound = "animalworld_moose", icon = "amoose.png", height = 1.86},
	{id = "otter", name = S("Otter"), entity = "animalworld:otter", sound = "animalworld_otter", icon = "aotter.png", height = 0.39},
	{id = "owl", name = S("Owl"), entity = "animalworld:owl", sound = "animalworld_owl", icon = "aowl.png", height = 0.72},
	{id = "seal", name = S("Seal"), entity = "animalworld:seal", sound = "animalworld_seal", icon = "aseal.png", height = 0.52},
	{id = "stellerseagle", name = S("Steller's sea eagle"), entity = "animalworld:stellerseagle", sound = "animalworld_stellerseagle", icon = "astellerseagle.png", height = 1.14},
	{id = "tapir", name = S("Tapir"), entity = "animalworld:tapir", sound = "animalworld_tapir", icon = "atapir.png", height = 1.16},
	{id = "tiger", name = S("Tiger"), entity = "animalworld:tiger", sound = "animalworld_tiger", icon = "atiger.png", height = 1.25},
	{id = "yak", name = S("Yak"), entity = "animalworld:yak", sound = "animalworld_yak", icon = "ayak.png", height = 1.23},
	{id = "zebra", name = S("Zebra"), entity = "animalworld:zebra", sound = "animalworld_zebra", icon = "azebra.png", height = 1.75},
}

local available = {}
for _, animal in ipairs(ANIMALS) do
	if core.get_modpath(animal.entity:match("^(.-):")) then
		available[#available + 1] = animal
	end
end

-- ============================================================
-- STATE
-- ============================================================

-- Runtime match state, keyed by arena name: entities and callbacks must not
-- end up in the persisted arena table.
local matches = {}
local huds = {}

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

local function answering(match)
	return match and (match.state == "listen" or match.state == "answer")
end

local function shuffle(list)
	for i = #list, 2, -1 do
		local j = math.random(i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

local function round_time(match)
	return math.max(MIN_TIME, INITIAL_TIME - math.floor(match.score / SCORE_PER_SECOND))
end

local function time_left(match)
	if match.state ~= "answer" then return match.round_time end
	return math.max(0, (match.deadline_us - core.get_us_time()) / 1000000)
end

local function record_key(arena)
	return "record:" .. arena.name
end

local function chat(arena, message)
	for p_name in pairs(arena.players) do
		core.chat_send_player(p_name, core.colorize("#ffb347", TAG) .. message)
	end
end

local function sound_all(arena, name, params)
	for p_name in pairs(arena.players) do
		local p = table.copy(params or {})
		p.to_player = p_name
		p.gain = p.gain or 0.7
		core.sound_play(name, p, true)
	end
end

local function title_all(arena, text, duration, color)
	for p_name in pairs(arena.players) do
		arena_lib.HUD_send_msg("title", p_name, text, duration, nil, color or 0xffffff)
	end
end

-- ============================================================
-- ANIMAL MODELS
-- ============================================================

-- Reads mesh, skin and idle animation from the registered mob. Animals keep
-- their natural size, except big ones (shrunk to fit the stage) and tiny ones
-- (enlarged so they can still be seen and clicked).
local models = {}

local function resolve_model(animal)
	local def = core.registered_entities[animal.entity]
	local props = def and def.initial_properties
	if not props or props.visual ~= "mesh" or not props.mesh then return end

	local textures = animal.textures
	if not textures then
		local list = def.texture_list
		if type(list) == "table" and list[1] then
			textures = type(list[1]) == "table" and list[1] or list
		end
	end
	if type(textures) ~= "table" or not textures[1] then return end

	local cb = props.collisionbox or {-0.5, 0, -0.5, 0.5, 1, 0.5}
	local height = animal.height or math.max(0.1, cb[5] - cb[2])
	local k = math.min(1, ANIMAL_MAX_HEIGHT / height)
	if height < ANIMAL_MIN_HEIGHT then
		k = math.min(ANIMAL_MAX_SCALE, ANIMAL_MIN_HEIGHT / height)
	end
	local size = props.visual_size or {x = 1, y = 1}
	local anim = def.animation or {}

	return {
		mesh = props.mesh,
		textures = table.copy(textures),
		visual_size = {x = size.x * k, y = size.y * k, z = (size.z or size.x) * k},
		height = height * k,
		lift = -cb[2] * k,
		stand = {x = anim.stand_start or 0, y = anim.stand_end or 0},
		stand_speed = anim.stand_speed or anim.speed_normal or 15,
		walk = anim.walk_start and {x = anim.walk_start, y = anim.walk_end or anim.walk_start},
		walk_speed = anim.walk_speed or anim.speed_normal or 15,
	}
end

core.register_on_mods_loaded(function()
	for _, animal in ipairs(available) do
		models[animal.id] = resolve_model(animal)
	end
end)

-- ============================================================
-- HUD
-- ============================================================

-- Anchored to the top-right corner, clear of the chat on the left.
local PANEL_MARGIN, PANEL_Y, PANEL_W, PANEL_H = 16, 16, 300, 176
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
	local h = {all = {}}

	hud_add(player, h, "image", 0, 0, {text = fill("#1d160dd8"), scale = {x = PANEL_W, y = PANEL_H}, z_index = 899})
	hud_add(player, h, "image", 0, 0, {text = fill("#ffb347"), scale = {x = PANEL_W, y = 4}})
	hud_add(player, h, "text", 14, 14, {text = S("ANIMAL SOUNDS"), number = 0xffc978, style = 1})
	h.round = hud_add(player, h, "text", PANEL_W - 14, 14, {text = "", number = 0xd9cbb5, alignment = {x = -1, y = 1}})

	hud_add(player, h, "text", 14, 42, {text = S("Score"), number = 0xe8dccb})
	h.score = hud_add(player, h, "text", PANEL_W - 14, 40, {text = "0", number = 0xffffff, style = 1, size = {x = 2, y = 2}, alignment = {x = -1, y = 1}})

	h.hearts = {}
	for i = 1, LIVES do
		h.hearts[i] = hud_add(player, h, "image", 14 + (i - 1) * 24, 78, {text = MOD .. "_heart.png", scale = {x = 2.25, y = 2.25}})
	end
	h.streak = hud_add(player, h, "text", PANEL_W - 14, 80, {text = "", number = 0xffc978, alignment = {x = -1, y = 1}})

	hud_add(player, h, "image", 14, 108, {text = fill("#ffffff30"), scale = {x = BAR_W, y = 1}})
	h.time_label = hud_add(player, h, "text", 14, 116, {text = "", number = 0xe8dccb})
	h.time = hud_add(player, h, "text", PANEL_W - 14, 116, {text = "", number = 0xffffff, style = 5, alignment = {x = -1, y = 1}})
	hud_add(player, h, "image", 14, 138, {text = fill("#3a2f22"), scale = {x = BAR_W, y = 10}})
	h.bar = hud_add(player, h, "image", 14, 138, {text = "", scale = {x = 1, y = 10}, z_index = 901})
	h.footer = hud_add(player, h, "text", 14, 154, {text = "", number = 0xb8a990})

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
	huds[p_name] = nil
end

-- Green while there is time, then yellow and red.
local function bar_color(frac)
	if frac > 0.5 then return "#5fd36a" end
	if frac > 0.25 then return "#f2c230" end
	return "#ff5a4f"
end

local function hud_update_timer(match, player, h)
	local frac, label, value
	if match.state == "answer" then
		local left = time_left(match)
		frac = left / match.round_time
		label = S("Time")
		value = string.format("%.1fs", left)
	elseif match.state == "listen" then
		frac = 1
		label = S("Listen...")
		value = match.round_time .. "s"
	else
		frac = 0
		label = ""
		value = ""
	end
	player:hud_change(h.time_label, "text", label)
	player:hud_change(h.time, "text", value)
	player:hud_change(h.time, "number", frac > 0.25 and 0xffffff or 0xff8a7a)
	if frac > 0 then
		player:hud_change(h.bar, "text", fill(bar_color(frac)))
		player:hud_change(h.bar, "scale", {x = math.max(1, math.floor(BAR_W * frac)), y = 10})
	else
		player:hud_change(h.bar, "text", "")
	end
end

local function hud_update_player(arena, match, p_name)
	local player = core.get_player_by_name(p_name)
	if not player then return end
	local h = hud_create(player)

	player:hud_change(h.round, "text", match.round > 0 and S("Round @1", match.round) or "")
	player:hud_change(h.score, "text", tostring(match.score))
	for i, id in ipairs(h.hearts) do
		player:hud_change(id, "text", MOD .. (i <= match.lives and "_heart.png" or "_heart_empty.png"))
	end
	player:hud_change(h.streak, "text", match.streak >= 2 and S("Streak x@1", match.streak) or "")

	local record = storage:get_int(record_key(arena))
	player:hud_change(h.footer, "text", S("Record: @1", record > 0 and record or "-")
		.. "     " .. S("Best streak: @1", match.best_streak))
	hud_update_timer(match, player, h)
end

local function hud_update_all(arena, match)
	for p_name in pairs(arena.players) do
		hud_update_player(arena, match, p_name)
	end
end

-- ============================================================
-- EFFECTS
-- ============================================================

local function burst(pos, color, amount, texture)
	core.add_particlespawner({
		amount = amount or 20,
		time = 0.1,
		minpos = vector.offset(pos, -0.4, 0, -0.4),
		maxpos = vector.offset(pos, 0.4, 0.6, 0.4),
		minvel = {x = -1.8, y = 1.5, z = -1.8},
		maxvel = {x = 1.8, y = 4, z = 1.8},
		minacc = {x = 0, y = -6, z = 0},
		maxacc = {x = 0, y = -6, z = 0},
		minexptime = 0.5,
		maxexptime = 1,
		minsize = 1.5,
		maxsize = 3,
		texture = MOD .. "_" .. (texture or "sparkle") .. ".png^[multiply:" .. color,
		glow = 12,
	})
end

local function puff(pos)
	core.add_particlespawner({
		amount = 16,
		time = 0.15,
		minpos = vector.offset(pos, -0.4, 0, -0.4),
		maxpos = vector.offset(pos, 0.4, 0.8, 0.4),
		minvel = {x = -0.6, y = 0.4, z = -0.6},
		maxvel = {x = 0.6, y = 1.2, z = 0.6},
		minexptime = 0.6,
		maxexptime = 1.2,
		minsize = 3,
		maxsize = 5,
		texture = MOD .. "_puff.png^[multiply:#8a8f94",
	})
end

-- Music notes rising from the bell while the sound plays.
local function notes(pos, seconds)
	core.add_particlespawner({
		amount = math.floor(6 * seconds),
		time = seconds,
		minpos = vector.offset(pos, -0.3, 0.2, -0.3),
		maxpos = vector.offset(pos, 0.3, 0.5, 0.3),
		minvel = {x = -0.4, y = 0.8, z = -0.4},
		maxvel = {x = 0.4, y = 1.4, z = 0.4},
		minexptime = 1,
		maxexptime = 1.6,
		minsize = 2,
		maxsize = 3,
		texture = MOD .. "_note.png^[multiply:#ffc978",
		glow = 10,
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
			core.sound_play("mcl_bows_firework", {pos = center, gain = 0.5, max_hear_distance = 48}, true)
		end)
	end
end

-- ============================================================
-- ENTITIES
-- ============================================================

local on_answer, on_replay

local function nametag(obj, text, bg)
	obj:set_properties({
		nametag = text,
		nametag_color = "#ffffff",
		nametag_bgcolor = bg .. "e0",
	})
end

core.register_entity(MOD .. ":animal", {
	initial_properties = {
		physical = false,
		collide_with_objects = false,
		pointable = true,
		static_save = false,
		visual = "sprite",
		textures = {"blank.png"},
		selectionbox = {-0.6, 0, -0.6, 0.6, 1, 0.6},
	},

	on_activate = function(self, staticdata)
		local data = core.deserialize(staticdata or "") or {}
		local match = matches[data.arena or ""]
		local animal = match and match.token == data.token and match.options and match.options[data.slot or 0]
		if not animal then
			self.object:remove()
			return
		end
		self.arena_name, self.token, self.slot = data.arena, data.token, data.slot
		self.object:set_armor_groups({immortal = 1})

		local model = models[animal.id]
		local top
		if model then
			top = model.height
			self.object:set_properties({
				visual = "mesh",
				mesh = model.mesh,
				textures = model.textures,
				visual_size = model.visual_size,
				backface_culling = false,
			})
			self.object:set_animation(model.stand, model.stand_speed, 0, true)
		else
			-- Flat spawn-egg style icon when the mob model is unavailable.
			top = 1.25
			self.object:set_properties({
				visual = "sprite",
				textures = {animal.icon},
				visual_size = {x = 1.25, y = 1.25},
			})
		end
		local box_top = math.max(0.9, top)
		local box = {-0.6, 0, -0.6, 0.6, box_top, 0.6}
		if not model then
			box = {-0.6, -0.625, -0.1, 0.6, 0.625, 0.1}
		end
		self.object:set_properties({selectionbox = box, collisionbox = box})
		nametag(self.object, animal.name, STATIONS[data.slot].color)
	end,

	on_rightclick = function(self, clicker)
		on_answer(clicker, self)
	end,

	on_punch = function(self, puncher)
		on_answer(puncher, self)
		return true
	end,
})

core.register_entity(MOD .. ":bell", {
	initial_properties = {
		physical = false,
		collide_with_objects = false,
		pointable = true,
		static_save = false,
		visual = "sprite",
		visual_size = {x = 0.8, y = 0.8},
		textures = {MOD .. "_bell.png"},
		selectionbox = {-0.45, -0.5, -0.45, 0.45, 0.45, 0.45},
		nametag = "",
	},

	on_activate = function(self, staticdata)
		local data = core.deserialize(staticdata or "") or {}
		local match = matches[data.arena or ""]
		if not match or match.token ~= data.token then
			self.object:remove()
			return
		end
		self.arena_name, self.token = data.arena, data.token
		self.object:set_armor_groups({immortal = 1})
		if has_mcl_bells then
			self.object:set_properties({
				visual = "mesh",
				mesh = "mcl_bells_bell.b3d",
				textures = {"mcl_bells_bell_uv_bell.png"},
				visual_size = {x = 1, y = 1},
			})
			self.object:set_animation({x = 195, y = 195})
		end
		nametag(self.object, S("Listen again"), "#7a4a12")
	end,

	ring = function(self)
		if has_mcl_bells then
			self.object:set_animation({x = 1, y = 195}, 240, 0, false)
		end
	end,

	on_rightclick = function(self, clicker)
		on_replay(clicker, self)
	end,

	on_punch = function(self, puncher)
		on_replay(puncher, self)
		return true
	end,
})

-- ============================================================
-- PODIUMS
-- ============================================================

local function podium_click(pos, clicker)
	local match = match_of_player(clicker)
	if not match then return end
	for _, station in ipairs(match.stations) do
		if vector.equals(station.pos, pos) then
			local ent = station.obj and station.obj:get_luaentity()
			if ent then on_answer(clicker, ent) end
			return
		end
	end
	if match.bell_pos and vector.equals(match.bell_pos, pos) then
		local ent = match.bell and match.bell:get_luaentity()
		if ent then on_replay(clicker, ent) end
	end
end

local function register_podium(name, color)
	local side = MOD .. "_podium_side.png"
	local top = MOD .. "_podium_top.png"
	if color then
		side = side .. "^(" .. MOD .. "_podium_band.png^[multiply:" .. color .. ")"
		top = top .. "^(" .. MOD .. "_podium_ring.png^[multiply:" .. color .. ")"
	end
	core.register_node(MOD .. ":" .. name, {
		description = S("Animal Sounds podium"),
		tiles = {top, MOD .. "_podium_top.png", side},
		paramtype = "light",
		groups = {not_in_creative_inventory = 1},
		is_ground_content = false,
		diggable = false,
		drop = "",
		on_rightclick = function(pos, node, clicker)
			podium_click(pos, clicker)
		end,
		on_punch = function(pos, node, puncher)
			podium_click(pos, puncher)
		end,
	})
end

register_podium("podium_bell")
for i, station in ipairs(STATIONS) do
	register_podium("podium_" .. i, station.color)
end

-- The stage is built in front of the first spawn point, facing it, and
-- stays for the whole match: only the animals change between questions.
local function stage_anchor(arena)
	local spawn = arena.spawn_points and arena.spawn_points[1]
	local pos, yaw
	if spawn and spawn.pos then
		pos = spawn.pos
		yaw = math.rad(spawn.rot and spawn.rot.x or 0)
	else
		local p_name = next(arena.players)
		local player = p_name and core.get_player_by_name(p_name)
		if not player then return end
		pos = player:get_pos()
		yaw = player:get_look_horizontal()
	end
	local look = {x = -math.sin(yaw), z = math.cos(yaw)}
	local forward
	if math.abs(look.x) > math.abs(look.z) then
		forward = {x = look.x >= 0 and 1 or -1, y = 0, z = 0}
	else
		forward = {x = 0, y = 0, z = look.z >= 0 and 1 or -1}
	end
	return vector.new(pos.x, pos.y, pos.z), forward
end

local function stage_pos(origin, forward, offset)
	local right = {x = forward.z, y = 0, z = -forward.x}
	local p = vector.add(origin, vector.add(vector.multiply(forward, STAGE_DISTANCE), vector.multiply(right, offset)))
	return {x = math.floor(p.x + 0.5), y = math.floor(origin.y + 0.5), z = math.floor(p.z + 0.5)}
end

local function place_node(match, pos, name)
	match.placed[#match.placed + 1] = {pos = pos, node = core.get_node(pos)}
	core.set_node(pos, {name = name})
end

local function build_stage(arena, match)
	local origin, forward = stage_anchor(arena)
	if not origin then return false end
	match.origin = origin
	for i, offset in ipairs(STATION_OFFSETS) do
		local pos = stage_pos(origin, forward, offset)
		core.load_area(pos)
		place_node(match, pos, MOD .. ":podium_" .. i)
		match.stations[i] = {pos = pos}
	end
	match.bell_pos = stage_pos(origin, forward, 0)
	place_node(match, match.bell_pos, MOD .. ":podium_bell")
	match.bell = core.add_entity(vector.offset(match.bell_pos, 0, 1, 0), MOD .. ":bell",
		core.serialize({arena = arena.name, token = match.token}))
	return true
end

local function remove_animals(match)
	for _, station in ipairs(match.stations) do
		if station.obj and station.obj:get_pos() then station.obj:remove() end
		station.obj = nil
	end
end

local function remove_stage(match)
	remove_animals(match)
	if match.bell and match.bell:get_pos() then match.bell:remove() end
	match.bell = nil
	-- Restore in reverse so overlapping placements end up as the original.
	for i = #match.placed, 1, -1 do
		local rec = match.placed[i]
		if core.get_node(rec.pos).name:sub(1, #MOD + 1) == MOD .. ":" then
			core.set_node(rec.pos, rec.node)
		end
	end
	match.placed = {}
end

local function spawn_animal(arena, match, slot)
	local station = match.stations[slot]
	local animal = match.options[slot]
	local model = models[animal.id]
	local pos = vector.offset(station.pos, 0, 0.5 + (model and model.lift or 0.65), 0)
	local obj = core.add_entity(pos, MOD .. ":animal",
		core.serialize({arena = arena.name, token = match.token, slot = slot}))
	if obj then
		obj:set_yaw(core.dir_to_yaw(vector.direction(station.pos, match.origin)))
		burst(vector.offset(station.pos, 0, 0.5, 0), STATIONS[slot].color, 10)
	end
	station.obj = obj
	station.rest = pos
end

-- A happy hop and a quick walk cycle for the right animal.
local function celebrate_animal(match, slot)
	local station = match.stations[slot]
	local obj = station.obj
	if not obj or not obj:get_pos() then return end
	local model = models[match.options[slot].id]
	if model and model.walk then
		obj:set_animation(model.walk, model.walk_speed * 1.5, 0, true)
	end
	obj:move_to(vector.offset(station.rest, 0, 0.5, 0), true)
	core.after(0.25, function()
		if obj:get_pos() then obj:move_to(station.rest, true) end
	end)
	core.add_particlespawner({
		amount = 24,
		time = REVEAL_TIME,
		attached = obj,
		minpos = {x = -0.5, y = 0, z = -0.5},
		maxpos = {x = 0.5, y = 1.2, z = 0.5},
		minvel = {x = 0, y = 0.4, z = 0},
		maxvel = {x = 0, y = 1, z = 0},
		minexptime = 0.6,
		maxexptime = 1.2,
		minsize = 1.5,
		maxsize = 2.5,
		texture = MOD .. "_sparkle.png^[multiply:#ffd43b",
		glow = 12,
	})
end

-- ============================================================
-- GAME FLOW
-- ============================================================

arena_lib.register_minigame(MOD, {
	name = "Animal Sounds",
	description = S("Listen to the sound and pick the right animal."),
	icon = MOD .. "_icon.png",
	min_players = 1,
	max_players = 1,
	keep_inventory = false,
	can_build = false,
	can_drop = false,
	disable_inventory = true,
	regenerate_map = true,
	eliminate_on_death = false,
	end_when_too_few = false,
	celebration_time = CELEBRATION_TIME,
	custom_messages = {
		-- arena_lib translates these with this mod's textdomain.
		celebration_one_player = "Well done, @1!",
		celebration_nobody = "Game over",
	},
	hud_flags = {
		hotbar = false,
		healthbar = false,
		breathbar = false,
		minimap = false,
	},
})

local begin_question

local function draw_animal(match)
	if #match.deck == 0 then
		for _, animal in ipairs(available) do match.deck[#match.deck + 1] = animal end
		shuffle(match.deck)
		-- Never the same animal twice in a row across reshuffles.
		if match.last and #match.deck > 1 and match.deck[#match.deck].id == match.last then
			match.deck[1], match.deck[#match.deck] = match.deck[#match.deck], match.deck[1]
		end
	end
	local animal = table.remove(match.deck)
	match.last = animal.id
	return animal
end

local function choose_options(match)
	local correct = draw_animal(match)
	local pool = {}
	for _, animal in ipairs(available) do
		if animal.id ~= correct.id then pool[#pool + 1] = animal end
	end
	shuffle(pool)
	local options = {correct, pool[1], pool[2], pool[3]}
	shuffle(options)
	for slot, animal in ipairs(options) do
		if animal == correct then return options, slot end
	end
end

local function play_animal(arena, match)
	if not match.options then return end
	sound_all(arena, match.options[match.correct_slot].sound, {gain = 1})
	if match.bell_pos then notes(vector.offset(match.bell_pos, 0, 1.2, 0), 1.5) end
end

local function game_over(arena, match)
	match.state = "over"
	match.token = match.token .. "!"
	local key = record_key(arena)
	local old = storage:get_int(key)
	local is_record = match.score > old
	if is_record then storage:set_int(key, match.score) end

	local winners = {}
	for p_name in pairs(arena.players) do
		winners[#winners + 1] = p_name
		if is_record and match.score > 0 then
			local player = core.get_player_by_name(p_name)
			if player then fireworks(player:get_pos()) end
		end
	end

	local msg = S("Final score: @1", match.score)
	if match.best_streak >= 2 then
		msg = msg .. "  " .. S("Best streak: @1", match.best_streak)
	end
	if is_record and match.score > 0 then
		chat(arena, msg .. "  " .. core.colorize("#ffd43b", S("NEW RECORD!")))
		sound_all(arena, "mcl_experience_level_up", {gain = 0.8})
	else
		chat(arena, msg .. "  " .. S("Record: @1", old))
		sound_all(arena, "mcl_experience", {gain = 0.5, pitch = 0.7})
	end
	arena_lib.HUD_send_msg_all("broadcast", arena,
		(is_record and match.score > 0) and S("New record: @1!", match.score) or S("Final score: @1", match.score),
		CELEBRATION_TIME, nil, (is_record and match.score > 0) and 0xffd43b or 0xffc978)

	hud_update_all(arena, match)
	arena_lib.load_celebration(MOD, arena, winners)
end

-- After a correct answer, a wrong one or a timeout.
local function resolve(arena, match, picked_slot)
	match.state = "reveal"
	local token = match.token
	local correct_slot = match.correct_slot
	local correct = match.options[correct_slot]
	local correct_station = match.stations[correct_slot]

	if picked_slot == correct_slot then
		match.score = match.score + 1
		match.streak = match.streak + 1
		match.best_streak = math.max(match.best_streak, match.streak)
		local station = match.stations[picked_slot]
		burst(vector.offset(station.pos, 0, 1, 0), STATIONS[picked_slot].color, 24)
		burst(vector.offset(station.pos, 0, 1, 0), "#ffffff", 12)
		celebrate_animal(match, picked_slot)
		if station.obj then nametag(station.obj, correct.name, "#2f9e44") end
		sound_all(arena, "mcl_experience", {gain = 0.6, pitch = 1 + math.min(match.streak, 8) * 0.04})
		local praise = match.streak >= 3 and S("Correct! @1 in a row!", match.streak) or S("Correct!")
		title_all(arena, praise, NEXT_DELAY, 0x7be08a)
	else
		match.lives = match.lives - 1
		match.streak = 0
		if picked_slot then
			local station = match.stations[picked_slot]
			puff(vector.offset(station.pos, 0, 0.6, 0))
			if station.obj then nametag(station.obj, match.options[picked_slot].name, "#8a2424") end
			title_all(arena, S("Wrong!"), REVEAL_TIME, 0xff6b5a)
			chat(arena, S("The right answer was @1 (you picked @2).",
				core.colorize("#7be08a", correct.name), match.options[picked_slot].name))
		else
			title_all(arena, S("Time is up!"), REVEAL_TIME, 0xff6b5a)
			chat(arena, S("Time is up! The right answer was @1.", core.colorize("#7be08a", correct.name)))
		end
		sound_all(arena, "default_place_node_hard", {gain = 0.8, pitch = 0.6})
		-- Highlight the right one and let the player hear it once more.
		for slot, station in ipairs(match.stations) do
			if slot ~= correct_slot and slot ~= picked_slot and station.obj then
				nametag(station.obj, match.options[slot].name, "#3a3f44")
			end
		end
		if correct_station.obj then nametag(correct_station.obj, correct.name, "#2f9e44") end
		celebrate_animal(match, correct_slot)
		core.after(0.6, function()
			if match.token == token then play_animal(arena, match) end
		end)
	end

	hud_update_all(arena, match)
	core.after(picked_slot == correct_slot and NEXT_DELAY or REVEAL_TIME, function()
		if match.token ~= token or not arena.in_game then return end
		if match.lives <= 0 then
			game_over(arena, match)
		else
			begin_question(arena, match)
		end
	end)
end

begin_question = function(arena, match)
	match.round = match.round + 1
	match.state = "listen"
	match.round_time = round_time(match)
	match.token = match.base_token .. ":" .. match.round
	local token = match.token

	remove_animals(match)
	match.options, match.correct_slot = choose_options(match)
	for slot in ipairs(match.options) do
		spawn_animal(arena, match, slot)
	end

	title_all(arena, S("Listen..."), LISTEN_TIME, 0xffc978)
	local bell = match.bell and match.bell:get_luaentity()
	if bell then bell:ring() end
	core.after(SOUND_DELAY, function()
		if match.token == token then play_animal(arena, match) end
	end)
	core.after(LISTEN_TIME, function()
		if match.token ~= token or match.state ~= "listen" then return end
		match.state = "answer"
		match.deadline_us = core.get_us_time() + match.round_time * 1000000
		match.last_tick = nil
		title_all(arena, S("Which animal is it?"), 1.2, 0xffffff)
		hud_update_all(arena, match)
	end)
	hud_update_all(arena, match)
end

on_answer = function(player, ent)
	local match, arena = match_of_player(player)
	if not answering(match) or ent.arena_name ~= arena.name or ent.token ~= match.token then return end
	resolve(arena, match, ent.slot)
end

on_replay = function(player, ent)
	local match, arena = match_of_player(player)
	if not answering(match) or ent.arena_name ~= arena.name then return end
	local now = core.get_us_time()
	if match.last_replay and now - match.last_replay < 1000000 then return end
	match.last_replay = now
	ent:ring()
	play_animal(arena, match)
end

arena_lib.on_start(MOD, function(arena)
	local match = {
		base_token = tostring(core.get_us_time()),
		state = "setup",
		score = 0,
		lives = LIVES,
		streak = 0,
		best_streak = 0,
		round = 0,
		round_time = INITIAL_TIME,
		stations = {},
		placed = {},
		deck = {},
	}
	match.token = match.base_token
	matches[arena.name] = match

	for p_name in pairs(arena.players) do
		local player = core.get_player_by_name(p_name)
		if player then hud_create(player) end
	end

	if #available < 4 then
		core.log("warning", "[skyss_animalgame] Fewer than 4 quiz animals: enable mobs_mc or animalworld")
		chat(arena, core.colorize("#ff8a7a", S("Not enough animals are installed: tell your teacher.")))
		game_over(arena, match)
		return
	end
	if not build_stage(arena, match) then
		core.log("warning", "[skyss_animalgame] Arena " .. arena.name .. " has no spawn point to build the stage")
		chat(arena, core.colorize("#ff8a7a", S("The arena has no spawn point: tell your teacher.")))
		game_over(arena, match)
		return
	end

	chat(arena, S("Listen to the animal and click the right one. Ring the bell to hear it again. You have @1 lives!", LIVES))
	begin_question(arena, match)
end)

arena_lib.on_celebration(MOD, function(arena)
	local match = get_match(arena)
	if not match then return end
	match.state = "over"
	hud_update_all(arena, match)
end)

arena_lib.on_quit(MOD, function(arena, p_name)
	local player = core.get_player_by_name(p_name)
	if player then hud_remove(player) end
end)

arena_lib.on_end(MOD, function(arena)
	local match = matches[arena.name]
	if not match then return end
	match.token = match.token .. "!"
	remove_stage(match)
	for p_name in pairs(arena.players or {}) do
		local player = core.get_player_by_name(p_name)
		if player then hud_remove(player) end
	end
	matches[arena.name] = nil
end)

-- Smooth countdown bar, last-seconds ticking and timeouts.
local tick = 0
core.register_globalstep(function(dtime)
	tick = tick + dtime
	if tick < 0.1 then return end
	tick = 0
	for name, match in pairs(matches) do
		if match.state == "answer" then
			local _, arena = arena_lib.get_arena_by_name(MOD, name)
			if arena and arena.in_game then
				local left = time_left(match)
				for p_name in pairs(arena.players) do
					local player = core.get_player_by_name(p_name)
					local h = huds[p_name]
					if player and h then hud_update_timer(match, player, h) end
				end
				local second = math.ceil(left)
				if left > 0 and second <= 3 and second ~= match.last_tick then
					match.last_tick = second
					sound_all(arena, "mesecons_noteblock_hit", {gain = 0.5, pitch = 1 + (3 - second) * 0.15})
				end
				if left <= 0 then
					resolve(arena, match, nil)
				end
			end
		end
	end
end)

core.register_on_leaveplayer(function(player)
	huds[player:get_player_name()] = nil
end)

core.log("action", "[skyss_animalgame] Game mod loaded")
