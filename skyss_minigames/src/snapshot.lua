local P = ...

-- Each match starts by saving its area (nodes as a schematic, metadata
-- apart) and ends by putting it back. A "dirty" flag in mod storage marks
-- areas saved but not yet restored, so a crash mid-match is repaired at the
-- next start.

local SNAP_DIR = P.DIR .. "/snapshots"
core.mkdir(SNAP_DIR)

local function paths(arena)
    local base = SNAP_DIR .. "/" .. arena.name
    return base .. ".mts", base .. ".meta"
end

local function dirty_key(arena)
    return "dirty:" .. arena.name
end

local EMERGE_TIMEOUT = 15

local function with_area(arena, fn)
    local done = false
    core.emerge_area(arena.pos1, arena.pos2, function(_, _, remaining)
        if remaining == 0 and not done then
            done = true
            fn()
        end
    end)
    -- A busy emerge queue must not leave a match stuck while loading: the
    -- hub map is pre-generated, so loading it from disk is enough.
    core.after(EMERGE_TIMEOUT, function()
        if done then return end
        done = true
        core.log("warning", "[skyss_minigames] Emerging " .. arena.name .. " timed out, loading it directly")
        core.load_area(arena.pos1, arena.pos2)
        fn()
    end)
end

-- callback(ok)
function P.snapshot_take(arena, callback)
    with_area(arena, function()
        local mts, meta_file = paths(arena)
        if not core.create_schematic(arena.pos1, arena.pos2, nil, mts) then
            core.log("error", "[skyss_minigames] Could not save the area of " .. arena.name)
            callback(false)
            return
        end
        local metas = {}
        for _, pos in ipairs(core.find_nodes_with_meta(arena.pos1, arena.pos2)) do
            local data = core.get_meta(pos):to_table()
            if data then
                for list_name, list in pairs(data.inventory or {}) do
                    data.inventory[list_name] = P.item_strings(list)
                end
                table.insert(metas, { pos = pos, meta = data })
            end
        end
        if not core.safe_file_write(meta_file, core.serialize(metas)) then
            core.log("error", "[skyss_minigames] Could not save the metadata of " .. arena.name)
            callback(false)
            return
        end
        P.storage:set_string(dirty_key(arena), "1")
        callback(true)
    end)
end

local function remove_loose_objects(arena)
    local p2 = vector.offset(arena.pos2, 1, 1, 1)
    for _, obj in ipairs(core.get_objects_in_area(arena.pos1, p2)) do
        local entity = obj:get_luaentity()
        if entity and (entity.name == "__builtin:item" or entity.name == "__builtin:falling_node") then
            obj:remove()
        end
    end
end

-- callback(ok)
function P.snapshot_restore(arena, callback)
    local mts, meta_file = paths(arena)
    local file = io.open(meta_file, "r")
    if not file then
        P.storage:set_string(dirty_key(arena), "")
        callback(false)
        return
    end
    local metas = core.deserialize(file:read("*a")) or {}
    file:close()

    with_area(arena, function()
        -- Schematics do not touch metadata: clear what the match left first.
        for _, pos in ipairs(core.find_nodes_with_meta(arena.pos1, arena.pos2)) do
            core.get_meta(pos):from_table(nil)
        end
        local ok = core.place_schematic(arena.pos1, mts, "0", nil, true)
        for _, entry in ipairs(metas) do
            core.get_meta(entry.pos):from_table(entry.meta)
        end
        remove_loose_objects(arena)
        if ok then
            P.storage:set_string(dirty_key(arena), "")
        else
            core.log("error", "[skyss_minigames] Could not restore the area of " .. arena.name)
        end
        callback(ok ~= nil and ok ~= false)
    end)
end

function P.snapshot_is_dirty(arena)
    return P.storage:get_string(dirty_key(arena)) == "1"
end

-- Repair areas left mid-match by a crash or a shutdown.
core.register_on_mods_loaded(function()
    core.after(2, function()
        for _, arena in pairs(P.arenas) do
            if P.snapshot_is_dirty(arena) and not arena.match then
                arena.resetting = true
                core.log("action", "[skyss_minigames] Restoring " .. arena.name .. " after an interrupted match")
                P.snapshot_restore(arena, function()
                    arena.resetting = false
                end)
            end
        end
    end)
end)
