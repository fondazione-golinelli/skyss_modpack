local P = ...
local S = P.S

-- One line per game, at its launcher in the hub. A match runs in any free
-- arena of the game:
-- * solo games start each player as soon as an arena is free (the farm's
--   six pens play in parallel);
-- * cooperative games start when the line is full, or AUTO_START seconds
--   after it reaches the minimum (any player in line can start it earlier).
-- Walking away from the launcher or disconnecting leaves the line.

local AUTO_START = 20
local MAX_DISTANCE = 24
local WARN_DISTANCE = 18  -- a warning a few steps before leaving the line

P.queues = {}  -- [game] = { list = {names}, deadline_us = number|nil }
P.queued = {}  -- [player name] = game

function P.queue_list(game_name)
    local queue = P.queues[game_name]
    return queue and queue.list or {}
end

function P.queue_seconds_left(game_name)
    local queue = P.queues[game_name]
    if not queue or not queue.deadline_us then return nil end
    return math.max(0, math.ceil((queue.deadline_us - core.get_us_time()) / 1000000))
end

function P.free_arenas(game_name)
    local free = {}
    for _, arena in ipairs(P.arenas_of(game_name)) do
        if not arena.match and not arena.resetting then table.insert(free, arena) end
    end
    return free
end

-- A running match of the game that late players can join.
local function joinable_match(game_name)
    local game = P.games[game_name]
    if not game or not game.join_in_progress then return nil end
    local _, max = P.game_limits(game_name)
    for _, arena in ipairs(P.arenas_of(game_name)) do
        local match = arena.match
        if match and (match.state == "running" or match.state == "countdown") and #match.player_list < max then
            return arena
        end
    end
end
P.joinable_match = joinable_match

local function remove_from_line(name)
    local game_name = P.queued[name]
    if not game_name then return nil end
    P.queued[name] = nil
    local queue = P.queues[game_name]
    if queue then
        for i, n in ipairs(queue.list) do
            if n == name then
                table.remove(queue.list, i)
                break
            end
        end
        if queue.warned then queue.warned[name] = nil end
        if #queue.list == 0 then P.queues[game_name] = nil end
    end
    return game_name
end

local function tell(name, text)
    core.chat_send_player(name, core.colorize("#ff8a7a", text))
end

