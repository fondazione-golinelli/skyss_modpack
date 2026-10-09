-- Zone and world missions.
--
-- The classrooms proxy stores one mission per zone and sends it inside the
-- "set_zones" payload (zone.mission); world missions (not tied to a zone)
-- come in the payload's "missions" list. This module:
--   * builds the catalog of deliverable items, animals, blocks and support
--     tools that exist in this world, and sends it to the proxy on request;
--   * provides the delivery chest students put items into;
--   * counts progress every few seconds, shows it in a HUD to participants
--     and staff, and reports it to the proxy ("mission_progress");
--   * gives participants the support tools the first time they enter the
--     mission's zone (world missions: the first time they are in the world).
-- World missions count animals and blocks around their delivery chest.
-- Completion is sticky: once every goal was met the mission stays completed.

local zones, send, is_staff = ...

local storage = minetest.get_mod_storage()
local TICK = 3
local REPORT_EVERY = 30
local BLOCK_BAND_DOWN, BLOCK_BAND_UP = 24, 40
local ANIMAL_BAND = 64
local HUD_MAX_MISSIONS = 2
local WORLD_RADIUS = 16 -- world missions: animals and blocks around the chest

local missions = {}
local world_missions = {} -- world missions from the proxy

function missions.set_world(list)
    world_missions = type(list) == "table" and list or {}
end

local function world_mission(id)
    for _, mission in ipairs(world_missions) do
        if mission.id == id then return mission end
    end
end

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

-- Item meta fields that make a chest item recognisable; kept in the node's
-- meta while placed, so digging it gives the same item back.
local CHEST_ITEM_FIELDS = { "description", "count_meta", "palette_index", "mission_id", "mission_ref", "zone" }


local function chest_key(zone_id)
    return "mission_chest_" .. tostring(zone_id)
end

local chest_viewers = {} -- [player] = pos string of the chest they look at

-- ── Item pictures ────────────────────────────────────────────────────────────

-- A flat texture for an item, usable in HUDs: its inventory image, or a face
-- of the node (front, side or top). Animated tiles have no single frame.
local function item_texture(name)
    local def = name and minetest.registered_items[name]
    if not def then return nil end
    if type(def.inventory_image) == "string" and def.inventory_image ~= "" then
        return def.inventory_image
    end
    local tiles = def.tiles
    if type(tiles) ~= "table" or #tiles == 0 then return nil end
    local tile = tiles[#tiles >= 6 and 6 or (#tiles >= 3 and 3 or 1)]
    if type(tile) == "table" then
        if tile.animation then return nil end
        tile = tile.name or tile.image
    end
    return type(tile) == "string" and tile ~= "" and tile or nil
end
missions.item_texture = item_texture

local function goal_icon(goal)
    local entry = resolve(goal.type == "collect" and "deliver" or goal.type, goal.key)
    return entry and entry.icon
end

-- ── Chest colors ─────────────────────────────────────────────────────────────
-- The chest's trim takes the color of its zone or group (param2 color4dir,
-- palette index = param2 // 4). Index 0 is the neutral gold.

local PALETTE = { "#c9a25a", "#e05252", "#4f8fe0", "#3fb56b", "#e0b43f", "#a35ce0",
    "#3fc8c8", "#e07a3f", "#d95fa6", "#9aa3b5", "#7fd18b", "#4fb3ff" }
local DEFAULT_COLOR = "#4fb3ff"

local function hex_rgb(color)
    local h = tostring(color or ""):gsub("^#", "")
    if #h < 6 then return nil end
    return tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16)
end

local function palette_index(color)
    local r, g, b = hex_rgb(color)
    if not r then return 0 end
    local best, best_d = 0, math.huge
    for i, c in ipairs(PALETTE) do
        local cr, cg, cb = hex_rgb(c)
        local d = (r - cr) ^ 2 + (g - cg) ^ 2 + (b - cb) ^ 2
        if d < best_d then best, best_d = i - 1, d end
    end
    return best
end
missions.palette_index = palette_index

