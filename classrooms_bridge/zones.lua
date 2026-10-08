-- Protected zones for class worlds.
--
-- The classrooms proxy owns the zone list and sends it with "set_zones" when
-- zones or group membership change and whenever a player joins this world.
-- The list is persisted in mod storage so protection keeps working after a
-- restart before the proxy re-sends it.
--
-- A zone covers the full height between two X/Z corners. Without `allowed`
-- only staff may build ("teachers only"); with `allowed` the listed group
-- members may build too; `open` zones protect nothing (meeting points).

local storage = minetest.get_mod_storage()
local STORAGE_KEY = "classrooms_zones"
local SHOW_SECONDS = 15
local MESSAGE_COOLDOWN = 2

local zones = {}
local is_staff = function() return false end
local last_message = {}

local zones_api = {}

local function normalize(list)
    local result = {}
    for _, z in ipairs(type(list) == "table" and list or {}) do
        local min_x, max_x = tonumber(z.min_x), tonumber(z.max_x)
        local min_z, max_z = tonumber(z.min_z), tonumber(z.max_z)
        if min_x and max_x and min_z and max_z then
            local allowed
            if type(z.allowed) == "table" then
                allowed = {}
                for _, name in ipairs(z.allowed) do
                    allowed[tostring(name)] = true
                end
            end
            table.insert(result, {
                id = z.id,
                name = tostring(z.name or "Zone"),
                group = z.group and tostring(z.group) or nil,
                open = z.open == true,
                color = tostring(z.color or "#9aa3b5"),
                min_x = math.min(min_x, max_x), max_x = math.max(min_x, max_x),
                min_z = math.min(min_z, max_z), max_z = math.max(min_z, max_z),
                allowed = allowed,
                ref_y = tonumber(z.ref_y),
                mission = type(z.mission) == "table" and z.mission or nil,
            })
        end
    end
    return result
end

local function load()
    local raw = storage:get_string(STORAGE_KEY)
    if raw ~= "" then
        local ok, data = pcall(minetest.parse_json, raw)
        if ok and type(data) == "table" then
            zones = normalize(data)
        end
    end
end
load()

-- `check(name)` reports whether a player is class staff on this world.
function zones_api.set_staff_check(check)
    is_staff = check
end

