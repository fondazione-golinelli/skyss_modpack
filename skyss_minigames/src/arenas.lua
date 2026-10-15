local P = ...

-- Arenas, launchers and game settings live in
-- <world>/skyss_minigames/arenas.json. hubgen writes it with the map, admins
-- change it with the in-game editor, and the raw document is written back
-- as-is so unknown keys survive. Format: see README.md.
--
-- One launcher per game, in the hub: players queue there and the match runs
-- in any free arena of that game. Players come back to the launcher's exit.

P.DIR = core.get_worldpath() .. "/skyss_minigames"
local FILE = P.DIR .. "/arenas.json"
core.mkdir(P.DIR)

P.arenas = {}     -- [name] = arena record
P.launchers = {}  -- [game] = { pos, yaw, exit = point|nil }
local doc = { version = 2, arenas = {}, launchers = {}, games = {} }
local launcher_at = {}  -- [hash of launcher pos] = game

-- Game settings an admin may override, with their type.
P.GAME_SETTINGS = {
    enabled = "boolean",
    time_limit = "number",
    min_players = "number",
    max_players = "number",
    can_dig = "boolean",
    can_place = "boolean",
}

local function build(name, raw)
    if type(raw) ~= "table" then return nil, "not an object" end
    local p1, p2 = P.to_vec(raw.pos1), P.to_vec(raw.pos2)
    if type(raw.game) ~= "string" or not p1 or not p2 then
        return nil, "needs game, pos1 and pos2"
    end
    local arena = {
        name = name,
        game = raw.game,
        params = type(raw.params) == "table" and raw.params or {},
        exclusive = raw.exclusive,
        spawns = {},
        fixtures = {},
    }
    arena.pos1, arena.pos2 = vector.sort(p1, p2)
    for _, spec in ipairs(raw.spawns or {}) do
        local point = P.parse_point(spec)
        if point then table.insert(arena.spawns, point) end
    end
    arena.exit = raw.exit and P.parse_point(raw.exit)
    for _, spec in ipairs(raw.fixtures or {}) do
        local pos = P.to_vec(spec.pos)
        if pos and type(spec.node) == "string" then
            table.insert(arena.fixtures, {
                pos = pos, node = { name = spec.node, param2 = tonumber(spec.param2) or 0 },
            })
        end
    end
    return arena
end

-- A game setting: admin override from arenas.json, else the game's default.
function P.game_setting(game_name, key)
    local overrides = doc.games[game_name]
    if type(overrides) == "table" and overrides[key] ~= nil and P.GAME_SETTINGS[key] then
        return overrides[key]
    end
    local game = P.games[game_name]
    return game and game[key]
end

-- An arena setting: arena value, else the game setting.
function P.setting(arena, key)
    if arena[key] ~= nil then return arena[key] end
    return P.game_setting(arena.game, key)
end

function P.game_enabled(game_name)
    return P.games[game_name] ~= nil and P.game_setting(game_name, "enabled") ~= false
end

function P.game_limits(game_name)
    if P.games[game_name].mode == "solo" then return 1, 1 end
    local min = math.max(1, tonumber(P.game_setting(game_name, "min_players")) or 1)
    local max = math.max(min, tonumber(P.game_setting(game_name, "max_players")) or min)
    return min, max
end

function P.limits(arena)
    return P.game_limits(arena.game)
end

function P.arena_title(arena)
    local game = P.games[arena.game]
    return (game and game.title) or arena.name
end

-- Arenas of a game, sorted by name.
function P.arenas_of(game_name)
    local list = {}
    for _, arena in pairs(P.arenas) do
        if arena.game == game_name then table.insert(list, arena) end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

function P.game_of_launcher(pos)
    return launcher_at[core.hash_node_position(vector.round(pos))]
end

-- Arena containing pos (arenas do not overlap).
function P.arena_at(pos)
    for _, arena in pairs(P.arenas) do
        if P.inside(pos, arena.pos1, arena.pos2) then return arena end
    end
end

