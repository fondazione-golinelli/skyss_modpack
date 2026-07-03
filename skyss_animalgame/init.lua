local MOD = "skyss_animalgame"
local has_mobs_mc = minetest.get_modpath("mobs_mc") ~= nil
local has_animalworld = minetest.get_modpath("animalworld") ~= nil
local has_mcl_bells = minetest.get_modpath("mcl_bells") ~= nil

local INITIAL_TIME = 10
local MIN_TIME = 4
local LISTEN_TIME = 3.5
local SOUND_PLAY_DELAY = 0.4
local END_FEEDBACK_TIME = 3
local CELEBRATION_TIME = 8
local hud_type = minetest.features.hud_def_type_field and "type" or "hud_elem_type"
local top_status_huds = {}

local ANIMALS = {
	{
		id = "pig",
		name = "Pig",
		mod = "mobs_mc",
		sound = "mobs_pig",
		icon = "mobs_mc_spawn_icon_pig.png",
		color = "#f0a5a2",
	},
	{
		id = "cow",
		name = "Cow",
		mod = "mobs_mc",
		sound = "mobs_mc_cow",
		icon = "mobs_mc_spawn_icon_cow.png",
		color = "#6b4d3a",
	},
	{
		id = "sheep",
		name = "Sheep",
		mod = "mobs_mc",
		sound = "mobs_sheep",
		icon = "mobs_mc_spawn_icon_sheep.png",
		color = "#eeeeee",
	},
	{
		id = "chicken",
		name = "Chicken",
		mod = "mobs_mc",
		sound = "mobs_mc_chicken_buck",
		icon = "mobs_mc_spawn_icon_chicken.png",
		color = "#f5f0db",
	},
	{
		id = "horse",
		name = "Horse",
		mod = "mobs_mc",
		sound = "mobs_mc_horse_random",
		icon = "mobs_mc_spawn_icon_horse.png",
		color = "#8a5d3b",
	},
	{
		id = "cat",
		name = "Cat",
		mod = "mobs_mc",
		sound = "mobs_mc_cat_idle",
		icon = "mobs_mc_spawn_icon_cat.png",
		color = "#d6a15f",
	},
	{
		id = "wolf",
		name = "Wolf",
		mod = "mobs_mc",
		sound = "mobs_mc_wolf_bark",
		icon = "mobs_mc_spawn_icon_wolf.png",
		color = "#cfcfcf",
	},
	{
		id = "bear",
		name = "Bear",
		mod = "animalworld",
		sound = "animalworld_bear",
		icon = "abear.png",
		color = "#6b4a2f",
	},
	{
		id = "boar",
		name = "Boar",
		mod = "animalworld",
		sound = "animalworld_boar",
		icon = "aboar.png",
		color = "#5b4030",
	},
	{
		id = "camel",
		name = "Camel",
		mod = "animalworld",
		sound = "animalworld_camel",
		icon = "acamel.png",
		color = "#c59b64",
	},
	{
		id = "crocodile",
		name = "Crocodile",
		mod = "animalworld",
		sound = "animalworld_crocodile",
		icon = "acrocodile.png",
		color = "#3f6f3d",
	},
	{
		id = "elephant",
		name = "Elephant",
		mod = "animalworld",
		sound = "animalworld_elephant",
		icon = "aelephant.png",
		color = "#8f8c83",
	},
	{
		id = "fox",
		name = "Fox",
		mod = "animalworld",
		sound = "animalworld_fox",
		icon = "afox.png",
		color = "#c46b34",
	},
	{
		id = "frog",
		name = "Frog",
		mod = "animalworld",
		sound = "animalworld_frog",
		icon = "afrog.png",
		color = "#60a64e",
	},
	{
		id = "goose",
		name = "Goose",
		mod = "animalworld",
		sound = "animalworld_goose",
		icon = "agoose.png",
		color = "#eeeeee",
	},
	{
		id = "hyena",
		name = "Hyena",
		mod = "animalworld",
		sound = "animalworld_hyena",
		icon = "ahyena.png",
		color = "#9b805c",
	},
	{
		id = "koala",
		name = "Koala",
		mod = "animalworld",
		sound = "animalworld_koala",
		icon = "akoala.png",
		color = "#9c9c9c",
	},
	{
		id = "marmot",
		name = "Marmot",
		mod = "animalworld",
		sound = "animalworld_marmot",
		icon = "amarmot.png",
		color = "#9a7146",
	},
	{
		id = "monkey",
		name = "Monkey",
		mod = "animalworld",
		sound = "animalworld_monkey",
		icon = "amonkey.png",
		color = "#765038",
	},
	{
		id = "moose",
		name = "Moose",
		mod = "animalworld",
		sound = "animalworld_moose",
		icon = "amoose.png",
		color = "#6a4b30",
	},
	{
		id = "otter",
		name = "Otter",
		mod = "animalworld",
		sound = "animalworld_otter",
		icon = "aotter.png",
		color = "#6f503a",
	},
	{
		id = "owl",
		name = "Owl",
		mod = "animalworld",
		sound = "animalworld_owl",
		icon = "aowl.png",
		color = "#8a7354",
	},
	{
		id = "seal",
		name = "Seal",
		mod = "animalworld",
		sound = "animalworld_seal",
		icon = "aseal.png",
		color = "#a7a49b",
	},
	{
		id = "stellerseagle",
		name = "Steller's Eagle",
		mod = "animalworld",
		sound = "animalworld_stellerseagle",
		icon = "astellerseagle.png",
		color = "#5b5148",
	},
	{
		id = "tapir",
		name = "Tapir",
		mod = "animalworld",
		sound = "animalworld_tapir",
		icon = "atapir.png",
		color = "#69524d",
	},
	{
		id = "tiger",
		name = "Tiger",
		mod = "animalworld",
		sound = "animalworld_tiger",
		icon = "atiger.png",
		color = "#d77928",
	},
	{
		id = "yak",
		name = "Yak",
		mod = "animalworld",
		sound = "animalworld_yak",
		icon = "ayak.png",
		color = "#4c3b34",
	},
	{
		id = "zebra",
		name = "Zebra",
		mod = "animalworld",
		sound = "animalworld_zebra",
		icon = "azebra.png",
		color = "#f0f0f0",
	},
}

