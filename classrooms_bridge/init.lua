-- classrooms_bridge/init.lua
-- Lightweight bridge mod: receives commands from the proxy plugin via mod channel
-- and executes server-local actions (freeze, teleport, watch, broadcast).

local CHANNEL_NAME = "classrooms:cmd"
local channel = nil
-- This API is only valid while the mod is loading. Cache the path so later
-- mod-channel callbacks can persist restart-required instance settings.
local MOD_DATA_PATH = minetest.get_mod_data_path()

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

local function write_settings(context)
    local ok = minetest.settings:write()
    if ok then
        minetest.log("action", "[classrooms_bridge] Wrote luanti.conf after " .. context)
    else
        minetest.log("warning", "[classrooms_bridge] Failed to write luanti.conf after " .. context)
    end
    return ok
end

local APPROVED_CONFIG_KEYS = {
    enable_damage = true,
    enable_pvp = true,
    mcl_enable_hunger = true,
    mobs_spawn = true,
    only_peaceful_mobs = true,
    enable_fire = true,
    mcl_explosions_griefing = true,
    static_spawnpoint = true,
    classrooms_spawn_yaw = true,
    classrooms_spawn_pitch = true,
}

local CONFIG_KEY_ORDER = {
    "enable_damage",
    "enable_pvp",
    "mcl_enable_hunger",
    "mobs_spawn",
    "only_peaceful_mobs",
    "enable_fire",
    "mcl_explosions_griefing",
    "static_spawnpoint",
    "classrooms_spawn_yaw",
    "classrooms_spawn_pitch",
}

local function pending_settings_path()
    return MOD_DATA_PATH .. "/instance_settings.conf"
end

local function read_pending_settings()
    local path = pending_settings_path()
    local settings = {}
    local file = io.open(path, "r")
    if not file then
        return settings
    end

    for line in file:lines() do
        local key, value = line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
        if key and APPROVED_CONFIG_KEYS[key] then
            settings[key] = value
        end
    end
    file:close()
    return settings
end

local function write_config_settings(settings, context)
    if type(settings) ~= "table" then
        return 0
    end

    local pending = read_pending_settings()
    local count = 0
    for key, value in pairs(settings) do
        if type(key) == "string" and APPROVED_CONFIG_KEYS[key] then
            pending[key] = tostring(value)
            count = count + 1
        end
    end

    local lines = {}
    for _, key in ipairs(CONFIG_KEY_ORDER) do
        if pending[key] ~= nil then
            table.insert(lines, key .. " = " .. pending[key])
        end
    end

    if minetest.safe_file_write(pending_settings_path(), table.concat(lines, "\n") .. "\n") then
        minetest.log("action", "[classrooms_bridge] Wrote pending instance settings after " .. context .. " (" .. count .. " values)")
    else
        minetest.log("warning", "[classrooms_bridge] Failed to write pending instance settings after " .. context)
    end
    return count
end

local function send_bridge_message(payload, context)
    if not channel then
        minetest.log("warning", "[classrooms_bridge] Cannot send " .. context .. ": mod channel is not joined")
        return false
    end

    local message = minetest.write_json(payload)
    local ok, err = pcall(function()
        channel:send_all(message)
    end)
    if ok then
        minetest.log("action", "[classrooms_bridge] Sent " .. context .. ": " .. message)
    else
        minetest.log("warning", "[classrooms_bridge] Failed to send " .. context .. ": " .. tostring(err))
    end
    return ok
end

local TEACHER_PANEL_ITEM = "classrooms_bridge:teacher_panel"
local teacher_access = {}

local function request_teacher_panel(user)
    if not user or not user:is_player() then return end
    local name = user:get_player_name()
    if not teacher_access[name] then return end

    send_bridge_message({
        action = "open_classes",
        player = name,
    }, "open_classes")
end

minetest.register_craftitem(TEACHER_PANEL_ITEM, {
    description = "Class Panel",
    inventory_image = "classrooms_bridge_teacher_panel.png",
    wield_image = "classrooms_bridge_teacher_panel.png",
    stack_max = 1,
    groups = { not_in_creative_inventory = 1 },
    on_place = function(itemstack, placer)
        request_teacher_panel(placer)
        return itemstack
    end,
    on_use = function(itemstack, user)
        request_teacher_panel(user)
        return itemstack
    end,
    on_secondary_use = function(itemstack, user)
        request_teacher_panel(user)
        return itemstack
    end,
    on_drop = function(itemstack)
        return ItemStack("")
    end,
})

