-- Zone missions.
--
-- The classrooms proxy stores one mission per zone and sends it inside the
-- "set_zones" payload (zone.mission). This module:
--   * builds the catalog of deliverable items, animals, blocks and support
--     tools that exist in this world, and sends it to the proxy on request;
--   * provides the delivery chest students put items into;
--   * counts progress every few seconds, shows it in a HUD to participants
--     and staff, and reports it to the proxy ("mission_progress");
--   * gives participants the support tools the first time they enter the
--     mission's zone.
-- Completion is sticky: once every goal was met the mission stays completed.

local zones, send, is_staff = ...

local storage = minetest.get_mod_storage()
local TICK = 3
local REPORT_EVERY = 30
local BLOCK_BAND_DOWN, BLOCK_BAND_UP = 24, 40
local ANIMAL_BAND = 64
local HUD_MAX_MISSIONS = 2

local missions = {}

-- ── Catalog ──────────────────────────────────────────────────────────────────
-- Each entry lists candidate names; only those registered in this world are
-- kept, so renamed items in the game don't break the catalog.

local CANDIDATES = {
    deliver = {
        { "wheat", "mcl_farming:wheat_item" },
        { "carrot", "mcl_farming:carrot_item" },
        { "potato", "mcl_farming:potato_item" },
        { "beetroot", "mcl_farming:beetroot_item" },
        { "bread", "mcl_farming:bread" },
        { "apple", "mcl_core:apple" },
        { "egg", "mcl_throwing:egg" },
        { "milk", "mcl_mobitems:milk_bucket" },
        { "wool", "mcl_wool:white" },
        { "leather", "mcl_mobitems:leather" },
        { "feather", "mcl_mobitems:feather" },
        { "sugar_cane", "mcl_core:reeds" },
        { "pumpkin", "mcl_farming:pumpkin" },
        { "oak_log", "mcl_trees:tree_oak", "mcl_core:tree" },
        { "oak_planks", "mcl_trees:wood_oak", "mcl_core:wood" },
        { "cobblestone", "mcl_core:cobble" },
        { "iron_ingot", "mcl_core:iron_ingot" },
        { "gold_ingot", "mcl_core:gold_ingot" },
        { "coal", "mcl_core:coal_lump", "mcl_core:charcoal_lump" },
        { "stick", "mcl_core:stick" },
    },
    animals = {
        { "cow", "mobs_mc:cow" },
        { "sheep", "mobs_mc:sheep" },
        { "pig", "mobs_mc:pig" },
        { "chicken", "mobs_mc:chicken" },
        { "horse", "mobs_mc:horse" },
        { "donkey", "mobs_mc:donkey" },
        { "rabbit", "mobs_mc:rabbit" },
        { "llama", "mobs_mc:llama" },
        { "mooshroom", "mobs_mc:mooshroom" },
        { "wolf", "mobs_mc:wolf" },
        { "cat", "mobs_mc:cat", "mobs_mc:ocelot" },
        { "parrot", "mobs_mc:parrot" },
        { "goat", "mobs_mc:goat" },
    },
    blocks = {
        { "water", "Water", "mcl_core:water_source" },
        { "farmland", "Farmland", "mcl_farming:soil", "mcl_farming:soil_wet" },
        { "planks", "Wooden planks", "group:wood" },
        { "logs", "Logs", "group:tree" },
        { "fences", "Fences", "group:fence" },
        { "flowers", "Flowers", "group:flower" },
        { "glass", "Glass", "mcl_core:glass" },
        { "cobblestone", "Cobblestone", "mcl_core:cobble" },
        { "stone_bricks", "Stone bricks", "mcl_core:stonebrick" },
        { "sand", "Sand", "mcl_core:sand" },
        { "hay", "Hay bales", "mcl_farming:hay_block" },
        { "wool", "Wool", "group:wool" },
        { "leaves", "Leaves", "group:leaves" },
        { "torches", "Torches", "group:torch" },
        { "crafting_table", "Crafting tables", "mcl_crafting_table:crafting_table" },
        { "furnace", "Furnaces", "mcl_furnaces:furnace", "mcl_furnaces:furnace_active" },
    },
    tools = {
        { "water_bucket", "mcl_buckets:bucket_water" },
        { "bucket", "mcl_buckets:bucket_empty" },
        { "iron_hoe", "mcl_farming:hoe_iron", "mcl_tools:hoe_iron" },
        { "iron_shovel", "mcl_tools:shovel_iron" },
        { "iron_axe", "mcl_tools:axe_iron" },
        { "iron_pickaxe", "mcl_tools:pick_iron" },
        { "wheat_seeds", "mcl_farming:wheat_seeds" },
        { "carrot", "mcl_farming:carrot_item" },
        { "potato", "mcl_farming:potato_item" },
        { "wheat", "mcl_farming:wheat_item" },
        { "bone_meal", "mcl_bone_meal:bone_meal" },
        { "oak_sapling", "mcl_trees:sapling_oak", "mcl_core:sapling" },
        { "oak_planks", "mcl_trees:wood_oak", "mcl_core:wood" },
        { "fence", "mcl_fences:fence" },
        { "fence_gate", "mcl_fences:fence_gate" },
        { "torch", "mcl_torches:torch" },
        { "lead", "mcl_mobitems:lead" },
        { "iron_ingot", "mcl_core:iron_ingot" },
        { "coal", "mcl_core:coal_lump", "mcl_core:charcoal_lump" },
        { "stick", "mcl_core:stick" },
        { "crafting_table", "mcl_crafting_table:crafting_table" },
        { "furnace", "mcl_furnaces:furnace" },
        { "cow_egg", "mobs_mc:cow" },
        { "sheep_egg", "mobs_mc:sheep" },
        { "pig_egg", "mobs_mc:pig" },
        { "chicken_egg", "mobs_mc:chicken" },
    },
}