-- Starts whoever can start now. force: start a cooperative match with the
-- minimum instead of waiting for the countdown.
function P.queue_try_start(game_name, force)
    local queue = P.queues[game_name]
    if not queue or not P.game_enabled(game_name) then return false end
    local game = P.games[game_name]
    local min, max = P.game_limits(game_name)
    local free = P.free_arenas(game_name)
    local started = false

    if game.mode == "solo" then
        while #queue.list > 0 and #free > 0 do
            local name = queue.list[1]
            remove_from_line(name)
            local ok, err = P.start(table.remove(free, 1), { name }, {})
            if ok then started = true else tell(name, err) end
            queue = P.queues[game_name]
            if not queue then break end
        end
        return started
    end

    local due = queue.deadline_us and core.get_us_time() >= queue.deadline_us
    if #free > 0 and (#queue.list >= max or (#queue.list >= min and (force or due))) then
        local names = {}
        for i = 1, math.min(max, #queue.list) do names[i] = queue.list[i] end
        for _, name in ipairs(names) do remove_from_line(name) end
        local ok, err = P.start(free[1], names, {})
        if not ok then
            for _, name in ipairs(names) do tell(name, err) end
        end
        started = ok
    end
    queue = P.queues[game_name]
    if queue then
        if #queue.list >= min and #P.free_arenas(game_name) > 0 then
            queue.deadline_us = queue.deadline_us or core.get_us_time() + AUTO_START * 1000000
        else
            queue.deadline_us = nil
        end
    end
    return started
end

function P.queue_join(name, game_name)
    if P.playing[name] then return false, S("@1 is already playing.", name) end
    if not P.games[game_name] then return false, S("This minigame is not installed.") end
    if not P.game_enabled(game_name) then return false, S("This minigame is switched off.") end
    if #P.arenas_of(game_name) == 0 then return false, S("This minigame has no arena yet.") end
    if P.queued[name] == game_name then return true end
    P.queue_leave(name, true)

    local arena = joinable_match(game_name)
    if arena and P.join_running(arena, name) then return true end

    local queue = P.queues[game_name]
    if not queue then
        queue = { list = {} }
        P.queues[game_name] = queue
    end
    table.insert(queue.list, name)
    P.queued[name] = game_name
    P.queue_try_start(game_name)
    if P.queued[name] then
        local min = P.game_limits(game_name)
        if #P.free_arenas(game_name) == 0 then
            core.chat_send_player(name, S("Every arena is busy: you are in line, @1 before you.", #P.queue_list(game_name) - 1))
        elseif #P.queue_list(game_name) < min then
            core.chat_send_player(name, S("Waiting for more players: @1/@2.", #P.queue_list(game_name), min))
        end
    end
    return true
end

-- quiet: do not touch the HUD (the player is about to enter a match).
function P.queue_leave(name, quiet)
    local game_name = remove_from_line(name)
    if not game_name then return false end
    P.queue_try_start(game_name)
    if not quiet then
        local player = core.get_player_by_name(name)
        if player then P.hud_status(player, nil) end
    end
    return true
end

-- Called when an arena has been restored after a match.
function P.on_arena_free(arena)
    P.queue_try_start(arena.game)
end

-- Teachers: start a game for chosen players. Solo games give each player a
-- free arena and put the others in line; cooperative games use the first
-- free arena. Returns ok, a translated message, and the number of players
-- started, put in line, and left out (cooperative games over the maximum).
function P.start_game(game_name, names, opts)
    if not P.games[game_name] then return false, S("This minigame is not installed.") end
    if not P.game_enabled(game_name) then return false, S("This minigame is switched off.") end
    local list, seen = {}, {}
    for _, name in ipairs(names) do
        if not seen[name] and core.get_player_by_name(name) and not P.playing[name] then
            seen[name] = true
            table.insert(list, name)
        end
    end
    if #list == 0 then return false, S("None of these players can play now.") end
    local free = P.free_arenas(game_name)

    if P.games[game_name].mode == "solo" then
        local started, waiting = 0, 0
        for _, name in ipairs(list) do
            local arena = table.remove(free, 1)
            if arena and P.start(arena, { name }, opts) then
                started = started + 1
            else
                P.queue_join(name, game_name)
                waiting = waiting + 1
            end
        end
        if waiting > 0 then
            return started > 0, S("Started for @1 player(s); @2 are in line for a free arena.", started, waiting),
                started, waiting, 0
        end
        return true, S("Started for @1 player(s).", started), started, 0, 0
    end

    if #free == 0 then return false, S("Every arena of this minigame is busy: try again when a match ends.") end
    local _, max = P.game_limits(game_name)
    local chosen = {}
    for i = 1, math.min(max, #list) do chosen[i] = list[i] end
    local ok, err = P.start(free[1], chosen, opts)
    if not ok then return false, err, 0, 0, 0 end
    if #list > #chosen then
        return true, S("Started for @1 player(s); @2 did not fit (maximum @3).", #chosen, #list - #chosen, max),
            #chosen, 0, #list - #chosen
    end
    return true, S("Started for @1 player(s).", #chosen), #chosen, 0, 0
end

local function queue_status(game_name)
    local title = P.games[game_name].title
    local min, max = P.game_limits(game_name)
    local count = #P.queue_list(game_name)
    if #P.free_arenas(game_name) == 0 then
        return S("@1: waiting for a free arena (@2 in line)", title, count)
    end
    local left = P.queue_seconds_left(game_name)
    if left then
        return S("@1: starting in @2 s (@3/@4)", title, left, count, max)
    end
    return S("@1: waiting for players (@2/@3)", title, count, min)
end

local timer = 0
core.register_globalstep(function(dtime)
    timer = timer + dtime
    if timer < 1 then return end
    timer = 0

    for game_name, queue in pairs(P.queues) do
        local launcher = P.launchers[game_name]
        for _, name in ipairs(table.copy(queue.list)) do
            local player = core.get_player_by_name(name)
            local dist = player and launcher and vector.distance(player:get_pos(), launcher.pos)
            local far = dist and dist > MAX_DISTANCE
            if not player or far then
                P.queue_leave(name)
                if far then core.chat_send_player(name, S("You walked away and left the line.")) end
            elseif dist and dist > WARN_DISTANCE then
                queue.warned = queue.warned or {}
                if not queue.warned[name] then
                    queue.warned[name] = true
                    P.hud_message(player, "hint", S("Careful! If you walk further from the launcher you leave the line for @1.",
                        P.games[game_name].title), 4, 0xffb347)
                    core.sound_play("mesecons_noteblock_hit", { to_player = name, gain = 0.6, pitch = 0.6 }, true)
                end
            elseif dist and dist < WARN_DISTANCE - 3 and queue.warned then
                queue.warned[name] = nil  -- warn again next time
            end
        end
    end

    for game_name in pairs(P.queues) do
        P.queue_try_start(game_name)
        if P.queues[game_name] then
            local text = queue_status(game_name)
            for _, name in ipairs(P.queues[game_name].list) do
                local player = core.get_player_by_name(name)
                if player then P.hud_status(player, text) end
            end
        end
    end
end)

-- A tick for everyone in line during the last seconds before the start
-- (checked often, so no second is skipped).
local BEEP_FROM = 5
local beep_timer = 0
core.register_globalstep(function(dtime)
    beep_timer = beep_timer + dtime
    if beep_timer < 0.2 then return end
    beep_timer = 0
    for _, queue in pairs(P.queues) do
        local left = queue.deadline_us and math.ceil((queue.deadline_us - core.get_us_time()) / 1000000)
        if left and left >= 1 and left <= BEEP_FROM then
            if queue.beeped_deadline ~= queue.deadline_us or queue.beeped ~= left then
                queue.beeped_deadline, queue.beeped = queue.deadline_us, left
                for _, name in ipairs(queue.list) do
                    core.sound_play("mesecons_noteblock_hit",
                        { to_player = name, gain = 0.7, pitch = left == 1 and 1.5 or 1.0 }, true)
                end
            end
        end
    end
end)

core.register_on_leaveplayer(function(player)
    P.queue_leave(player:get_player_name(), true)
end)
