-- World map for class worlds.
--
-- The map texture of each instance template is rendered offline by
-- tools/render_maps.py (bounds in maps.lua). This world uses the map of the
-- template named by INSTANCE_TEMPLATE_NAME (set by the classrooms plugin) or
-- the classrooms.map_template setting; without one the feature is off.
--
-- Everyone sees the map with zones, waypoints, teleport points and their own
-- position. Staff can add/remove waypoints and teleport points; students can
-- teleport to teleport points only.
--
-- On the "hub" map (the HUB lobby) every player carries the map, staff are the
-- hub admins (server or hub_admin privilege) and they can also move the spawn
-- point of the hub mod; there is no "Return to HUB" button. Waypoints are shown in the world as HUD
-- markers, light beams nearby, and a direction indicator to the nearest one.

-- `hooks.spawn()` returns the world spawn (pos, yaw); `hooks.return_hub(player)`
-- sends the player back to the HUB.
local modpath, zones, toolbar, is_staff, is_frozen, hooks = ...

local S = minetest.get_translator("classrooms_bridge")
local TAG_MAP = S("[Map]") .. " "

-- Translates on the server, for texts that are cut or stored here.
local function translate_for(name, text)
    local info = minetest.get_player_information(name)
    return minetest.get_translated_string(info and info.lang_code or "", text)
end

local FORM = "classrooms_bridge:map"
local ITEM = "classrooms_bridge:map"
local TOOL = "map"
local VIEW = 9.6          -- viewport size in formspec units
local GRID = 20           -- clickable cells per side at zoom ×1
local ZOOMS = { 1, 2, 4, 8 }
local MAX_MARKERS = 30
local BEAM_RANGE = 80
local TP_COOLDOWN = 3
local WAYPOINT_COLORS = { "#ff5a5a", "#ffd43b", "#5fd36a", "#4fb3ff", "#d27cff", "#ff9f43" }

local storage = minetest.get_mod_storage()
local worldmap = {}

local maps = dofile(modpath .. "/maps.lua")
local template = minetest.settings:get("classrooms.map_template") or os.getenv("INSTANCE_TEMPLATE_NAME")
local MAP = template and maps[template]
local TEXTURE = MAP and ("classrooms_bridge_map_" .. template .. ".png")

worldmap.available = MAP ~= nil
if MAP then
    minetest.log("action", "[classrooms_bridge] World map: " .. template)
end

local HUB_MODE = MAP ~= nil and template == "hub"
if HUB_MODE then
    is_staff = function(name)
        return minetest.check_player_privs(name, { server = true })
            or minetest.check_player_privs(name, { hub_admin = true })
    end
end

-- ── HUB spawn ────────────────────────────────────────────────────────────────

local HUB_SPAWN_KEY = "hub_spawn"

local function hub_spawn_point()
    local hub_mod = rawget(_G, "hub")
    return hub_mod and hub_mod.get_hub_spawn_point and hub_mod.get_hub_spawn_point()
end

-- The hub mod keeps references to its spawn vector, so it is changed in place.
local function apply_hub_spawn(pos)
    local spawn = hub_spawn_point()
    if spawn then
        spawn.x, spawn.y, spawn.z = pos.x, pos.y, pos.z
    end
    return spawn ~= nil
end

-- Spawn from the world's hub/SETTINGS.lua, before any change made on the map.
local original_spawn

-- Facing set by the hub mod on join (degrees in its settings).
local function hub_spawn_look()
    local hub_mod = rawget(_G, "hub")
    local settings = hub_mod and hub_mod.settings or {}
    return tonumber(settings.join_rotation_x) and math.rad(settings.join_rotation_x),
        tonumber(settings.join_rotation_y) and math.rad(settings.join_rotation_y)
end

if HUB_MODE then
    minetest.register_on_mods_loaded(function()
        local spawn = hub_spawn_point()
        original_spawn = spawn and vector.copy(spawn)
        local saved = storage:get_string(HUB_SPAWN_KEY)
        saved = saved ~= "" and minetest.parse_json(saved)
        if saved and apply_hub_spawn(saved) then
            minetest.log("action", ("[classrooms_bridge] HUB spawn: %d, %d, %d"):format(saved.x, saved.y, saved.z))
        end
    end)
end

-- ── Markers ──────────────────────────────────────────────────────────────────

local markers = minetest.parse_json(storage:get_string("map_markers") ~= "" and storage:get_string("map_markers") or "[]") or {}
local next_id = 1
for _, m in ipairs(markers) do next_id = math.max(next_id, (m.id or 0) + 1) end

local function save_markers()
    storage:set_string("map_markers", minetest.write_json(markers))
end

local function marker_by_id(id)
    for i, m in ipairs(markers) do
        if m.id == id then return m, i end
    end
end

local refresh_huds -- forward

local function solid_or_liquid(pos)
    local def = minetest.registered_nodes[minetest.get_node(pos).name]
    return def and (def.walkable or def.liquidtype == "source")
end

-- Highest walkable or liquid node of a column, after generating it. In the HUB
-- the lowest spot with headroom instead, so tree crowns and the floating logo
-- are not taken for the ground.
local function find_ground(x, z, callback)
    local p1, p2 = { x = x, y = -64, z = z }, { x = x, y = 255, z = z }
    minetest.emerge_area(p1, p2, function(_, _, remaining)
        if remaining > 0 then return end
        if HUB_MODE then
            for y = -64, 253 do
                if solid_or_liquid({ x = x, y = y, z = z }) and not solid_or_liquid({ x = x, y = y + 1, z = z })
                        and not solid_or_liquid({ x = x, y = y + 2, z = z }) then
                    callback(y + 1)
                    return
                end
            end
        end
        for y = 255, -64, -1 do
            local node = minetest.get_node({ x = x, y = y, z = z })
            local def = minetest.registered_nodes[node.name]
            if def and (def.walkable or def.liquidtype == "source") then
                callback(y + 1)
                return
            end
        end
        callback(10)
    end)
