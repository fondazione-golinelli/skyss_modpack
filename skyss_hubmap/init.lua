-- skyss_hubmap: the map of the HUB lobby.
--
-- A fixed list of places (places.lua) grouped by tag: spawn point, worlds
-- portal, minigame pavilions and country gardens. Players open the map from
-- the hotbar and teleport to a place from its pin or from the list. Names are
-- translated (it/es/fr/de/pl/hu), positions are exact feet positions with a
-- facing, so a teleport always lands in the same spot.
--
-- Where a place is: an admin's change (mod storage) > the world's
-- skyss_hubmap/places.json (written by hubgen) > places.lua. The spawn point
-- is the hub mod's spawn and a minigame follows its launcher's return point.
-- Admins (server or hub_admin privilege) can move the spawn, the portal and
-- the countries to where they stand.

local S = core.get_translator("skyss_hubmap")
local MODPATH = core.get_modpath("skyss_hubmap")
local L = dofile(MODPATH .. "/src/layout.lua")
local TAGS, PLACES = assert(loadfile(MODPATH .. "/places.lua"))(S)
local storage = core.get_mod_storage()
local bridge = rawget(_G, "classrooms_bridge")

local FORM = "skyss_hubmap:map"
local ITEM = "skyss_hubmap:map"
local TOOL = "hubmap"
local TOOL_ORDER = 4          -- the slot of the old classrooms_bridge map
local BOUNDS = { min = -170, max = 169 } -- X and Z drawn in skyss_hubmap_map.png
local TP_COOLDOWN = 2
local PIN = 0.62
local ME = 0.5            -- size of the player triangle on the map
local ROW_H, HEAD_H, HEAD_GAP = 0.55, 0.52, 0.12
local SCROLL = 0.1

local UI = { ink = "#302c2e", soft = "#6e4a2a", light = "#f9f3df", row = "#c4daa5", sel = "#f3dd8f",
    head = "#8a5a32", head_line = "#5e3b1f" }
local esc = core.formspec_escape

skyss_hubmap = {}

local by_id, tag_by_id = {}, {}
for _, place in ipairs(PLACES) do
    place.default = { pos = vector.new(place.pos[1], place.pos[2], place.pos[3]), yaw = place.yaw }
    by_id[place.id] = place
end
for _, tag in ipairs(TAGS) do tag_by_id[tag.id] = tag end

local function is_admin(name)
    return core.check_player_privs(name, { server = true }) or core.check_player_privs(name, { hub_admin = true })
end

-- ── Where places are ─────────────────────────────────────────────────────────

local function parse_point(raw)
    if type(raw) ~= "table" or type(raw.pos) ~= "table" then return nil end
    local x, y, z = tonumber(raw.pos[1] or raw.pos.x), tonumber(raw.pos[2] or raw.pos.y), tonumber(raw.pos[3] or raw.pos.z)
    if not (x and y and z) then return nil end
    return { pos = vector.new(x, y, z), yaw = tonumber(raw.yaw) or 0 }
end

local function point_json(point)
    return core.write_json({ pos = { point.pos.x, point.pos.y, point.pos.z }, yaw = point.yaw })
end

-- The world's places.json (from hubgen).
do
    local file = io.open(core.get_worldpath() .. "/skyss_hubmap/places.json", "r")
    if file then
        local doc = core.parse_json(file:read("*a") or "")
        file:close()
        local places = type(doc) == "table" and doc.places
        if type(places) == "table" then
            for id, raw in pairs(places) do
                local point = by_id[id] and parse_point(raw)
                if point then
                    by_id[id].world = point
                else
                    core.log("warning", "[skyss_hubmap] places.json: ignoring " .. tostring(id))
                end
            end
        end
    end
end

local function override_of(place)
    local raw = storage:get_string("place:" .. place.id)
    return raw ~= "" and parse_point(core.parse_json(raw)) or nil
end

local function hub_mod()
    local hub = rawget(_G, "hub")
    return hub and hub.get_hub_spawn_point and hub
end

local function launchers()
    return core.global_exists("skyss_minigames") and skyss_minigames.list_launchers
        and skyss_minigames.list_launchers() or {}
end

