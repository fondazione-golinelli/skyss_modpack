local P = ...

P.hud_type = core.features.hud_def_type_field and "type" or "hud_elem_type"

-- Compass names accepted in arenas.json "look" fields. Luanti yaw 0 faces +Z
-- and grows counter-clockwise, so +X (east) is 270 degrees.
local LOOK = { north = 0, west = 90, south = 180, east = 270 }

-- Accepts [x, y, z] or {x =, y =, z =}.
function P.to_vec(v)
    if type(v) ~= "table" then return nil end
    if v.x and v.y and v.z then return vector.new(v.x, v.y, v.z) end
    if #v == 3 then return vector.new(v[1], v[2], v[3]) end
end

function P.vec_to_json(v)
    return { v.x, v.y, v.z }
end

-- A point is [x, y, z] or {pos = [x, y, z], yaw = degrees | look = "east"}.
function P.parse_point(spec)
    if type(spec) ~= "table" then return nil end
    local pos = spec.pos and P.to_vec(spec.pos) or P.to_vec(spec)
    if not pos then return nil end
    local deg = tonumber(spec.yaw) or LOOK[spec.look or ""] or 0
    return { pos = pos, yaw = math.rad(deg) }
end

function P.point_to_json(point)
    return { pos = P.vec_to_json(point.pos), yaw = math.floor(math.deg(point.yaw) + 0.5) % 360 }
end

-- Node area p1..p2 (sorted); a player's feet may be half a node outside it.
function P.inside(pos, p1, p2)
    return pos.x >= p1.x - 0.5 and pos.x <= p2.x + 0.5
        and pos.y >= p1.y - 0.5 and pos.y <= p2.y + 0.5
        and pos.z >= p1.z - 0.5 and pos.z <= p2.z + 0.5
end

function P.count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

function P.format_time(seconds)
    seconds = math.max(0, math.floor(seconds + 0.5))
    return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
end

function P.item_strings(list)
    local out = {}
    for i, stack in ipairs(list or {}) do
        out[i] = type(stack) == "string" and stack or ItemStack(stack):to_string()
    end
    return out
end

-- Runs fn with error reporting, so a broken game callback cannot leave an
-- arena stuck in a match. Returns fn's first result.
function P.call(label, fn, ...)
    if not fn then return end
    local ok, result = xpcall(fn, debug.traceback, ...)
    if not ok then
        core.log("error", "[skyss_minigames] " .. label .. " failed: " .. tostring(result))
        return
    end
    return result
end

core.register_privilege("minigames_admin", {
    description = "Can configure minigame arenas and stop matches",
    give_to_singleplayer = false,
})

function P.is_admin(name)
    return core.check_player_privs(name, { minigames_admin = true })
        or core.check_player_privs(name, { server = true })
        or core.check_player_privs(name, { hub_admin = true })
end

-- classrooms_bridge plugs its teacher check in here.
local staff_check
function skyss_minigames.set_staff_check(fn)
    staff_check = fn
end

-- Staff (admins and teachers) may start matches for others, stop them and
-- walk into arenas that are in use.
function P.is_staff(name)
    return P.is_admin(name) or (staff_check ~= nil and staff_check(name) == true)
end

function P.teleport(player, point)
    player:set_pos(point.pos)
    if point.yaw then
        player:set_look_horizontal(point.yaw)
        player:set_look_vertical(0)
    end
end