local function remove_teacher_panel_items(player)
    local inv = player:get_inventory()
    if not inv then return end

    local size = inv:get_size("main")
    for index = 1, size do
        if inv:get_stack("main", index):get_name() == TEACHER_PANEL_ITEM then
            inv:set_stack("main", index, "")
        end
    end
end

local function ensure_teacher_panel_item(player)
    local inv = player:get_inventory()
    if not inv then return end

    local size = inv:get_size("main")
    if size < 1 then return end

    local first = inv:get_stack("main", 1)
    if first:get_name() == TEACHER_PANEL_ITEM then
        first:set_count(1)
        inv:set_stack("main", 1, first)
        return
    end

    -- Prefer swapping an existing panel item into slot 1 so no player item is
    -- displaced unnecessarily.
    for index = 2, size do
        local stack = inv:get_stack("main", index)
        if stack:get_name() == TEACHER_PANEL_ITEM then
            inv:set_stack("main", index, first)
            inv:set_stack("main", 1, ItemStack(TEACHER_PANEL_ITEM))
            return
        end
    end

    inv:set_stack("main", 1, ItemStack(TEACHER_PANEL_ITEM))
    if not first:is_empty() then
        local leftover = inv:add_item("main", first)
        if not leftover:is_empty() then
            minetest.add_item(player:get_pos(), leftover)
        end
    end
end

local function set_teacher_access(player, enabled)
    local name = player:get_player_name()
    if enabled then
        teacher_access[name] = true
        ensure_teacher_panel_item(player)
    else
        teacher_access[name] = nil
        remove_teacher_panel_items(player)
    end
end

minetest.register_allow_player_inventory_action(function(player, action, _, info)
    if not teacher_access[player:get_player_name()] then return end

    if action == "move" then
        if (info.from_list == "main" and info.from_index == 1)
                or (info.to_list == "main" and info.to_index == 1) then
            return 0
        end
    elseif (action == "put" or action == "take")
            and info.listname == "main" and info.index == 1 then
        return 0
    end
end)

local teacher_item_timer = 0
minetest.register_globalstep(function(dtime)
    teacher_item_timer = teacher_item_timer + dtime
    if teacher_item_timer < 1 then return end
    teacher_item_timer = 0

    for name in pairs(teacher_access) do
        local player = minetest.get_player_by_name(name)
        if player then
            ensure_teacher_panel_item(player)
        end
    end
end)

local function get_classroom_spawn()
    local pos = minetest.settings:get_pos("static_spawnpoint")
    if not pos then
        return nil
    end

    return {
        pos = pos,
        yaw = tonumber(minetest.settings:get("classrooms_spawn_yaw")),
        pitch = tonumber(minetest.settings:get("classrooms_spawn_pitch")),
    }
end

local function apply_classroom_spawn(player)
    local spawn = get_classroom_spawn()
    if not spawn then
        return
    end

    player:set_pos(spawn.pos)
    if spawn.yaw then
        player:set_look_horizontal(spawn.yaw)
    end
    if spawn.pitch then
        player:set_look_vertical(spawn.pitch)
    end
end

local function apply_classroom_spawn_later(name, delay)
    minetest.after(delay, function()
        local player = minetest.get_player_by_name(name)
        if player then
            apply_classroom_spawn(player)
        end
    end)
end

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

function handlers.set_world_time(data)
    local name = data.player
    if not name then return end

    local preset = data.preset or "day"
    local mapping = {
        day = 0.25,
        evening = 0.6,
        night = 0.0,
    }

    local time_value = data.time
    if type(time_value) ~= "number" then
        time_value = mapping[preset]
    end

    if data.stop_time then
        minetest.settings:set("time_speed", "0")
        minetest.chat_send_player(name, minetest.colorize("#FFD700",
            "[Teacher] Time is now frozen at the current setting."))
    else
        if type(time_value) == "number" then
            minetest.set_timeofday(time_value)
        end
        minetest.settings:set("time_speed", "1")
        minetest.chat_send_player(name, minetest.colorize("#FFD700",
            "[Teacher] Time has been updated to the selected preset."))
    end

    write_settings("set_world_time")
end

function handlers.set_world_weather(data)
    local name = data.player
    if not name then return end

    local preset = data.preset or data.weather or "sunny"
    local weather = data.weather or preset
    local target = "none"

    if weather == "rain" then
        target = "rain"
    elseif weather == "sunny" then
        target = "none"
    end

    if mcl_weather and mcl_weather.change_weather then
        mcl_weather.change_weather(target, nil, name)
    elseif minetest.set_weather then
        minetest.set_weather(target)
    else
        minetest.log("warning", "[classrooms_bridge] No weather API is available to change the world weather")
    end

    minetest.chat_send_player(name, minetest.colorize("#FFD700",
        "[Teacher] Weather has been updated to the selected preset."))
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