-- Point (pos, yaw in degrees) of a place. `launcher_list` is optional.
local function locate(place, launcher_list)
    if place.id == "spawn" and hub_mod() then
        local hub = hub_mod()
        return { pos = vector.copy(hub.get_hub_spawn_point()), yaw = tonumber(hub.settings.join_rotation_x) or 0 }
    end
    if place.game then
        local launcher = (launcher_list or launchers())[place.game]
        if launcher and launcher.exit then
            return { pos = vector.copy(launcher.exit.pos), yaw = math.deg(launcher.exit.yaw or 0) % 360 }
        end
    end
    return override_of(place) or place.world or place.default
end

-- Admins can move every place except the minigames (moved with the minigames editor).
local function movable(place)
    return place.game == nil
end

-- The hub mod keeps references to its spawn vector, so it is changed in place.
local original_spawn
local function apply_spawn(point)
    local hub = hub_mod()
    if not hub then return end
    local spawn = hub.get_hub_spawn_point()
    spawn.x, spawn.y, spawn.z = point.pos.x, point.pos.y, point.pos.z
    hub.settings.join_rotation_x = point.yaw
end

core.register_on_mods_loaded(function()
    local hub = hub_mod()
    if not hub then return end
    original_spawn = { pos = vector.copy(hub.get_hub_spawn_point()), yaw = hub.settings.join_rotation_x }
    local saved = override_of(by_id.spawn)
    if saved then
        apply_spawn(saved)
        core.log("action", ("[skyss_hubmap] HUB spawn: %s"):format(core.pos_to_string(saved.pos)))
    end
end)

local function set_place(place, point)
    if point then
        storage:set_string("place:" .. place.id, point_json(point))
    else
        storage:set_string("place:" .. place.id, "")
    end
    if place.id == "spawn" then
        if point then
            apply_spawn(point)
        elseif original_spawn then
            apply_spawn(original_spawn)
        end
    end
end

-- Texts shown for a place, all translatable.
local function place_title(place, launcher_list)
    local launcher = place.game and (launcher_list or launchers())[place.game]
    return launcher and launcher.title or place.title
end

local function place_info(place, title)
    if place.info then return place.info end
    if place.tag == "minigames" then
        return S("The pavilion of @1: start the minigame at its launcher.", title)
    end
    return S("The garden of @1, with its countryside beyond it.", title)
end

-- Badge of a place: image layers, bottom first.
local function place_badge(place, launcher_list)
    if place.flag then return { "skyss_hubmap_flag_" .. place.flag .. ".png" } end
    if place.tag == "minigames" then
        local launcher = (launcher_list or launchers())[place.game]
        if launcher and launcher.icon then
            return { "skyss_hubmap_pin_minigames.png", launcher.icon }
        end
    end
    return { "skyss_hubmap_tag_" .. place.tag .. ".png" }
end

-- ── Form ─────────────────────────────────────────────────────────────────────

local views = {} -- [name] = { tag, sel, scroll }

local function view_of(name)
    views[name] = views[name] or { tag = "all", scroll = 0 }
    return views[name]
end

local function htext(text)
    return esc((tostring(text):gsub("\\", "\\\\"):gsub("<", "\\<")))
end

local function button_style(name, kind)
    local base = "skyss_hubmap_btn_" .. kind
    return ("style[%s;bgimg=%s.png;bgimg_hovered=%s_hover.png;bgimg_pressed=%s_pressed.png;bgimg_middle=4;"
        .. "border=false;textcolor=%s;font=bold]"):format(name, base, base, base, UI.light)
end

local Form = {}
Form.__index = Form

local function new_form()
    local w, h = L.size[1], L.size[2]
    local f = setmetatable({ parts = {}, n = 0 }, Form)
    f:add(table.concat({
        "formspec_version[6]",
        ("size[%g,%g]"):format(w, h),
        "position[0.5,0.48]",
        "no_prepend[]",
        "bgcolor[#00000080;true]",
        ("background[0,0;%g,%g;skyss_hubmap_ui_board.png]"):format(w, h),
        "style_type[image_button;border=false;bgimg_hovered=" .. esc("[fill:1x1:#ffffff40") .. "]",
    }))
    return f
end

