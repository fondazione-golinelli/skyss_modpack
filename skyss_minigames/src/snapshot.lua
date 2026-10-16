local P = ...

-- Each match starts by saving its area (nodes and param2 through a
-- VoxelManip, metadata apart) and ends by putting it back. A "dirty" flag in
-- mod storage marks areas saved but not yet restored, so a crash mid-match
-- is repaired at the next start.
--
-- Not schematics: core.place_schematic() keeps a schematic file in memory by
-- its path for the whole server session, so every restore after the first
-- one would put back the first snapshot again (and each new file would stay
-- in memory for good).

local SNAP_DIR = P.DIR .. "/snapshots"
core.mkdir(SNAP_DIR)

local FORMAT = "vm1"
local CHUNK = 2048  -- nodes packed per string.char call

local function paths(arena)
    local base = SNAP_DIR .. "/" .. arena.name
    return base .. ".snap", base .. ".meta", base .. ".mts"
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

local function compress(data)
    local ok, out = pcall(core.compress, data, "zstd")
    if ok and out then return out, "zstd" end
    return core.compress(data, "deflate"), "deflate"
end

-- Nodes of the box p1..p2 as a palette (content id -> index) and a string
-- of 3 bytes per node: palette index (2 bytes) and param2.
local function read_box(p1, p2)
    local vm = core.get_voxel_manip()
    local e1, e2 = vm:read_from_map(p1, p2)
    local area = VoxelArea:new({ MinEdge = e1, MaxEdge = e2 })
    local data, param2 = vm:get_data(), vm:get_param2_data()
    local palette, names = {}, {}
    local parts, bytes, n = {}, {}, 0
    local char, floor = string.char, math.floor
    for z = p1.z, p2.z do
        for y = p1.y, p2.y do
            local i = area:index(p1.x, y, z)
            for _ = p1.x, p2.x do
                local id = data[i]
                local idx = palette[id]
                if not idx then
                    names[#names + 1] = core.get_name_from_content_id(id)
                    idx = #names
                    palette[id] = idx
                end
                bytes[n + 1] = idx % 256
                bytes[n + 2] = floor(idx / 256)
                bytes[n + 3] = param2[i]
                n = n + 3
                if n >= CHUNK * 3 then
                    parts[#parts + 1] = char(unpack(bytes, 1, n))
                    n = 0
                end
                i = i + 1
            end
        end
    end
    if n > 0 then parts[#parts + 1] = char(unpack(bytes, 1, n)) end
    return names, table.concat(parts)
end

local function write_box(p1, p2, names, blob)
    local ids = {}
    for i, name in ipairs(names) do
        ids[i] = name ~= "ignore" and core.registered_nodes[name] and core.get_content_id(name) or false
    end
    local vm = core.get_voxel_manip()
    local e1, e2 = vm:read_from_map(p1, p2)
    local area = VoxelArea:new({ MinEdge = e1, MaxEdge = e2 })
    local data, param2 = vm:get_data(), vm:get_param2_data()
    local byte = string.byte
    local pos, len = 1, #blob
    for z = p1.z, p2.z do
        for y = p1.y, p2.y do
            local i = area:index(p1.x, y, z)
            local row = { byte(blob, pos, pos + (p2.x - p1.x + 1) * 3 - 1) }
            for k = 1, #row, 3 do
                local id = ids[row[k] + row[k + 1] * 256]
                if id then  -- nodes no longer registered are left as they are
                    data[i] = id
                    param2[i] = row[k + 2]
                end
                i = i + 1
            end
            pos = pos + (p2.x - p1.x + 1) * 3
            if pos > len + 1 then return false end
        end
    end
    vm:set_data(data)
    vm:set_param2_data(param2)
    vm:write_to_map(true)
    return true
end

-- callback(ok)
function P.snapshot_take(arena, callback)
    with_area(arena, function()
        local snap, meta_file = paths(arena)
        local p1, p2 = vector.copy(arena.pos1), vector.copy(arena.pos2)
        local t0 = core.get_us_time()
        local names, blob = read_box(p1, p2)
        local packed, method = compress(blob)
        if not packed or not core.safe_file_write(snap, packed) then
            core.log("error", "[skyss_minigames] Could not save the area of " .. arena.name)
            callback(false)
            return
        end
        local metas = {}
        for _, pos in ipairs(core.find_nodes_with_meta(p1, p2)) do
            local data = core.get_meta(pos):to_table()
            if data then
                for list_name, list in pairs(data.inventory or {}) do
                    data.inventory[list_name] = P.item_strings(list)
                end
                table.insert(metas, { pos = pos, meta = data })
            end
        end
        -- The corners are kept with the snapshot: the arena's may change
        -- (editor, hubgen) between a crash and the repair.
        local data = { format = FORMAT, origin = p1, pos2 = p2, names = names,
            compression = method, metas = metas }
        if not core.safe_file_write(meta_file, core.serialize(data)) then
            core.log("error", "[skyss_minigames] Could not save the metadata of " .. arena.name)
            callback(false)
            return
        end
        P.storage:set_string(dirty_key(arena), "1")
        core.log("action", ("[skyss_minigames] Saved %s (%d nodes, %d KiB) in %d ms"):format(arena.name,
            #blob / 3, math.floor(#packed / 1024), math.floor((core.get_us_time() - t0) / 1000)))
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

-- Snapshots written before the VoxelManip format: a schematic at the
-- arena's pos1 of that time (if the arena has changed since, its pos2 tells).
local function restore_schematic(arena, mts)
    local schem = core.read_schematic(mts, {})
    local size = schem and schem.size
    if not size then return false end
    local origin = vector.subtract(arena.pos2, vector.subtract(size, 1))
    return core.place_schematic(origin, mts, "0", nil, true)
end

-- callback(ok)
function P.snapshot_restore(arena, callback)
    local snap, meta_file, mts = paths(arena)
    local file = io.open(meta_file, "r")
    if not file then
        P.storage:set_string(dirty_key(arena), "")
        callback(false)
        return
    end
    local data = core.deserialize(file:read("*a")) or {}
    file:close()

    with_area(arena, function()
        -- Metadata is not part of the nodes: clear what the match left first.
        for _, pos in ipairs(core.find_nodes_with_meta(arena.pos1, arena.pos2)) do
            core.get_meta(pos):from_table(nil)
        end
        local ok, metas
        if data.format == FORMAT then
            metas = data.metas or {}
            local f = io.open(snap, "rb")
            local packed = f and f:read("*a")
            if f then f:close() end
            local blob = packed and core.decompress(packed, data.compression or "deflate")
            ok = blob and write_box(data.origin, data.pos2, data.names, blob) or false
        else
            metas = data.metas or data
            ok = restore_schematic(arena, mts)
        end
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
