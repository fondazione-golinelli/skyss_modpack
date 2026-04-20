-- classrooms_bridge/init.lua
-- Lightweight bridge mod: receives commands from the proxy plugin via mod channel
-- and executes server-local actions (freeze, teleport, watch, broadcast).

local CHANNEL_NAME = "classrooms:cmd"
local channel = nil

-- Runtime state (not persisted — proxy re-sends on reconnect/server switch)
local frozen_players = {}   -- { [player_name] = true }
local watching_players = {}  -- { [player_name] = teacher_name }

-- ── Mod Channel Setup ───────────────────────────────────────────────────────

minetest.register_on_mods_loaded(function()
    channel = minetest.mod_channel_join(CHANNEL_NAME)
    minetest.log("action", "[classrooms_bridge] Joined mod channel: " .. CHANNEL_NAME)
end)

-- ── Action Handlers ─────────────────────────────────────────────────────────

local handlers = {}

function handlers.freeze(data)
    local name = data.player
    if not name then return end
    local player = minetest.get_player_by_name(name)
    if not player then return end

    frozen_players[name] = true
    -- Use playerphysics API if available (Mineclonia), fall back to direct override
    if playerphysics then
        playerphysics.add_physics_factor(player, "speed", "classrooms_freeze", 0)
        playerphysics.add_physics_factor(player, "jump", "classrooms_freeze", 0)
    else
        player:set_physics_override({ speed = 0, jump = 0 })
    end
    minetest.chat_send_player(name, minetest.colorize("#FF9900",
        "[Teacher] You have been frozen by the teacher."))
end

function handlers.unfreeze(data)
    local name = data.player
    if not name then return end

    frozen_players[name] = nil
    watching_players[name] = nil

    local player = minetest.get_player_by_name(name)
    if player then
        if playerphysics then
            playerphysics.remove_physics_factor(player, "speed", "classrooms_freeze")
            playerphysics.remove_physics_factor(player, "jump", "classrooms_freeze")
        else
            player:set_physics_override({ speed = 1, jump = 1 })
        end
        minetest.chat_send_player(name, minetest.colorize("#00CC66",
            "[Teacher] You are free to move again."))
    end
end

function handlers.watch(data)
    local name = data.player
    local teacher = data.teacher
    if not name or not teacher then return end

    local player = minetest.get_player_by_name(name)
    if not player then return end

    watching_players[name] = teacher
    minetest.chat_send_player(name, minetest.colorize("#FF9900",
        "[Teacher] Pay attention! Look at the teacher."))
end

function handlers.unwatch(data)
    local name = data.player
    if not name then return end

    watching_players[name] = nil
    minetest.chat_send_player(name, minetest.colorize("#00CC66",
        "[Teacher] You can look around freely again."))
end

function handlers.gather(data)
    local players = data.players
    local target_name = data.target
    if not players or not target_name then return end

    local target_player = minetest.get_player_by_name(target_name)
    if not target_player then return end

    local pos = target_player:get_pos()
    local count = #players
    local offset = 0

    for _, name in ipairs(players) do
        local player = minetest.get_player_by_name(name)
        if player then
            local tp_pos = {
                x = pos.x + math.cos(offset) * 2,
                y = pos.y,
                z = pos.z + math.sin(offset) * 2,
            }
            player:set_pos(tp_pos)
            offset = offset + (2 * math.pi / count)
            minetest.chat_send_player(name, minetest.colorize("#FF9900",
                "[Teacher] You have been teleported to the teacher."))
        end
    end
end

function handlers.tp_to(data)
    local player_name = data.player
    local target_name = data.target
    if not player_name or not target_name then return end

    local player = minetest.get_player_by_name(player_name)
    local target = minetest.get_player_by_name(target_name)
    if player and target then
        player:set_pos(target:get_pos())
    end
end

function handlers.broadcast(data)
    local players = data.players
    local message = data.message
    local sender = data.sender or "Teacher"
    local class_name = data.class or ""
    if not players or not message then return end

    local prefix = minetest.colorize("#FFD700",
        "[" .. class_name .. "] " .. sender .. ": ")
    local body = minetest.colorize("#FFFFFF", message)
    local formatted = prefix .. body

    for _, name in ipairs(players) do
        if minetest.get_player_by_name(name) then
            minetest.chat_send_player(name, formatted)
        end
    end
end

function handlers.ping(data)
    if channel and channel:is_writeable() then
        channel:send_all(minetest.write_json({
            action = "pong",
            server = minetest.get_server_status().description,
        }))
    end
end

-- ── Mod Channel Message Receiver ────────────────────────────────────────────