end

local function add_marker(kind, name, x, y, z)
    if #markers >= MAX_MARKERS then return false end
    local count = 0
    for _, m in ipairs(markers) do
        if m.kind == "waypoint" then count = count + 1 end
    end
    table.insert(markers, {
        id = next_id, kind = kind, name = name,
        x = x, y = y, z = z,
        color = kind == "waypoint" and WAYPOINT_COLORS[count % #WAYPOINT_COLORS + 1] or "#66e0ff",
    })
    next_id = next_id + 1
    save_markers()
    refresh_huds()
    return true
end

-- ── View state ───────────────────────────────────────────────────────────────
--
-- At zoom ×1 the whole map fits the viewport. At higher zooms the map is
-- drawn at full zoomed size inside two nested scroll containers, so panning
-- (mouse wheel, dragging the scrollbars) happens on the client without
-- redrawing. Scroll events only update the stored view; the form is redrawn
-- when the view leaves the band covered by the clickable grid.

local views = {} -- [name] = { cx, cz, zoom, sel, name_text, band, list_scroll }

local W = MAP and (MAP.max_x - MAP.min_x + 1) or 1
local D = MAP and (MAP.max_z - MAP.min_z + 1) or 1
local EXTENT = math.max(W, D)
local SCROLL_FACTOR = 0.1
local CELL = VIEW / 24     -- size of a clickable selection cell
local BAND_MARGIN = VIEW * 0.3 -- selection cells kept around the view when zoomed
-- Scrollbar thumb length as a share of the bar. A short thumb leaves a long
-- track, so dragging it moves the map close to 1:1 with the mouse at ×2.
local THUMB_SHARE = 0.06

local function clamp(v, lo, hi)
    if lo > hi then return (lo + hi) / 2 end
    return math.max(lo, math.min(hi, v))
end

-- Content size in formspec units at a zoom level.
local function content_size(zoom)
    local c = VIEW * zoom
    return c * W / EXTENT, c * D / EXTENT
end

local function node_to_content(x, z, zoom)
    local cw, ch = content_size(zoom)
    return (x - MAP.min_x) / W * cw, (MAP.max_z + 1 - z) / D * ch
end

local function content_to_node(px, py, zoom)
    local cw, ch = content_size(zoom)
    return math.floor(MAP.min_x + px / cw * W), math.floor(MAP.max_z + 1 - py / ch * D)
end

-- Scroll offsets (content units) that centre the view on (cx, cz).
local function scroll_for(v)
    local cw, ch = content_size(v.zoom)
    local px, py = node_to_content(v.cx, v.cz, v.zoom)
    return clamp(px - VIEW / 2, 0, math.max(0, cw - VIEW)), clamp(py - VIEW / 2, 0, math.max(0, ch - VIEW))
end

local function view_of(player)
    local name = player:get_player_name()
    local v = views[name]
    if not v then
        local pos = player:get_pos()
        v = { cx = pos.x, cz = pos.z, zoom = 2, name_text = "", list_scroll = 0 }
        views[name] = v
    end
    return v
end

-- ── Formspec ─────────────────────────────────────────────────────────────────

local C = { bg = "#141a2a", header = "#0f3460", accent = "#e94560", card = "#202a44", row = "#28334f",
    button = "#34446a", primary = "#2a8c7f", muted = "#aaaaaa", light = "#f0f0f0" }

local function esc(s) return minetest.formspec_escape(tostring(s)) end
local function colored(color, text) return esc(minetest.colorize(color, text)) end
-- Translated text for formspec elements.
local function F(...) return esc(S(...)) end

local function distance_to(player, x, z)
    local p = player:get_pos()
    local d = math.floor(math.sqrt((p.x - x) ^ 2 + (p.z - z) ^ 2) + 0.5)
    return d >= 1000 and string.format("%.1f km", d / 1000) or (d .. " m")
end

local function distance_text(player, m)
    return distance_to(player, m.x, m.z)
end

-- Zones the player may teleport to from the list: staff all, students the
-- zones of their own group.
local function teleport_zones(name, staff)
    local list = {}
    for _, zone in ipairs(zones.list()) do
        if zone.tp and (staff or (zone.allowed and zone.allowed[name])) then
            table.insert(list, zone)
        end
    end
    return list
end

local show -- forward

show = function(player)
    local name = player:get_player_name()
    local staff = is_staff(name)
    local v = view_of(player)
    local zoom = v.zoom
    local cw, ch = content_size(zoom)
    local sx, sy = scroll_for(v)
    local ox, oy = 0.3, 1.25
    local zoomed = zoom > 1

    local fs = {
        "formspec_version[6]size[17.2,11.25]",
        "bgcolor[" .. C.bg .. ";true]",
        "box[0,0;17.2,11.25;" .. C.bg .. "]",
        "style_type[button;bgcolor=" .. C.button .. ";border=false;textcolor=" .. C.light .. "]",
        "style_type[label;textcolor=" .. C.light .. "]",
        "box[0,0;17.2,1.0;" .. C.header .. "]box[0,1.0;17.2,0.05;" .. C.accent .. "]",
        "label[0.35,0.35;" .. colored(C.light, S("World map")) .. "]",
        "label[0.35,0.72;" .. colored(C.muted, zoomed
            and S("Wheel and scrollbars move the map · click to select")
            or S("Click the map to select a point")) .. "]",
        "image_button_exit[16.35,0.17;0.66,0.66;clear.png;map_close;]",
        ("style[map_spawn;bgcolor=%s]button[%g,0.2;3.75,0.6;map_spawn;%s]"):format(
            C.primary, staff and 12.45 or 9.7, F("Teleport to world spawn")),
        "tooltip[map_spawn;" .. F("Go back to where players arrive in this world") .. "]",
        ("box[%g,%g;%g,%g;#1b2033]"):format(ox, oy, VIEW, VIEW),
    }
    if not staff and not HUB_MODE then
        table.insert(fs, ("style[map_hub;bgcolor=%s]button_exit[13.55,0.2;2.65,0.6;map_hub;%s]"):format("#9b2c3c", F("Return to HUB")))
        table.insert(fs, "tooltip[map_hub;" .. F("Leave this world and go back to the HUB") .. "]")
    end

    if zoomed then
        local max_x = math.max(0, math.ceil((cw - VIEW) / SCROLL_FACTOR))
        local max_y = math.max(0, math.ceil((ch - VIEW) / SCROLL_FACTOR))
        local step = math.max(1, math.floor(VIEW / 10 / SCROLL_FACTOR))
        table.insert(fs, ("scrollbaroptions[min=0;max=%d;smallstep=%d;largestep=%d;thumbsize=%d]"):format(
            max_y, step, step * 4, math.max(1, math.floor((max_y + 1) * THUMB_SHARE))))
        table.insert(fs, ("scrollbar[%g,%g;0.3,%g;vertical;map_sv;%d]"):format(ox + VIEW + 0.05, oy, VIEW,
            math.floor(sy / SCROLL_FACTOR + 0.5)))
        table.insert(fs, ("scrollbaroptions[min=0;max=%d;smallstep=%d;largestep=%d;thumbsize=%d]"):format(
            max_x, step, step * 4, math.max(1, math.floor((max_x + 1) * THUMB_SHARE))))
        table.insert(fs, ("scrollbar[%g,%g;%g,0.3;horizontal;map_sh;%d]"):format(ox, oy + VIEW + 0.05, VIEW,
            math.floor(sx / SCROLL_FACTOR + 0.5)))
        -- The innermost container receives the mouse wheel: make it vertical.
        table.insert(fs, ("scroll_container[%g,%g;%g,%g;map_sh;horizontal;%g]"):format(ox, oy, VIEW, VIEW, SCROLL_FACTOR))
        table.insert(fs, ("scroll_container[0,0;%g,%g;map_sv;vertical;%g]"):format(cw, VIEW, SCROLL_FACTOR))
    else
        table.insert(fs, ("container[%g,%g]"):format(ox, oy))
    end

    -- Everything below is in content coordinates.
    local function pos(x, z) return node_to_content(x, z, zoom) end
    table.insert(fs, ("image[0,0;%g,%g;%s]"):format(cw, ch, TEXTURE))

    for _, zone in ipairs(zones.list()) do
        local x1, y1 = pos(zone.min_x, zone.max_z + 1)
        local x2, y2 = pos(zone.max_x + 1, zone.min_z)
        local bw, bh = x2 - x1, y2 - y1
        local color = zone.color:match("^#%x%x%x%x%x%x$") and zone.color or "#9aa3b5"
        local mine = zone.allowed and zone.allowed[name]
        local t = mine and 0.09 or 0.05
        table.insert(fs, ("box[%g,%g;%g,%g;%s50]"):format(x1, y1, bw, bh, color))
        table.insert(fs, ("box[%g,%g;%g,%g;%s]box[%g,%g;%g,%g;%s]"):format(x1, y1, bw, t, color, x1, y2 - t, bw, t, color))
        table.insert(fs, ("box[%g,%g;%g,%g;%s]box[%g,%g;%g,%g;%s]"):format(x1, y1, t, bh, color, x2 - t, y1, t, bh, color))
        if bw > 1.0 and bh > 0.4 then
            table.insert(fs, ("label[%g,%g;%s]"):format(x1 + 0.1, y1 + 0.22, colored(color, zone.name)))
        end
    end
    for _, m in ipairs(markers) do
        local px, py = pos(m.x, m.z)
        local icon = m.kind == "teleport" and "classrooms_bridge_map_tp.png"
            or ("classrooms_bridge_map_pin.png^[multiply:" .. m.color)
        local yoff = m.kind == "teleport" and 0.25 or 0.5
        table.insert(fs, ("image[%g,%g;0.5,0.5;%s]"):format(px - 0.25, py - yoff, esc(icon)))
    end
    -- Zone teleport points: staff every zone, students their group's zones.
    for _, zone in ipairs(teleport_zones(name, staff)) do
        local px, py = pos(zone.tp.x, zone.tp.z)
        local color = zone.color:match("^#%x%x%x%x%x%x$") and zone.color or "#9aa3b5"
        table.insert(fs, ("image[%g,%g;0.45,0.45;%s]"):format(px - 0.225, py - 0.225,
            esc("classrooms_bridge_map_tp.png^[multiply:" .. color)))
    end
    local me = player:get_pos()
    local mx, my = pos(me.x, me.z)
    table.insert(fs, ("image[%g,%g;0.42,0.42;classrooms_bridge_map_me.png]"):format(mx - 0.21, my - 0.21))
    if v.sel then
        local px, py = pos(v.sel.x, v.sel.z)
        table.insert(fs, ("box[%g,%g;0.5,0.04;#ffffff]box[%g,%g;0.04,0.5;#ffffff]"):format(
            px - 0.25, py - 0.02, px - 0.02, py - 0.25))
    end

    -- Selection grid: small cells over the whole map at ×1, over the view
    -- plus a margin when zoomed.
    v.band, v.cell = nil, nil
    do
        table.insert(fs, "style_type[image_button;border=false;bgcolor=#00000000;bgimg_hovered="
            .. esc("[fill:1x1:#ffffff22") .. "]")
        local i0, i1, j0, j1
        if zoomed then
            i0 = math.max(0, math.floor((sx - BAND_MARGIN) / CELL))
            i1 = math.min(math.ceil(cw / CELL) - 1, math.floor((sx + VIEW + BAND_MARGIN) / CELL))
            j0 = math.max(0, math.floor((sy - BAND_MARGIN) / CELL))
            j1 = math.min(math.ceil(ch / CELL) - 1, math.floor((sy + VIEW + BAND_MARGIN) / CELL))
            v.band = { x0 = i0 * CELL, x1 = (i1 + 1) * CELL, y0 = j0 * CELL, y1 = (j1 + 1) * CELL }
        else
            i0, i1, j0, j1 = 0, math.ceil(cw / CELL) - 1, 0, math.ceil(ch / CELL) - 1
        end
        v.cell = CELL
        for j = j0, j1 do
            for i = i0, i1 do
                table.insert(fs, ("image_button[%g,%g;%g,%g;blank.png;mc_%d_%d;]"):format(i * CELL, j * CELL, CELL, CELL, i, j))
            end
        end
    end

    -- Other players (staff, when shown): above the click grid so hovering
    -- shows the name and clicking selects their position.
    v.players = {}
    if staff and v.show_players ~= false then
        local group_of = {}
        for _, zone in ipairs(zones.list()) do
            if zone.group and zone.allowed then
                for member in pairs(zone.allowed) do
                    group_of[member] = { name = zone.group, color = zone.color }
                end
            end
        end
        for _, other in ipairs(minetest.get_connected_players()) do
            local other_name = other:get_player_name()
            if other ~= player then
                local p = other:get_pos()
                local px, py = pos(p.x, p.z)
                local group = group_of[other_name]
                local color, info = "#ffffff", other_name
                if is_staff(other_name) then
                    color, info = "#ffd43b", S("@1 (teacher)", other_name)
                elseif group then
                    color, info = group.color, S("@1 · group @2", other_name, group.name)
                end
                table.insert(v.players, { name = other_name, x = math.floor(p.x + 0.5), z = math.floor(p.z + 0.5) })
                local field = "map_pl_" .. #v.players
                table.insert(fs, ("image_button[%g,%g;0.42,0.42;%s;%s;]tooltip[%s;%s]"):format(
                    px - 0.21, py - 0.21, esc("classrooms_bridge_map_student.png^[multiply:" .. color),
                    field, field, esc(info)))
            end
        end
    end
    table.insert(fs, zoomed and "scroll_container_end[]scroll_container_end[]" or "container_end[]")

    -- Side panel.
    local px0 = 10.5
    table.insert(fs, ("box[%g,1.25;6.4,2.35;%s]"):format(px0, C.card))
    table.insert(fs, ("label[%g,1.55;%s]"):format(px0 + 0.2, colored(C.muted, S("ZOOM ×@1", zoom))))
    table.insert(fs, ("button[%g,1.3;0.8,0.55;map_zoom_out;-]button[%g,1.3;0.8,0.55;map_zoom_in;+]"):format(px0 + 2.2, px0 + 3.05))
    table.insert(fs, ("button[%g,1.3;1.6,0.55;map_me;%s]"):format(px0 + 4.6, F("Me")))
    table.insert(fs, "tooltip[map_me;" .. F("Center the map on your position") .. "]")
    table.insert(fs, ("button[%g,2.0;0.9,0.5;map_n;N]"):format(px0 + 1.4))
    table.insert(fs, ("button[%g,2.55;0.9,0.5;map_w;W]button[%g,2.55;0.9,0.5;map_e;E]"):format(px0 + 0.45, px0 + 2.35))
    table.insert(fs, ("button[%g,3.1;0.9,0.5;map_s;S]"):format(px0 + 1.4))
    if staff then
        local shown = v.show_players ~= false
        table.insert(fs, ("style[map_players;bgcolor=%s]button[%g,2.0;2.6,0.5;map_players;%s]"):format(
            shown and C.primary or C.button, px0 + 3.6, shown and F("Students: shown") or F("Students: hidden")))
        table.insert(fs, "tooltip[map_players;" .. F("Show or hide the other players on the map") .. "]")
    end
    table.insert(fs, ("label[%g,2.8;%s]"):format(px0 + 3.6, colored(C.muted,
        S("You: @1, @2", math.floor(me.x + 0.5), math.floor(me.z + 0.5)))))

    table.insert(fs, ("box[%g,3.75;6.4,%g;%s]"):format(px0, staff and 2.35 or 1.25, C.card))
    if v.sel then
        table.insert(fs, ("label[%g,4.05;%s]"):format(px0 + 0.2, colored(C.light,
            S("Selected point: @1, @2", v.sel.x, v.sel.z))))
        table.insert(fs, ("button[%g,4.35;1.9,0.5;map_center;%s]"):format(px0 + 0.2, F("Center")))
        if staff then
            table.insert(fs, ("button[%g,4.35;2.0,0.5;map_go_sel;%s]"):format(px0 + 2.2, F("Go there")))
            if HUB_MODE then
                table.insert(fs, ("style[map_set_spawn;bgcolor=%s]button[%g,4.35;1.95,0.5;map_set_spawn;%s]"):format(
                    C.accent, px0 + 4.3, F("Set spawn")))
                table.insert(fs, "tooltip[map_set_spawn;" .. F("Players arrive here when they join the HUB") .. "]")
            end
            table.insert(fs, ("field[%g,5.0;2.3,0.5;map_name;;%s]"):format(px0 + 0.2, esc(v.name_text)))
            table.insert(fs, "field_close_on_enter[map_name;false]tooltip[map_name;" .. F("Name of the new point") .. "]")
            table.insert(fs, ("style[map_add_wp;bgcolor=%s]button[%g,5.0;1.95,0.5;map_add_wp;%s]"):format(C.primary, px0 + 2.6, F("+ Waypoint")))
            table.insert(fs, ("style[map_add_tp;bgcolor=%s]button[%g,5.0;1.75,0.5;map_add_tp;%s]"):format(C.primary, px0 + 4.6, F("+ Teleport")))
            table.insert(fs, "tooltip[map_add_wp;" .. F("Students see it as a marker with distance and direction") .. "]")
            table.insert(fs, "tooltip[map_add_tp;" .. F("Students can teleport here from their map") .. "]")
        end
    else
        table.insert(fs, ("label[%g,4.25;%s]"):format(px0 + 0.2, colored(C.muted, S("Click the map to select a point."))))
    end

    if staff and HUB_MODE then
        local spawn = hub_spawn_point()
        if spawn then
            table.insert(fs, ("label[%g,5.78;%s]"):format(px0 + 3.35, colored(C.muted,
                S("Spawn: @1, @2, @3", math.floor(spawn.x), math.floor(spawn.y), math.floor(spawn.z)))))
        end
        if storage:get_string(HUB_SPAWN_KEY) ~= "" then
            table.insert(fs, ("button[%g,5.55;3.0,0.45;map_reset_spawn;%s]"):format(px0 + 0.2, F("Reset spawn")))
            table.insert(fs, "tooltip[map_reset_spawn;" .. F("Back to the spawn point of the hub settings") .. "]")
        end
    end

    -- Places list: markers, then zones the player can teleport to.
    local list_y = staff and 6.25 or 5.15
    local list_h = 10.95 - list_y
    table.insert(fs, ("box[%g,%g;6.4,%g;%s]"):format(px0, list_y, list_h, C.card))
    table.insert(fs, ("label[%g,%g;%s]"):format(px0 + 0.2, list_y + 0.28, colored(C.muted, S("PLACES"))))
    local rows = {}
    for _, m in ipairs(markers) do table.insert(rows, { marker = m }) end
    for _, zone in ipairs(teleport_zones(name, staff)) do table.insert(rows, { zone = zone }) end
    if #rows == 0 then
        table.insert(fs, ("label[%g,%g;%s]"):format(px0 + 0.2, list_y + 0.75, colored(C.muted,
            staff and S("None yet: select a point on the map.")
                or (HUB_MODE and S("No places yet.") or S("Your teacher has not placed any yet.")))))
    end
    local area_y, area_h = list_y + 0.5, list_h - 0.6
    local content_h = #rows * 0.55
    if content_h > area_h then
        table.insert(fs, ("scrollbaroptions[min=0;max=%d;smallstep=5;largestep=20]"):format(
            math.ceil((content_h - area_h) / SCROLL_FACTOR)))
        table.insert(fs, ("scrollbar[%g,%g;0.25,%g;vertical;map_list;%d]"):format(px0 + 6.1, area_y, area_h, v.list_scroll))
    end
    table.insert(fs, ("scroll_container[%g,%g;6.05,%g;map_list;vertical;%g]"):format(px0 + 0.05, area_y, area_h, SCROLL_FACTOR))
    for i, row in ipairs(rows) do
        local ly = (i - 1) * 0.55
        table.insert(fs, ("box[0.05,%g;5.95,0.5;%s]"):format(ly, C.row))
        local label, dist, go, show_key, del
        if row.marker then
            local m = row.marker
            local icon = m.kind == "teleport" and "classrooms_bridge_map_tp.png"
                or ("classrooms_bridge_map_pin.png^[multiply:" .. m.color)
            table.insert(fs, ("image[0.1,%g;0.4,0.4;%s]"):format(ly + 0.05, esc(icon)))
            label, dist = m.name, distance_text(player, m)
            go = (m.kind == "teleport" or staff) and ("map_tp_" .. m.id) or nil
            show_key, del = "map_show_" .. m.id, staff and ("map_del_" .. m.id) or nil
        else
            local zone = row.zone
            local color = zone.color:match("^#%x%x%x%x%x%x$") and zone.color or "#9aa3b5"
            table.insert(fs, ("box[0.15,%g;0.3,0.3;%s]"):format(ly + 0.1, color))
            label, dist = translate_for(name, S("Zone: @1", zone.name)), distance_to(player, zone.tp.x, zone.tp.z)
            go, show_key = "map_ztp_" .. zone.id, "map_zshow_" .. zone.id
        end
        if #label > 13 then label = label:sub(1, 12) .. "…" end
        table.insert(fs, ("label[0.6,%g;%s]"):format(ly + 0.25, colored(C.light, label)))
        table.insert(fs, ("label[2.75,%g;%s]"):format(ly + 0.25, colored(C.muted, dist)))
        table.insert(fs, ("button[3.75,%g;0.95,0.42;%s;%s]"):format(ly + 0.04, show_key, F("Show")))
        if go then
            table.insert(fs, ("style[%s;bgcolor=%s]button[4.75,%g;0.75,0.42;%s;%s]tooltip[%s;%s]"):format(
                go, C.primary, ly + 0.04, go, F("Go"), go, F("Teleport there")))
        end
        if del then
            table.insert(fs, ("image_button[5.55,%g;0.42,0.42;clear.png;%s;]tooltip[%s;%s]"):format(ly + 0.04, del, del, F("Remove")))
        end
    end
    table.insert(fs, "scroll_container_end[]")

    minetest.show_formspec(name, FORM, table.concat(fs))
end

function worldmap.show(player)
    if not MAP then
        minetest.chat_send_player(player:get_player_name(), minetest.colorize("#FFB347",
            TAG_MAP .. S("This world has no map.")))
        return
    end
    show(player)
end

-- ── Teleport ─────────────────────────────────────────────────────────────────

local last_tp = {}

local function teleport(player, x, y, z, yaw)
    player:set_pos({ x = x, y = y + 0.5, z = z })
    if yaw then player:set_look_horizontal(yaw) end
end

-- Students: cooldown and freeze checks. Returns true when allowed.
local function may_teleport(name, staff)
    if staff then return true end
    if is_frozen(name) then
        minetest.chat_send_player(name, minetest.colorize("#FFB347", TAG_MAP .. S("You are frozen by the teacher.")))
        return false
    end
    local now = minetest.get_us_time() / 1e6
    if last_tp[name] and now - last_tp[name] < TP_COOLDOWN then
        minetest.chat_send_player(name, minetest.colorize("#FFB347", TAG_MAP .. S("Wait a moment before teleporting again.")))
        return false
    end
    last_tp[name] = now
    return true
end

local function zone_by_id(id)
    for _, zone in ipairs(zones.list()) do
        if zone.id == id then return zone end
    end
end

-- Updates the view centre from submitted scrollbar positions. Returns true
-- when the event was only a scroll.
local function apply_scroll(v, fields)
    local scrolled = false
    for _, key in ipairs({ "map_sh", "map_sv", "map_list" }) do
        local value = fields[key]
        if value then
            local n = tonumber(value:match(":(%-?%d+)$") or "")
            if n then
                if key == "map_list" then
                    v.list_scroll = n
                elseif v.zoom > 1 then
                    local off = n * SCROLL_FACTOR
                    local cw, ch = content_size(v.zoom)
                    local _, cur_y = node_to_content(v.cx, v.cz, v.zoom)
                    local cur_x = node_to_content(v.cx, v.cz, v.zoom)
                    if key == "map_sh" then cur_x = off + VIEW / 2 else cur_y = off + VIEW / 2 end
                    cur_x, cur_y = clamp(cur_x, 0, cw), clamp(cur_y, 0, ch)
                    v.cx, v.cz = content_to_node(cur_x, cur_y, v.zoom)
                end
            end
            scrolled = scrolled or value:sub(1, 4) == "CHG:"
        end
    end
    return scrolled
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= FORM or not MAP then return false end
    local name = player:get_player_name()
    local staff = is_staff(name)
    local v = view_of(player)
    -- "Return to HUB" is an exit button: it arrives together with "quit".
    if fields.map_hub and not staff and not HUB_MODE then
        if hooks and hooks.return_hub then hooks.return_hub(player) end
        return true
    end
    if fields.map_close or fields.quit then return true end
    if fields.map_name then v.name_text = fields.map_name end

    -- Pure scroll: keep the client's view. When the view leaves the cells
    -- of the selection grid, redraw once scrolling has stopped, so dragging a
    -- scrollbar is never interrupted.
    if apply_scroll(v, fields) then
        local sx, sy = scroll_for(v)
        local b = v.band
        if not b or (sx >= b.x0 and sx + VIEW <= b.x1 and sy >= b.y0 and sy + VIEW <= b.y1) then
            return true
        end
        local token = {}
        v.redraw_token = token
        minetest.after(0.6, function()
            local current = minetest.get_player_by_name(name)
            if current and views[name] and views[name].redraw_token == token then
                show(current)
            end
        end)
        return true
    end

    if fields.map_spawn then
        local spawn_pos, spawn_yaw
        local spawn_pitch
        if HUB_MODE then
            local spawn = hub_spawn_point()
            spawn_pos = spawn and vector.copy(spawn)
            spawn_yaw, spawn_pitch = hub_spawn_look()
        elseif hooks and hooks.spawn then
            spawn_pos, spawn_yaw = hooks.spawn(player)
        end
        if not spawn_pos then
            minetest.chat_send_player(name, minetest.colorize("#FFB347", TAG_MAP .. S("This world has no spawn point.")))
        elseif may_teleport(name, staff) then
            player:set_pos(spawn_pos)
            if spawn_yaw then player:set_look_horizontal(spawn_yaw) end
            if spawn_pitch then player:set_look_vertical(spawn_pitch) end
            minetest.close_formspec(name, FORM)
        end
        return true
    end
    if fields.map_players and staff then
        v.show_players = v.show_players == false
        show(player)
        return true
    end

    local e = EXTENT / v.zoom
    local step = e / 4
    if fields.map_zoom_in then
        for i, z in ipairs(ZOOMS) do if z == v.zoom and ZOOMS[i + 1] then v.zoom = ZOOMS[i + 1] break end end
        if v.sel then v.cx, v.cz = v.sel.x, v.sel.z end
    elseif fields.map_zoom_out then
        for i, z in ipairs(ZOOMS) do if z == v.zoom and ZOOMS[i - 1] then v.zoom = ZOOMS[i - 1] break end end
    elseif fields.map_n then v.cz = v.cz + step
    elseif fields.map_s then v.cz = v.cz - step
    elseif fields.map_e then v.cx = v.cx + step
    elseif fields.map_w then v.cx = v.cx - step
    elseif fields.map_me then
        local p = player:get_pos()
        v.cx, v.cz = p.x, p.z
    elseif fields.map_center and v.sel then
        v.cx, v.cz = v.sel.x, v.sel.z
    elseif (fields.map_add_wp or fields.map_add_tp) and staff and v.sel then
        local kind = fields.map_add_wp and "waypoint" or "teleport"
        local label = (v.name_text or ""):gsub("[%c]", ""):sub(1, 30)
        if label == "" then
            -- Stored with the marker, so named in the teacher's language.
            label = translate_for(name, kind == "waypoint" and S("Waypoint @1", next_id)
                or S("Teleport @1", next_id))
        end
        local sel = v.sel
        find_ground(sel.x, sel.z, function(y)
            if not add_marker(kind, label, sel.x, y, sel.z) then
                minetest.chat_send_player(name, minetest.colorize("#FFB347", TAG_MAP .. S("Too many points: remove some first.")))
            end
            local current = minetest.get_player_by_name(name)
            if current then show(current) end
        end)
        v.name_text = ""
        return true
    elseif fields.map_set_spawn and staff and HUB_MODE and v.sel then
        local sel = v.sel
        find_ground(sel.x, sel.z, function(y)
            local pos = { x = sel.x, y = y, z = sel.z }
            if apply_hub_spawn(pos) then
                storage:set_string(HUB_SPAWN_KEY, minetest.write_json(pos))
                minetest.log("action", ("[classrooms_bridge] %s moved the HUB spawn to %d, %d, %d"):format(name, pos.x, pos.y, pos.z))
                minetest.chat_send_player(name, minetest.colorize("#7CFC00",
                    TAG_MAP .. S("Spawn point moved to @1, @2, @3.", pos.x, pos.y, pos.z)))
            end
            local current = minetest.get_player_by_name(name)
            if current then show(current) end
        end)
        return true
    elseif fields.map_reset_spawn and staff and HUB_MODE then
        if original_spawn and apply_hub_spawn(original_spawn) then
            storage:set_string(HUB_SPAWN_KEY, "")
            local o = original_spawn
            minetest.log("action", ("[classrooms_bridge] %s reset the HUB spawn to %d, %d, %d"):format(name, o.x, o.y, o.z))
            minetest.chat_send_player(name, minetest.colorize("#7CFC00",
                TAG_MAP .. S("Spawn point reset to @1, @2, @3.", o.x, o.y, o.z)))
        end
        show(player)
        return true
    elseif fields.map_go_sel and staff and v.sel then
        local sel = v.sel
        find_ground(sel.x, sel.z, function(y)
            local current = minetest.get_player_by_name(name)
            if current then teleport(current, sel.x, y, sel.z) end
        end)
        minetest.close_formspec(name, FORM)
        return true
    else
        for key in pairs(fields) do
            local i, j = key:match("^mc_(%d+)_(%d+)$")
            if i and v.cell then
                local x, z = content_to_node((tonumber(i) + 0.5) * v.cell, (tonumber(j) + 0.5) * v.cell, v.zoom)
                v.sel = { x = x, z = z }
                if v.zoom > 1 then
                    -- Keep the client's current scroll: don't recentre.
                    local sx, sy = scroll_for(v)
                    v.cx, v.cz = content_to_node(sx + VIEW / 2, sy + VIEW / 2, v.zoom)
                end
                break
            end
            local pl = tonumber(key:match("^map_pl_(%d+)$") or "")
            if pl and staff and v.players and v.players[pl] then
                local target = v.players[pl]
                v.sel = { x = target.x, z = target.z }
                v.name_text = target.name
                break
            end
            local id = tonumber(key:match("^map_show_(%d+)$") or "")
            if id then
                local m = marker_by_id(id)
                if m then v.cx, v.cz, v.sel = m.x, m.z, { x = m.x, z = m.z } end
                break
            end
            id = tonumber(key:match("^map_zshow_(%d+)$") or "")
            if id then
                local zone = zone_by_id(id)
                if zone and zone.tp then v.cx, v.cz, v.sel = zone.tp.x, zone.tp.z, { x = zone.tp.x, z = zone.tp.z } end
                break
            end
            id = tonumber(key:match("^map_tp_(%d+)$") or "")
            if id then
                local m = marker_by_id(id)
                if m and (staff or m.kind == "teleport") and may_teleport(name, staff) then
                    teleport(player, m.x, m.y, m.z)
                    minetest.close_formspec(name, FORM)
                    return true
                end
                break
            end
            id = tonumber(key:match("^map_ztp_(%d+)$") or "")
            if id then
                local zone = zone_by_id(id)
                local allowed = zone and zone.tp and (staff or (zone.allowed and zone.allowed[name]))
                if allowed and may_teleport(name, staff) then
                    teleport(player, zone.tp.x, zone.tp.y, zone.tp.z, tonumber(zone.tp.yaw))
                    minetest.close_formspec(name, FORM)
                    return true
                end
                break
            end
            id = tonumber(key:match("^map_del_(%d+)$") or "")
            if id and staff then
                local _, idx = marker_by_id(id)
                if idx then
                    table.remove(markers, idx)
                    save_markers()
                    refresh_huds()
                end
                break
            end
        end
    end
    show(player)
    return true
end)