local catalog -- [kind] = { {key, label, names = {...}} }, built lazily

local function item_name(name)
    if minetest.registered_items[name] then return name end
    local alias = minetest.registered_aliases[name]
    if alias and minetest.registered_items[alias] then return alias end
end

local function item_label(name)
    local def = minetest.registered_items[name]
    local text = def and def.description or name
    text = minetest.strip_colors(text):match("^[^\n]*")
    return text ~= "" and text or name
end

-- First node (by name) in a group, used as the group's icon; nil if none.
local function group_member(group)
    local best
    for name, def in pairs(minetest.registered_nodes) do
        if (def.groups or {})[group] and (not best or name < best)
                and not (def.groups or {}).not_in_creative_inventory then
            best = name
        end
    end
    return best
end

local function title_case(key)
    return (key:gsub("_", " "):gsub("^%l", string.upper))
end

local function build_catalog()
    local result = { deliver = {}, animals = {}, blocks = {}, tools = {} }
    for _, kind in ipairs({ "deliver", "tools" }) do
        for _, entry in ipairs(CANDIDATES[kind]) do
            for i = 2, #entry do
                local name = item_name(entry[i])
                if name then
                    local label = item_label(name)
                    if kind == "tools" and minetest.registered_entities[name] then
                        label = label .. " (spawn egg)"
                    end
                    table.insert(result[kind], { key = entry[1], label = label, names = { name }, icon = name })
                    break
                end
            end
        end
    end
    for _, entry in ipairs(CANDIDATES.animals) do
        for i = 2, #entry do
            if minetest.registered_entities[entry[i]] then
                -- Spawn eggs share the mob's name: use them as the icon.
                local icon = minetest.registered_items[entry[i]] and entry[i] or nil
                table.insert(result.animals, { key = entry[1], label = title_case(entry[1]),
                    names = { entry[i] }, icon = icon })
                break
            end
        end
    end
    for _, entry in ipairs(CANDIDATES.blocks) do
        local names, icon = {}, nil
        for i = 3, #entry do
            local n = entry[i]
            if n:sub(1, 6) == "group:" then
                local member = group_member(n:sub(7))
                if member then
                    table.insert(names, n)
                    icon = icon or member
                end
            elseif minetest.registered_nodes[n] then
                table.insert(names, n)
                icon = icon or n
            end
        end
        if #names > 0 then
            table.insert(result.blocks, { key = entry[1], label = entry[2], names = names, icon = icon })
        end
    end
    return result