-- Where players go after a match: the arena's own exit, else the exit of
-- the game's launcher in the hub, else in front of the launcher, else the
-- hub spawn.
function P.exit_point(arena)
    if arena.exit then return arena.exit end
    local launcher = P.launchers[arena.game]
    if launcher then
        if launcher.exit then return launcher.exit end
        local front = vector.new(-math.sin(launcher.yaw), 0, math.cos(launcher.yaw))
        return { pos = vector.add(launcher.pos, vector.round(vector.multiply(front, 2))),
            yaw = launcher.yaw + math.pi }
    end
    return P.hub_point() or arena.spawns[1]
end

function P.hub_point()
    if core.global_exists("hub") and hub.get_hub_spawn_point then
        return { pos = hub.get_hub_spawn_point() }
    end
    local pos = core.setting_get_pos("static_spawnpoint")
    return pos and { pos = pos }
end

-- Puts launchers and fixtures back if the map lacks them (new map, someone
-- with worldedit, ...). set_node runs on_construct, which bins need.
local function ensure_node(pos, node)
    core.emerge_area(pos, pos, function(_, _, remaining)
        if remaining > 0 then return end
        local current = core.get_node(pos)
        if current.name ~= node.name or (node.param2 and current.param2 ~= node.param2) then
            core.set_node(pos, node)
        end
    end)
end

function P.launcher_node(launcher)
    return {
        name = "skyss_minigames:launcher",
        param2 = core.dir_to_facedir(vector.new(-math.sin(launcher.yaw), 0, math.cos(launcher.yaw))),
    }
end

function P.ensure_launcher(game_name)
    local launcher = P.launchers[game_name]
    if launcher and P.games[game_name] then
        ensure_node(launcher.pos, P.launcher_node(launcher))
    end
end

function P.ensure_arena_nodes(arena)
    for _, fixture in ipairs(arena.fixtures) do
        if core.registered_nodes[fixture.node.name] then
            ensure_node(fixture.pos, fixture.node)
        else
            core.log("warning", "[skyss_minigames] Arena " .. arena.name .. ": unknown fixture node " .. fixture.node.name)
        end
    end
end

-- Returns the number of arenas loaded and a list of problems.
function P.load_arenas()
    local problems = {}
    local file = io.open(FILE, "r")
    if file then
        local text = file:read("*a")
        file:close()
        local parsed = core.parse_json(text)
        if type(parsed) == "table" then
            doc = parsed
        else
            table.insert(problems, "arenas.json is not valid JSON")
        end
    end
    -- write_json turns an empty table into null.
    for _, key in ipairs({ "arenas", "launchers", "games" }) do
        if type(doc[key]) ~= "table" then doc[key] = {} end
    end

    local old = P.arenas
    P.arenas = {}
    local loaded = 0
    for name, raw in pairs(doc.arenas) do
        local arena, err = build(name, raw)
        if arena and not P.games[arena.game] then
            arena, err = nil, "unknown game " .. arena.game
        elseif arena and #arena.spawns == 0 then
            arena, err = nil, "no spawns"
        end
        if arena then
            -- Keep runtime state across reloads of an arena in use.
            local previous = old[name]
            if previous then
                arena.match, arena.resetting = previous.match, previous.resetting
                if arena.match then arena.match.arena = arena end
            end
            P.arenas[name] = arena
            loaded = loaded + 1
        else
            table.insert(problems, name .. ": " .. err)
        end
    end
    -- An arena removed from the file while in use stays until its match ends.
    for name, arena in pairs(old) do
        if not P.arenas[name] and (arena.match or arena.resetting) then
            P.arenas[name] = arena
        end
    end

    local old_launchers = launcher_at
    P.launchers, launcher_at = {}, {}
    for game_name, raw in pairs(doc.launchers) do
        local point = type(raw) == "table" and P.parse_point(raw)
        if point then
            point.exit = raw.exit and P.parse_point(raw.exit)
            P.launchers[game_name] = point
            launcher_at[core.hash_node_position(vector.round(point.pos))] = game_name
        else
            table.insert(problems, "launcher " .. tostring(game_name) .. ": needs pos")
        end
    end

    -- A launcher that moved or went away leaves its node behind: remember
    -- where, so it is removed even if the server restarts first.
    if type(doc.stale_launchers) ~= "table" then doc.stale_launchers = nil end
    for hash in pairs(old_launchers) do
        if not launcher_at[hash] then
            doc.stale_launchers = doc.stale_launchers or {}
            table.insert(doc.stale_launchers, P.vec_to_json(core.get_position_from_hash(hash)))
        end
    end
    if doc.stale_launchers then core.after(0, P.clean_stale_launchers) end

    for _, problem in ipairs(problems) do
        core.log("warning", "[skyss_minigames] " .. problem)
    end
    return loaded, problems
