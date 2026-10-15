local P = ...
local S = P.S
local mg = skyss_minigames

-- Match states: loading (saving the area) -> countdown -> running ->
-- ending (celebration) -> done (players out, area being restored).

local SAVED_KEY = "skyss_minigames:saved"
P.LEAVE_ITEM = "skyss_minigames:leave"
local TICK = 0.5

local DEFAULTS = {
    mode = "coop",          -- "solo" (one player per match) or "coop" (one shared team)
    min_players = 1,
    max_players = 8,
    time_limit = 180,       -- seconds, 0 = no limit (recommended: 3 minutes)
    ranking = "time",       -- "time" (lower is better) or "score" (higher is better)
    can_dig = false,
    can_place = false,
    exclusive = true,       -- keep non-players out of the area during a match
    join_in_progress = false,
    countdown = 3,
    celebration_time = 5,
    hotbar_slots = 9,
    leave_item = true,
    show_timer = true,      -- framework timer at the top (off for games with their own)
    icon = "skyss_minigames_launcher_top.png",
}

P.playing = {}  -- [player name] = match
local next_id = 0

function mg.register_game(name, def)
    assert(type(name) == "string" and type(def) == "table", "register_game(name, def)")
    local game = table.copy(DEFAULTS)
    for key, value in pairs(def) do game[key] = value end
    game.name = name
    game.title = def.title or name
    assert(game.mode == "solo" or game.mode == "coop", name .. ": mode must be solo or coop")
    assert(game.ranking == "time" or game.ranking == "score", name .. ": ranking must be time or score")
    if game.mode == "solo" then
        game.min_players, game.max_players = 1, 1
    end
    P.games[name] = game
end

-- ── Helpers for games ──────────────────────────────────────────────────────

function mg.get_match_by_player(name)
    return P.playing[name]
end

function mg.is_playing(name)
    return P.playing[name] ~= nil
end

function mg.get_match(arena_name)
    local arena = P.arenas[arena_name]
    return arena and arena.match
end

-- for name, player in skyss_minigames.players(match) do ... end
-- Skips players who are offline for a moment.
function mg.players(match)
    local i = 0
    local list = table.copy(match.player_list)
    return function()
        while true do
            i = i + 1
            local name = list[i]
            if not name then return nil end
            local player = core.get_player_by_name(name)
            if player and match.players[name] then return name, player end
        end
    end
end

function mg.player_count(match)
    return #match.player_list
end

function mg.elapsed(match)
    if not match.started_us then return 0 end
    return ((match.stopped_us or core.get_us_time()) - match.started_us) / 1000000
end

-- nil when the match has no time limit.
function mg.time_left(match)
    if not match.time_limit or match.time_limit <= 0 then return nil end
    return math.max(0, match.time_limit - mg.elapsed(match))
end

function mg.chat(match, message)
    local prefix = core.colorize("#ffc978", "[" .. match.game.title .. "] ")
    for name in mg.players(match) do
        core.chat_send_player(name, prefix .. message)
    end
end

function mg.title(match, text, seconds, color)
    for _, player in mg.players(match) do
        P.hud_title(player, text, seconds, color)
    end
end

function mg.title_player(name, text, seconds, color)
    local player = core.get_player_by_name(name)
    if player then P.hud_title(player, text, seconds, color) end
end

-- Short message above the hotbar.
function mg.hint_player(name, text, seconds, color)
    local player = core.get_player_by_name(name)
    if player then P.hud_message(player, "hint", text, seconds, color) end
end

function mg.sound(match, spec, params)
    for name in mg.players(match) do
        local p = table.copy(params or {})
        p.to_player = name
        core.sound_play(spec, p, true)
    end
end