end

function missions.catalog()
    catalog = catalog or build_catalog()
    return catalog
end

local function resolve(kind, key)
    for _, entry in ipairs(missions.catalog()[kind] or {}) do
        if entry.key == key then return entry end
    end
end

-- Catalog without the resolved names, for the proxy.
function missions.catalog_payload()
    local out = {}
    for kind, list in pairs(missions.catalog()) do
        out[kind] = {}
        for _, entry in ipairs(list) do
            table.insert(out[kind], { key = entry.key, label = entry.label, icon = entry.icon })
        end
    end
    return out
end

-- ── Delivery chest ───────────────────────────────────────────────────────────

local CHEST = "classrooms_bridge:delivery_chest"

local function chest_key(zone_id)
    return "mission_chest_" .. tostring(zone_id)
end

local chest_viewers = {} -- [player] = pos string of the chest they look at

local function chest_zone(pos)
    local id = minetest.get_meta(pos):get_int("zone_id")
    for _, zone in ipairs(zones.list()) do
        if (id ~= 0 and zone.id == id) then return zone end
    end
    return zones.zone_at(pos)
end

-- Delivery goals of the chest's mission: { label, need, have, names = set, icon }.
local function chest_requests(pos)
    local zone = chest_zone(pos)
    local mission = zone and zone.mission
    local list = {}
    if not mission then return list, zone, mission end
    local inv = minetest.get_meta(pos):get_inventory()
    for _, goal in ipairs(mission.objectives or {}) do
        if goal.type == "deliver" then
            local entry = resolve("deliver", goal.key)
            if entry then
                local names, have = {}, 0
                for _, n in ipairs(entry.names) do names[n] = true end
                for _, stack in ipairs(inv:get_list("main") or {}) do
                    if names[stack:get_name()] then have = have + stack:get_count() end
                end
                table.insert(list, { label = goal.label or entry.label, need = tonumber(goal.count) or 1,
                    have = have, names = names, icon = entry.icon })
            end
        end
    end
    return list, zone, mission
end