local animals_by_id = {}
local available_animals = {}

local function is_animal_available(animal)
	return animal.mod == "mobs_mc" and has_mobs_mc
		or animal.mod == "animalworld" and has_animalworld
end

for _, animal in ipairs(ANIMALS) do
	if is_animal_available(animal) then
		animals_by_id[animal.id] = animal
		table.insert(available_animals, animal)
	end
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

local function ensure_top_status_hud(player)
	local p_name = player:get_player_name()
	if top_status_huds[p_name] then
		return top_status_huds[p_name]
	end

	local bg_id = player:hud_add({
		[hud_type] = "image",
		position = {x = 0.5, y = 0.25},
		offset = {x = 0, y = 105},
		text = "",
		scale = {x = 19, y = 1.2},
		number = 0xffffff,
		z_index = 1101,
	})
	local text_id = player:hud_add({
		[hud_type] = "text",
		position = {x = 0.5, y = 0.25},
		offset = {x = 0, y = 105},
		text = "",
		size = {x = 1.2, y = 1.2},
		number = 0xffffff,
		z_index = 1102,
	})

	top_status_huds[p_name] = {
		bg = bg_id,
		text = text_id,
	}
	return top_status_huds[p_name]
end

local function hide_top_status(player_or_name)
	local p_name = type(player_or_name) == "string" and player_or_name or player_or_name:get_player_name()
	local player = minetest.get_player_by_name(p_name)
	local hud = top_status_huds[p_name]
	if not player or not hud then
		return
	end

	player:hud_change(hud.bg, "text", "")
	player:hud_change(hud.text, "text", "")
end

local function top_status(player, text, duration, color)
	local p_name = player:get_player_name()
	local hud = ensure_top_status_hud(player)

	player:hud_change(hud.bg, "text", "arenalib_hud_bg.png^[opacity:115")
	player:hud_change(hud.text, "text", text)
	player:hud_change(hud.text, "number", color or 0xffffff)

	if duration then
		minetest.after(duration, function()
			local current_player = minetest.get_player_by_name(p_name)
			local current_hud = top_status_huds[p_name]
			if not current_player or not current_hud then
				return
			end
			local current_text = current_player:hud_get(current_hud.text)
			if not current_text or current_text.text ~= text then
				return
			end
			hide_top_status(p_name)
		end)
	end
end

local function show_score_hud(player, score)
	local p_name = player:get_player_name()
	hide_top_status(player)
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