-- ── In-world markers ─────────────────────────────────────────────────────────

local huds = {} -- [name] = { waypoints = {ids}, arrow = id, text = id, arrow_tex = s }

local function clear_waypoint_huds(player)
    local h = huds[player:get_player_name()]
    if not h then return end
    for _, id in ipairs(h.waypoints or {}) do player:hud_remove(id) end
    h.waypoints = {}
end

local function add_waypoint_huds(player)
    local name = player:get_player_name()
    huds[name] = huds[name] or {}
    clear_waypoint_huds(player)
    for _, m in ipairs(markers) do
        if m.kind == "waypoint" then
            table.insert(huds[name].waypoints, player:hud_add({
                type = "waypoint",
                name = m.name,
                text = " m",
                precision = 1,
                number = tonumber(m.color:sub(2), 16) or 0xFFFFFF,
                world_pos = { x = m.x, y = m.y + 1.5, z = m.z },
            }))
        end
    end
end

refresh_huds = function()
    for _, player in ipairs(minetest.get_connected_players()) do
        add_waypoint_huds(player)
    end
end

-- Arrow towards the nearest waypoint, at the top of the screen.
local function update_indicator(player)
    local name = player:get_player_name()
    local h = huds[name] or {}
    huds[name] = h
    local pos = player:get_pos()
    local best, best_d
    for _, m in ipairs(markers) do
        if m.kind == "waypoint" then
            local d = math.sqrt((pos.x - m.x) ^ 2 + (pos.z - m.z) ^ 2)
            if not best_d or d < best_d then best, best_d = m, d end
        end
    end
    if not best or best_d < 6 then
        if h.arrow then
            player:hud_remove(h.arrow)
            player:hud_remove(h.text)
            h.arrow, h.text, h.arrow_tex = nil, nil, nil
        end
        return
    end
    -- Direction relative to where the player looks (0 = ahead, clockwise).
    local target = math.atan2(-(best.x - pos.x), best.z - pos.z)
    local rel = (player:get_look_horizontal() - target) % (2 * math.pi)
    local tex = "classrooms_bridge_arrow_" .. (math.floor(rel / (math.pi / 4) + 0.5) % 8) .. ".png"
    local text = best.name .. " · " .. distance_text(player, best)
    if not h.arrow then
        h.arrow = player:hud_add({
            type = "image", position = { x = 0.5, y = 0.07 }, alignment = { x = 0, y = 0 },
            scale = { x = 1.2, y = 1.2 }, text = tex, z_index = 80,
        })
        h.text = player:hud_add({
            type = "text", position = { x = 0.5, y = 0.07 }, offset = { x = 0, y = 30 },
            alignment = { x = 0, y = 0 }, text = text, number = tonumber(best.color:sub(2), 16) or 0xFFE066,
            z_index = 80,
        })
        h.arrow_tex = tex
        return
    end
    if h.arrow_tex ~= tex then
        player:hud_change(h.arrow, "text", tex)
        h.arrow_tex = tex
    end
    player:hud_change(h.text, "text", text)