function Form:add(s)
    self.parts[#self.parts + 1] = s
    return self
end

function Form:text(x, y, w, h, text, opts)
    opts = opts or {}
    self.n = self.n + 1
    local body = htext(text)
    if opts.bold then body = "<b>" .. body .. "</b>" end
    return self:add(("hypertext[%g,%g;%g,%g;t%d;<global size=%d font=mono color=%s halign=%s valign=middle>%s]"):format(
        x, y, w, h, self.n, opts.size or 15, opts.color or UI.ink, opts.halign or "left", body))
end

function Form:image(x, y, w, h, texture)
    return self:add(("image[%g,%g;%g,%g;%s]"):format(x, y, w, h, esc(texture)))
end

-- Invisible button over an area, with a tooltip.
function Form:hotspot(x, y, w, h, field, tip)
    self:add(("image_button[%g,%g;%g,%g;blank.png;%s;]"):format(x, y, w, h, field))
    if tip then self:add(("tooltip[%s;%s]"):format(field, esc(tip))) end
    return self
end

function Form:button(x, y, w, h, field, label, kind)
    self:add(button_style(field, kind))
    return self:add(("button[%g,%g;%g,%g;%s;%s]"):format(x, y, w, h, field, esc(label)))
end

local function to_map(pos)
    local mx, my, size = L.map[1], L.map[2], L.map[3]
    local span = BOUNDS.max - BOUNDS.min + 1
    return mx + (pos.x - BOUNDS.min + 0.5) / span * size, my + (BOUNDS.max - pos.z + 0.5) / span * size
end

local function on_map(pos)
    return pos.x >= BOUNDS.min and pos.x <= BOUNDS.max + 1 and pos.z >= BOUNDS.min and pos.z <= BOUNDS.max + 1
end

local function distance(player, pos)
    local p = player:get_pos()
    return math.floor(math.sqrt((p.x - pos.x) ^ 2 + (p.z - pos.z) ^ 2) + 0.5)
end

local function shown(v, place)
    return v.tag == "all" or v.tag == place.tag
end

local function show(player)
    local name = player:get_player_name()
    local v = view_of(name)
    local admin = is_admin(name)
    local list = launchers()
    local f = new_form()

    -- title
    local ix, iy, is = L.icon[1], L.icon[2], L.icon[3]
    f:image(ix + 0.2, iy + 0.2, is - 0.4, is - 0.4, "skyss_hubmap_item.png")
    local px, py, pw, ph = L.plaque[1], L.plaque[2], L.plaque[3], L.plaque[4]
    f:text(px + 0.2, py, pw - 0.4, ph, S("HUB map"), { size = 22, bold = true, halign = "center" })
    local cx, cy, cs = L.close[1], L.close[2], L.close[3]
    f:add(("image_button_exit[%g,%g;%g,%g;skyss_hubmap_close.png;close;;true;false;skyss_hubmap_close_pressed.png]")
        :format(cx, cy, cs, cs))

    -- map: image, the pins, then the player on top
    local mx, my, size = L.map[1], L.map[2], L.map[3]
    f:image(mx, my, size, size, "skyss_hubmap_map.png")
    local points = {}
    for i, place in ipairs(PLACES) do
        points[i] = locate(place, list)
    end
    for pass = 1, 2 do -- places of other tags first, dimmed, under the shown ones
        for i, place in ipairs(PLACES) do
            if (pass == 2) == shown(v, place) then
                local x, y = to_map(points[i].pos)
                if v.sel == place.id then
                    f:image(x - 0.45, y - 0.45, 0.9, 0.9, "skyss_hubmap_selected.png")
                end
                for layer, tex in ipairs(place_badge(place, list)) do
                    local s = layer == 1 and PIN or PIN * 0.62
                    f:image(x - s / 2, y - s / 2, s, s, pass == 1 and (tex .. "^[opacity:110") or tex)
                end
                f:hotspot(x - PIN / 2, y - PIN / 2, PIN, PIN, "pin_" .. i, place_title(place, list))
            end
        end
    end
    -- The player: a triangle pointing where they look. Smaller than a pin,
    -- so the pin under it can still be clicked around its edge.
    local me = player:get_pos()
    if on_map(me) then
        local ax, ay = to_map(me)
        local dir = math.floor(player:get_look_horizontal() / (math.pi / 4) + 0.5) % 8
        f:image(ax - ME / 2, ay - ME / 2, ME, ME, "skyss_hubmap_me_" .. dir .. ".png")
        f:add(("tooltip[%g,%g;%g,%g;%s]"):format(ax - ME / 2, ay - ME / 2, ME, ME, esc(S("You are here"))))
    end

    -- tag tabs
    local tabs = { { id = "all", title = S("All places") } }
    for _, tag in ipairs(TAGS) do tabs[#tabs + 1] = tag end
    for i, tag in ipairs(tabs) do
        local r = L.tabs[i]
        if v.tag == tag.id then
            f:add(("box[%g,%g;%g,%g;#fff2b860]"):format(r[1] + 0.05, r[2] + 0.05, r[3] - 0.1, r[4] - 0.1))
            f:add(("box[%g,%g;%g,0.06;%s]"):format(r[1] + 0.15, r[2] + r[4] - 0.14, r[3] - 0.3, UI.light))
        end
        f:image(r[1] + (r[3] - 0.52) / 2, r[2] + (r[4] - 0.52) / 2, 0.52, 0.52, "skyss_hubmap_tag_" .. tag.id .. ".png")
        f:hotspot(r[1], r[2], r[3], r[4], "tab_" .. tag.id, tag.title)
    end

    -- list, grouped by tag
    local lx, ly, lw, lh = L.list[1] + 0.1, L.list[2] + 0.12, L.list[3] - 0.2, L.list[4] - 0.24
    local rows, height = {}, 0
    for _, tag in ipairs(TAGS) do
        if v.tag == "all" or v.tag == tag.id then
            -- Space above every category but the first.
            if #rows > 0 then height = height + HEAD_GAP end
            rows[#rows + 1] = { tag = tag, y = height }
            height = height + HEAD_H
            for i, place in ipairs(PLACES) do
                if place.tag == tag.id then
                    rows[#rows + 1] = { index = i, place = place, y = height }
                    height = height + ROW_H
                end
            end
        end
    end
    local bar = height > lh
    local rw = bar and lw - 0.35 or lw
    if bar then
        local max = math.ceil((height - lh) / SCROLL)
        v.scroll = math.min(v.scroll or 0, max)
        f:add(("scrollbaroptions[min=0;max=%d;smallstep=5;largestep=20;thumbsize=%d]"):format(
            max, math.max(1, math.floor(max * lh / height))))
        f:add(("scrollbar[%g,%g;0.28,%g;vertical;list_sb;%d]"):format(lx + lw - 0.28, ly, lh, v.scroll))
    else
        v.scroll = 0
    end
    f:add(("scroll_container[%g,%g;%g,%g;list_sb;vertical;%g]"):format(lx, ly, rw, lh, SCROLL))
    for _, row in ipairs(rows) do
        local y = row.y
        if row.tag then
            -- Category: a wooden band, so it does not look like a place row.
            f:add(("box[0,%g;%g,%g;%s]"):format(y, rw, HEAD_H, UI.head))
            f:add(("box[0,%g;%g,0.04;%s]"):format(y + HEAD_H - 0.04, rw, UI.head_line))
            f:image(0.08, y + 0.08, 0.36, 0.36, "skyss_hubmap_tag_" .. row.tag.id .. ".png")
            f:text(0.55, y, rw - 0.6, HEAD_H, row.tag.title, { size = 14, bold = true, color = UI.light })
        else
            local place, i = row.place, row.index
            local title = place_title(place, list)
            local selected = v.sel == place.id
            if selected or (i % 2 == 0) then
                f:add(("box[0,%g;%g,%g;%s]"):format(y + 0.02, rw, ROW_H - 0.04, selected and UI.sel or UI.row))
            end
            for layer, tex in ipairs(place_badge(place, list)) do
                local s = layer == 1 and 0.42 or 0.26
                f:image(0.3 - s / 2, y + ROW_H / 2 - s / 2, s, s, tex)
            end
            f:text(0.6, y, rw - 2.6, ROW_H, title, { size = 14, bold = selected })
            f:text(rw - 2.05, y, 1.05, ROW_H, distance(player, points[i].pos) .. " m",
                { size = 12, color = UI.soft, halign = "right" })
            f:hotspot(0, y, rw - 0.95, ROW_H, "row_" .. i, title)
            f:button(rw - 0.9, y + 0.06, 0.88, ROW_H - 0.12, "go_" .. i, S("Go"), "green")
            f:add(("tooltip[go_%d;%s]"):format(i, esc(S("Teleport there"))))
        end
    end
    f:add("scroll_container_end[]")

    -- selected place
    local dx, dy, dw = L.detail[1], L.detail[2], L.detail[3]
    local sel = v.sel and by_id[v.sel]
    if not sel then
        f:text(dx + 0.3, dy + 0.2, dw - 0.6, 2.0, S("Choose a place on the map or in the list."),
            { size = 15, color = UI.soft, halign = "center" })
    else
        local i
        for k, place in ipairs(PLACES) do if place == sel then i = k end end
        local title = place_title(sel, list)
        for layer, tex in ipairs(place_badge(sel, list)) do
            local s = layer == 1 and 0.85 or 0.53
            f:image(dx + 0.6 - s / 2, dy + 0.6 - s / 2, s, s, tex)
        end
        f:text(dx + 1.15, dy + 0.12, dw - 1.3, 0.5, title, { size = 17, bold = true })
        f:text(dx + 1.15, dy + 0.58, dw - 1.3, 0.4,
            S("@1 · @2 m away", tag_by_id[sel.tag].title, distance(player, points[i].pos)),
            { size = 13, color = UI.soft })
        f:text(dx + 0.2, dy + 1.0, dw - 0.4, 0.7, place_info(sel, title), { size = 13 })
        local by = dy + L.detail[4] - 0.78
        f:button(dx + 0.2, by, admin and 2.4 or dw - 0.4, 0.62, "teleport", S("Teleport"), "green")
        if admin then
            if movable(sel) then
                f:button(dx + 2.75, by, 2.15, 0.62, "move", S("Move here"), "blue")
                f:add("tooltip[move;" .. esc(S("Put this place where you stand, facing where you look")) .. "]")
                if override_of(sel) then
                    f:button(dx + 5.05, by, 1.15, 0.62, "reset", S("Reset"), "wood")
                    f:add("tooltip[reset;" .. esc(S("Back to the position of the HUB map")) .. "]")
                end
            else
                f:text(dx + 2.75, by - 0.1, dw - 2.95, 0.82, S("Moved with the Return point tool of the minigames editor."),
                    { size = 11, color = UI.soft })
            end
        end
    end

    core.show_formspec(name, FORM, table.concat(f.parts))
end

function skyss_hubmap.show(player)
    show(player)
end

-- ── Teleport ─────────────────────────────────────────────────────────────────

local last_tp = {}

local function chat(name, text, color)
    core.chat_send_player(name, core.colorize(color or "#FFB347", S("[Map]") .. " " .. text))
end

local function may_teleport(name, admin)
    if core.global_exists("skyss_minigames") and (skyss_minigames.is_playing(name)
            or (skyss_minigames.is_editing and skyss_minigames.is_editing(name))) then
        chat(name, S("Leave the minigame first."))
        return false
    end
    if admin then return true end
    if bridge and bridge.is_frozen and bridge.is_frozen(name) then
        chat(name, S("You are frozen by the teacher."))
        return false
    end
    local now = core.get_us_time() / 1e6
    if last_tp[name] and now - last_tp[name] < TP_COOLDOWN then
        chat(name, S("Wait a moment before teleporting again."))
        return false
    end
    last_tp[name] = now
    return true
end

-- Teleports a player to a place by id. Returns true on success.
function skyss_hubmap.teleport(player, id)
    local place = by_id[id]
    if not place then return false end
    local name = player:get_player_name()
    if not may_teleport(name, is_admin(name)) then return false end
    local point = locate(place)
    player:set_pos(point.pos)
    player:set_look_horizontal(math.rad(point.yaw))
    player:set_look_vertical(0)
    core.close_formspec(name, FORM)
    return true
end

-- Plain data for other mods: { {id, tag, pos, yaw}, ... } in list order.
function skyss_hubmap.list_places()
    local list, out = launchers(), {}
    for _, place in ipairs(PLACES) do
        local point = locate(place, list)
        out[#out + 1] = { id = place.id, tag = place.tag, title = place_title(place, list),
            pos = point.pos, yaw = point.yaw }
    end
    return out
end

core.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= FORM then return false end
    local name = player:get_player_name()
    local v = view_of(name)
    if fields.list_sb then
        local n = tonumber(fields.list_sb:match(":(%-?%d+)$") or "")
        if n then v.scroll = n end
        if fields.list_sb:sub(1, 4) == "CHG:" then return true end
    end
    if fields.close or fields.quit then return true end

    local sel = v.sel and by_id[v.sel]
    if fields.teleport and sel then
        skyss_hubmap.teleport(player, sel.id)
        return true
    end
    if (fields.move or fields.reset) and sel and movable(sel) and is_admin(name) then
        if fields.move then
            local p = player:get_pos()
            local point = { pos = vector.new(math.floor(p.x + 0.5), math.floor(p.y + 0.5), math.floor(p.z + 0.5)),
                yaw = math.floor(math.deg(player:get_look_horizontal()) / 15 + 0.5) * 15 % 360 }
            set_place(sel, point)
            core.log("action", ("[skyss_hubmap] %s moved %s to %s yaw %d"):format(
                name, sel.id, core.pos_to_string(point.pos), point.yaw))
            chat(name, S("@1 moved to @2.", sel.title, core.pos_to_string(point.pos)), "#7CFC00")
        else
            set_place(sel, nil)
            core.log("action", ("[skyss_hubmap] %s reset %s"):format(name, sel.id))
            chat(name, S("@1 is back to its position on the HUB map.", sel.title), "#7CFC00")
        end
        show(player)
        return true
    end
    for key in pairs(fields) do
        local tag = key:match("^tab_(.+)$")
        if tag and (tag == "all" or tag_by_id[tag]) then
            v.tag, v.scroll = tag, 0
            if v.sel and by_id[v.sel] and not shown(v, by_id[v.sel]) then v.sel = nil end
            break
        end
        local kind, i = key:match("^(%a+)_(%d+)$")
        local place = i and PLACES[tonumber(i)]
        if place and (kind == "pin" or kind == "row") then
            v.sel = place.id
            if not shown(v, place) then v.tag = "all" end
            break
        elseif place and kind == "go" then
            v.sel = place.id
            if skyss_hubmap.teleport(player, place.id) then return true end
            break
        end
    end
    show(player)
    return true
end)

-- ── Item ─────────────────────────────────────────────────────────────────────

local function use(_, user)
    if user and user:is_player() then show(user) end
end

core.register_craftitem(ITEM, {
    description = S("HUB map") .. "\n" .. core.colorize("#aaaaaa", S("Use it to teleport around the HUB")),
    inventory_image = "skyss_hubmap_item.png",
    wield_image = "skyss_hubmap_item.png",
    stack_max = 1,
    groups = { not_in_creative_inventory = 1 },
    on_use = use,
    on_place = use,
    on_secondary_use = use,
    -- In the classrooms toolbar the map cannot be dropped; elsewhere it stays.
    on_drop = bridge and bridge.on_drop or function(itemstack) return itemstack end,
})

-- Everyone carries the map: in a dedicated slot of the classrooms toolbar, or
-- in the inventory when classrooms_bridge is not loaded.
if bridge and bridge.register_tool then
    bridge.register_tool(TOOL, ITEM, TOOL_ORDER)
end

core.register_on_joinplayer(function(player)
    local name = player:get_player_name()
    core.after(1, function()
        local current = core.get_player_by_name(name)
        if not current then return end
        if bridge and bridge.set_tool then
            bridge.set_tool(current, TOOL, true)
        else
            local inv = current:get_inventory()
            if not inv:contains_item("main", ITEM) then inv:add_item("main", ITEM) end
        end
    end)
end)

core.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    views[name], last_tp[name] = nil, nil
end)

core.register_chatcommand("hubmap", {
    description = S("Open the HUB map"),
    func = function(name)
        local player = core.get_player_by_name(name)
        if not player then return false end
        show(player)
        return true
    end,
})

core.log("action", "[skyss_hubmap] Loaded, " .. #PLACES .. " places")