function handlers.set_gamemode(data)
    local name = data.player
    local gamemode = data.gamemode
    if not name or not gamemode then return end
    if gamemode ~= "creative" and gamemode ~= "survival" then return end

    local player = minetest.get_player_by_name(name)
    if not player then return end

    if mcl_gamemode and mcl_gamemode.set_gamemode then
        mcl_gamemode.set_gamemode(player, gamemode)
        minetest.chat_send_player(name, minetest.colorize("#00CC66",
            "[Teacher] Your game mode is now " .. gamemode .. "."))
    else
        minetest.log("warning", "[classrooms_bridge] mcl_gamemode API is not available")
    end
end

function handlers.set_teacher_defaults(data)
    local name = data.player
    if not name then return end

    local player = minetest.get_player_by_name(name)
    if not player then return end

    set_teacher_access(player, true)

    local privs = minetest.get_player_privs(name)
    privs.fly = true
    privs.fast = true
    minetest.set_player_privs(name, privs)

    if mcl_gamemode and mcl_gamemode.set_gamemode then
        mcl_gamemode.set_gamemode(player, "creative")
    else
        minetest.log("warning", "[classrooms_bridge] mcl_gamemode API is not available")
    end
end

function handlers.set_teacher_access(data)
    local name = data.player
    if not name then return end

    local player = minetest.get_player_by_name(name)
    if player then
        set_teacher_access(player, true)
    end
end

function handlers.clear_teacher_defaults(data)
    local name = data.player
    if not name then return end

    local player = minetest.get_player_by_name(name)
    if not player then return end

    set_teacher_access(player, true)

    local privs = minetest.get_player_privs(name)
    privs.fly = nil
    privs.fast = nil
    minetest.set_player_privs(name, privs)

    if mcl_gamemode and mcl_gamemode.set_gamemode then
        mcl_gamemode.set_gamemode(player, "survival")
    end
end

function handlers.clear_teacher_access(data)
    local name = data.player
    if not name then return end

    local player = minetest.get_player_by_name(name)
    if player then
        set_teacher_access(player, false)
    else
        teacher_access[name] = nil
    end
end

function handlers.capture_spawnpoint(data)
    local name = data.player
    local request_id = data.request_id
    if not name or not request_id then return end

    local player = minetest.get_player_by_name(name)
    if not player then return end

    local pos = player:get_pos()
    local yaw = player:get_look_horizontal()
    local pitch = player:get_look_vertical()
    local pos_string = string.format("(%.2f,%.2f,%.2f)", pos.x, pos.y, pos.z)
    minetest.settings:set("static_spawnpoint", pos_string)
    minetest.settings:set("classrooms_spawn_yaw", tostring(yaw))
    minetest.settings:set("classrooms_spawn_pitch", tostring(pitch))
    write_config_settings({
        static_spawnpoint = pos_string,
        classrooms_spawn_yaw = yaw,
        classrooms_spawn_pitch = pitch,
    }, "capture_spawnpoint")

    send_bridge_message({
        action = "spawnpoint_captured",
        player = name,
        request_id = request_id,
        pos = pos,
        pos_string = pos_string,
        yaw = yaw,
        pitch = pitch,
    }, "spawnpoint_captured")
end

function handlers.set_settings(data)
    local config_settings = data.config_settings or data.settings
    local runtime_settings = data.runtime_settings or {}

    write_config_settings(config_settings, "set_settings")

    local runtime_count = 0
    for key, value in pairs(runtime_settings) do
        if type(key) == "string" then
            minetest.settings:set(key, tostring(value))
            runtime_count = runtime_count + 1
        end
    end
    if runtime_count > 0 then
        write_settings("runtime set_settings")
    end
    minetest.log("action", "[classrooms_bridge] Applied runtime settings after set_settings (" .. runtime_count .. " values)")
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
    send_bridge_message({
        action = "pong",
        server = minetest.get_server_status().description,
    }, "pong")
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
    apply_classroom_spawn_later(name, 0.4)

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

minetest.register_on_respawnplayer(function(player)
    apply_classroom_spawn_later(player:get_player_name(), 0.4)
    if teacher_access[player:get_player_name()] then
        minetest.after(0, function()
            local current = minetest.get_player_by_name(player:get_player_name())
            if current then ensure_teacher_panel_item(current) end
        end)
    end
    return false
end)

-- ── Cleanup on leave ────────────────────────────────────────────────────────

minetest.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    watching_players[name] = nil
    teacher_access[name] = nil
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
