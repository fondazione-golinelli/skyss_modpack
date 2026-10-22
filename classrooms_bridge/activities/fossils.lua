-- "Find the fossils": special mission activity.
--
-- When the mission starts, small fossils (rock with fossil traces) and buried
-- skeletons (rock hiding bones, laid flat) are placed underground in the
-- mission's zone, in natural rock and soil. Students get a fossil hammer, a
-- brush and a field notebook while they are in the zone:
--   * the hammer breaks rock with fossil traces and gives the fossil;
--   * the brush uncovers bones one stroke at a time; a skeleton counts once
--     every bone is uncovered;
--   * the notebook lists the species the student found, with a fact each.
-- Help (setting "help"): 1 none; 2 dust rising from the ground near each
-- fossil still hidden (a few blocks off, so it marks an area, not the block);
-- 3 also a fossil detector telling how close and how deep the nearest one is.
-- Inside the zone everyone playing also wears a miner's helmet (head armor
-- slot, the previous helmet is given back on leaving) whose lamp lights the
-- tunnels: an invisible light node follows the player's head.
-- Every changed node is recorded with what it was, and put back when the
-- mission is deleted. Holes dug by the students stay.

local missions, zones, is_staff = ...

local S = minetest.get_translator("classrooms_bridge")
local TAG = S("[Fossils]") .. " "
local P = "classrooms_bridge:"
local KIND = "fossils"
local storage = minetest.get_mod_storage()
local STROKES = 3 -- brush strokes to uncover a bone

local HAMMER, BRUSH, NOTEBOOK = P .. "fossil_hammer", P .. "fossil_brush", P .. "fossil_notebook"
local DETECTOR = P .. "fossil_detector"
local HELP_NONE, HELP_CLUES, HELP_DETECTOR = 1, 2, 3
local CLUE_EVERY = 2     -- seconds between dust puffs
local CLUE_RANGE = 40    -- puffs show near players within this distance
local CLUE_SPREAD = 2    -- puffs are up to this many blocks off the fossil

-- ── Species ──────────────────────────────────────────────────────────────────

local SMALL = {
    { key = "ammonite", name = S("Ammonite"),
      fact = S("Sea animal with a spiral shell. 400 to 66 million years ago.") },
    { key = "trilobite", name = S("Trilobite"),
      fact = S("One of the first animals with eyes. 521 to 252 million years ago.") },
    { key = "shark_tooth", name = S("Megalodon tooth"),
      fact = S("Tooth of a giant shark up to 18 m long. 23 to 3.6 million years ago.") },
    { key = "fern", name = S("Fern leaf"),
      fact = S("Plant of the great coal forests. 359 to 299 million years ago.") },
    { key = "fish", name = S("Fossil fish"),
      fact = S("Fish turned to stone at the bottom of an ancient lake. About 50 million years ago.") },
}

-- Skeletons lie flat, head towards +X. S skull, B spine, R ribs, L limb,
-- T tail; rows run along Z.
local SKELETONS = {
    { key = "ichthyosaur", name = S("Ichthyosaurus"),
      fact = S("Sea reptile shaped like a dolphin. 250 to 90 million years ago."),
      shape = { ".L..L..", "TBRRBBS", ".L..L.." } },
    { key = "raptor", name = S("Velociraptor"),
      fact = S("Small feathered hunting dinosaur. 75 to 71 million years ago."),
      shape = { "...L.L..", "TTTBRRBS", "...L.L.." } },
    { key = "triceratops", name = S("Triceratops"),
      fact = S("Plant-eating dinosaur with three horns. 68 to 66 million years ago."),
      shape = { "..L....L..", "TBBRRRRBSS", "..L....L.." } },
    { key = "mammoth", name = S("Woolly mammoth"),
      fact = S("Hairy elephant of the Ice Age. Until about 4,000 years ago."),
      shape = { ".L....L..", "TBRRRRBSS", ".L....L.." } },
}
local PARTS = { S = "skull", B = "spine", R = "rib", L = "limb", T = "tail" }

local function species_info(key)
    for _, sp in ipairs(SMALL) do if sp.key == key then return sp end end
    for _, sp in ipairs(SKELETONS) do if sp.key == key then return sp end end
end

-- ── Nodes ────────────────────────────────────────────────────────────────────
-- Rock with fossil traces and rock hiding a bone exist for every host rock,
-- so they look like the ground around them.

local HOSTS = {
    "mcl_core:stone", "mcl_core:granite", "mcl_core:diorite", "mcl_core:andesite",
    "mcl_deepslate:deepslate", "mcl_deepslate:tuff", "mcl_core:sandstone", "mcl_core:redsandstone",
    "mcl_core:dirt", "mcl_core:coarse_dirt", "mcl_core:clay",
}
local host_suffix = {}  -- [host node] = suffix of its fossil nodes
local our_nodes = {}    -- [node name] = "small" | "covered" | "bone"

local function hint(name, text)
    minetest.chat_send_player(name, minetest.colorize("#FFB347", TAG .. text))
end

local function holds(digger, item)
    return digger and digger:is_player() and digger:get_wielded_item():get_name() == item
end

