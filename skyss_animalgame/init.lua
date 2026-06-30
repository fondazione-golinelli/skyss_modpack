local MOD = "skyss_animalgame"
local has_mobs_mc = minetest.get_modpath("mobs_mc") ~= nil

local INITIAL_TIME = 10
local MIN_TIME = 4
local CELEBRATION_TIME = 5

local ANIMALS = {
	{
		id = "pig",
		name = "Pig",
		sound = "mobs_pig",
		icon = "mobs_mc_spawn_icon_pig.png",
		color = "#f0a5a2",
	},
	{
		id = "cow",
		name = "Cow",
		sound = "mobs_mc_cow",
		icon = "mobs_mc_spawn_icon_cow.png",
		color = "#6b4d3a",
	},
	{
		id = "sheep",
		name = "Sheep",
		sound = "mobs_sheep",
		icon = "mobs_mc_spawn_icon_sheep.png",
		color = "#eeeeee",
	},
	{
		id = "chicken",
		name = "Chicken",
		sound = "mobs_mc_chicken_buck",
		icon = "mobs_mc_spawn_icon_chicken.png",
		color = "#f5f0db",
	},
	{
		id = "horse",
		name = "Horse",
		sound = "mobs_mc_horse_random",
		icon = "mobs_mc_spawn_icon_horse.png",
		color = "#8a5d3b",
	},
	{
		id = "cat",
		name = "Cat",
		sound = "mobs_mc_cat_idle",
		icon = "mobs_mc_spawn_icon_cat.png",
		color = "#d6a15f",
	},
	{
		id = "wolf",
		name = "Wolf",
		sound = "mobs_mc_wolf_bark",
		icon = "mobs_mc_spawn_icon_wolf.png",
		color = "#cfcfcf",
	},
}

local animals_by_id = {}
for _, animal in ipairs(ANIMALS) do
	animals_by_id[animal.id] = animal
end