minetest.register_on_modchannel_message(function(channel_name, sender, message)
    minetest.log("action", "[classrooms_bridge] Received message on " .. channel_name .. " from '" .. sender .. "': " .. message)
    if channel_name ~= CHANNEL_NAME then return end

    local ok, data = pcall(minetest.parse_json, message)
    if not ok or type(data) ~= "table" then
        minetest.log("warning", "[classrooms_bridge] Failed to parse message: " .. tostring(message))
        return
    end

    local action = data.action
    if not action then return end

    local handler = handlers[action]
    if handler then
        handler(data)
    else
        minetest.log("warning", "[classrooms_bridge] Unknown action: " .. tostring(action))
    end
end)

-- ── Watch Teacher Loop ──────────────────────────────────────────────────────

-- Smoothing factor: higher = snappier, lower = smoother (0..1 range per second)
local WATCH_LERP_SPEED = 12

-- Normalize an angle to [-pi, pi]
local function normalize_angle(a)
    a = a % (2 * math.pi)
    if a > math.pi then a = a - 2 * math.pi end
    return a
end

-- Shortest-path lerp between two angles
local function lerp_angle(from, to, t)
    local diff = normalize_angle(to - from)
    return from + diff * t
end

minetest.register_globalstep(function(dtime)
    -- Clamp lerp factor so it stays in (0, 1] even at very low FPS
    local t = math.min(1, dtime * WATCH_LERP_SPEED)

    for student_name, teacher_name in pairs(watching_players) do
        local sp = minetest.get_player_by_name(student_name)
        local tp = minetest.get_player_by_name(teacher_name)
        if sp and tp then
            local spos = sp:get_pos()
            local tpos = tp:get_pos()

            -- Adjust for eye height
            spos.y = spos.y + 1.625
            tpos.y = tpos.y + 1.625

            local dx = tpos.x - spos.x
            local dy = tpos.y - spos.y
            local dz = tpos.z - spos.z

            local target_yaw = math.atan2(-dx, dz)
            local target_pitch = -math.atan2(dy, math.sqrt(dx * dx + dz * dz))

            local cur_yaw = sp:get_look_horizontal()
            local cur_pitch = sp:get_look_vertical()

            sp:set_look_horizontal(lerp_angle(cur_yaw, target_yaw, t))
            sp:set_look_vertical(lerp_angle(cur_pitch, target_pitch, t))
        else
            -- Teacher or student left this server
            watching_players[student_name] = nil
        end
    end
end)

-- ── Re-apply states on join ─────────────────────────────────────────────────

minetest.register_on_joinplayer(function(player)
    local name = player:get_player_name()
    if frozen_players[name] then
        minetest.after(0.2, function()
            local p = minetest.get_player_by_name(name)
            if p then
                if playerphysics then
                    playerphysics.add_physics_factor(p, "speed", "classrooms_freeze", 0)
                    playerphysics.add_physics_factor(p, "jump", "classrooms_freeze", 0)
                else
                    p:set_physics_override({ speed = 0, jump = 0 })
                end
            end
        end)
    end
end)

-- ── Cleanup on leave ────────────────────────────────────────────────────────

minetest.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    watching_players[name] = nil
    -- Keep frozen_players[name] so it re-applies if they reconnect to this server
end)

-- ── Proxy Command Stubs (for /help visibility) ──────────────────────────────
-- These are intercepted by the mt-multiserver-proxy classrooms plugin.
-- Handlers below only run on direct connections that bypass the proxy.

local function proxy_only(name)
    minetest.chat_send_player(name, minetest.colorize("#FF6600",
        "[Classrooms] Connect via the proxy to use this command."))
end

minetest.register_chatcommand("classes", {
    description = "Open teacher dashboard",
    func = function(name) proxy_only(name) end,
})

minetest.register_chatcommand("admin", {
    description = "Open admin dashboard",
    func = function(name) proxy_only(name) end,
})

minetest.register_chatcommand("lobby", {
    description = "Go back to the lobby",
    func = function(name) proxy_only(name) end,
})

minetest.register_chatcommand("freeze", {
    description = "Freeze a student or class",
    params = "<student_name|class_name>",
    func = function(name) proxy_only(name) end,
})

minetest.register_chatcommand("unfreeze", {
    description = "Unfreeze a student or class",
    params = "<student_name|class_name>",
    func = function(name) proxy_only(name) end,
})

minetest.register_chatcommand("teacher_add", {
    description = "Register a new teacher",
    params = "<username>",
    func = function(name) proxy_only(name) end,
})

minetest.register_chatcommand("teacher_remove", {
    description = "Unregister a teacher",
    params = "<username>",
    func = function(name) proxy_only(name) end,
})

minetest.register_chatcommand("teacher_list", {
    description = "List all registered teachers",
    func = function(name) proxy_only(name) end,
})

minetest.log("action", "[classrooms_bridge] Loaded successfully.")