function zones_api.set(list)
    zones = normalize(list)
    storage:set_string(STORAGE_KEY, minetest.write_json(type(list) == "table" and list or {}))
    minetest.log("action", "[classrooms_bridge] Applied " .. #zones .. " protected zones")
end

local function zone_at(pos)
    local x, z = math.floor(pos.x + 0.5), math.floor(pos.z + 0.5)
    for _, zone in ipairs(zones) do
        if x >= zone.min_x and x <= zone.max_x and z >= zone.min_z and z <= zone.max_z then
            return zone
        end
    end
end

-- Returns the zone that forbids `name` from editing `pos`, if any.
function zones_api.zone_at(pos)
    return zone_at(pos)
end

function zones_api.list()
    return zones
end

local function blocking_zone(pos, name)
    if not name or name == "" or #zones == 0 then return nil end
    local zone = zone_at(pos)
    if not zone then return nil end
    if is_staff(name) or minetest.check_player_privs(name, { protection_bypass = true }) then
        return nil
    end
    if zone.open or (zone.allowed and zone.allowed[name]) then
        return nil
    end
    return zone
end

minetest.register_on_mods_loaded(function()
    local previous_is_protected = minetest.is_protected
    minetest.is_protected = function(pos, name)
        if blocking_zone(pos, name) then
            return true
        end
        return previous_is_protected(pos, name)
    end

end)

minetest.register_on_protection_violation(function(pos, name)
    local zone = blocking_zone(pos, name)
    if not zone then return end
    local now = minetest.get_us_time() / 1e6
    if last_message[name] and now - last_message[name] < MESSAGE_COOLDOWN then return end
    last_message[name] = now
    local text = zone.group
        and ("Only group " .. zone.group .. " can build in \"" .. zone.name .. "\".")
        or ("\"" .. zone.name .. "\" is protected by your teacher.")
    minetest.chat_send_player(name, minetest.colorize("#FFB347", "[Zone] " .. text))
end)

minetest.register_on_leaveplayer(function(player)
    last_message[player:get_player_name()] = nil
end)

-- Draws the zone borders around the player with particles, and labels each
-- zone with a waypoint, for a few seconds.
function zones_api.show(player)
    local name = player:get_player_name()
    if #zones == 0 then
        minetest.chat_send_player(name, minetest.colorize("#FFB347", "[Zone] This world has no zones."))
        return
    end
    local pos = player:get_pos()
    local y = math.floor(pos.y + 0.5)
    local huds = {}
    for _, zone in ipairs(zones) do
        local color = zone.color:match("^#%x%x%x%x%x%x$") and zone.color or "#9aa3b5"
        local texture = "[fill:4x4:" .. color
        local perimeter = 2 * ((zone.max_x - zone.min_x) + (zone.max_z - zone.min_z))
        local step = math.max(1, math.ceil(perimeter / 400))
        local function mark(x, z)
            for dy = 0, 2 do
                minetest.add_particle({
                    pos = { x = x, y = y + dy, z = z },
                    expirationtime = SHOW_SECONDS,
                    size = 3,
                    texture = texture,
                    glow = 14,
                    playername = name,
                })
            end
        end
        for x = zone.min_x, zone.max_x, step do
            mark(x, zone.min_z - 0.5)
            mark(x, zone.max_z + 0.5)
        end
        for z = zone.min_z, zone.max_z, step do
            mark(zone.min_x - 0.5, z)
            mark(zone.max_x + 0.5, z)
        end
        local label = zone.name .. (zone.open and " (everyone)"
            or zone.group and (" (" .. zone.group .. ")") or " (teachers only)")
        table.insert(huds, player:hud_add({
            type = "waypoint",
            name = label,
            text = "",
            precision = 0,
            number = tonumber(color:sub(2), 16),
            world_pos = {
                x = (zone.min_x + zone.max_x) / 2,
                y = y + 3,
                z = (zone.min_z + zone.max_z) / 2,
            },
        }))
    end
    minetest.after(SHOW_SECONDS, function()
        local current = minetest.get_player_by_name(name)
        if not current then return end
        for _, id in ipairs(huds) do
            current:hud_remove(id)
        end
    end)
    minetest.chat_send_player(name, minetest.colorize("#00CCFF",
        "[Zone] Showing " .. #zones .. " zone(s) for " .. SHOW_SECONDS .. " seconds."))
end

-- ── Corner markers while a teacher draws a new zone ──────────────────────────

local drafts = {} -- [name] = { corners = { [1] = pos, [2] = pos }, spawners = {} }
local MARKER_COLOR = "#FFE066"
local TELEPORT_COLOR = "#66E0FF"

local function clear_spawners(draft)
    for _, id in ipairs(draft.spawners) do
        minetest.delete_particlespawner(id)
    end
    draft.spawners = {}
end

-- Infinite spawner emitting `rate` particles per second inside a box.
local function line_spawner(name, minpos, maxpos, color, rate, size)
    return minetest.add_particlespawner({
        amount = rate,
        time = 0,
        minpos = minpos,
        maxpos = maxpos,
        minvel = { x = 0, y = 0.1, z = 0 },
        maxvel = { x = 0, y = 0.4, z = 0 },
        minexptime = 0.8,
        maxexptime = 1.4,
        minsize = size,
        maxsize = size * 1.5,
        texture = "[fill:4x4:" .. color,
        glow = 14,
        playername = name,
    })
end

local function redraw_draft(name)
    local draft = drafts[name]
    if not draft then return end
    clear_spawners(draft)
    for _, pos in pairs(draft.corners) do
        -- A light beam on each marked corner.
        table.insert(draft.spawners, line_spawner(name,
            { x = pos.x, y = pos.y, z = pos.z },
            { x = pos.x, y = pos.y + 8, z = pos.z },
            MARKER_COLOR, 30, 2.5))
    end
    if draft.tp then
        table.insert(draft.spawners, line_spawner(name,
            { x = draft.tp.x, y = draft.tp.y, z = draft.tp.z },
            { x = draft.tp.x, y = draft.tp.y + 4, z = draft.tp.z },
            TELEPORT_COLOR, 40, 2))
    end
    local a, b = draft.corners[1], draft.corners[2]
    if a and b then
        -- Preview of the future border at the first corner's height.
        local x1, x2 = math.min(a.x, b.x) - 0.5, math.max(a.x, b.x) + 0.5
        local z1, z2 = math.min(a.z, b.z) - 0.5, math.max(a.z, b.z) + 0.5
        local y1, y2 = math.min(a.y, b.y), math.min(a.y, b.y) + 2
        local rate_x = math.min(120, math.max(10, (x2 - x1) * 2))
        local rate_z = math.min(120, math.max(10, (z2 - z1) * 2))
        for _, edge in ipairs({
            { { x = x1, y = y1, z = z1 }, { x = x2, y = y2, z = z1 }, rate_x },
            { { x = x1, y = y1, z = z2 }, { x = x2, y = y2, z = z2 }, rate_x },
            { { x = x1, y = y1, z = z1 }, { x = x1, y = y2, z = z2 }, rate_z },
            { { x = x2, y = y1, z = z1 }, { x = x2, y = y2, z = z2 }, rate_z },
        }) do
            table.insert(draft.spawners, line_spawner(name, edge[1], edge[2], MARKER_COLOR, edge[3], 1.2))
        end
    end
end

function zones_api.mark_corner(player, corner, pos)
    local name = player:get_player_name()
    drafts[name] = drafts[name] or { corners = {}, spawners = {} }
    drafts[name].corners[corner] = pos
    redraw_draft(name)
end

function zones_api.mark_teleport(player, pos)
    local name = player:get_player_name()
    drafts[name] = drafts[name] or { corners = {}, spawners = {} }
    drafts[name].tp = pos
    redraw_draft(name)
end

function zones_api.clear_draft(name)
    local draft = drafts[name]
    if draft then
        clear_spawners(draft)
        drafts[name] = nil
    end
end

-- ── Border glow and "Entered zone" notice ────────────────────────────────────

local GLOW_RADIUS = 24
local SURFACE_SCAN = 12      -- nodes above/below the player searched for the ground
local SURFACE_TTL = 8        -- seconds a column's surface height is cached
local current_zone = {} -- [name] = zone id
local notice_huds = {}  -- [name] = { ids, token }
local surface_cache = {} -- ["x,z"] = { y, t, ref }
local surface_cache_size = 0

local function is_ground(name)
    local def = minetest.registered_nodes[name]
    if not def then return false end
    return def.walkable or def.liquidtype == "source"
end

-- Height of the top face of the ground at a column, near `ref_y`.
local function surface_y(x, z, ref_y)
    local key = x .. "," .. z
    local now = minetest.get_us_time() / 1e6
    local cached = surface_cache[key]
    if cached and now - cached.t < SURFACE_TTL and math.abs(cached.ref - ref_y) < 6 then
        return cached.y
    end
    local found
    for y = ref_y + SURFACE_SCAN, ref_y - SURFACE_SCAN, -1 do
        local node = minetest.get_node_or_nil({ x = x, y = y, z = z })
        if node and is_ground(node.name) then
            found = y + 0.5
            break
        end
    end
    surface_cache_size = surface_cache_size + (cached and 0 or 1)
    if surface_cache_size > 20000 then
        surface_cache, surface_cache_size = {}, 0
    end
    surface_cache[key] = { y = found, t = now, ref = ref_y }
    return found
end

-- One light-curtain emitter over a run of border columns at the same height.
local function curtain(name, color, minpos, maxpos, length)
    minetest.add_particlespawner({
        amount = math.max(1, math.floor(length * 1.5)),
        time = 1,
        minpos = minpos,
        maxpos = maxpos,
        minvel = { x = 0, y = 0.5, z = 0 },
        maxvel = { x = 0, y = 0.9, z = 0 },
        minexptime = 1.2,
        maxexptime = 2.0,
        minsize = 2.5,
        maxsize = 4,
        vertical = true,
        glow = 14,
        texture = {
            name = "classrooms_bridge_zone_glow.png^[multiply:" .. color,
            scale = { x = 0.25, y = 1.6 },
            alpha_tween = { 0.85, 0 },
            blend = "add",
        },
        playername = name,
    })
end

-- Light rising from the top of the border blocks near the player.
local function glow_edges(player, pos)
    local name = player:get_player_name()
    local px, pz = math.floor(pos.x + 0.5), math.floor(pos.z + 0.5)
    local ref_y = math.floor(pos.y + 0.5)
    for _, zone in ipairs(zones) do
        local color = zone.color:match("^#%x%x%x%x%x%x$") and zone.color or "#9aa3b5"
        -- Each edge: fixed coordinate (just outside the zone) and a range.
        local edges = {
            { axis = "x", fixed = zone.min_z - 0.5, from = zone.min_x, to = zone.max_x, near = math.abs(pz - zone.min_z) },
            { axis = "x", fixed = zone.max_z + 0.5, from = zone.min_x, to = zone.max_x, near = math.abs(pz - zone.max_z) },
            { axis = "z", fixed = zone.min_x - 0.5, from = zone.min_z, to = zone.max_z, near = math.abs(px - zone.min_x) },
            { axis = "z", fixed = zone.max_x + 0.5, from = zone.min_z, to = zone.max_z, near = math.abs(px - zone.max_x) },
        }
        for _, edge in ipairs(edges) do
            if edge.near <= GLOW_RADIUS then
                local center = edge.axis == "x" and px or pz
                local a = math.max(edge.from, center - GLOW_RADIUS)
                local b = math.min(edge.to, center + GLOW_RADIUS)
                -- Ground under the border: the inner column of the zone.
                local inner = edge.axis == "x"
                    and (edge.fixed < zone.min_z and zone.min_z or zone.max_z)
                    or (edge.fixed < zone.min_x and zone.min_x or zone.max_x)
                local run_start, run_y
                local function flush(last)
                    if run_start and run_y then
                        local p1, p2
                        if edge.axis == "x" then
                            p1 = { x = run_start - 0.5, y = run_y, z = edge.fixed }
                            p2 = { x = last + 0.5, y = run_y + 0.05, z = edge.fixed }
                        else
                            p1 = { x = edge.fixed, y = run_y, z = run_start - 0.5 }
                            p2 = { x = edge.fixed, y = run_y + 0.05, z = last + 0.5 }
                        end
                        curtain(name, color, p1, p2, last - run_start + 1)
                    end
                end
                for i = a, b do
                    local y = edge.axis == "x" and surface_y(i, inner, ref_y) or surface_y(inner, i, ref_y)
                    if y ~= run_y then
                        flush(i - 1)
                        run_start, run_y = i, y
                    end
                end
                flush(b)
            end
        end
    end
end

local function show_notice(player, title, subtitle, color)
    local name = player:get_player_name()
    local old = notice_huds[name]
    if old then
        for _, id in ipairs(old.ids) do player:hud_remove(id) end
    end
    local number = tonumber(color:sub(2, 7), 16) or 0xFFFFFF
    local ids = {
        player:hud_add({
            type = "text",
            position = { x = 0.5, y = 0.22 },
            text = title,
            number = number,
            size = { x = 2 },
            style = 1,
            alignment = { x = 0, y = 0 },
            z_index = 100,
        }),
        player:hud_add({
            type = "text",
            position = { x = 0.5, y = 0.22 },
            offset = { x = 0, y = 34 },
            text = subtitle,
            number = 0xDDDDDD,
            alignment = { x = 0, y = 0 },
            z_index = 100,
        }),
    }
    local token = {}
    notice_huds[name] = { ids = ids, token = token }
    minetest.after(3, function()
        local current = minetest.get_player_by_name(name)
        local entry = notice_huds[name]
        if not current or not entry or entry.token ~= token then return end
        for _, id in ipairs(entry.ids) do current:hud_remove(id) end
        notice_huds[name] = nil
    end)
end

local function update_presence(player, pos)
    local name = player:get_player_name()
    local zone = zone_at(pos)
    local id = zone and zone.id or false
    if current_zone[name] == id then return end
    current_zone[name] = id
    if zone then
        local who = zone.group and ("Only group " .. zone.group .. " can build here")
            or "Only teachers can build here"
        if zone.open then
            who = "Everyone can build here"
        elseif zone.allowed and zone.allowed[name] then
            who = "Your group can build here"
        elseif is_staff(name) then
            who = zone.group and ("Reserved for group " .. zone.group) or "Teachers only"
        end
        show_notice(player, "Entered zone " .. zone.name, who, zone.color)
    end
end

local tick = 0
minetest.register_globalstep(function(dtime)
    tick = tick + dtime
    if tick < 1 then return end
    tick = 0
    if #zones == 0 then return end
    for _, player in ipairs(minetest.get_connected_players()) do
        local pos = player:get_pos()
        update_presence(player, pos)
        glow_edges(player, pos)
    end
end)

minetest.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    zones_api.clear_draft(name)
    current_zone[name] = nil
    notice_huds[name] = nil
end)

return zones_api
