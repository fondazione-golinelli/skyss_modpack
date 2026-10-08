-- World map for class worlds.
--
-- The map texture of each instance template is rendered offline by
-- tools/render_maps.py (bounds in maps.lua). This world uses the map of the
-- template named by INSTANCE_TEMPLATE_NAME (set by the classrooms plugin) or
-- the classrooms.map_template setting; without one the feature is off.
--
-- Everyone sees the map with zones, waypoints, teleport points and their own
-- position. Staff can add/remove waypoints and teleport points; students can
-- teleport to teleport points only. Waypoints are shown in the world as HUD
-- markers, light beams nearby, and a direction indicator to the nearest one.

local modpath, zones, toolbar, is_staff, is_frozen = ...

local FORM = "classrooms_bridge:map"
local ITEM = "classrooms_bridge:map"
local TOOL = "map"
local VIEW = 9.6          -- viewport size in formspec units
local GRID = 20           -- clickable cells per side
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

-- Highest walkable or liquid node of a column, after generating it.
local function find_ground(x, z, callback)
    local p1, p2 = { x = x, y = -64, z = z }, { x = x, y = 255, z = z }
    minetest.emerge_area(p1, p2, function(_, _, remaining)
        if remaining > 0 then return end
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

local views = {} -- [name] = { cx, cz, zoom, sel, name_text }

local W = MAP and (MAP.max_x - MAP.min_x + 1) or 1
local D = MAP and (MAP.max_z - MAP.min_z + 1) or 1
local EXTENT = math.max(W, D)
local PX = MAP and (MAP.width / W) or 1

local function clamp(v, lo, hi)
    if lo > hi then return (lo + hi) / 2 end
    return math.max(lo, math.min(hi, v))
end

local function view_of(player)
    local name = player:get_player_name()
    local v = views[name]
    if not v then
        local pos = player:get_pos()
        v = { cx = pos.x, cz = pos.z, zoom = 2, name_text = "" }
        views[name] = v
    end
    local e = EXTENT / v.zoom
    v.cx = clamp(v.cx, MAP.min_x + e / 2, MAP.max_x + 1 - e / 2)
    v.cz = clamp(v.cz, MAP.min_z + e / 2, MAP.max_z + 1 - e / 2)
    return v, e
end

-- ── Formspec ─────────────────────────────────────────────────────────────────

local C = { bg = "#141a2a", header = "#0f3460", accent = "#e94560", card = "#202a44", row = "#28334f",
    button = "#34446a", primary = "#2a8c7f", muted = "#aaaaaa", light = "#f0f0f0" }

local function esc(s) return minetest.formspec_escape(tostring(s)) end
local function colored(color, text) return esc(minetest.colorize(color, text)) end

local function distance_text(player, m)
    local p = player:get_pos()
    local d = math.floor(math.sqrt((p.x - m.x) ^ 2 + (p.z - m.z) ^ 2) + 0.5)
    return d >= 1000 and string.format("%.1f km", d / 1000) or (d .. " m")
end

local function show(player)
    local name = player:get_player_name()
    local staff = is_staff(name)
    local v, e = view_of(player)
    local wx0, wz1 = v.cx - e / 2, v.cz + e / 2
    local ox, oy = 0.3, 1.25
    local function fx(x) return ox + (x - wx0) / e * VIEW end
    local function fy(z) return oy + (wz1 - z) / e * VIEW end
    local function inside(x, z) return x >= wx0 and x <= wx0 + e and z <= wz1 and z >= wz1 - e end

    local fs = {
        "formspec_version[6]size[16.9,11.15]",
        "bgcolor[" .. C.bg .. ";true]",
        "box[0,0;16.9,11.15;" .. C.bg .. "]",
        "style_type[button;bgcolor=" .. C.button .. ";border=false;textcolor=" .. C.light .. "]",
        "style_type[label;textcolor=" .. C.light .. "]",
        "box[0,0;16.9,1.0;" .. C.header .. "]box[0,1.0;16.9,0.05;" .. C.accent .. "]",
        "label[0.35,0.35;" .. colored(C.light, "World map") .. "]",
        "label[0.35,0.72;" .. colored(C.muted, staff and "Click the map to select a point"
            or "Zones, waypoints and teleport points") .. "]",
        "image_button_exit[16.05,0.17;0.66,0.66;clear.png;map_close;]",
    }

    -- Map picture: the visible window cropped from the template texture.
    local x0 = math.floor((wx0 - MAP.min_x) * PX + 0.5)
    local y0 = math.floor((MAP.max_z + 1 - wz1) * PX + 0.5)
    local size = math.max(1, math.floor(e * PX + 0.5))
    local texture = ("[combine:%dx%d:%d,%d=%s"):format(size, size, -x0, -y0, TEXTURE)
    table.insert(fs, ("box[%g,%g;%g,%g;#1b2033]"):format(ox, oy, VIEW, VIEW))
    table.insert(fs, ("image[%g,%g;%g,%g;%s]"):format(ox, oy, VIEW, VIEW, esc(texture)))

    -- Zones.
    for _, zone in ipairs(zones.list()) do
        local x1, x2 = math.max(zone.min_x, wx0), math.min(zone.max_x + 1, wx0 + e)
        local z1, z2 = math.max(zone.min_z, wz1 - e), math.min(zone.max_z + 1, wz1)
        if x1 < x2 and z1 < z2 then
            local bx, by = fx(x1), fy(z2)
            local bw, bh = (x2 - x1) / e * VIEW, (z2 - z1) / e * VIEW
            local color = zone.color:match("^#%x%x%x%x%x%x$") and zone.color or "#9aa3b5"
            local mine = zone.allowed and zone.allowed[name]
            local t = mine and 0.09 or 0.05
            table.insert(fs, ("box[%g,%g;%g,%g;%s50]"):format(bx, by, bw, bh, color))
            table.insert(fs, ("box[%g,%g;%g,%g;%s]"):format(bx, by, bw, t, color))
            table.insert(fs, ("box[%g,%g;%g,%g;%s]"):format(bx, by + bh - t, bw, t, color))
            table.insert(fs, ("box[%g,%g;%g,%g;%s]"):format(bx, by, t, bh, color))
            table.insert(fs, ("box[%g,%g;%g,%g;%s]"):format(bx + bw - t, by, t, bh, color))
            local who = zone.open and "everyone" or (zone.group and ("group " .. zone.group) or "teachers only")
            table.insert(fs, ("tooltip[%g,%g;%g,%g;%s]"):format(bx, by, bw, bh,
                esc(zone.name .. " (" .. who .. ")" .. (mine and " · your group" or ""))))
            if bw > 1.0 and bh > 0.4 then
                table.insert(fs, ("label[%g,%g;%s]"):format(bx + 0.1, by + 0.22, colored(color, zone.name)))
            end
        end
    end

    -- Other players (staff only), then markers, then me.
    if staff then
        for _, other in ipairs(minetest.get_connected_players()) do
            local p = other:get_pos()
            if other ~= player and inside(p.x, p.z) then
                table.insert(fs, ("box[%g,%g;0.16,0.16;#ffffffdd]"):format(fx(p.x) - 0.08, fy(p.z) - 0.08))
                table.insert(fs, ("tooltip[%g,%g;0.3,0.3;%s]"):format(fx(p.x) - 0.15, fy(p.z) - 0.15,
                    esc(other:get_player_name())))
            end
        end
    end
    for _, m in ipairs(markers) do
        if inside(m.x, m.z) then
            local icon = m.kind == "teleport" and "classrooms_bridge_map_tp.png"
                or ("classrooms_bridge_map_pin.png^[multiply:" .. m.color)
            local s = 0.5
            local yoff = m.kind == "teleport" and s / 2 or s
            table.insert(fs, ("image[%g,%g;%g,%g;%s]"):format(fx(m.x) - s / 2, fy(m.z) - yoff, s, s, esc(icon)))
            table.insert(fs, ("tooltip[%g,%g;%g,%g;%s]"):format(fx(m.x) - s / 2, fy(m.z) - yoff, s, s,
                esc((m.kind == "teleport" and "Teleport point: " or "Waypoint: ") .. m.name)))
        end
    end
    local me = player:get_pos()
    if inside(me.x, me.z) then
        table.insert(fs, ("image[%g,%g;0.42,0.42;classrooms_bridge_map_me.png]"):format(fx(me.x) - 0.21, fy(me.z) - 0.21))
    end
    if v.sel and inside(v.sel.x, v.sel.z) then
        local sx, sy = fx(v.sel.x), fy(v.sel.z)
        table.insert(fs, ("box[%g,%g;0.5,0.04;#ffffff]box[%g,%g;0.04,0.5;#ffffff]"):format(
            sx - 0.25, sy - 0.02, sx - 0.02, sy - 0.25))
    end

    -- Invisible click grid.
    table.insert(fs, "style_type[image_button;border=false;bgcolor=#00000000;bgimg_hovered="
        .. esc("[fill:1x1:#ffffff22") .. "]")
    local cell = VIEW / GRID
    for j = 0, GRID - 1 do
        for i = 0, GRID - 1 do
            table.insert(fs, ("image_button[%g,%g;%g,%g;blank.png;mc_%d_%d;]"):format(
                ox + i * cell, oy + j * cell, cell, cell, i, j))
        end
    end

    -- Side panel.
    local px0 = 10.2
    table.insert(fs, ("box[%g,1.25;6.4,2.35;%s]"):format(px0, C.card))
    table.insert(fs, ("label[%g,1.55;%s]"):format(px0 + 0.2, colored(C.muted, "ZOOM ×" .. v.zoom)))
    table.insert(fs, ("button[%g,1.3;0.8,0.55;map_zoom_out;-]button[%g,1.3;0.8,0.55;map_zoom_in;+]"):format(px0 + 2.2, px0 + 3.05))
    table.insert(fs, ("button[%g,1.3;1.6,0.55;map_me;Me]"):format(px0 + 4.6))
    table.insert(fs, "tooltip[map_me;Center the map on your position]")
    table.insert(fs, ("button[%g,2.0;0.9,0.5;map_n;N]"):format(px0 + 1.4))
    table.insert(fs, ("button[%g,2.55;0.9,0.5;map_w;W]button[%g,2.55;0.9,0.5;map_e;E]"):format(px0 + 0.45, px0 + 2.35))
    table.insert(fs, ("button[%g,3.1;0.9,0.5;map_s;S]"):format(px0 + 1.4))
    table.insert(fs, ("label[%g,2.8;%s]"):format(px0 + 3.6, colored(C.muted,
        ("Position: %d, %d"):format(math.floor(me.x + 0.5), math.floor(me.z + 0.5)))))

    -- Selected point.
    table.insert(fs, ("box[%g,3.75;6.4,%g;%s]"):format(px0, staff and 2.35 or 1.25, C.card))
    if v.sel then
        table.insert(fs, ("label[%g,4.05;%s]"):format(px0 + 0.2, colored(C.light,
            ("Selected point: %d, %d"):format(v.sel.x, v.sel.z))))
        table.insert(fs, ("button[%g,4.35;1.9,0.5;map_center;Center]"):format(px0 + 0.2))
        if staff then
            table.insert(fs, ("button[%g,4.35;2.0,0.5;map_go_sel;Go there]"):format(px0 + 2.2))
            table.insert(fs, ("field[%g,5.0;2.3,0.5;map_name;;%s]"):format(px0 + 0.2, esc(v.name_text)))
            table.insert(fs, "field_close_on_enter[map_name;false]tooltip[map_name;Name of the new point]")
            table.insert(fs, ("style[map_add_wp;bgcolor=%s]button[%g,5.0;1.95,0.5;map_add_wp;+ Waypoint]"):format(C.primary, px0 + 2.6))
            table.insert(fs, ("style[map_add_tp;bgcolor=%s]button[%g,5.0;1.75,0.5;map_add_tp;+ Teleport]"):format(C.primary, px0 + 4.6))
            table.insert(fs, "tooltip[map_add_wp;Students see it as a marker with distance and direction]")
            table.insert(fs, "tooltip[map_add_tp;Students can teleport here from their map]")
        end
    else
        table.insert(fs, ("label[%g,4.25;%s]"):format(px0 + 0.2, colored(C.muted, "Click the map to select a point.")))
    end

    -- Points list.
    local list_y = staff and 6.25 or 5.15
    table.insert(fs, ("box[%g,%g;6.4,%g;%s]"):format(px0, list_y, 10.95 - list_y, C.card))
    table.insert(fs, ("label[%g,%g;%s]"):format(px0 + 0.2, list_y + 0.28, colored(C.muted, "WAYPOINTS AND TELEPORT POINTS")))
    if #markers == 0 then
        table.insert(fs, ("label[%g,%g;%s]"):format(px0 + 0.2, list_y + 0.75, colored(C.muted,
            staff and "None yet: select a point on the map." or "Your teacher has not placed any yet.")))
    end
    local ly = list_y + 0.5
    local max_rows = math.floor((10.85 - ly) / 0.55)
    for i, m in ipairs(markers) do
        if i > max_rows then break end
        local icon = m.kind == "teleport" and "classrooms_bridge_map_tp.png"
            or ("classrooms_bridge_map_pin.png^[multiply:" .. m.color)
        table.insert(fs, ("box[%g,%g;6.2,0.5;%s]"):format(px0 + 0.1, ly, C.row))
        table.insert(fs, ("image[%g,%g;0.4,0.4;%s]"):format(px0 + 0.15, ly + 0.05, esc(icon)))
        local label = m.name
        if #label > 16 then label = label:sub(1, 15) .. "…" end
        table.insert(fs, ("label[%g,%g;%s]"):format(px0 + 0.65, ly + 0.25, colored(C.light, label)))
        table.insert(fs, ("label[%g,%g;%s]"):format(px0 + 2.75, ly + 0.25, colored(C.muted, distance_text(player, m))))
        table.insert(fs, ("button[%g,%g;0.95,0.42;map_show_%d;Show]"):format(px0 + 3.85, ly + 0.04, m.id))
        if m.kind == "teleport" or staff then
            table.insert(fs, ("style[map_tp_%d;bgcolor=%s]button[%g,%g;0.75,0.42;map_tp_%d;Go]"):format(
                m.id, C.primary, px0 + 4.85, ly + 0.04, m.id))
            table.insert(fs, ("tooltip[map_tp_%d;Teleport there]"):format(m.id))
        end
        if staff then
            table.insert(fs, ("image_button[%g,%g;0.42,0.42;clear.png;map_del_%d;]"):format(px0 + 5.7, ly + 0.04, m.id))
            table.insert(fs, ("tooltip[map_del_%d;Remove]"):format(m.id))
        end
        ly = ly + 0.55
    end

    minetest.show_formspec(name, FORM, table.concat(fs))
end

function worldmap.show(player)
    if not MAP then
        minetest.chat_send_player(player:get_player_name(), minetest.colorize("#FFB347",
            "[Map] This world has no map."))
        return
    end
    show(player)
end

-- ── Teleport ─────────────────────────────────────────────────────────────────

local last_tp = {}

local function teleport(player, x, y, z)
    player:set_pos({ x = x, y = y + 0.5, z = z })
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= FORM or not MAP then return false end
    local name = player:get_player_name()
    local staff = is_staff(name)
    local v, e = view_of(player)
    if fields.map_close or fields.quit then return true end
    if fields.map_name then v.name_text = fields.map_name end

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
            label = (kind == "waypoint" and "Waypoint " or "Teleport ") .. tostring(next_id)
        end
        local sel = v.sel
        find_ground(sel.x, sel.z, function(y)
            if not add_marker(kind, label, sel.x, y, sel.z) then
                minetest.chat_send_player(name, minetest.colorize("#FFB347", "[Map] Too many points: remove some first."))
            end
            local current = minetest.get_player_by_name(name)
            if current then show(current) end
        end)
        v.name_text = ""
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
            if i then
                local cell = e / GRID
                v.sel = {
                    x = math.floor(v.cx - e / 2 + (tonumber(i) + 0.5) * cell),
                    z = math.floor(v.cz + e / 2 - (tonumber(j) + 0.5) * cell),
                }
                break
            end
            local id = tonumber(key:match("^map_show_(%d+)$") or "")
            if id then
                local m = marker_by_id(id)
                if m then v.cx, v.cz, v.sel = m.x, m.z, { x = m.x, z = m.z } end
                break
            end
            id = tonumber(key:match("^map_tp_(%d+)$") or "")
            if id then
                local m = marker_by_id(id)
                local now = minetest.get_us_time() / 1e6
                if m and (staff or m.kind == "teleport") then
                    if not staff and is_frozen(name) then
                        minetest.chat_send_player(name, minetest.colorize("#FFB347", "[Map] You are frozen by the teacher."))
                    elseif not staff and last_tp[name] and now - last_tp[name] < TP_COOLDOWN then
                        minetest.chat_send_player(name, minetest.colorize("#FFB347", "[Map] Wait a moment before teleporting again."))
                    else
                        last_tp[name] = now
                        teleport(player, m.x, m.y, m.z)
                        minetest.close_formspec(name, FORM)
                        return true
                    end
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
    description = "World Map\n" .. minetest.colorize("#aaaaaa", "Use to see zones, waypoints and teleport points"),
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

-- Students carry the map; staff open it from World Tools.
function worldmap.set_item(player, enabled)
    if MAP then
        toolbar.set_enabled(player, TOOL, enabled)
    end
end

minetest.register_on_joinplayer(function(player)
    if not MAP then return end
    local name = player:get_player_name()
    minetest.after(1, function()
        local current = minetest.get_player_by_name(name)
        if not current then return end
        add_waypoint_huds(current)
        if not is_staff(name) then
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