local function side_tile(def)
    local tiles = def.tiles or {}
    local tile = tiles[#tiles >= 3 and 3 or 1] or tiles[1]
    if type(tile) == "table" then tile = tile.name or tile.image end
    return type(tile) == "string" and tile or "blank.png"
end

local found_small, brush_bone -- defined below

for _, host in ipairs(HOSTS) do
    local def = minetest.registered_nodes[host]
    if def then
        local suffix = host:gsub(":", "_")
        host_suffix[host] = suffix
        local tile = side_tile(def)
        local groups = { not_in_creative_inventory = 1, fossil = 1,
            pickaxey = def.groups.pickaxey, shovely = def.groups.shovely, handy = def.groups.handy }
        local common = {
            groups = groups,
            sounds = def.sounds,
            drop = "",
            is_ground_content = false,
            _mcl_hardness = def._mcl_hardness or 1,
            _mcl_blast_resistance = 1200,
            on_blast = function() end,
        }

        local small = table.copy(common)
        small.description = S("Rock with fossil traces")
        small.tiles = { tile .. "^classrooms_bridge_fossil_traces.png" }
        small.on_dig = function(pos, node, digger)
            local name = digger and digger:get_player_name() or ""
            if not holds(digger, HAMMER) and not is_staff(name) then
                hint(name, S("Use the fossil hammer to free the fossil."))
                return false
            end
            return minetest.node_dig(pos, node, digger)
        end
        small.after_dig_node = function(pos, _, _, digger)
            found_small(pos, digger)
        end
        minetest.register_node(P .. "fossil_" .. suffix, small)
        our_nodes[P .. "fossil_" .. suffix] = "small"

        local covered = table.copy(common)
        covered.description = S("Rock hiding a bone")
        covered.tiles = { tile .. "^classrooms_bridge_bone_traces.png" }
        covered.on_dig = function(_, _, digger)
            hint(digger and digger:get_player_name() or "", S("A bone is hidden here: uncover it with the brush."))
            return false
        end
        minetest.register_node(P .. "bone_covered_" .. suffix, covered)
        our_nodes[P .. "bone_covered_" .. suffix] = "covered"
    end
end

for _, part in pairs(PARTS) do
    minetest.register_node(P .. "bone_" .. part, {
        description = S("Fossil bone"),
        tiles = { "classrooms_bridge_dig_ground.png^classrooms_bridge_bone_" .. part .. ".png",
            "classrooms_bridge_dig_ground.png" },
        paramtype2 = "facedir",
        groups = { not_in_creative_inventory = 1, fossil = 1, pickaxey = 1 },
        drop = "",
        is_ground_content = false,
        _mcl_hardness = 1,
        _mcl_blast_resistance = 1200,
        on_blast = function() end,
        on_dig = function(_, _, digger)
            hint(digger and digger:get_player_name() or "", S("Leave the skeleton where it is: the whole class can see it."))
            return false
        end,
    })
    our_nodes[P .. "bone_" .. part] = "bone"
end

-- ── Items ────────────────────────────────────────────────────────────────────

for _, sp in ipairs(SMALL) do
    minetest.register_craftitem(P .. "fossil_" .. sp.key, {
        description = sp.name .. "\n" .. minetest.colorize("#aaaaaa", sp.fact),
        inventory_image = "classrooms_bridge_fossil_" .. sp.key .. ".png",
        groups = { fossil_item = 1 },
    })
    missions.register_catalog_item("deliver", "fossil_" .. sp.key, P .. "fossil_" .. sp.key)
end

-- Mission tools stay in the zone: they cannot be dropped.
local function no_drop() return nil end

minetest.register_tool(HAMMER, {
    description = S("Fossil hammer") .. "\n" .. minetest.colorize("#aaaaaa",
        S("Breaks rock and soil, and frees fossils. Never wears out.")),
    inventory_image = "classrooms_bridge_fossil_hammer.png",
    groups = { not_in_creative_inventory = 1, mission_tool = 1 },
    tool_capabilities = { full_punch_interval = 0.6, max_drop_level = 1,
        groupcaps = {}, damage_groups = { fleshy = 1 } },
    _mcl_diggroups = {
        pickaxey = { speed = 6, level = 2, uses = 0 },
        shovely = { speed = 6, level = 1, uses = 0 },
    },
    _mcl_toollike_wield = true,
    -- No wear: the engine adds wear only without after_use.
    after_use = function(itemstack) return itemstack end,
    on_drop = no_drop,
})

minetest.register_tool(BRUSH, {
    description = S("Fossil brush") .. "\n" .. minetest.colorize("#aaaaaa",
        S("Click a hidden bone a few times to uncover it.")),
    inventory_image = "classrooms_bridge_fossil_brush.png",
    groups = { not_in_creative_inventory = 1, mission_tool = 1 },
    _mcl_toollike_wield = true,
    on_use = function(itemstack, user, pointed)
        if pointed and pointed.type == "node" then brush_bone(pointed.under, user) end
        return itemstack
    end,
    on_drop = no_drop,
})

local use_detector -- defined below

minetest.register_tool(DETECTOR, {
    description = S("Fossil detector") .. "\n" .. minetest.colorize("#aaaaaa",
        S("Click to find out how close the nearest fossil is.")),
    inventory_image = "classrooms_bridge_fossil_detector.png",
    groups = { not_in_creative_inventory = 1, mission_tool = 1 },
    on_use = function(itemstack, user)
        if user and user:is_player() then use_detector(user) end
        return itemstack
    end,
    on_secondary_use = function(itemstack, user)
        if user and user:is_player() then use_detector(user) end
        return itemstack
    end,
    on_place = function(itemstack, user)
        if user and user:is_player() then use_detector(user) end
        return itemstack
    end,
    on_drop = no_drop,
})

local show_notebook -- defined below

minetest.register_craftitem(NOTEBOOK, {
    description = S("Field notebook") .. "\n" .. minetest.colorize("#aaaaaa", S("The fossils you found")),
    inventory_image = "classrooms_bridge_fossil_notebook.png",
    stack_max = 1,
    groups = { not_in_creative_inventory = 1, mission_tool = 1 },
    on_use = function(itemstack, user)
        if user and user:is_player() then show_notebook(user) end
        return itemstack
    end,
    on_place = function(itemstack, user)
        if user and user:is_player() then show_notebook(user) end
        return itemstack
    end,
    on_secondary_use = function(itemstack, user)
        if user and user:is_player() then show_notebook(user) end
        return itemstack
    end,
    on_drop = no_drop,
})

-- ── Miner's helmet ───────────────────────────────────────────────────────────

local HELMET = P .. "miner_helmet"
local LIGHT = P .. "miner_light"
local HEAD_SLOT = 2 -- mcl_armor head index in the "armor" list
local SAVED_HELMET = "classrooms_bridge:saved_helmet"
local LIGHT_EVERY = 0.2

minetest.register_tool(HELMET, {
    description = S("Miner's helmet") .. "\n" .. minetest.colorize("#aaaaaa",
        S("Its lamp lights the way underground.")),
    inventory_image = "classrooms_bridge_miner_helmet.png",
    groups = { not_in_creative_inventory = 1, mission_tool = 1, armor = 1, non_combat_armor = 1,
        armor_head = 1, non_combat_head = 1 },
    _mcl_armor_element = "head",
    _mcl_armor_texture = "classrooms_bridge_miner_helmet_layer.png",
    on_drop = no_drop,
})

-- Air lit by a helmet lamp; removes itself once no lamp is near.
minetest.register_node(LIGHT, {
    description = S("Miner's helmet light"),
    drawtype = "airlike",
    paramtype = "light",
    sunlight_propagates = true,
    light_source = 12,
    walkable = false, pointable = false, diggable = false, buildable_to = true,
    floodable = true,
    drop = "",
    groups = { not_in_creative_inventory = 1 },
    on_construct = function(pos) minetest.get_node_timer(pos):start(1) end,
    on_timer = function(pos)
        for _, player in ipairs(minetest.get_connected_players()) do
            if vector.distance(player:get_pos(), pos) < 2.5 then return true end
        end
        minetest.remove_node(pos)
        return false
    end,
})

local lit = {}       -- [player] = true while wearing the lamp
local lamp_pos = {}  -- [player] = position of their light node

local function armor_inv(player)
    local inv = player:get_inventory()
    return inv:get_size("armor") > 0 and inv or nil
end

local function remove_light(name)
    local p = lamp_pos[name]
    if p and minetest.get_node(p).name == LIGHT then minetest.remove_node(p) end
    lamp_pos[name] = nil
end

-- Puts the helmet on, keeping the player's own helmet aside.
local function wear_helmet(player)
    local name = player:get_player_name()
    lit[name] = true
    local inv = armor_inv(player)
    if not inv or not minetest.global_exists("mcl_armor") then return end
    local old = inv:get_stack("armor", HEAD_SLOT)
    if old:get_name() == HELMET then return end
    local returned = mcl_armor.equip(ItemStack(HELMET), player, true)
    if returned:get_name() == HELMET then return end -- cursed helmet: keep it
    if not returned:is_empty() then
        local meta = player:get_meta()
        if meta:get_string(SAVED_HELMET) == "" then
            meta:set_string(SAVED_HELMET, returned:to_string())
        else
            local leftover = inv:add_item("main", returned)
            if not leftover:is_empty() then minetest.add_item(player:get_pos(), leftover) end
        end
    end
end

-- Takes the helmet off and gives the player's own helmet back. On leave the
-- armor API must not run (the player's model is already gone).
local function remove_helmet(player, leaving)
    local name = player:get_player_name()
    lit[name] = nil
    remove_light(name)
    local inv = armor_inv(player)
    if not inv then return end
    local meta = player:get_meta()
    local saved = ItemStack(meta:get_string(SAVED_HELMET))
    if inv:get_stack("armor", HEAD_SLOT):get_name() == HELMET then
        if leaving or not minetest.global_exists("mcl_armor") then
            inv:set_stack("armor", HEAD_SLOT, saved)
            saved = ItemStack("")
        else
            mcl_armor.unequip(player, HEAD_SLOT)
        end
    end
    if not saved:is_empty() then
        if leaving or not minetest.global_exists("mcl_armor") then
            if inv:get_stack("armor", HEAD_SLOT):is_empty() then
                inv:set_stack("armor", HEAD_SLOT, saved)
            else
                minetest.add_item(player:get_pos(), saved)
            end
        elseif inv:get_stack("armor", HEAD_SLOT):is_empty() then
            mcl_armor.equip(saved, player)
        else
            local leftover = inv:add_item("main", saved)
            if not leftover:is_empty() then minetest.add_item(player:get_pos(), leftover) end
        end
    end
    meta:set_string(SAVED_HELMET, "")
    -- A helmet taken off by hand never leaves the dig site.
    for _, list in ipairs({ "main", "craft", "offhand" }) do
        for i, stack in ipairs(inv:get_list(list) or {}) do
            if stack:get_name() == HELMET then inv:set_stack(list, i, ItemStack("")) end
        end
    end
end

local light_timer = 0
minetest.register_globalstep(function(dtime)
    light_timer = light_timer + dtime
    if light_timer < LIGHT_EVERY or not next(lit) then return end
    light_timer = 0
    for name in pairs(lit) do
        local player = minetest.get_player_by_name(name)
        if player then
            local inv = armor_inv(player)
            if inv and inv:get_stack("armor", HEAD_SLOT):get_name() ~= HELMET then
                -- Taken off by hand: back on the head, no copy left behind.
                remove_light(name)
                for _, list in ipairs({ "main", "craft", "offhand" }) do
                    for i, stack in ipairs(inv:get_list(list) or {}) do
                        if stack:get_name() == HELMET then inv:set_stack(list, i, ItemStack("")) end
                    end
                end
                wear_helmet(player)
            else
                local head = vector.round(vector.offset(player:get_pos(), 0, 1.5, 0))
                if not (lamp_pos[name] and vector.equals(lamp_pos[name], head)) then
                    remove_light(name)
                    local node = minetest.get_node(head)
                    if node.name == "air" or node.name == LIGHT then
                        minetest.set_node(head, { name = LIGHT })
                        lamp_pos[name] = head
                    end
                end
            end
        end
    end
end)

minetest.register_on_joinplayer(function(player)
    -- Left during a mission: the helmet comes off until the next tick.
    if player:get_meta():get_string(SAVED_HELMET) ~= ""
            or (armor_inv(player) and armor_inv(player):get_stack("armor", HEAD_SLOT):get_name() == HELMET) then
        remove_helmet(player, true)
    end
end)

minetest.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    if lit[name] then remove_helmet(player, true) end
    lit[name] = nil
    lamp_pos[name] = nil
end)

-- ── Records ──────────────────────────────────────────────────────────────────
-- storage "fossils_<id>" = {
--     zone = zone id,
--     help = 1..3,
--     small = { {x, y, z, orig, p2, species, found, cx, cz, sy} },
--     skeletons = { {species, done, cx, cz, sy, cells = { {x, y, z, orig, p2, part, rot, open} } } },
--     (cx, cz: where its clue rises; sy: the ground height there at the start)
--     short_small, short_skeletons,  -- asked for but did not fit
-- }

local ACTIVE_KEY = "fossils_active" -- { [id] = true }
local records = {}  -- [id] = record, loaded lazily
local index = {}    -- [pos hash] = { id, kind, i, j }
local strokes = {}  -- [pos hash] = brush strokes so far

local function record_key(id) return "fossils_" .. tostring(id) end

local function active_ids()
    return minetest.parse_json(storage:get_string(ACTIVE_KEY) ~= "" and storage:get_string(ACTIVE_KEY) or "{}") or {}
end

local function hash(p) return minetest.hash_node_position(p) end

local function index_record(id, rec)
    for i, f in ipairs(rec.small or {}) do
        index[hash(f)] = { id = id, kind = "small", i = i }
    end
    for i, sk in ipairs(rec.skeletons or {}) do
        for j, cell in ipairs(sk.cells) do
            index[hash(cell)] = { id = id, kind = "bone", i = i, j = j }
        end
    end
end

local function load_record(id)
    if records[id] == nil then
        local raw = storage:get_string(record_key(id))
        records[id] = raw ~= "" and minetest.parse_json(raw) or false
    end
    return records[id] or nil
end

local function save_record(id)
    if records[id] then storage:set_string(record_key(id), minetest.write_json(records[id])) end
end

local active = {} -- [id] = true, missions with fossils in the world

for id in pairs(active_ids()) do
    local rec = load_record(tonumber(id))
    if rec then
        index_record(tonumber(id), rec)
        active[tonumber(id)] = true
    end
end

-- ── Notebook ─────────────────────────────────────────────────────────────────

local NOTES_KEY = "classrooms_bridge:fossil_notes"

local function notes(player)
    return minetest.parse_json(player:get_meta():get_string(NOTES_KEY) ~= ""
        and player:get_meta():get_string(NOTES_KEY) or "{}") or {}
end

local function note(player, key)
    local list = notes(player)
    list[key] = (tonumber(list[key]) or 0) + 1
    player:get_meta():set_string(NOTES_KEY, minetest.write_json(list))
end

show_notebook = function(player)
    local list = notes(player)
    local all = {}
    for _, sp in ipairs(SMALL) do table.insert(all, { sp = sp, icon = "classrooms_bridge_fossil_" .. sp.key .. ".png" }) end
    for _, sp in ipairs(SKELETONS) do table.insert(all, { sp = sp, icon = "classrooms_bridge_bone_skull.png" }) end
    local known = 0
    for _, e in ipairs(all) do if list[e.sp.key] then known = known + 1 end end
    local fs = {
        "formspec_version[6]size[11,", tostring(1.6 + #all * 0.95), "]",
        "bgcolor[#2a2016ee]box[0,0;11,1.1;#4a2f1c]",
        "label[0.4,0.55;", minetest.formspec_escape(S("Field notebook · @1 of @2 species found", known, #all)), "]",
    }
    local y = 1.35
    for _, e in ipairs(all) do
        local count = list[e.sp.key]
        table.insert(fs, ("box[0.3,%g;10.4,0.85;%s]"):format(y, count and "#e9dfc4" or "#5a4632"))
        if count then
            table.insert(fs, ("image[0.4,%g;0.65,0.65;%s]"):format(y + 0.1, e.icon))
            table.insert(fs, ("label[1.25,%g;%s]"):format(y + 0.25,
                minetest.formspec_escape(minetest.colorize("#2a2016", e.sp.name .. "  ×" .. count))))
            table.insert(fs, ("label[1.25,%g;%s]"):format(y + 0.6,
                minetest.formspec_escape(minetest.colorize("#5a4632", e.sp.fact))))
        else
            table.insert(fs, ("label[1.25,%g;%s]"):format(y + 0.42,
                minetest.formspec_escape(minetest.colorize("#c9b48a", S("??? Not found yet")))))
        end
        y = y + 0.95
    end
    minetest.show_formspec(player:get_player_name(), "classrooms_bridge:fossil_notebook", table.concat(fs))
end

-- ── Finding ──────────────────────────────────────────────────────────────────

local function burst(pos, texture)
    minetest.add_particlespawner({
        amount = 24, time = 0.2,
        minpos = vector.subtract(pos, 0.4), maxpos = vector.add(pos, 0.4),
        minvel = { x = -1.5, y = 0.5, z = -1.5 }, maxvel = { x = 1.5, y = 2.5, z = 1.5 },
        minacc = { x = 0, y = -6, z = 0 }, maxacc = { x = 0, y = -6, z = 0 },
        minexptime = 0.4, maxexptime = 0.9, minsize = 1, maxsize = 2.5,
        texture = texture,
    })
end

found_small = function(pos, digger)
    local entry = index[hash(pos)]
    local key
    if entry and entry.kind == "small" then
        local rec = load_record(entry.id)
        local f = rec and rec.small[entry.i]
        if f and not f.found then
            f.found = true
            key = f.species
            save_record(entry.id)
        end
        index[hash(pos)] = nil
    end
    key = key or SMALL[math.random(#SMALL)].key
    local sp = species_info(key)
    burst(pos, "classrooms_bridge_fossil_" .. key .. ".png")
    if not (digger and digger:is_player()) then return end
    local stack = ItemStack(P .. "fossil_" .. key)
    local leftover = digger:get_inventory():add_item("main", stack)
    if not leftover:is_empty() then minetest.add_item(pos, leftover) end
    note(digger, key)
    minetest.chat_send_player(digger:get_player_name(), minetest.colorize("#7FD18B",
        TAG .. S("You found: @1!", sp.name)) .. " " .. minetest.colorize("#cccccc", sp.fact))
end

local function zone_by_id(id)
    for _, zone in ipairs(zones.list()) do
        if zone.id == id then return zone end
    end
end

local function skeleton_done(rec, sk, pos)
    sk.done = true
    local sp = species_info(sk.species)
    local zone = zone_by_id(rec.zone)
    for _, player in ipairs(minetest.get_connected_players()) do
        local here = zone and zones.zone_at(player:get_pos()) == zone
        if here or vector.distance(player:get_pos(), pos) < 24 then
            note(player, sk.species)
            minetest.chat_send_player(player:get_player_name(), minetest.colorize("#7FD18B",
                TAG .. S("Skeleton uncovered: @1!", sp.name)) .. " " .. minetest.colorize("#cccccc", sp.fact))
        end
    end
    for _, cell in ipairs(sk.cells) do
        burst(cell, "classrooms_bridge_spark.png^[multiply:#ffe066")
    end
end

brush_bone = function(pos, user)
    local name = user and user:get_player_name() or ""
    local node = minetest.get_node(pos)
    if our_nodes[node.name] ~= "covered" then
        if our_nodes[node.name] == "small" then
            hint(name, S("Fossils in rock are freed with the hammer."))
        end
        return
    end
    if minetest.is_protected(pos, name) then
        minetest.record_protection_violation(pos, name)
        return
    end
    local h = hash(pos)
    strokes[h] = (strokes[h] or 0) + 1
    burst(pos, "classrooms_bridge_dig_ground.png")
    local def = minetest.registered_nodes[node.name]
    if def and def.sounds and def.sounds.dig then
        minetest.sound_play(def.sounds.dig, { pos = pos, gain = 0.5, max_hear_distance = 12 }, true)
    end
    if strokes[h] < STROKES then return end
    strokes[h] = nil
    local entry = index[h]
    local rec = entry and load_record(entry.id)
    local sk = rec and rec.skeletons[entry.i]
    local cell = sk and sk.cells[entry.j]
    if not cell then
        minetest.swap_node(pos, { name = P .. "bone_spine" })
        return
    end
    cell.open = true
    minetest.swap_node(pos, { name = P .. "bone_" .. cell.part, param2 = cell.rot })
    local all = true
    for _, c in ipairs(sk.cells) do
        if not c.open then all = false break end
    end
    if all and not sk.done then skeleton_done(rec, sk, pos) end
    save_record(entry.id)
end

-- ── Placement ────────────────────────────────────────────────────────────────

local DEPTHS = { { 2, 6 }, { 4, 12 }, { 8, 24 } }

local function natural_ground(name)
    local def = minetest.registered_nodes[name]
    if not def or not def.walkable then return false end
    local g = def.groups or {}
    if g.tree or g.leaves or g.wood or g.cobble then return false end
    return (g.stone or g.dirt or g.soil or g.sand or g.sandstone or g.material_sand) ~= nil
        or host_suffix[name] ~= nil
end

local function make_finder(site)
    local top = (site.ref_y and math.floor(site.ref_y) or 120) + 60
    local bottom = (site.ref_y and math.floor(site.ref_y) or 0) - 90
    local cache = {}
    -- Highest natural ground of a column, or nil.
    return function(x, z)
        local k = x .. "," .. z
        if cache[k] == nil then
            cache[k] = false
            minetest.load_area({ x = x, y = bottom, z = z }, { x = x, y = top, z = z })
            for y = top, bottom, -1 do
                local n = minetest.get_node({ x = x, y = y, z = z }).name
                if natural_ground(n) then
                    cache[k] = y
                    break
                end
            end
        end
        return cache[k] or nil
    end
end

-- Local skeleton cell (lx along the body, lz across) in direction dir:
-- 0 +X, 1 +Z, 2 -X, 3 -Z, and the facedir turning the head that way.
local ROTATE = {
    [0] = function(lx, lz) return lx, lz end,
    [1] = function(lx, lz) return -lz, lx end,
    [2] = function(lx, lz) return -lx, -lz end,
    [3] = function(lx, lz) return lz, -lx end,
}
local FACEDIR = { [0] = 0, [1] = 3, [2] = 2, [3] = 1 }

local function place(site, mission)
    if not site.min_x then return end
    local settings = mission.settings or {}
    local want_small = math.max(0, math.min(60, tonumber(settings.small) or 0))
    local want_skel = math.max(0, math.min(6, tonumber(settings.skeletons) or 0))
    local depth = DEPTHS[tonumber(settings.depth) or 2] or DEPTHS[2]
    local rng = PcgRandom(mission.id * 7919 + os.time())
    local function clue_xz(x, z)
        return math.max(site.min_x, math.min(site.max_x, x + rng:next(-CLUE_SPREAD, CLUE_SPREAD))),
            math.max(site.min_z, math.min(site.max_z, z + rng:next(-CLUE_SPREAD, CLUE_SPREAD)))
    end
    local surface = make_finder(site)
    local used = {}
    local rec = { zone = site.id, small = {}, skeletons = {},
        help = tonumber(settings.help) or HELP_DETECTOR }
    local x1, x2, z1, z2 = site.min_x + 1, site.max_x - 1, site.min_z + 1, site.max_z - 1
    if x2 < x1 then x1, x2 = site.min_x, site.max_x end
    if z2 < z1 then z1, z2 = site.min_z, site.max_z end

    local function host_at(p)
        if used[hash(p)] then return nil end
        local node = minetest.get_node(p)
        return host_suffix[node.name] and node or nil
    end

    -- Skeletons first: they need more room.
    for s = 1, want_skel do
        local sp = SKELETONS[(s - 1) % #SKELETONS + 1]
        if s > #SKELETONS then sp = SKELETONS[rng:next(1, #SKELETONS)] end
        for _ = 1, 40 do
            local dir = rng:next(0, 3)
            local ox, oz = rng:next(x1, x2), rng:next(z1, z2)
            local cells, lowest, ok = {}, math.huge, true
            for row, line in ipairs(sp.shape) do
                for col = 1, #line do
                    local part = PARTS[line:sub(col, col)]
                    if part then
                        local dx, dz = ROTATE[dir](col - 1, row - 2)
                        local x, z = ox + dx, oz + dz
                        local surf = (x >= site.min_x and x <= site.max_x and z >= site.min_z and z <= site.max_z)
                            and surface(x, z)
                        if not surf then ok = false break end
                        lowest = math.min(lowest, surf)
                        table.insert(cells, { x = x, z = z, part = part })
                    end
                end
                if not ok then break end
            end
            if ok then
                local y = lowest - rng:next(depth[1], depth[2])
                for _, c in ipairs(cells) do
                    c.y = y
                    local node = host_at(c)
                    if not node then ok = false break end
                    c.orig, c.p2, c.node = node.name, node.param2, node.name
                end
            end
            if ok then
                local sk = { species = sp.key, cells = {}, sy = lowest }
                local mid = cells[math.ceil(#cells / 2)]
                sk.cx, sk.cz = clue_xz(mid.x, mid.z)
                for _, c in ipairs(cells) do
                    used[hash(c)] = true
                    minetest.swap_node(c, { name = P .. "bone_covered_" .. host_suffix[c.orig] })
                    table.insert(sk.cells, { x = c.x, y = c.y, z = c.z, orig = c.orig, p2 = c.p2,
                        part = c.part, rot = FACEDIR[dir] })
                end
                table.insert(rec.skeletons, sk)
                break
            end
        end
    end

    for i = 1, want_small do
        for _ = 1, 30 do
            local x, z = rng:next(x1, x2), rng:next(z1, z2)
            local surf = surface(x, z)
            if surf then
                local p = { x = x, y = surf - rng:next(depth[1], depth[2]), z = z }
                local node = host_at(p)
                if node then
                    used[hash(p)] = true
                    minetest.swap_node(p, { name = P .. "fossil_" .. host_suffix[node.name] })
                    local cx, cz = clue_xz(x, z)
                    table.insert(rec.small, { x = p.x, y = p.y, z = p.z, orig = node.name, p2 = node.param2,
                        species = SMALL[(i - 1) % #SMALL + 1].key, cx = cx, cz = cz, sy = surf })
                    break
                end
            end
        end
    end

    rec.short_small = want_small - #rec.small
    rec.short_skeletons = want_skel - #rec.skeletons
    records[mission.id] = rec
    save_record(mission.id)
    index_record(mission.id, rec)
    local ids = active_ids()
    ids[tostring(mission.id)] = true
    storage:set_string(ACTIVE_KEY, minetest.write_json(ids))
    active[mission.id] = true
    minetest.log("action", ("[classrooms_bridge] Fossils for mission %d: %d small, %d skeletons in zone %s")
        :format(mission.id, #rec.small, #rec.skeletons, tostring(site.name)))

    if rec.short_small > 0 or rec.short_skeletons > 0 then
        -- Goals count the missing ones as found, so the mission can end.
        for _, player in ipairs(minetest.get_connected_players()) do
            if is_staff(player:get_player_name()) then
                hint(player:get_player_name(), S("Only @1 small fossils and @2 skeletons fit underground in @3: there is not enough rock.",
                    #rec.small, #rec.skeletons, tostring(site.name)))
            end
        end
    end
end

-- Puts back the rock where fossils and bones are still in place.
local function clean(id)
    local rec = load_record(id)
    if rec then
        local function restore(p)
            minetest.load_area(p)
            local node = minetest.get_node(p)
            if our_nodes[node.name] then
                minetest.swap_node(p, { name = p.orig, param2 = p.p2 or 0 })
            end
            index[hash(p)] = nil
            strokes[hash(p)] = nil
        end
        for _, f in ipairs(rec.small or {}) do restore(f) end
        for _, sk in ipairs(rec.skeletons or {}) do
            for _, cell in ipairs(sk.cells) do restore(cell) end
        end
    end
    records[id] = false
    storage:set_string(record_key(id), "")
    local ids = active_ids()
    ids[tostring(id)] = nil
    storage:set_string(ACTIVE_KEY, minetest.write_json(ids))
    active[id] = nil
end

-- ── Help: clues and detector ─────────────────────────────────────────────────

-- Fossils still hidden in a record: { pos, cx, cz, sy, bone }.
local function hidden(rec)
    local out = {}
    for _, f in ipairs(rec.small or {}) do
        if not f.found then table.insert(out, { pos = f, cx = f.cx, cz = f.cz, sy = f.sy }) end
    end
    for _, sk in ipairs(rec.skeletons or {}) do
        if not sk.done then
            for _, cell in ipairs(sk.cells) do
                if not cell.open then
                    table.insert(out, { pos = cell, cx = sk.cx, cz = sk.cz, sy = sk.sy, bone = true, skeleton = sk })
                end
            end
        end
    end
    return out
end

-- Top of the ground over a clue column, following holes the students dug.
local function clue_ground(cx, cz, sy, floor_y)
    for y = sy + 3, floor_y + 1, -1 do
        local node = minetest.get_node_or_nil({ x = cx, y = y, z = cz })
        if not node then return nil end
        local def = minetest.registered_nodes[node.name]
        if def and def.walkable then return y + 1 end
    end
    return floor_y + 1
end

local function puff(pos, bone)
    minetest.add_particlespawner({
        amount = bone and 10 or 6, time = CLUE_EVERY,
        minpos = { x = pos.x - 0.7, y = pos.y - 0.4, z = pos.z - 0.7 },
        maxpos = { x = pos.x + 0.7, y = pos.y - 0.2, z = pos.z + 0.7 },
        minvel = { x = -0.1, y = 0.3, z = -0.1 }, maxvel = { x = 0.1, y = 0.8, z = 0.1 },
        minexptime = 1.2, maxexptime = 2.2, minsize = 1.5, maxsize = bone and 3.5 or 2.5,
        texture = bone and "classrooms_bridge_spark.png^[multiply:#efe6cf" or "classrooms_bridge_dig_ground.png",
        glow = bone and 6 or 2,
    })
end

local clue_timer = 0
minetest.register_globalstep(function(dtime)
    clue_timer = clue_timer + dtime
    if clue_timer < CLUE_EVERY or not next(active) then return end
    clue_timer = 0
    local players = minetest.get_connected_players()
    for id in pairs(active) do
        local rec = load_record(id)
        local zone = rec and (rec.help or HELP_NONE) >= HELP_CLUES and zone_by_id(rec.zone)
        if zone then
            local near = {}
            for _, player in ipairs(players) do
                if zones.zone_at(player:get_pos()) == zone then table.insert(near, player:get_pos()) end
            end
            if #near > 0 then
                local shown = {}
                for _, target in ipairs(hidden(rec)) do
                    local key = target.cx .. "," .. target.cz
                    if not shown[key] and target.cx then
                        for _, p in ipairs(near) do
                            if math.abs(p.x - target.cx) <= CLUE_RANGE and math.abs(p.z - target.cz) <= CLUE_RANGE then
                                shown[key] = true
                                local y = clue_ground(target.cx, target.cz, target.sy, target.pos.y)
                                if y then puff({ x = target.cx, y = y, z = target.cz }, target.bone) end
                                break
                            end
                        end
                    end
                end
            end
        end
    end
end)

local detector_huds = {} -- [player] = { id, token }
local detector_last = {} -- [player] = time of the last use

local function detector_message(player, text, color)
    local name = player:get_player_name()
    local old = detector_huds[name]
    if old then player:hud_remove(old.id) end
    local token = {}
    detector_huds[name] = { token = token, id = player:hud_add({
        type = "text", position = { x = 0.5, y = 0.72 }, alignment = { x = 0, y = 0 },
        text = text, number = color, size = { x = 1.5 }, style = 1, z_index = 110,
    }) }
    minetest.after(3, function()
        local current = minetest.get_player_by_name(name)
        local hud = detector_huds[name]
        if current and hud and hud.token == token then
            current:hud_remove(hud.id)
            detector_huds[name] = nil
        end
    end)
end

use_detector = function(player)
    local name = player:get_player_name()
    local now = minetest.get_us_time() / 1e6
    if detector_last[name] and now - detector_last[name] < 1 then return end
    detector_last[name] = now
    local pos = player:get_pos()
    local zone = zones.zone_at(pos)
    local best, best_d
    for id in pairs(active) do
        local rec = load_record(id)
        if rec and zone and zone_by_id(rec.zone) == zone then
            for _, target in ipairs(hidden(rec)) do
                local d = vector.distance(pos, target.pos)
                if not best_d or d < best_d then best, best_d = target, d end
            end
        end
    end
    if not best then
        detector_message(player, zone and S("No fossils left to find here.")
            or S("Use the detector inside the dig site."), 0xCCCCCC)
        return
    end
    local text, color
    if best_d <= 4 then
        text, color = S("Very hot! A fossil is right here."), 0xFF5A3C
    elseif best_d <= 10 then
        text, color = S("Hot: a fossil is very close."), 0xFFA03C
    elseif best_d <= 20 then
        text, color = S("Warm: a fossil is not far."), 0xFFE066
    else
        text, color = S("Cold: the nearest fossil is far away."), 0x6FB7FF
    end
    local below = math.floor(pos.y + 0.5) - best.pos.y
    if below >= 2 then
        text = text .. "\n" .. S("About @1 blocks below you.", below)
    end
    detector_message(player, text, color)
    minetest.sound_play("mcl_experience", { to_player = name, gain = 0.3,
        pitch = best_d <= 4 and 2 or (best_d <= 10 and 1.5 or (best_d <= 20 and 1.1 or 0.7)) }, true)
    -- A short trail of sparks pointing the way along the ground.
    local dir = { x = best.pos.x - pos.x, y = 0, z = best.pos.z - pos.z }
    if vector.length(dir) > 2 then
        dir = vector.normalize(dir)
        for i = 1, 4 do
            minetest.add_particle({
                pos = { x = pos.x + dir.x * i * 0.8, y = pos.y + 0.6, z = pos.z + dir.z * i * 0.8 },
                velocity = vector.multiply(dir, 0.6), expirationtime = 1.2, size = 2.5, glow = 12,
                texture = "classrooms_bridge_spark.png^[multiply:#7fd18b", playername = name,
            })
        end
    end
end

minetest.register_on_leaveplayer(function(player)
    detector_huds[player:get_player_name()] = nil
    detector_last[player:get_player_name()] = nil
end)

-- ── Registration ─────────────────────────────────────────────────────────────

missions.register_special(KIND, {
    label = S("Find the fossils"),
    description = S("Fossils and skeletons hidden underground in the zone"),
    icon = P .. "fossil_ammonite",
    zone_only = true,
    dig = true,
    settings = {
        { key = "small", label = S("Small fossils to hide"), type = "number", default = 10, min = 0, max = 40 },
        { key = "skeletons", label = S("Skeletons to hide"), type = "number", default = 1, min = 0, max = 4 },
        { key = "depth", label = S("How deep"), type = "choice", default = 2,
          options = { S("Shallow (2-6 blocks)"), S("Medium (4-12 blocks)"), S("Deep (8-24 blocks)") } },
        { key = "help", label = S("Help to find them"), type = "choice", default = HELP_DETECTOR,
          options = { S("None"), S("Dust clues on the ground"), S("Dust clues and fossil detector") } },
    },
    goals = {
        { key = "fossils_small", label = S("Fossils found"), icon = P .. "fossil_ammonite", count_from = "small" },
        { key = "fossils_skeletons", label = S("Skeletons uncovered"), icon = P .. "bone_skull", count_from = "skeletons" },
    },
    tools = { HAMMER, BRUSH, NOTEBOOK, { name = DETECTOR, setting = "help", min = HELP_DETECTOR } },
    on_start = place,
    on_stop = clean,
    on_presence = function(player, inside)
        if inside then wear_helmet(player) else remove_helmet(player) end
    end,
    count = function(_, goal, mission, previous)
        local rec = load_record(mission.id)
        if not rec then return previous or 0 end
        local n = 0
        if goal.key == "fossils_small" then
            for _, f in ipairs(rec.small or {}) do if f.found then n = n + 1 end end
            return n + math.max(0, rec.short_small or 0)
        elseif goal.key == "fossils_skeletons" then
            for _, sk in ipairs(rec.skeletons or {}) do if sk.done then n = n + 1 end end
            return n + math.max(0, rec.short_skeletons or 0)
        end
        return previous or 0
    end,
})