local function set_chest_color(pos, color)
    local node = minetest.get_node(pos)
    if node.name ~= CHEST then return end
    local param2 = node.param2 % 4 + palette_index(color) * 4
    if param2 ~= node.param2 then
        node.param2 = param2
        minetest.swap_node(pos, node)
    end
end

-- The chest's mission, where it is played and its color: a world mission the
-- chest was given for, or the mission of the zone it stands in.
local function chest_mission(pos)
    local meta = minetest.get_meta(pos)
    local mission_id = meta:get_int("mission_id")
    if mission_id ~= 0 then
        local mission = world_mission(mission_id)
        return mission, "Whole world", mission and mission.color or DEFAULT_COLOR
    end
    local id = meta:get_int("zone_id")
    local zone
    for _, z in ipairs(zones.list()) do
        if id ~= 0 and z.id == id then zone = z end
    end
    zone = zone or zones.zone_at(pos)
    return zone and zone.mission, zone and ("Zone " .. zone.name), zone and zone.color or PALETTE[1]
end

-- Delivery goals of the chest's mission: { label, need, have, names = set, icon }.
local function chest_requests(pos)
    local mission, place, color = chest_mission(pos)
    local list = {}
    if not mission then return list, place, mission, color end
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
    return list, place, mission, color
end

local function mission_done(mission)
    return mission and storage:get_string("mission_done_" .. tostring(mission.id)) == "1"
end

-- ── Chest window ─────────────────────────────────────────────────────────────

local OTHER_GOAL_TEXT = {
    collect = "Gather %d %s",
    animals = "%d %s %s",
    blocks = "%d %s blocks %s",
}