local function chest_formspec(pos, viewer)
    local spos = pos.x .. "," .. pos.y .. "," .. pos.z
    local requests, zone, mission = chest_requests(pos)
    local esc = minetest.formspec_escape
    local fs = {
        "formspec_version[6]size[12,11.6]",
        "bgcolor[#141a2a;true]box[0,0;12,11.6;#141a2a]",
        "box[0,0;12,1.0;#0f3460]box[0,1.0;12,0.05;#e94560]",
        "style_type[label;textcolor=#f0f0f0]",
        "label[0.35,0.35;" .. esc("Delivery chest") .. "]",
        "label[0.35,0.72;" .. esc(minetest.colorize("#aaaaaa",
            (zone and ("Zone " .. zone.name) or "No zone") ..
            (mission and ("  ·  " .. tostring(mission.title)) or ""))) .. "]",
        "button_exit[11.1,0.17;0.72,0.66;chest_close;X]",
        "box[0.3,1.3;11.4,2.6;#202a44]",
        "label[0.55,1.6;" .. esc(minetest.colorize("#aaaaaa", "REQUESTED ITEMS")) .. "]",
    }
    if #requests == 0 then
        table.insert(fs, "label[0.55,2.3;" .. esc(minetest.colorize("#aaaaaa",
            mission and "This mission asks for no deliveries." or "This zone has no mission.")) .. "]")
    end
    for i, r in ipairs(requests) do
        if i > 6 then break end
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        local x, y = 0.5 + col * 5.65, 1.9 + row * 0.65
        local done = r.have >= r.need
        table.insert(fs, ("box[%g,%g;5.45,0.58;#28334f]"):format(x, y))
        if r.icon then
            table.insert(fs, ("item_image[%g,%g;0.5,0.5;%s]"):format(x + 0.05, y + 0.04, r.icon))
        end
        table.insert(fs, ("label[%g,%g;%s]"):format(x + 0.65, y + 0.29, esc(r.label)))
        local w = 1.9
        table.insert(fs, ("box[%g,%g;%g,0.2;#151b2e]"):format(x + 2.55, y + 0.19, w))
        local ratio = math.min(1, r.have / math.max(r.need, 1))
        if ratio > 0 then
            table.insert(fs, ("box[%g,%g;%g,0.2;%s]"):format(x + 2.55, y + 0.19, w * ratio, done and "#3fb56b" or "#2a8c7f"))
        end
        table.insert(fs, ("label[%g,%g;%s]"):format(x + 4.55, y + 0.29,
            esc(minetest.colorize(done and "#7fd18b" or "#f0f0f0", math.min(r.have, r.need) .. "/" .. r.need))))
    end
    table.insert(fs, "label[0.55,3.65;" .. esc(minetest.colorize("#aaaaaa",
        "Only these items fit, up to the amount still missing.")) .. "]")

    -- Inventories with visible slots, in the panel style.
    table.insert(fs, "listcolors[#2a3450;#3a4a78;#0f1424;#202a44;#f0f0f0]")
    table.insert(fs, "style_type[list;size=0.85,0.85;spacing=0.15,0.15]")
    local lx = (12 - (9 * 0.85 + 8 * 0.15)) / 2
    table.insert(fs, "label[" .. lx .. ",4.3;" .. esc(minetest.colorize("#aaaaaa", "CHEST")) .. "]")
    table.insert(fs, ("list[nodemeta:%s;main;%g,4.5;9,3;]"):format(spos, lx))
    table.insert(fs, "label[" .. lx .. ",7.65;" .. esc(minetest.colorize("#aaaaaa", "YOUR INVENTORY")) .. "]")
    table.insert(fs, ("list[current_player;main;%g,7.85;9,3;9]"):format(lx))
    table.insert(fs, ("list[current_player;main;%g,10.75;9,1;]"):format(lx))
    table.insert(fs, ("listring[nodemeta:%s;main]listring[current_player;main]"):format(spos))
    return table.concat(fs)
end

local function show_chest(player, pos)
    local name = player:get_player_name()
    chest_viewers[name] = minetest.pos_to_string(pos)
    minetest.show_formspec(name, CHEST, chest_formspec(pos, player))
end

-- Redraw the chest for everyone looking at it (progress changed).
local function refresh_chest(pos)
    local key = minetest.pos_to_string(pos)
    for name, viewed in pairs(chest_viewers) do
        if viewed == key then
            local player = minetest.get_player_by_name(name)
            if player then show_chest(player, pos) else chest_viewers[name] = nil end
        end
    end
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= CHEST then return false end
    if fields.quit or fields.chest_close then
        chest_viewers[player:get_player_name()] = nil
    end
    return true
end)

