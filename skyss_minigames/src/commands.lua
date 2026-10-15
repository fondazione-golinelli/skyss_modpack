local P = ...
local S = P.S

local function sorted_arenas()
    local list = {}
    for _, arena in pairs(P.arenas) do table.insert(list, arena) end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

local function arena_line(arena)
    local state
    if arena.resetting then
        state = S("getting ready")
    elseif arena.match then
        state = S("playing (@1)", #arena.match.player_list)
    else
        state = S("free")
    end
    return ("%s  [%s]  %s"):format(arena.name, P.arena_title(arena), state)
end

local function split(text)
    local words = {}
    for word in (text or ""):gmatch("%S+") do table.insert(words, word) end
    return words
end

local function game_names()
    local names = {}
    for game_name in pairs(P.games) do table.insert(names, game_name) end
    table.sort(names)
    return table.concat(names, "|")
end

core.register_chatcommand("minigames", {
    params = "[list | leave | board <game> | start <game> <players...> | stop <arena> | "
        .. "edit [game] | tools | undo | reload]",
    description = S("Minigames: list arenas, leave a match, leaderboards"),
    func = function(name, param)
        local words = split(param)
        local sub = words[1] or "list"

        if sub == "list" then
            local lines = {}
            for _, arena in ipairs(sorted_arenas()) do table.insert(lines, arena_line(arena)) end
            if #lines == 0 then return true, S("No arenas.") end
            return true, table.concat(lines, "\n")
        elseif sub == "leave" then
            if P.leave(name, "quit") or P.queue_leave(name) then return true end
            return false, S("You are not in a minigame.")
        elseif sub == "board" then
            local game = words[2]
            if not game or not P.games[game] then
                return false, "/minigames board <" .. game_names() .. ">"
            end
            P.show_board_form(name, game)
            return true
        end

        -- Staff (teachers and admins) from here on.
        if not P.is_staff(name) then return false, S("Only teachers can do this.") end
        if sub == "start" then
            local game = words[2]
            if not game or not P.games[game] then
                return false, "/minigames start <" .. game_names() .. "> <players...>"
            end
            local names = {}
            for i = 3, #words do
                for n in words[i]:gmatch("[^,]+") do table.insert(names, n) end
            end
            return P.start_game(game, names, { by = name })
        elseif sub == "stop" then
            local arena = P.arenas[words[2] or ""]
            if not arena then return false, S("Unknown arena: @1", tostring(words[2])) end
            if not P.stop(arena) then return false, S("No match is being played there.") end
            return true, S("The match was stopped.")
        end

        -- Admins from here on.
        if not P.is_admin(name) then return false, S("Only admins can do this.") end
        if sub == "edit" then
            P.show_editor(name, words[2])
            return true
        elseif sub == "undo" then
            if not P.undo_arenas() then return false, S("Nothing to undo.") end
            return true, S("Last change undone.")
        elseif sub == "tools" then
            local player = core.get_player_by_name(name)
            if not player then return false end
            if P.editing[name] then
                P.leave_edit_mode(player)
                return true
            end
            return P.enter_edit_mode(player)
        elseif sub == "reload" then
            local loaded, problems = P.load_arenas()
            for game_name in pairs(P.launchers) do P.ensure_launcher(game_name) end
            for _, arena in pairs(P.arenas) do P.ensure_arena_nodes(arena) end
            local text = S("@1 arena(s) loaded.", loaded)
            if #problems > 0 then text = text .. "\n" .. table.concat(problems, "\n") end
            return true, text
        end
        return false, S("Unknown action: @1", sub)
    end,
})

-- ── Public API for other mods (classrooms_bridge) ──────────────────────────

-- opts: { time_limit = seconds (0 = none), by = name }. Returns ok, err.
function skyss_minigames.start(arena_name, names, opts)
    local arena = P.arenas[arena_name]
    if not arena then return false, S("Unknown arena: @1", tostring(arena_name)) end
    return P.start(arena, names, opts)
end

-- Starts a game in its free arenas (see P.start_game). Returns ok, message.
function skyss_minigames.start_game(game_name, names, opts)
    return P.start_game(game_name, names, opts)
end

function skyss_minigames.stop(arena_name)
    local arena = P.arenas[arena_name]
    return arena ~= nil and P.stop(arena)
end

-- Plain data about every arena, for dashboards.
function skyss_minigames.list_arenas()
    local list = {}
    for _, arena in ipairs(sorted_arenas()) do
        local game = P.games[arena.game]
        local min, max = P.limits(arena)
        local state = arena.resetting and "resetting" or (arena.match and arena.match.state) or "free"
        table.insert(list, {
            name = arena.name,
            game = arena.game,
            title = P.arena_title(arena),
            mode = game.mode,
            enabled = P.game_enabled(arena.game),
            min_players = min,
            max_players = max,
            time_limit = tonumber(P.setting(arena, "time_limit")) or 0,
            state = state,
            players = arena.match and table.copy(arena.match.player_list) or {},
            queue = table.copy(P.queue_list(arena.game)),
        })
    end
    return list
end