local function chest_formspec(pos, viewer)
    local spos = pos.x .. "," .. pos.y .. "," .. pos.z
    local requests, place, mission, color = chest_requests(pos)
    local done = mission_done(mission)
    local esc = minetest.formspec_escape
    local grey = function(t) return esc(minetest.colorize("#aaaaaa", t)) end
    local W = 12.4
    local fs = {}
    local function add(f, ...) table.insert(fs, select("#", ...) > 0 and f:format(...) or f) end

    -- Requested items: two columns of cards.
    local rows = math.max(1, math.ceil(math.min(#requests, 6) / 2))
    local description = mission and not done and mission.description and mission.description ~= ""
        and tostring(mission.description)
    local cards_top = description and 2.3 or 1.85
    local others = {}
    for _, goal in ipairs(mission and mission.objectives or {}) do
        if goal.type ~= "deliver" then table.insert(others, goal) end
    end
    local others_h = #others > 0 and 0.95 or 0
    local inv_top = cards_top + 0.45 + rows * 1.2 + 0.25 + others_h
    local H = inv_top + 7.85

    add("formspec_version[6]size[%g,%g]", W, H)
    add("bgcolor[#141a2a;true]box[0,0;%g,%g;#141a2a]", W, H)
    add("box[0,0;%g,1.45;#0f3460]box[0,1.45;%g,0.05;%s]", W, W, color or "#e94560")
    add("box[0,0;0.18,1.45;%s]", color or "#e94560")
    add("item_image[0.4,0.25;0.95,0.95;%s]", CHEST)
    add("style_type[label;textcolor=#f0f0f0]")
    add("style_type[label;font_size=*1.35]")
    add("label[1.6,0.48;%s]", esc(mission and tostring(mission.title) or "Delivery chest"))
    add("style_type[label;font_size=*1]")
    local sub = mission and ("Delivery chest  ·  " .. (place or "")) or "Delivery chest  ·  no mission uses it"
    if done then sub = sub .. "  ·  completed" end
    add("label[1.6,1.0;%s]", grey(sub))
    add("button_exit[%g,0.37;0.72,0.72;chest_close;X]", W - 0.95)

    add("box[0.3,1.7;%g,%g;#202a44]", W - 0.6, inv_top - 1.95)
    local heading = done and "MISSION COMPLETE: THANK YOU!" or "BRING THESE ITEMS"
    add("label[0.55,1.98;%s]", esc(minetest.colorize(done and "#7fd18b" or "#aaaaaa", heading)))
    if description then
        if #description > 80 then description = description:sub(1, 78) .. "..." end
        add("label[0.55,2.4;%s]", grey(description))
    end
    if #requests == 0 then
        add("label[0.55,%g;%s]", cards_top + 0.8, grey(mission and "This mission asks for no deliveries."
            or "No mission uses this chest."))
    end
    local card_w = (W - 0.6 - 0.6) / 2
    for i, r in ipairs(requests) do
        if i > 6 then break end
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        local x, y = 0.5 + col * (card_w + 0.2), cards_top + 0.45 + row * 1.2
        local met = done or r.have >= r.need
        add("box[%g,%g;%g,1.08;%s]", x, y, card_w, met and "#24412f" or "#28334f")
        add("box[%g,%g;0.08,1.08;%s]", x, y, met and "#3fb56b" or (color or "#2a8c7f"))
        if r.icon then add("item_image[%g,%g;0.85,0.85;%s]", x + 0.2, y + 0.12, r.icon) end
        local count = math.min(r.have, r.need) .. " / " .. r.need
        add("label[%g,%g;%s]", x + 1.2, y + 0.27, esc(r.label))
        add("label[%g,%g;%s]", x + card_w - 0.2 - #count * 0.17, y + 0.27,
            esc(minetest.colorize(met and "#7fd18b" or "#f0f0f0", count)))
        local bar_x, bar_w = x + 1.2, card_w - 1.4
        add("box[%g,%g;%g,0.2;#151b2e]", bar_x, y + 0.5, bar_w)
        local ratio = math.min(1, r.have / math.max(r.need, 1))
        if met then ratio = 1 end
        if ratio > 0 then
            add("box[%g,%g;%g,0.2;%s]", bar_x, y + 0.5, bar_w * ratio, met and "#3fb56b" or "#2a8c7f")
        end
        add("label[%g,%g;%s]", x + 1.2, y + 0.89, met
            and esc(minetest.colorize("#7fd18b", "Done!"))
            or grey((r.need - r.have) .. " more needed"))
    end

    -- The mission's other goals, for context.
    if #others > 0 then
        local y = cards_top + 0.45 + rows * 1.2 + 0.1
        add("label[0.55,%g;%s]", y + 0.3, grey("ALSO:"))
        local x = 1.45
        for i, goal in ipairs(others) do
            if i > 3 then break end
            local icon = goal_icon(goal)
            if icon then add("item_image[%g,%g;0.55,0.55;%s]", x, y + 0.03, icon) end
            local text = (OTHER_GOAL_TEXT[goal.type] or "%d %s"):format(tonumber(goal.count) or 1,
                tostring(goal.label or goal.key), place == "Whole world" and "near the chest" or "in the zone")
            add("label[%g,%g;%s]", x + 0.65, y + 0.3, esc(text))
            x = x + 0.75 + #text * 0.17 + 0.35
        end
    end

    -- Inventories with visible slots, in the panel style.
    add("listcolors[#2a3450;#3a4a78;#0f1424;#202a44;#f0f0f0]")
    add("style_type[list;size=0.85,0.85;spacing=0.15,0.15]")
    local lx = (W - (9 * 0.85 + 8 * 0.15)) / 2
    add("label[%g,%g;%s]", lx, inv_top + 0.2, grey(done and "CHEST" or "CHEST  (only the items above fit)"))
    add("list[nodemeta:%s;main;%g,%g;9,3;]", spos, lx, inv_top + 0.4)
    add("label[%g,%g;%s]", lx, inv_top + 3.55, grey("YOUR INVENTORY"))
    add("list[current_player;main;%g,%g;9,3;9]", lx, inv_top + 3.75)
    add("list[current_player;main;%g,%g;9,1;]", lx, inv_top + 6.8)
    add("listring[nodemeta:%s;main]listring[current_player;main]", spos)
    return table.concat(fs)
end

local function show_chest(player, pos)
    local name = player:get_player_name()
    chest_viewers[name] = minetest.pos_to_string(pos)
    minetest.show_formspec(name, CHEST, chest_formspec(pos, player))
end

-- ── Chest sign: floating text and items above the chest ─────────────────────

local DISPLAY = "classrooms_bridge:chest_display"
local DISPLAY_RANGE = 48
local displays = {} -- [pos string] = { label = obj, items = { obj }, items_sig, text }

minetest.register_entity(DISPLAY, {
    initial_properties = {
        visual = "sprite",
        textures = { "classrooms_bridge_blank.png" },
        visual_size = { x = 0.1, y = 0.1 },
        physical = false,
        pointable = false,
        collisionbox = { 0, 0, 0, 0, 0, 0 },
        selectionbox = { 0, 0, 0, 0, 0, 0 },
        static_save = false,
    },
})

local function alive(obj)
    return obj and obj:get_pos() ~= nil
end

local function remove_display(key)
    local d = displays[key]
    if not d then return end
    if alive(d.label) then d.label:remove() end
    for _, obj in ipairs(d.items or {}) do
        if alive(obj) then obj:remove() end
    end
    displays[key] = nil
end

-- Text shown above the chest and as its infotext.
local function chest_sign(requests, mission, done)
    if not mission then return "Delivery chest\n(no mission)" end
    local lines = { (done and "MISSION COMPLETE: " or "MISSION: ") .. tostring(mission.title) }
    if #requests == 0 then
        table.insert(lines, "Animals and blocks count around this chest")
    elseif not done then
        table.insert(lines, "Bring here:")
    end
    for i, r in ipairs(requests) do
        if i > 6 then break end
        local met = done or r.have >= r.need
        table.insert(lines, ("%s  %d/%d%s"):format(r.label, math.min(r.have, r.need), r.need, met and "  - done" or ""))
    end
    return table.concat(lines, "\n")
end

local function update_display(pos, players)
    local key = minetest.pos_to_string(pos)
    local requests, _, mission, color = chest_requests(pos)
    local done = mission_done(mission)
    local text = chest_sign(requests, mission, done)
    local meta = minetest.get_meta(pos)
    if meta:get_string("infotext") ~= text then meta:set_string("infotext", text) end
    set_chest_color(pos, color)

    local near = false
    for _, player in ipairs(players) do
        if vector.distance(player:get_pos(), pos) <= DISPLAY_RANGE then near = true end
    end
    if not near then
        remove_display(key)
        return
    end
    local d = displays[key] or { items = {} }
    displays[key] = d
    if not alive(d.label) then
        d.label = minetest.add_entity(vector.add(pos, { x = 0, y = 1.55, z = 0 }), DISPLAY)
        d.text = nil
    end
    if d.label and d.text ~= text then
        d.label:set_properties({
            nametag = text,
            nametag_color = done and "#7fd18b" or (color or "#ffffff"),
            nametag_bgcolor = "#000000b0",
        })
        d.text = text
    end
    -- Requested items float and spin above the chest, in a ring.
    local names = {}
    for i, r in ipairs(requests) do
        if i <= 6 and r.icon then table.insert(names, r.icon) end
    end
    local sig = table.concat(names, ",")
    local any_dead = false
    for _, obj in ipairs(d.items) do
        if not alive(obj) then any_dead = true end
    end
    if sig ~= d.items_sig or any_dead then
        for _, obj in ipairs(d.items) do
            if alive(obj) then obj:remove() end
        end
        d.items = {}
        local radius = #names > 1 and 0.32 or 0
        for i, name in ipairs(names) do
            local angle = (i - 1) / #names * math.pi * 2
            local obj = minetest.add_entity(vector.add(pos, {
                x = math.cos(angle) * radius, y = 1.05, z = math.sin(angle) * radius }), DISPLAY)
            if obj then
                obj:set_properties({
                    visual = "wielditem",
                    wield_item = name,
                    visual_size = { x = 0.2, y = 0.2, z = 0.2 },
                    automatic_rotate = 1.2,
                    glow = 6,
                })
                table.insert(d.items, obj)
            end
        end
        d.items_sig = sig
    end
    -- A few sparks in the mission color while it is in progress.
    if mission and not done then
        local spark = "classrooms_bridge_spark.png^[multiply:" .. (color or DEFAULT_COLOR)
        minetest.add_particlespawner({
            amount = 6,
            time = TICK,
            minpos = vector.add(pos, { x = -0.45, y = 0.4, z = -0.45 }),
            maxpos = vector.add(pos, { x = 0.45, y = 0.6, z = 0.45 }),
            minvel = { x = 0, y = 0.4, z = 0 },
            maxvel = { x = 0, y = 0.8, z = 0 },
            minexptime = 1.2,
            maxexptime = 2.2,
            minsize = 1,
            maxsize = 1.6,
            glow = 12,
            texture = { name = spark, alpha_tween = { 1, 0 }, blend = "add" },
        })
    end
end

-- Keeps the signs of every mission chest up to date (called every tick).
function missions.update_chests(players)
    local seen = {}
    local function visit(key)
        local pos = minetest.string_to_pos(storage:get_string(chest_key(key)))
        if not pos then return end
        local node = minetest.get_node_or_nil(pos)
        if not node or node.name ~= CHEST then return end
        seen[minetest.pos_to_string(pos)] = true
        update_display(pos, players)
    end
    for _, zone in ipairs(zones.list()) do
        if zone.mission then visit(zone.id) end
    end
    for _, mission in ipairs(world_missions) do
        visit("g" .. tostring(mission.id))
    end
    for key in pairs(displays) do
        if not seen[key] then remove_display(key) end
    end
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
    if displays[key] then
        displays[key].text = nil
        update_display(pos, minetest.get_connected_players())
    end
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= CHEST then return false end
    if fields.quit or fields.chest_close then
        chest_viewers[player:get_player_name()] = nil
    end
    return true
end)

local function trimmed(base, trim)
    return { { name = base, color = "white" } }, { name = trim }
end

local tile_top, trim_top = trimmed("classrooms_bridge_chest_top.png", "classrooms_bridge_chest_trim_top.png")
local tile_side, trim_side = trimmed("classrooms_bridge_chest_side.png", "classrooms_bridge_chest_trim_side.png")
local tile_front, trim_front = trimmed("classrooms_bridge_chest_front.png", "classrooms_bridge_chest_trim_front.png")

minetest.register_node(CHEST, {
    description = "Delivery Chest\n" .. minetest.colorize("#aaaaaa", "Place it inside a mission zone"),
    -- Wood stays white-tinted; the trim overlay takes the palette color.
    tiles = { tile_top[1], tile_top[1], tile_side[1], tile_side[1], tile_side[1], tile_front[1] },
    overlay_tiles = { trim_top, trim_top, trim_side, trim_side, trim_side, trim_front },
    paramtype2 = "color4dir",
    palette = "classrooms_bridge_chest_palette.png",
    groups = { not_in_creative_inventory = 1, handy = 1, axey = 1, dig_immediate = 2 },
    is_ground_content = false,
    _mcl_hardness = 1,
    stack_max = 1,
    drop = CHEST,
    on_construct = function(pos)
        local meta = minetest.get_meta(pos)
        meta:get_inventory():set_size("main", 27)
        meta:set_string("infotext", "Delivery chest")
    end,
    after_place_node = function(pos, placer, itemstack)
        local name = placer and placer:get_player_name() or ""
        local item_meta = itemstack and itemstack:get_meta()
        -- A zone mission's chest only goes into its own zone.
        local wanted_zone = item_meta and item_meta:get_string("zone") or ""
        if wanted_zone ~= "" and item_meta:get_int("mission_id") == 0 then
            local here = zones.zone_at(pos)
            if not here or here.name ~= wanted_zone then
                minetest.remove_node(pos)
                minetest.chat_send_player(name, minetest.colorize("#FFB347",
                    "[Mission] This delivery chest belongs inside zone " .. wanted_zone .. "."))
                return true -- keep the item
            end
        end
        -- Remember the item, so digging the chest gives the same one back.
        if item_meta then
            local fields = {}
            for _, key in ipairs(CHEST_ITEM_FIELDS) do
                local v = item_meta:get_string(key)
                if v ~= "" then fields[key] = v end
            end
            minetest.get_meta(pos):set_string("chest_item", minetest.write_json(fields))
        end
        -- A chest given for a world mission works anywhere.
        local mission_id = item_meta and item_meta:get_int("mission_id") or 0
        if mission_id ~= 0 then
            local mission = world_mission(mission_id)
            local title = mission and tostring(mission.title) or "mission"
            storage:set_string(chest_key("g" .. mission_id), minetest.pos_to_string(pos))
            local meta = minetest.get_meta(pos)
            meta:set_int("mission_id", mission_id)
            meta:set_string("infotext", "Delivery chest: " .. title)
            set_chest_color(pos, mission and mission.color or DEFAULT_COLOR)
            minetest.chat_send_player(name, minetest.colorize("#00CC66",
                "[Mission] Delivery chest set for mission " .. title .. "."))
            return
        end
        local zone = zones.zone_at(pos)
        if not zone then
            set_chest_color(pos, PALETTE[1])
            minetest.chat_send_player(name, minetest.colorize("#FFB347",
                "[Mission] Place the delivery chest inside a zone."))
            return
        end
        storage:set_string(chest_key(zone.id), minetest.pos_to_string(pos))
        local meta = minetest.get_meta(pos)
        meta:set_int("zone_id", zone.id)
        meta:set_string("infotext", "Delivery chest: " .. zone.name)
        set_chest_color(pos, zone.color)
        minetest.chat_send_player(name, minetest.colorize("#00CC66",
            "[Mission] Delivery chest set for zone " .. zone.name .. "."))
    end,
    can_dig = function(pos, player)
        return player and is_staff(player:get_player_name())
    end,
    after_destruct = function(pos)
        remove_display(minetest.pos_to_string(pos))
    end,
    preserve_metadata = function(_, _, oldmeta, drops)
        local fields = oldmeta.chest_item and minetest.parse_json(oldmeta.chest_item)
        if type(fields) ~= "table" then return end
        for _, drop in ipairs(drops) do
            if drop:get_name() == CHEST then
                local meta = drop:get_meta()
                for key, v in pairs(fields) do meta:set_string(key, tostring(v)) end
            end
        end
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

-- Short mark printed on the chest icon (count_meta): the initials of the
-- mission title, or its first letters when it is a single word.
local function mission_tag(title)
    local words = {}
    for word in tostring(title or ""):gmatch("[%w]+") do table.insert(words, word) end
    if #words == 0 then return "" end
    if #words == 1 then return words[1]:sub(1, 4):upper() end
    local tag = ""
    for i = 1, math.min(3, #words) do tag = tag .. words[i]:sub(1, 1):upper() end
    return tag
end
missions.mission_tag = mission_tag

-- Gives a delivery chest. For a world mission (mission_id) it is bound to
-- that mission and works anywhere; otherwise to the zone it is placed in.
-- The item is named after the mission, shows its initials and color, and
-- lists what it collects. A teacher gets at most one per mission.
function missions.give_chest(player, mission_id, title, info)
    info = info or {}
    local inv = player:get_inventory()
    local name = player:get_player_name()
    local ref = tonumber(info.ref) or mission_id
    local mission = mission_id and world_mission(mission_id)
    title = title or (mission and mission.title)
    if ref then
        for _, held in ipairs(inv:get_list("main") or {}) do
            if held:get_name() == CHEST and held:get_meta():get_int("mission_ref") == ref then
                minetest.chat_send_player(name, minetest.colorize("#FFB347",
                    "[Mission] You already have the delivery chest of " .. tostring(title or "this mission") .. "."))
                return
            end
        end
    end
    local stack = ItemStack(CHEST)
    local meta = stack:get_meta()
    if mission_id then
        meta:set_int("mission_id", mission_id)
    end
    if ref then
        meta:set_int("mission_ref", ref)
    end
    if info.zone then
        meta:set_string("zone", tostring(info.zone))
    end
    if title then
        local wanted = {}
        for _, goal in ipairs(mission and mission.objectives or info.objectives or {}) do
            if goal.type == "deliver" then table.insert(wanted, tostring(goal.label or goal.key)) end
        end
        local tag = mission_tag(title)
        local lines = { "Delivery Chest: " .. tostring(title) }
        table.insert(lines, minetest.colorize("#aaaaaa", mission_id and "Whole world: place it anywhere"
            or ("Place it inside zone " .. tostring(info.zone or "of the mission"))))
        if #wanted > 0 then
            table.insert(lines, minetest.colorize("#ffe066", "Collects: " .. table.concat(wanted, ", ")))
        end
        if tag ~= "" then
            table.insert(lines, minetest.colorize("#aaaaaa", "Marked \"" .. tag .. "\" on the icon"))
        end
        meta:set_string("description", table.concat(lines, "\n"))
        meta:set_string("count_meta", tag)
        -- Inventory icon in the mission color (items use the palette index).
        meta:set_string("palette_index", tostring(palette_index(info.color or (mission and mission.color))))
    end
    local leftover = inv:add_item("main", stack)
    if not leftover:is_empty() then
        minetest.chat_send_player(name, minetest.colorize("#FFB347",
            "[Mission] Your inventory is full."))
        return
    end
    minetest.chat_send_player(name, minetest.colorize("#00CC66",
        mission_id and "[Mission] Place the delivery chest where students should bring things."
        or "[Mission] Place the delivery chest inside the zone."))
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

-- Participants: listed names (group or class). Staff see every mission.
local function is_participant(mission, name)
    for _, p in ipairs(mission.participants or {}) do
        if p == name then return true end
    end
    return false
end

-- Where a world mission counts animals and blocks: around its chest.
local function world_site(mission)
    local site = { id = "g" .. tostring(mission.id), global = true }
    local pos = minetest.string_to_pos(storage:get_string(chest_key(site.id)))
    if pos then
        site.min_x, site.max_x = pos.x - WORLD_RADIUS, pos.x + WORLD_RADIUS
        site.min_z, site.max_z = pos.z - WORLD_RADIUS, pos.z + WORLD_RADIUS
        site.ref_y = pos.y
    end
    return site
end

local function count_goal(zone, goal, previous, mission)
    local kind = goal.type == "collect" and "deliver" or goal.type
    local entry = resolve(kind, goal.key)
    if not entry then return 0 end
    local names = {}
    for _, n in ipairs(entry.names) do names[n] = true end
    local ref_y = zone.ref_y or 0

    -- Gather: items in the inventories of participants online here.
    if goal.type == "collect" then
        local total, online = 0, false
        for _, player in ipairs(minetest.get_connected_players()) do
            if is_participant(mission, player:get_player_name()) then
                online = true
                for _, stack in ipairs(player:get_inventory():get_list("main") or {}) do
                    if names[stack:get_name()] then total = total + stack:get_count() end
                end
            end
        end
        if not online then return previous or 0 end
        return total
    end

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

    if not zone.min_x then return 0 end -- world mission without its chest
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

local GOAL_VERBS = { deliver = "Deliver", collect = "Gather", animals = "Animals:", blocks = "Blocks:" }

local function goal_label(goal)
    return (GOAL_VERBS[goal.type] or "") .. " " .. tostring(goal.label or goal.key)
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
local HUD_ICON_PX = 24 -- goal picture column (16 px textures at 1.1x, plus a gap)

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
            local icon = item_texture(goal_icon(goal))
            for j, text in ipairs(goal_lines) do
                table.insert(lines, { text = j == 1 and text or ("     " .. text), color = ok and 0x7FD18B or 0xFFFFFF,
                    icon = j == 1 and icon or nil, indent = icon ~= nil })
            end
        end
        if state.needs_chest then
            table.insert(lines, { text = "Waiting for the teacher's delivery chest", color = 0xFFB347 })
        end
        table.insert(lines, { text = "", color = 0xFFFFFF })
    end
    -- Redraw only when the text changed.
    local parts = {}
    for _, line in ipairs(lines) do table.insert(parts, line.text .. (line.icon or "")) end
    local signature = table.concat(parts, "\n")
    local name = player:get_player_name()
    if huds[name] and huds[name].signature == signature then return end
    clear_hud(player)
    if #list == 0 then return end
    local height = #lines * 20 + 16
    local widest = 0
    for _, line in ipairs(lines) do
        widest = math.max(widest, #line.text * (line.size and HUD_CHAR_PX + 1 or HUD_CHAR_PX)
            + (line.indent and HUD_ICON_PX or 0))
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
        -- Goal pictures form a column at the right edge, text on their left.
        if line.icon then
            table.insert(ids, player:hud_add({
                type = "image",
                position = { x = 1, y = 0.2 },
                offset = { x = -22, y = y },
                alignment = { x = -1, y = 1 },
                scale = { x = 1.1, y = 1.1 },
                text = line.icon,
                z_index = 91,
            }))
        end
        table.insert(ids, player:hud_add({
            type = "text",
            position = { x = 1, y = 0.2 },
            offset = { x = line.indent and -(24 + HUD_ICON_PX) or -24, y = y },
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
    if zone.min_x then fireworks(zone) end
    for _, player in ipairs(minetest.get_connected_players()) do
        local name = player:get_player_name()
        local participant = is_participant(mission, name)
        if participant or is_staff(name) then
            -- World missions: the title and fireworks are for everyone playing.
            if zone.global or zones.zone_at(player:get_pos()) == zone then
                show_title(player, "Mission complete!", tostring(mission.title))
            end
            if zone.global and not zone.min_x and participant then
                local p = vector.round(player:get_pos())
                fireworks({ min_x = p.x - 2, max_x = p.x + 2, min_z = p.z - 2, max_z = p.z + 2, ref_y = p.y })
            end
            minetest.chat_send_player(name, minetest.colorize("#7FD18B",
                "[Mission] \"" .. tostring(mission.title) .. "\" completed"
                .. (zone.global and "" or (" in zone " .. zone.name)) .. "!"))
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

-- Counts, completes and reports one mission played at a site (its zone, or
-- the area around a world mission's chest), and lists it for HUDs.
local function update_mission(site, mission, players, visible)
    local state = progress[mission.id] or { counts = {} }
    progress[mission.id] = state
    state.complete = state.complete or storage:get_string(done_key(mission.id)) == "1"
    if not state.complete then
        local all = #(mission.objectives or {}) > 0
        state.needs_chest = false
        for i, goal in ipairs(mission.objectives or {}) do
            state.counts[i] = count_goal(site, goal, state.counts[i], mission)
            if state.counts[i] < (tonumber(goal.count) or 1) then all = false end
            if (goal.type == "deliver" and chest_inventory(site.id) == nil)
                    or (site.global and not site.min_x and (goal.type == "animals" or goal.type == "blocks")) then
                state.needs_chest = true
            end
        end
        if all then
            state.complete = true
            storage:set_string(done_key(mission.id), "1")
            announce_complete(site, mission)
        end
    end
    state.chest = storage:get_string(chest_key(site.id)) ~= ""

    for _, player in ipairs(players) do
        local name = player:get_player_name()
        local participant = is_participant(mission, name)
        -- A zone's mission panel shows only while standing in its zone; a
        -- world mission leaves the HUD once completed (the teacher still
        -- sees it as completed in World Tools).
        local here = site.global or zones.zone_at(player:get_pos()) == site
        if here and (participant or is_staff(name)) and not (site.global and state.complete) then
            visible[name] = visible[name] or {}
            table.insert(visible[name], { mission = mission, state = state, mine = participant })
        end
        if participant and here then
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

local function step()
    local players = minetest.get_connected_players()
    if #players == 0 then return end
    local visible = {} -- [name] = list
    for _, zone in ipairs(zones.list()) do
        if zone.mission and zone.mission.id then
            update_mission(zone, zone.mission, players, visible)
        end
    end
    for _, mission in ipairs(world_missions) do
        if mission.id then
            update_mission(world_site(mission), mission, players, visible)
        end
    end
    missions.update_chests(players)
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