minetest.register_node(CHEST, {
    description = "Delivery Chest\n" .. minetest.colorize("#aaaaaa", "Place it inside a mission zone"),
    tiles = {
        "classrooms_bridge_chest_top.png", "classrooms_bridge_chest_top.png",
        "classrooms_bridge_chest_side.png", "classrooms_bridge_chest_side.png",
        "classrooms_bridge_chest_side.png", "classrooms_bridge_chest_front.png",
    },
    paramtype2 = "facedir",
    groups = { not_in_creative_inventory = 1, handy = 1, axey = 1, dig_immediate = 2 },
    is_ground_content = false,
    _mcl_hardness = 1,
    stack_max = 1,
    on_construct = function(pos)
        local meta = minetest.get_meta(pos)
        meta:get_inventory():set_size("main", 27)
        meta:set_string("infotext", "Delivery chest")
    end,
    after_place_node = function(pos, placer)
        local zone = zones.zone_at(pos)
        local name = placer and placer:get_player_name() or ""
        if not zone then
            minetest.chat_send_player(name, minetest.colorize("#FFB347",
                "[Mission] Place the delivery chest inside a zone."))
            return
        end
        storage:set_string(chest_key(zone.id), minetest.pos_to_string(pos))
        local meta = minetest.get_meta(pos)
        meta:set_int("zone_id", zone.id)
        meta:set_string("infotext", "Delivery chest: " .. zone.name)
        minetest.chat_send_player(name, minetest.colorize("#00CC66",
            "[Mission] Delivery chest set for zone " .. zone.name .. "."))
    end,
    can_dig = function(pos, player)
        return player and is_staff(player:get_player_name())
    end,
    on_rightclick = function(pos, _, clicker)
        if clicker and clicker:is_player() then
            show_chest(clicker, pos)
        end
    end,
    -- Only requested items, up to the amount still missing.
    allow_metadata_inventory_put = function(pos, _, _, stack, player)
        local requests = chest_requests(pos)
        for _, r in ipairs(requests) do
            if r.names[stack:get_name()] then
                return math.max(0, math.min(stack:get_count(), r.need - r.have))
            end
        end
        local wanted = {}
        for _, r in ipairs(requests) do table.insert(wanted, r.label) end
        minetest.chat_send_player(player:get_player_name(), minetest.colorize("#FFB347",
            #wanted > 0 and ("[Mission] This chest only takes: " .. table.concat(wanted, ", ") .. ".")
            or "[Mission] This chest takes nothing right now."))
        return 0
    end,
    -- Students deliver; only staff take items back out.
    allow_metadata_inventory_take = function(_, _, _, stack, player)
        return is_staff(player:get_player_name()) and stack:get_count() or 0
    end,
    allow_metadata_inventory_move = function(_, _, _, _, _, count, player)
        return is_staff(player:get_player_name()) and count or 0
    end,
    on_metadata_inventory_put = function(pos) refresh_chest(pos) end,
    on_metadata_inventory_take = function(pos) refresh_chest(pos) end,
    on_blast = function() end,
})

minetest.register_on_leaveplayer(function(player)
    chest_viewers[player:get_player_name()] = nil
end)

-- Students get the support tools again the next time they are in the zone.
function missions.reset_tools(mission_id)
    storage:set_string("mission_tools_" .. tostring(mission_id), "")
end

function missions.give_chest(player)
    local leftover = player:get_inventory():add_item("main", ItemStack(CHEST))
    if not leftover:is_empty() then
        minetest.chat_send_player(player:get_player_name(), minetest.colorize("#FFB347",
            "[Mission] Your inventory is full."))
        return
    end
    minetest.chat_send_player(player:get_player_name(), minetest.colorize("#00CC66",
        "[Mission] Place the delivery chest inside the zone."))
end

local function chest_inventory(zone_id)
    local pos = minetest.string_to_pos(storage:get_string(chest_key(zone_id)))
    if not pos then return nil end
    local node = minetest.get_node_or_nil(pos)
    if not node then return false end -- unloaded: keep the last count
    if node.name ~= CHEST then return nil end
    return minetest.get_meta(pos):get_inventory()
end

-- ── Progress ─────────────────────────────────────────────────────────────────

local progress = {}  -- [mission id] = { counts = {}, complete = bool, chest = bool }
local reported = {}  -- [mission id] = serialized last report
local huds = {}      -- [player] = { ids }

local function done_key(id) return "mission_done_" .. tostring(id) end
local function tools_key(id) return "mission_tools_" .. tostring(id) end

local function area_loaded(zone)
    local center = {
        x = (zone.min_x + zone.max_x) / 2,
        y = zone.ref_y or 0,
        z = (zone.min_z + zone.max_z) / 2,
    }
    return minetest.compare_block_status(center, "active") ~= false
        and minetest.get_node_or_nil(center) ~= nil
end