end

local function write(text)
    return core.safe_file_write(FILE, text)
end

-- Earlier versions of the file, newest last, for Undo (this server run).
local undo_stack = {}
local UNDO_MAX = 30

function P.save_arenas()
    doc.version = 2
    local file = io.open(FILE, "r")
    if file then
        local previous = file:read("*a")
        file:close()
        table.insert(undo_stack, previous)
        if #undo_stack > UNDO_MAX then table.remove(undo_stack, 1) end
    end
    return write(core.write_json(doc, true))
end

function P.undo_count()
    return #undo_stack
end

-- Puts the previous version of arenas.json back. Returns ok.
function P.undo_arenas()
    local text = table.remove(undo_stack)
    if not text or not write(text) then return false end
    P.load_arenas()
    for game_name in pairs(P.launchers) do P.ensure_launcher(game_name) end
    for _, arena in pairs(P.arenas) do P.ensure_arena_nodes(arena) end
    if P.label_launchers then P.label_launchers() end
    if P.refresh_all_markers then P.refresh_all_markers() end
    return true
end

-- Removes launcher nodes (and their labels) left where no launcher is now.
function P.clean_stale_launchers()
    local list = doc.stale_launchers
    if not list then return end
    doc.stale_launchers = nil
    write(core.write_json(doc, true))
    for _, spec in ipairs(list) do
        local pos = P.to_vec(spec)
        if pos and not launcher_at[core.hash_node_position(pos)] then
            core.emerge_area(pos, pos, function(_, _, remaining)
                if remaining > 0 or launcher_at[core.hash_node_position(pos)] then return end
                if core.get_node(pos).name == "skyss_minigames:launcher" then
                    core.remove_node(pos)
                    core.log("action", "[skyss_minigames] Removed old launcher at " .. core.pos_to_string(pos))
                end
                for _, obj in ipairs(core.get_objects_inside_radius(vector.offset(pos, 0, 1.3, 0), 0.6)) do
                    local entity = obj:get_luaentity()
                    if entity and entity.name == "skyss_minigames:launcher_label" then obj:remove() end
                end
            end)
        end
    end
end

-- The editor works on the raw document, then saves and reloads.
function P.raw_arena(name)
    return doc.arenas[name]
end

function P.raw_arena_names()
    local names = {}
    for name in pairs(doc.arenas) do table.insert(names, name) end
    table.sort(names)
    return names
end

function P.set_raw_arena(name, raw)
    doc.arenas[name] = raw
end

function P.raw_launcher(game_name)
    return doc.launchers[game_name]
end

function P.set_raw_launcher(game_name, raw)
    doc.launchers[game_name] = raw
end

-- Admin overrides of a game's settings (created on demand).
function P.raw_game(game_name)
    if type(doc.games[game_name]) ~= "table" then doc.games[game_name] = {} end
    return doc.games[game_name]
end

function P.reset_raw_game(game_name)
    doc.games[game_name] = nil
end

core.register_on_mods_loaded(function()
    local loaded = P.load_arenas()
    core.log("action", "[skyss_minigames] " .. loaded .. " arena(s) loaded from " .. FILE)
    -- Leave the first server step to other mods before touching the map.
    core.after(1, function()
        for game_name in pairs(P.launchers) do
            P.ensure_launcher(game_name)
        end
        for _, arena in pairs(P.arenas) do
            P.ensure_arena_nodes(arena)
        end
    end)
end)