end

-- Light beams on markers near each player.
local function beams(player)
    local pos = player:get_pos()
    for _, m in ipairs(markers) do
        if math.abs(pos.x - m.x) < BEAM_RANGE and math.abs(pos.z - m.z) < BEAM_RANGE then
            minetest.add_particlespawner({
                amount = 24,
                time = 1,
                minpos = { x = m.x, y = m.y, z = m.z },
                maxpos = { x = m.x, y = m.y + 0.5, z = m.z },
                minvel = { x = 0, y = 2.5, z = 0 },
                maxvel = { x = 0, y = 4, z = 0 },
                minexptime = 2,
                maxexptime = 3,
                minsize = 4,
                maxsize = 6,
                vertical = true,
                glow = 14,
                texture = {
                    name = "classrooms_bridge_zone_glow.png^[multiply:" .. m.color,
                    scale = { x = 0.4, y = 2.5 },
                    alpha_tween = { 1, 0 },
                    blend = "add",
                },
                playername = player:get_player_name(),
            })
        end
    end
end

-- ── Map item and lifecycle ───────────────────────────────────────────────────

minetest.register_craftitem(ITEM, {
    description = S("World Map") .. "\n" .. minetest.colorize("#aaaaaa", S("Use to see zones, waypoints and teleport points")),
    inventory_image = "classrooms_bridge_map.png",
    wield_image = "classrooms_bridge_map.png",
    stack_max = 1,
    groups = { not_in_creative_inventory = 1 },
    on_place = function(_, placer) if placer then worldmap.show(placer) end end,
    on_use = function(_, user) if user then worldmap.show(user) end end,
    on_secondary_use = function(_, user) if user then worldmap.show(user) end end,
    on_drop = toolbar.on_drop,
})
toolbar.register_tool(TOOL, ITEM, 4)

-- Students carry the map; staff open it from World Tools. In the HUB everyone carries it.
function worldmap.set_item(player, enabled)
    if MAP then
        toolbar.set_enabled(player, TOOL, enabled or HUB_MODE)
    end
end

minetest.register_on_joinplayer(function(player)
    if not MAP then return end
    local name = player:get_player_name()
    minetest.after(1, function()
        local current = minetest.get_player_by_name(name)
        if not current then return end
        add_waypoint_huds(current)
        if HUB_MODE or not is_staff(name) then
            worldmap.set_item(current, true)
        end
    end)
end)

minetest.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    huds[name], views[name], last_tp[name] = nil, nil, nil
end)

local timer, beam_timer = 0, 0
minetest.register_globalstep(function(dtime)
    if not MAP or #markers == 0 then return end
    timer = timer + dtime
    beam_timer = beam_timer + dtime
    if timer < 0.4 then return end
    timer = 0
    local do_beams = beam_timer >= 1
    if do_beams then beam_timer = 0 end
    for _, player in ipairs(minetest.get_connected_players()) do
        update_indicator(player)
        if do_beams then beams(player) end
    end
end)

return worldmap