local function count_goal(zone, goal, previous)
    local kind = goal.type == "deliver" and "deliver" or goal.type
    local entry = resolve(kind, goal.key)
    if not entry then return 0 end
    local names = {}
    for _, n in ipairs(entry.names) do names[n] = true end
    local ref_y = zone.ref_y or 0

    if goal.type == "deliver" then
        local inv = chest_inventory(zone.id)
        if inv == false then return previous or 0 end
        if not inv then return 0 end
        local total = 0
        for _, stack in ipairs(inv:get_list("main") or {}) do
            if names[stack:get_name()] then total = total + stack:get_count() end
        end
        return total
    end

    if not area_loaded(zone) then return previous or 0 end

    if goal.type == "animals" then
        local total = 0
        local minp = { x = zone.min_x - 0.5, y = ref_y - ANIMAL_BAND, z = zone.min_z - 0.5 }
        local maxp = { x = zone.max_x + 0.5, y = ref_y + ANIMAL_BAND, z = zone.max_z + 0.5 }
        for obj in minetest.objects_in_area(minp, maxp) do
            local ent = obj:get_luaentity()
            if ent and names[ent.name] then total = total + 1 end
        end
        return total
    end

    if goal.type == "blocks" then
        local minp = { x = zone.min_x, y = ref_y - BLOCK_BAND_DOWN, z = zone.min_z }
        local maxp = { x = zone.max_x, y = ref_y + BLOCK_BAND_UP, z = zone.max_z }
        local _, counts = minetest.find_nodes_in_area(minp, maxp, entry.names)
        local total = 0
        for _, n in pairs(counts or {}) do total = total + n end
        return total
    end
    return 0
end

-- Participants: listed names (group or class). Staff see every mission.
local function is_participant(mission, name)
    for _, p in ipairs(mission.participants or {}) do
        if p == name then return true end
    end
    return false
end

local function goal_label(goal)
    local verb = goal.type == "deliver" and "Deliver" or (goal.type == "animals" and "Animals:" or "Blocks:")
    return verb .. " " .. tostring(goal.label or goal.key)
end

local function clear_hud(player)
    local name = player:get_player_name()
    for _, id in ipairs((huds[name] or {}).ids or {}) do
        player:hud_remove(id)
    end
    huds[name] = nil
end

-- Word-wraps text to lines of at most `width` characters.
local function wrap(text, width)
    local lines, line = {}, ""
    for word in tostring(text):gmatch("%S+") do
        if line ~= "" and #line + 1 + #word > width then
            table.insert(lines, line)
            line = word
        else
            line = line == "" and word or (line .. " " .. word)
        end
    end
    if line ~= "" then table.insert(lines, line) end
    return lines
end

local HUD_WRAP = 40
local HUD_CHAR_PX = 9