local function spawn_point(match, name)
    local spawns = match.arena.spawns
    return spawns[((match.slot[name] or 1) - 1) % #spawns + 1]
end
mg.spawn_of = spawn_point

function mg.respawn(match, name)
    local player = core.get_player_by_name(name)
    if player then P.teleport(player, spawn_point(match, name)) end
end

-- ── Player state ───────────────────────────────────────────────────────────

-- The player's things are kept in their metadata, so a disconnect or a crash
-- mid-match gives them back at the next join.
local function save_player(player, match)
    local meta = player:get_meta()
    local inv = player:get_inventory()
    if meta:get_string(SAVED_KEY) == "" then
        local exit = P.exit_point(match.arena)
        local state = {
            lists = {},
            hotbar_count = player:hud_get_hotbar_itemcount(),
            hotbar_image = player:hud_get_hotbar_image(),
            physics = player:get_physics_override(),
            hud_flags = player:hud_get_flags(),
            exit = { pos = exit.pos, yaw = exit.yaw },
        }
        for _, list_name in ipairs({ "main", "craft" }) do
            if inv:get_size(list_name) > 0 then
                state.lists[list_name] = P.item_strings(inv:get_list(list_name))
            end
        end
        meta:set_string(SAVED_KEY, core.serialize(state))
    end
    for _, list_name in ipairs({ "main", "craft" }) do
        if inv:get_size(list_name) > 0 then inv:set_list(list_name, {}) end
    end
end

-- Returns the saved state (with its exit point) or nil. at_join: only items
-- and physics; hub and classrooms_bridge have just set up the hotbar.
function P.restore_player(player, at_join)
    local meta = player:get_meta()
    local raw = meta:get_string(SAVED_KEY)
    if raw == "" then return nil end
    local state = core.deserialize(raw) or {}
    local inv = player:get_inventory()
    for list_name, list in pairs(state.lists or {}) do
        inv:set_list(list_name, list)
    end
    if not at_join then
        if state.hotbar_count then player:hud_set_hotbar_itemcount(state.hotbar_count) end
        if state.hotbar_image and state.hotbar_image ~= "" then
            player:hud_set_hotbar_image(state.hotbar_image)
        end
    end
    if state.physics then player:set_physics_override(state.physics) end
    if state.hud_flags then player:hud_set_flags(state.hud_flags) end
    meta:set_string(SAVED_KEY, "")
    return state
end

local function equip(player, match)
    local game = match.game
    save_player(player, match)
    P.hud_status(player, nil)
    local slots = game.hotbar_slots
    player:hud_set_hotbar_itemcount(slots)
    local image = game.hotbar_image
    if not image and slots == 9 and core.get_modpath("mcl_inventory") then
        image = "mcl_inventory_hotbar.png"
    end
    if image then player:hud_set_hotbar_image(image) end
    if game.hud_flags then player:hud_set_flags(game.hud_flags) end
    if game.leave_item then
        player:get_inventory():set_stack("main", slots, P.LEAVE_ITEM)
    end
end

local function release_player(player, match)
    P.hud_clear(player)
    P.restore_player(player)
    P.teleport(player, P.exit_point(match.arena))
    if player:get_hp() > 0 then
        player:set_hp(player:get_properties().hp_max)
    end
end

local function freeze(player, match, frozen)
    local name = player:get_player_name()
    if frozen then
        local physics = player:get_physics_override()
        match.frozen[name] = { speed = physics.speed, jump = physics.jump }
        player:set_physics_override({ speed = 0, jump = 0 })
    elseif match.frozen[name] then
        player:set_physics_override(match.frozen[name])
        match.frozen[name] = nil
    end
end

local function unmark(match, name)
    P.playing[name] = nil
    match.players[name] = nil
    for i, n in ipairs(match.player_list) do
        if n == name then
            table.remove(match.player_list, i)
            break
        end
    end
end

-- ── Lifecycle ──────────────────────────────────────────────────────────────

local teardown

local function countdown(match, n)
    if match.state ~= "countdown" then return end
    if #match.player_list == 0 then
        teardown(match)
        return
    end
    if n > 0 then
        mg.title(match, tostring(n), 1, 0xffc978)
        mg.sound(match, "mesecons_noteblock_hit", { gain = 0.6 })
        core.after(1, countdown, match, n - 1)
        return
    end
    for _, player in mg.players(match) do
        freeze(player, match, false)
    end
    match.state = "running"
    match.started_us = core.get_us_time()
    match.started = true
    mg.title(match, S("Go!"), 1.5, 0x7be08a)
    P.call(match.game.name .. ".on_start", match.game.on_start, match)
end

local function begin(match)
    match.state = "countdown"
    if #match.player_list == 0 then
        -- Everybody left while the area was being saved.
        teardown(match)
        return
    end
    for _, name in ipairs(table.copy(match.player_list)) do
        local player = core.get_player_by_name(name)
        if player then
            equip(player, match)
            P.teleport(player, spawn_point(match, name))
            match.last_ok[name] = spawn_point(match, name).pos
            if match.game.countdown > 0 then freeze(player, match, true) end
        else
            unmark(match, name)
        end
    end
    countdown(match, match.game.countdown)
end

-- opts: { time_limit = seconds (0 = none), by = player name }
-- Returns true, or false and a translated reason.
function P.start(arena, names, opts)
    opts = opts or {}
    local game = P.games[arena.game]
    if not game then return false, S("This minigame is not installed.") end
    if not P.game_enabled(arena.game) then return false, S("This minigame is switched off.") end
    if arena.match or arena.resetting then
        return false, S("The arena is busy, try again in a moment.")
    end
    local min, max = P.limits(arena)
    local list, seen = {}, {}
    for _, name in ipairs(names) do
        if not seen[name] then
            seen[name] = true
            if not core.get_player_by_name(name) then return false, S("@1 is not online.", name) end
            if P.playing[name] then return false, S("@1 is already playing.", name) end
            table.insert(list, name)
        end
    end
    if #list < min then return false, S("At least @1 players are needed.", min) end
    if #list > max then return false, S("At most @1 players can play.", max) end

    next_id = next_id + 1
    local match = {
        id = next_id,
        arena = arena,
        game = game,
        -- Shortcuts to the arena's data.
        name = arena.name,
        pos1 = arena.pos1,
        pos2 = arena.pos2,
        spawns = arena.spawns,
        params = arena.params,
        players = {},
        player_list = {},
        slot = {},
        data = {},          -- free for the game
        state = "loading",
        time_limit = tonumber(opts.time_limit) or P.setting(arena, "time_limit") or 0,
        started_by = opts.by,
        last_ok = {},
        warned = {},
        frozen = {},
    }
    arena.match = match
    for i, name in ipairs(list) do
        P.queue_leave(name, true)
        match.players[name] = true
        match.player_list[i] = name
        match.slot[name] = i
        P.playing[name] = match
    end
    match.next_slot = #list + 1

    P.snapshot_take(arena, function(ok)
        if arena.match ~= match then return end
        if not ok then
            for _, name in ipairs(table.copy(match.player_list)) do
                unmark(match, name)
                core.chat_send_player(name, S("The arena could not be prepared: tell your teacher."))
            end
            arena.match = nil
            return
        end
        begin(match)
    end)
    core.log("action", "[skyss_minigames] " .. arena.name .. " started for " .. table.concat(list, ", ")
        .. (opts.by and (" by " .. opts.by) or ""))
    return true
end

-- Adds a player to a running match of a game with join_in_progress.
function P.join_running(arena, name)
    local match = arena.match
    local _, max = P.limits(arena)
    if not match or not match.game.join_in_progress
            or (match.state ~= "running" and match.state ~= "countdown") then
        return false, S("This match cannot be joined now.")
    end
    if P.playing[name] then return false, S("@1 is already playing.", name) end
    if #match.player_list >= max then return false, S("The match is full.") end
    local player = core.get_player_by_name(name)
    if not player then return false end

    P.queue_leave(name, true)
    match.players[name] = true
    table.insert(match.player_list, name)
    match.slot[name] = match.next_slot
    match.next_slot = match.next_slot + 1
    P.playing[name] = match
    equip(player, match)
    P.teleport(player, spawn_point(match, name))
    match.last_ok[name] = spawn_point(match, name).pos
    if match.state == "running" then
        P.call(match.game.name .. ".on_join", match.game.on_join, match, name)
    else
        freeze(player, match, true)
    end
    return true
end

-- result: { success = bool, score = number, time = seconds (default: the
-- elapsed time), celebration_time = seconds }. The framework adds timeout,
-- abandoned, forced and rank.
function mg.finish(match, result)
    if match.state ~= "running" and match.state ~= "countdown" then return end
    result = result or {}
    match.state = "ending"
    match.stopped_us = core.get_us_time()
    match.result = result
    result.time = tonumber(result.time) or mg.elapsed(match)

    local game = match.game
    local mode = P.ranking_of(game.name)
    local value
    if mode == "time" and result.success then
        value = result.time
    elseif mode == "score" then
        value = tonumber(result.score)
        if value and value <= 0 then value = nil end
    end
    if value and match.started and not result.abandoned and #match.player_list > 0 then
        result.rank = P.record(game.name, match.player_list, value, mode)
        if result.rank then
            mg.chat(match, core.colorize("#ffd43b",
                S("Leaderboard: you are number @1 (@2)!", result.rank, P.format_value(mode, value))))
            mg.sound(match, "mcl_experience_level_up", { gain = 0.6 })
        end
    end

    if match.started then
        P.call(game.name .. ".on_finish", game.on_finish, match, result)
    end
    local delay = result.abandoned and 0 or (tonumber(result.celebration_time) or game.celebration_time)
    core.after(delay, teardown, match)
end

teardown = function(match)
    if match.state == "done" then return end
    match.state = "done"
    local arena, game = match.arena, match.game
    if match.started then
        P.call(game.name .. ".on_end", game.on_end, match, match.result or {})
    end
    for _, name in ipairs(table.copy(match.player_list)) do
        unmark(match, name)
        local player = core.get_player_by_name(name)
        if player then release_player(player, match) end
    end
    arena.match = nil
    arena.resetting = true
    P.snapshot_restore(arena, function()
        arena.resetting = false
        P.on_arena_free(arena)
    end)
end

-- reason: "quit", "disconnect" or "kicked".
function P.leave(name, reason)
    local match = P.playing[name]
    if not match then return false end
    local equipped = match.state ~= "loading"
    unmark(match, name)
    if equipped then
        if match.started and match.state ~= "done" then
            P.call(match.game.name .. ".on_leave", match.game.on_leave, match, name, reason)
        end
        local player = core.get_player_by_name(name)
        if player and reason ~= "disconnect" then release_player(player, match) end
    end
    if #match.player_list == 0 and (match.state == "running" or match.state == "countdown") then
        if match.state == "countdown" then
            teardown(match)
        else
            mg.finish(match, { success = false, abandoned = true })
        end
    end
    return true
end

function mg.leave(name)
    return P.leave(name, "quit")
end

-- Stops the arena's match without results (admins, teachers).
function P.stop(arena)
    local match = arena.match
    if not match then return false end
    if match.state == "loading" then
        -- begin() finds nobody and tears down after the save.
        for _, name in ipairs(table.copy(match.player_list)) do unmark(match, name) end
        return true
    end
    if match.state == "running" or match.state == "countdown" then
        mg.chat(match, S("The match was stopped."))
        if match.state == "countdown" then
            teardown(match)
        else
            mg.finish(match, { success = false, abandoned = true, forced = true })
        end
    end
    return true
end

-- ── Rules: play area, exclusivity, time limit ──────────────────────────────

local function status_text(match)
    local left = mg.time_left(match)
    if left then return "\xE2\x8F\xB1 " .. P.format_time(left) end
    return "\xE2\x8F\xB1 " .. P.format_time(mg.elapsed(match))
end

local timer = 0
core.register_globalstep(function(dtime)
    timer = timer + dtime
    if timer < TICK then return end
    timer = 0
    local now = core.get_us_time()

    for _, arena in pairs(P.arenas) do
        local match = arena.match
        if match and (match.state == "countdown" or match.state == "running" or match.state == "ending") then
            for name, player in mg.players(match) do
                local pos = player:get_pos()
                if P.inside(pos, arena.pos1, arena.pos2) then
                    match.last_ok[name] = pos
                else
                    player:set_pos(match.last_ok[name] or spawn_point(match, name).pos)
                    if not match.warned[name] or now - match.warned[name] > 3000000 then
                        match.warned[name] = now
                        core.chat_send_player(name, core.colorize("#ff8a7a", S("You can't leave the play area.")))
                    end
                end
                if match.state == "running" and match.game.show_timer then
                    P.hud_status(player, status_text(match))
                end
            end

            if match.state == "running" and match.time_limit > 0 and mg.elapsed(match) >= match.time_limit then
                local result = P.call(match.game.name .. ".on_timeout", match.game.on_timeout, match)
                if match.state == "running" then
                    result = type(result) == "table" and result or { success = false }
                    result.timeout = true
                    mg.title(match, S("Time is up!"), 3, 0xff6b5a)
                    mg.finish(match, result)
                end
            end
        end
    end

    for _, player in ipairs(core.get_connected_players()) do
        local name = player:get_player_name()
        if not P.playing[name] then
            local arena = P.arena_at(player:get_pos())
            if arena and arena.match and arena.match.state ~= "done"
                    and P.setting(arena, "exclusive") and not P.is_staff(name) then
                local exit = P.exit_point(arena)
                if P.inside(exit.pos, arena.pos1, arena.pos2) then exit = P.hub_point() or exit end
                P.teleport(player, exit)
                core.chat_send_player(name, S("A match is being played here: wait for it to end."))
            end
        end
    end
end)

-- ── Engine hooks ───────────────────────────────────────────────────────────

-- Wrapped after every mod has loaded, so this sits on top of hub's "nobody
-- builds in the lobby" rule (hub is an optional dependency for that reason).
core.register_on_mods_loaded(function()
    local digging = {}
    local node_dig = core.node_dig
    core.node_dig = function(pos, node, digger)
        local name = digger and digger:is_player() and digger:get_player_name()
        if name then digging[name] = true end
        local result = node_dig(pos, node, digger)
        if name then digging[name] = nil end
        return result
    end

    local is_protected = core.is_protected
    core.is_protected = function(pos, name)
        local match = name and P.playing[name]
        if match then
            local arena = match.arena
            if match.state == "running" and P.inside(pos, arena.pos1, arena.pos2) then
                if digging[name] then return not P.setting(arena, "can_dig") end
                return not P.setting(arena, "can_place")
            end
            return true
        end
        local arena = P.arena_at(pos)
        if arena and (arena.match or arena.resetting) and not (name and P.is_admin(name)) then
            return true
        end
        return is_protected(pos, name)
    end
end)

core.register_on_respawnplayer(function(player)
    local name = player:get_player_name()
    local match = P.playing[name]
    if not match or match.state == "loading" then return end
    P.teleport(player, spawn_point(match, name))
    if match.state == "running" then
        P.call(match.game.name .. ".on_respawn", match.game.on_respawn, match, name)
    end
    return true
end)

core.register_on_leaveplayer(function(player)
    P.leave(player:get_player_name(), "disconnect")
end)

-- Registered after hub's own join callback (optional dependency), which
-- resets the inventory to the lobby items: put the player's things back.
core.register_on_joinplayer(function(player)
    local state = P.restore_player(player, true)
    if state and state.exit and state.exit.pos then
        P.teleport(player, { pos = vector.new(state.exit.pos), yaw = state.exit.yaw })
    end
end)

-- ── Leave item ─────────────────────────────────────────────────────────────

local function ask_leave(itemstack, user)
    if user and user:is_player() and P.playing[user:get_player_name()] then
        P.show_leave_form(user:get_player_name())
    end
    return itemstack
end

core.register_craftitem(P.LEAVE_ITEM, {
    description = S("Leave the minigame"),
    inventory_image = "skyss_minigames_leave.png",
    stack_max = 1,
    groups = { not_in_creative_inventory = 1 },
    on_use = ask_leave,
    on_secondary_use = ask_leave,
    on_place = ask_leave,
    on_drop = function(itemstack) return itemstack end,
})