local function create_replay_position(arena)
	arena.animalgame_station_anchor = arena.animalgame_station_anchor or capture_station_anchor(arena)

	local center = arena.animalgame_station_anchor.center
	local forward = arena.animalgame_station_anchor.forward
	local row_center = vector.add(center, vector.multiply(forward, 4))

	return {
		x = math.floor(row_center.x + 0.5),
		y = math.floor(center.y - 0.5),
		z = math.floor(row_center.z + 0.5),
	}
end

local function find_replay_position(arena)
	if not arena.animalgame_replay_position then
		arena.animalgame_replay_position = create_replay_position(arena)
	end
	return arena.animalgame_replay_position
end

local function choose_animals()
	if #available_animals < 4 then
		return nil, nil
	end

	local correct = available_animals[math.random(#available_animals)]
	local options = {correct}
	local pool = {}

	for _, animal in ipairs(available_animals) do
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

local function spawn_text_label(arena, pos, text, y_offset)
	local obj = minetest.add_entity(vector.offset(pos, 0, y_offset or 1.45, 0), MOD .. ":label", minetest.serialize({text = text}))
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

local function place_replay_button(arena)
	local replay_pos = find_replay_position(arena)
	remember_and_set_node(arena, replay_pos, {name = MOD .. ":totem_base"})

	local meta = minetest.get_meta(replay_pos)
	meta:set_string("infotext", "Hear the sound again")

	local obj = minetest.add_entity(vector.offset(replay_pos, 0, 1.25, 0), MOD .. ":replay_bell")
	if obj then
		table.insert(arena.animalgame_entities, obj)
	end

	spawn_text_label(arena, replay_pos, "Hear again", 2.05)
end

local end_game
local handle_answer
local replay_current_sound

local function update_timer_hud(arena, token)
	if not arena.in_game or arena.in_celebration or arena.animalgame_token ~= token then
		return
	end

	local p_name = get_player_name(arena)
	local player = p_name and minetest.get_player_by_name(p_name)
	if not player then
		return
	end

	if not arena.animalgame_deadline then
		return
	end

	local left = math.max(0, arena.animalgame_deadline - os.time())
	top_status(player, "Score: " .. (arena.animalgame_score or 0) .. " | Time: " .. left .. "s")

	if left <= 0 then
		end_game(arena, "Time is up!", 0xff3333, true)
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
	arena.animalgame_answer_locked = false

	local correct, options = choose_animals()
	if not correct then
		end_game(arena, "Not enough animals", 0xff3333)
		return
	end

	local stations = find_station_positions(arena)

	arena.animalgame_correct = correct.id
	arena.animalgame_current_sound = correct.sound
	arena.animalgame_deadline = nil

	for i, animal in ipairs(options) do
		place_station(arena, stations[i], animal, animal.id == correct.id)
	end

	place_replay_button(arena)

	local p_name = get_player_name(arena)
	local player = p_name and minetest.get_player_by_name(p_name)
	local token = arena.animalgame_token
	if player then
		arena_lib.HUD_send_msg("title", p_name, "Listen...", LISTEN_TIME, nil, 0xffffff)
		top_status(player, "Listen first. Click 'Hear again' to replay.")
		minetest.after(SOUND_PLAY_DELAY, function()
			if arena.in_game and not arena.in_celebration and arena.animalgame_token == token then
				play_sound_to_player(p_name, correct.sound)
			end
		end)
	end

	minetest.after(LISTEN_TIME, function()
		if not arena.in_game or arena.in_celebration or arena.animalgame_token ~= token then
			return
		end

		arena.animalgame_deadline = os.time() + get_round_time(arena.animalgame_score)
		if p_name and minetest.get_player_by_name(p_name) then
			arena_lib.HUD_send_msg("title", p_name, "Choose!", 0.8, nil, 0xffffff)
		end
		update_timer_hud(arena, token)
	end)
end

local function get_correct_animal(arena)
	if not arena or not arena.animalgame_correct then
		return nil
	end
	return animals_by_id[arena.animalgame_correct]
end

end_game = function(arena, message, color, show_correct)
	if arena.animalgame_ended or arena.in_celebration then
		return
	end

	arena.animalgame_ended = true
	arena.animalgame_token = (arena.animalgame_token or 0) + 1

	local p_name = get_player_name(arena)
	local player = p_name and minetest.get_player_by_name(p_name)

	if player then
		local correct = show_correct and get_correct_animal(arena)
		arena_lib.HUD_send_msg("broadcast", p_name, message, END_FEEDBACK_TIME, nil, color or 0xff3333)
		if correct then
			top_status(player, "Correct answer: " .. correct.name, END_FEEDBACK_TIME, 0x55ff55)
			minetest.chat_send_player(p_name, "[AnimalGame] Correct answer: " .. correct.name)
		end

		minetest.after(END_FEEDBACK_TIME, function()
			if arena.in_game and not arena.in_celebration then
				arena_lib.HUD_hide("broadcast", p_name)
				hide_top_status(player)
				show_score_hud(player, arena.animalgame_score or 0)
				arena_lib.load_celebration(MOD, arena, nil)
			end
		end)
	else
		arena_lib.load_celebration(MOD, arena, nil)
	end
end

replay_current_sound = function(arena, p_name)
	if not arena or arena.animalgame_ended or arena.in_celebration or not arena.animalgame_current_sound then
		return
	end

	play_sound_to_player(p_name, arena.animalgame_current_sound)
	local player = minetest.get_player_by_name(p_name)
	if player then
		top_status(player, "Playing the sound again.", 2)
	end
end

handle_answer = function(arena, p_name, answer)
	if not arena or arena.animalgame_ended or arena.in_celebration or not answer then
		return
	end
	if arena.animalgame_answer_locked then
		return
	end

	arena.animalgame_answer_locked = true

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
		end_game(arena, "Wrong answer!", 0xff3333, true)
	end
end

minetest.register_entity(MOD .. ":replay_bell", {
	initial_properties = {
		physical = false,
		collide_with_objects = false,
		pointable = true,
		static_save = false,
		visual = "sprite",
		visual_size = {x = 1.0, y = 1.0},
		collisionbox = {-0.55, -0.55, -0.55, 0.55, 0.55, 0.55},
		selectionbox = {-0.55, -0.55, -0.55, 0.55, 0.55, 0.55},
		textures = {"default_stone.png^[colorize:#ffaa33:150"},
	},

	on_activate = function(self)
		if has_mcl_bells then
			self.object:set_properties({
				visual = "mesh",
				mesh = "mcl_bells_bell.b3d",
				textures = {"mcl_bells_bell_uv_bell.png"},
				visual_size = {x = 0.8, y = 0.8},
				collisionbox = {-0.55, -0.55, -0.55, 0.55, 0.55, 0.55},
				selectionbox = {-0.55, -0.55, -0.55, 0.55, 0.55, 0.55},
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

		if has_mcl_bells then
			self.object:set_animation({x = 1, y = 195}, 240, 0, false)
		end
		replay_current_sound(arena, p_name)
	end,
})

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
		local animal = animals_by_id[data.animal_id] or available_animals[1] or ANIMALS[1]
		self.animal_id = animal.id
		self.is_correct = data.is_correct == true

		if animal.icon and is_animal_available(animal) then
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
		if data.text then
			self.object:set_properties({
				nametag = data.text,
				nametag_color = "#ffffff",
			})
			return
		end

		local animal = animals_by_id[data.animal_id] or available_animals[1] or ANIMALS[1]
		self.object:set_properties({
			nametag = animal.name,
			nametag_color = "#ffffff",
		})
	end,
})

minetest.register_node(MOD .. ":replay_button", {
	description = "Animal Game Replay Button",
	drawtype = "nodebox",
	tiles = {"default_stone.png^[colorize:#ffaa33:90"},
	paramtype = "light",
	node_box = {
		type = "fixed",
		fixed = {-0.4, -0.5, -0.4, 0.4, -0.2, 0.4},
	},
	selection_box = {
		type = "fixed",
		fixed = {-0.45, -0.5, -0.45, 0.45, -0.15, 0.45},
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

		replay_current_sound(arena, p_name)
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
	arena.animalgame_replay_position = nil

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
		hide_top_status(player)
		show_score_hud(player, arena.animalgame_score or 0)
	end
end)

arena_lib.on_end(MOD, function(arena)
	local p_name = get_player_name(arena)
	if p_name then
		hide_top_status(p_name)
	end
	cleanup_stations(arena)
end)

minetest.register_on_leaveplayer(function(player)
	top_status_huds[player:get_player_name()] = nil
end)

if #available_animals < 4 then
	minetest.log("warning", "[skyss_animalgame] fewer than 4 quiz animals are available; enable mobs_mc or animalworld.")
end

minetest.log("action", "[skyss_animalgame] Game mod loaded")