local function shuffle(list)
	for i = #list, 2, -1 do
		local j = math.random(i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

local function copy_pos(pos)
	return {x = pos.x, y = pos.y, z = pos.z}
end

local function pos_key(pos)
	return minetest.pos_to_string(pos)
end

local function get_player_name(arena)
	for p_name, _ in pairs(arena.players or {}) do
		return p_name
	end
end

local function get_round_time(score)
	return math.max(MIN_TIME, INITIAL_TIME - math.floor((score or 0) / 2))
end

local function hud_text(player, text)
	local p_name = player:get_player_name()
	arena_lib.HUD_send_msg("hotbar", p_name, text, 2, nil, 0xffffff)
end

local function show_score_hud(player, score)
	local p_name = player:get_player_name()
	arena_lib.HUD_send_msg("title", p_name, "Final score: " .. score, CELEBRATION_TIME, nil, 0xffffff)
end

local function play_sound_to_player(p_name, sound)
	minetest.sound_play(sound, {
		to_player = p_name,
		gain = 1.0,
		max_hear_distance = 16,
	}, true)
end

local function remove_entity(obj)
	if obj and obj:get_luaentity() then
		obj:remove()
	end
end

local function restore_nodes(arena)
	if not arena.animalgame_nodes then
		return
	end

	for _, record in ipairs(arena.animalgame_nodes) do
		local current = minetest.get_node(record.pos)
		if current.name:sub(1, #MOD + 1) == MOD .. ":" then
			minetest.set_node(record.pos, record.node)
		end
	end
	arena.animalgame_nodes = {}
end

local function cleanup_stations(arena)
	restore_nodes(arena)

	if arena.animalgame_entities then
		for _, obj in ipairs(arena.animalgame_entities) do
			remove_entity(obj)
		end
	end
	arena.animalgame_entities = {}
	arena.animalgame_buttons = {}
end

local function remember_and_set_node(arena, pos, node)
	arena.animalgame_nodes = arena.animalgame_nodes or {}
	table.insert(arena.animalgame_nodes, {
		pos = copy_pos(pos),
		node = minetest.get_node(pos),
	})
	minetest.set_node(pos, node)
end

local function get_snapped_forward(player)
	local look = player and player:get_look_dir() or {x = 0, y = 0, z = 1}
	local x = look.x or 0
	local z = look.z or 0

	if math.abs(x) > math.abs(z) then
		return {x = x >= 0 and 1 or -1, y = 0, z = 0}
	end

	return {x = 0, y = 0, z = z >= 0 and 1 or -1}
end

local function capture_station_anchor(arena)
	local p_name = get_player_name(arena)
	local player = p_name and minetest.get_player_by_name(p_name)

	return {
		center = player and player:get_pos() or {x = 0, y = 0, z = 0},
		forward = get_snapped_forward(player),
	}
end

local function create_station_positions(arena)
	arena.animalgame_station_anchor = arena.animalgame_station_anchor or capture_station_anchor(arena)

	local center = arena.animalgame_station_anchor.center
	local forward = arena.animalgame_station_anchor.forward
	local right = {x = -forward.z, y = 0, z = forward.x}
	local row_center = vector.add(center, vector.multiply(forward, 4))
	local base_y = math.floor(center.y - 0.5)
	local positions = {}

	for i, offset in ipairs({-3, -1, 1, 3}) do
		local pos = vector.add(row_center, vector.multiply(right, offset))
		positions[i] = {
			x = math.floor(pos.x + 0.5),
			y = base_y,
			z = math.floor(pos.z + 0.5),
		}
	end

	return positions
end

local function find_station_positions(arena)
	if not arena.animalgame_station_positions then
		arena.animalgame_station_positions = create_station_positions(arena)
	end
	return arena.animalgame_station_positions
end

local function choose_animals()
	local correct = ANIMALS[math.random(#ANIMALS)]
	local options = {correct}
	local pool = {}

	for _, animal in ipairs(ANIMALS) do
		if animal.id ~= correct.id then
			table.insert(pool, animal)
		end
	end

	shuffle(pool)
	for i = 1, 3 do
		table.insert(options, pool[i])
	end

	return correct, shuffle(options)
end

local function spawn_animal_entity(arena, pos, animal, is_correct)
	local obj = minetest.add_entity(vector.offset(pos, 0, 1.45, 0), MOD .. ":animal", minetest.serialize({
		animal_id = animal.id,
		is_correct = is_correct,
	}))
	if obj then
		table.insert(arena.animalgame_entities, obj)
	end
end

local function spawn_label_entity(arena, pos, animal)
	local obj = minetest.add_entity(vector.offset(pos, 0, 1.95, 0), MOD .. ":label", minetest.serialize({animal_id = animal.id}))
	if obj then
		table.insert(arena.animalgame_entities, obj)
	end
end

local function place_station(arena, pos, animal, is_correct)
	local base_pos = copy_pos(pos)
	local button_pos = vector.offset(base_pos, 0, 1, 0)

	remember_and_set_node(arena, base_pos, {name = MOD .. ":totem_base"})
	remember_and_set_node(arena, button_pos, {name = MOD .. ":answer_button"})

	local meta = minetest.get_meta(button_pos)
	meta:set_string("animal_id", animal.id)
	meta:set_string("animal_name", animal.name)
	meta:set_int("is_correct", is_correct and 1 or 0)
	meta:set_string("infotext", "Answer: " .. animal.name)

	arena.animalgame_buttons[pos_key(button_pos)] = {
		animal_id = animal.id,
		is_correct = is_correct,
	}

	spawn_animal_entity(arena, base_pos, animal, is_correct)
	spawn_label_entity(arena, base_pos, animal)
end

local end_game
local handle_answer

local function update_timer_hud(arena, token)
	if not arena.in_game or arena.in_celebration or arena.animalgame_token ~= token then
		return
	end

	local p_name = get_player_name(arena)
	local player = p_name and minetest.get_player_by_name(p_name)
	if not player then
		return
	end

	local left = math.max(0, (arena.animalgame_deadline or os.time()) - os.time())
	hud_text(player, "Score: " .. (arena.animalgame_score or 0) .. " | Time: " .. left .. "s")

	if left <= 0 then
		end_game(arena, "Time is up!", 0xff3333)
		return
	end

	minetest.after(1, function()
		update_timer_hud(arena, token)
	end)
end

local function begin_question(arena)
	if not arena.in_game or arena.in_celebration then
		return
	end

	cleanup_stations(arena)

	arena.animalgame_token = (arena.animalgame_token or 0) + 1
	arena.animalgame_buttons = {}
	arena.animalgame_entities = {}

	local correct, options = choose_animals()
	local stations = find_station_positions(arena)

	arena.animalgame_correct = correct.id
	arena.animalgame_deadline = os.time() + get_round_time(arena.animalgame_score)

	for i, animal in ipairs(options) do
		place_station(arena, stations[i], animal, animal.id == correct.id)
	end

	local p_name = get_player_name(arena)
	local player = p_name and minetest.get_player_by_name(p_name)
	if player then
		arena_lib.HUD_send_msg("title", p_name, "Listen...", 1.5, nil, 0xffffff)
		minetest.after(0.7, function()
			if arena.in_game and not arena.in_celebration and arena.animalgame_correct == correct.id then
				play_sound_to_player(p_name, correct.sound)
			end
		end)
	end

	update_timer_hud(arena, arena.animalgame_token)
end

end_game = function(arena, message, color)
	if arena.animalgame_ended or arena.in_celebration then
		return
	end

	arena.animalgame_ended = true
	arena.animalgame_token = (arena.animalgame_token or 0) + 1

	local p_name = get_player_name(arena)
	local player = p_name and minetest.get_player_by_name(p_name)
	cleanup_stations(arena)

	if player then
		arena_lib.HUD_send_msg("title", p_name, message, 2, nil, color or 0xff3333)
		minetest.after(1.2, function()
			if arena.in_game and not arena.in_celebration then
				show_score_hud(player, arena.animalgame_score or 0)
				arena_lib.load_celebration(MOD, arena, nil)
			end
		end)
	else
		arena_lib.load_celebration(MOD, arena, nil)
	end
end

handle_answer = function(arena, p_name, answer)
	if not arena or arena.animalgame_ended or arena.in_celebration or not answer then
		return
	end

	local animal = animals_by_id[answer.animal_id]
	if answer.is_correct then
		arena.animalgame_score = (arena.animalgame_score or 0) + 1
		arena.animalgame_token = (arena.animalgame_token or 0) + 1
		arena_lib.HUD_send_msg("title", p_name, "Correct!", 1, nil, 0x55ff55)
		if animal then
			minetest.chat_send_player(p_name, "[AnimalGame] Correct: " .. animal.name .. ". Score: " .. arena.animalgame_score)
		end
		minetest.after(0.9, function()
			begin_question(arena)
		end)
	else
		local label = animal and animal.name or "that animal"
		minetest.chat_send_player(p_name, "[AnimalGame] Wrong answer: " .. label .. ".")
		end_game(arena, "Wrong answer!", 0xff3333)
	end
end

minetest.register_entity(MOD .. ":animal", {
	initial_properties = {
		physical = false,
		collide_with_objects = false,
		pointable = true,
		static_save = false,
		visual = "sprite",
		visual_size = {x = 1.25, y = 1.25},
		collisionbox = {-0.65, -0.65, -0.1, 0.65, 0.65, 0.1},
		selectionbox = {-0.65, -0.65, -0.1, 0.65, 0.65, 0.1},
		textures = {"default_stone.png^[colorize:#ffffff:180"},
	},

	on_activate = function(self, staticdata)
		local data = minetest.deserialize(staticdata or "") or {}
		local animal = animals_by_id[data.animal_id] or ANIMALS[1]
		self.animal_id = animal.id
		self.is_correct = data.is_correct == true

		if has_mobs_mc then
			self.object:set_properties({
				physical = false,
				collide_with_objects = false,
				pointable = true,
				static_save = false,
				visual = "sprite",
				visual_size = {x = 1.25, y = 1.25},
				collisionbox = {-0.65, -0.65, -0.1, 0.65, 0.65, 0.1},
				selectionbox = {-0.65, -0.65, -0.1, 0.65, 0.65, 0.1},
				textures = {animal.icon},
			})
		else
			local texture = "default_stone.png^[colorize:" .. animal.color .. ":220"
			self.object:set_properties({
				visual = "sprite",
				visual_size = {x = 1.25, y = 1.25},
				textures = {texture},
			})
		end
	end,

	on_rightclick = function(self, clicker)
		if not clicker or not clicker:is_player() then
			return
		end

		local p_name = clicker:get_player_name()
		local arena = arena_lib.get_arena_by_player(p_name)
		if not arena or arena_lib.get_mod_by_player(p_name) ~= MOD then
			return
		end

		handle_answer(arena, p_name, {
			animal_id = self.animal_id,
			is_correct = self.is_correct,
		})
	end,
})

minetest.register_entity(MOD .. ":label", {
	initial_properties = {
		physical = false,
		collide_with_objects = false,
		pointable = false,
		static_save = false,
		visual = "sprite",
		visual_size = {x = 0.01, y = 0.01},
		textures = {"default_stone.png^[opacity:0"},
		nametag = "",
		nametag_color = "#ffffff",
	},

	on_activate = function(self, staticdata)
		local data = minetest.deserialize(staticdata or "") or {}
		local animal = animals_by_id[data.animal_id] or ANIMALS[1]
		self.object:set_properties({
			nametag = animal.name,
			nametag_color = "#ffffff",
		})
	end,
})

minetest.register_node(MOD .. ":totem_base", {
	description = "Animal Game Totem Base",
	tiles = {"default_tree_top.png", "default_tree_top.png", "default_wood.png"},
	groups = {not_in_creative_inventory = 1},
	is_ground_content = false,
	diggable = false,
})

minetest.register_node(MOD .. ":answer_button", {
	description = "Animal Game Answer Button",
	drawtype = "nodebox",
	tiles = {"default_stone.png^[colorize:#44ccff:70"},
	paramtype = "light",
	node_box = {
		type = "fixed",
		fixed = {-0.35, -0.5, -0.35, 0.35, -0.25, 0.35},
	},
	selection_box = {
		type = "fixed",
		fixed = {-0.4, -0.5, -0.4, 0.4, -0.2, 0.4},
	},
	groups = {not_in_creative_inventory = 1},
	is_ground_content = false,
	diggable = false,
	walkable = false,

	on_rightclick = function(pos, node, clicker)
		if not clicker or not clicker:is_player() then
			return
		end

		local p_name = clicker:get_player_name()
		local arena = arena_lib.get_arena_by_player(p_name)
		if not arena or arena_lib.get_mod_by_player(p_name) ~= MOD then
			return
		end
		if arena.animalgame_ended or arena.in_celebration then
			return
		end

		local answer = arena.animalgame_buttons and arena.animalgame_buttons[pos_key(pos)]
		if not answer then
			return
		end

		handle_answer(arena, p_name, answer)
	end,
})

arena_lib.register_minigame(MOD, {
	name = "Animal Sounds",
	description = "Identify the animal by listening to its sound.",
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
		celebration_nobody = "Game over",
	},
	hud_flags = {
		hotbar = false,
		healthbar = false,
		breathbar = false,
		minimap = false,
	},
})

arena_lib.on_start(MOD, function(arena)
	arena.animalgame_score = 0
	arena.animalgame_token = 0
	arena.animalgame_ended = false
	arena.animalgame_nodes = {}
	arena.animalgame_entities = {}
	arena.animalgame_buttons = {}
	arena.animalgame_station_positions = nil
	arena.animalgame_station_anchor = capture_station_anchor(arena)

	local p_name = get_player_name(arena)
	if p_name then
		minetest.chat_send_player(p_name, "[AnimalGame] Listen to the sound and click the matching animal.")
	end

	begin_question(arena)
end)

arena_lib.on_celebration(MOD, function(arena)
	cleanup_stations(arena)

	local p_name = get_player_name(arena)
	local player = p_name and minetest.get_player_by_name(p_name)
	if player then
		show_score_hud(player, arena.animalgame_score or 0)
	end
end)

arena_lib.on_end(MOD, function(arena)
	cleanup_stations(arena)
end)

if not has_mobs_mc then
	minetest.log("warning", "[skyss_animalgame] mobs_mc is not enabled; animal icons and sounds will use placeholders.")
end

minetest.log("action", "[skyss_animalgame] Game mod loaded")