local function draw_hud(player, list)
    local ids = {}
    local y = 0
    local lines = {}
    for _, item in ipairs(list) do
        local mission, state = item.mission, item.state
        local heading = (state.complete and "MISSION COMPLETE: " or "MISSION: ") .. tostring(mission.title)
        for _, text in ipairs(wrap(heading, HUD_WRAP)) do
            table.insert(lines, { text = text, color = state.complete and 0x7FD18B or 0xFFE066, size = 1 })
        end
        if not state.complete and mission.description and mission.description ~= "" then
            for _, text in ipairs(wrap(mission.description, HUD_WRAP)) do
                table.insert(lines, { text = text, color = 0xCCCCCC })
            end
        end
        for i, goal in ipairs(mission.objectives or {}) do
            local have = state.counts[i] or 0
            local need = tonumber(goal.count) or 1
            local ok = state.complete or have >= need
            local goal_lines = wrap((ok and "[x] " or "[ ] ") .. goal_label(goal) .. "  "
                .. math.min(have, need) .. "/" .. need, HUD_WRAP)
            for j, text in ipairs(goal_lines) do
                table.insert(lines, { text = j == 1 and text or ("     " .. text), color = ok and 0x7FD18B or 0xFFFFFF })
            end
        end
        if state.needs_chest then
            table.insert(lines, { text = "Waiting for the teacher's delivery chest", color = 0xFFB347 })
        end
        table.insert(lines, { text = "", color = 0xFFFFFF })
    end
    -- Redraw only when the text changed.
    local parts = {}
    for _, line in ipairs(lines) do table.insert(parts, line.text) end
    local signature = table.concat(parts, "\n")
    local name = player:get_player_name()
    if huds[name] and huds[name].signature == signature then return end
    clear_hud(player)
    if #list == 0 then return end
    local height = #lines * 20 + 16
    local widest = 0
    for _, line in ipairs(lines) do
        widest = math.max(widest, #line.text * (line.size and HUD_CHAR_PX + 1 or HUD_CHAR_PX))
    end
    table.insert(ids, player:hud_add({
        type = "image",
        position = { x = 1, y = 0.2 },
        offset = { x = -12, y = -8 },
        alignment = { x = -1, y = 1 },
        scale = { x = widest + 28, y = height },
        text = "[fill:1x1:#00000088",
        z_index = 90,
    }))
    for _, line in ipairs(lines) do
        table.insert(ids, player:hud_add({
            type = "text",
            position = { x = 1, y = 0.2 },
            offset = { x = -24, y = y },
            alignment = { x = -1, y = 1 },
            text = line.text,
            number = line.color,
            style = line.size and 1 or 0,
            z_index = 91,
        }))
        y = y + 20
    end
    huds[name] = { ids = ids, signature = signature }
end

local FIREWORK_COLORS = { "#ff5a5a", "#ffd43b", "#5fd36a", "#4fb3ff", "#d27cff" }

-- Three bursts above the zone, like the clean-up minigame.
local function fireworks(zone)
    local base = {
        x = (zone.min_x + zone.max_x) / 2,
        y = (zone.ref_y or 0) + 6,
        z = (zone.min_z + zone.max_z) / 2,
    }
    local spread_x = math.min(6, (zone.max_x - zone.min_x) / 2)
    local spread_z = math.min(6, (zone.max_z - zone.min_z) / 2)
    for i = 1, 4 do
        minetest.after(i * 0.45, function()
            local center = {
                x = base.x + math.random() * 2 * spread_x - spread_x,
                y = base.y + math.random(0, 4),
                z = base.z + math.random() * 2 * spread_z - spread_z,
            }
            minetest.add_particlespawner({
                amount = 70,
                time = 0.05,
                minpos = center,
                maxpos = center,
                minvel = { x = -5, y = -4, z = -5 },
                maxvel = { x = 5, y = 5, z = 5 },
                minacc = { x = 0, y = -2.5, z = 0 },
                maxacc = { x = 0, y = -2.5, z = 0 },
                minexptime = 0.9,
                maxexptime = 1.8,
                minsize = 2,
                maxsize = 4,
                glow = 14,
                texture = {
                    name = "classrooms_bridge_spark.png^[multiply:" .. FIREWORK_COLORS[math.random(#FIREWORK_COLORS)],
                    alpha_tween = { 1, 0 },
                    blend = "add",
                },
            })
            minetest.sound_play("mcl_bows_firework", { pos = center, gain = 0.6, max_hear_distance = 64 }, true)
        end)
    end
end

local function show_title(player, title, subtitle)
    local name = player:get_player_name()
    local ids = {
        player:hud_add({
            type = "text", position = { x = 0.5, y = 0.3 }, alignment = { x = 0, y = 0 },
            text = title, number = 0x7FD18B, size = { x = 3 }, style = 1, z_index = 110,
        }),
        player:hud_add({
            type = "text", position = { x = 0.5, y = 0.3 }, offset = { x = 0, y = 46 },
            alignment = { x = 0, y = 0 }, text = subtitle, number = 0xFFFFFF, size = { x = 1.4 }, z_index = 110,
        }),
    }
    minetest.after(4, function()
        local current = minetest.get_player_by_name(name)
        if current then
            for _, id in ipairs(ids) do current:hud_remove(id) end
        end
    end)
end

local function announce_complete(zone, mission)
    fireworks(zone)
    for _, player in ipairs(minetest.get_connected_players()) do
        local name = player:get_player_name()
        if is_participant(mission, name) or is_staff(name) then
            if zones.zone_at(player:get_pos()) == zone then
                show_title(player, "Mission complete!", tostring(mission.title))
            end
            minetest.chat_send_player(name, minetest.colorize("#7FD18B",
                "[Mission] \"" .. tostring(mission.title) .. "\" completed in zone " .. zone.name .. "!"))
        end
    end
end

local function give_tools(player, mission)
    if type(mission.tools) ~= "table" or #mission.tools == 0 then return end
    local name = player:get_player_name()
    local key = tools_key(mission.id)
    local given = minetest.parse_json(storage:get_string(key) ~= "" and storage:get_string(key) or "{}") or {}
    if given[name] then return end
    local inv = player:get_inventory()
    local got = {}
    for _, tool in ipairs(mission.tools) do
        local entry = resolve("tools", tool.key)
        if entry then
            local stack = ItemStack(entry.names[1] .. " " .. math.max(1, math.min(99, tonumber(tool.count) or 1)))
            local leftover = inv:add_item("main", stack)
            if not leftover:is_empty() then
                minetest.add_item(player:get_pos(), leftover)
            end
            table.insert(got, stack:get_count() .. " " .. entry.label)
        end
    end
    given[name] = true
    storage:set_string(key, minetest.write_json(given))
    if #got > 0 then
        minetest.chat_send_player(name, minetest.colorize("#00CCFF",
            "[Mission] Tools for this mission: " .. table.concat(got, ", ")))
    end
end

local function step()
    local players = minetest.get_connected_players()
    if #players == 0 then return end
    local visible = {} -- [name] = list
    for _, zone in ipairs(zones.list()) do
        local mission = zone.mission
        if mission and mission.id then
            local state = progress[mission.id] or { counts = {} }
            progress[mission.id] = state
            state.complete = state.complete or storage:get_string(done_key(mission.id)) == "1"
            if not state.complete then
                local all = #(mission.objectives or {}) > 0
                state.needs_chest = false
                for i, goal in ipairs(mission.objectives or {}) do
                    state.counts[i] = count_goal(zone, goal, state.counts[i])
                    if state.counts[i] < (tonumber(goal.count) or 1) then all = false end
                    if goal.type == "deliver" and chest_inventory(zone.id) == nil then
                        state.needs_chest = true
                    end
                end
                if all then
                    state.complete = true
                    storage:set_string(done_key(mission.id), "1")
                    announce_complete(zone, mission)
                end
            end
            state.chest = storage:get_string(chest_key(zone.id)) ~= ""

            for _, player in ipairs(players) do
                local name = player:get_player_name()
                local participant = is_participant(mission, name)
                -- The mission panel shows only while standing in its zone.
                local inside = zones.zone_at(player:get_pos()) == zone
                if inside and (participant or is_staff(name)) then
                    visible[name] = visible[name] or {}
                    table.insert(visible[name], { mission = mission, state = state, mine = participant })
                end
                if participant and inside then
                    give_tools(player, mission)
                end
            end

            local report = minetest.write_json({ state.counts, state.complete, state.chest })
            local now = minetest.get_us_time() / 1e6
            if report ~= reported[mission.id] or now - (state.reported_at or 0) > REPORT_EVERY then
                reported[mission.id] = report
                state.reported_at = now
                send({
                    action = "mission_progress",
                    mission = mission.id,
                    counts = state.counts,
                    complete = state.complete,
                    chest = state.chest,
                }, "mission_progress")
            end
        end
    end
    for _, player in ipairs(players) do
        local list = visible[player:get_player_name()] or {}
        -- Own missions first, at most a couple on screen.
        table.sort(list, function(a, b) return a.mine and not b.mine end)
        while #list > HUD_MAX_MISSIONS do table.remove(list) end
        draw_hud(player, list)
    end
end

local timer = 0
minetest.register_globalstep(function(dtime)
    timer = timer + dtime
    if timer < TICK then return end
    timer = 0
    local ok, err = pcall(step)
    if not ok then
        minetest.log("error", "[classrooms_bridge] Mission update failed: " .. tostring(err))
    end
end)

minetest.register_on_leaveplayer(function(player)
    huds[player:get_player_name()] = nil
end)

return missions
