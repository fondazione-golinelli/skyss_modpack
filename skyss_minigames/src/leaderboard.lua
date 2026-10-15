local P = ...

-- One global board per game and ranking mode ("time": lower is better,
-- "score": higher is better). Switching a game's mode keeps both boards.
-- An entry is a player (solo games) or a whole cooperative team; the same
-- player or team keeps only its best result.

local SIZE = 10
P.BOARD_SIZE = SIZE

local function board_key(game, mode)
    return "board:" .. game .. ":" .. mode
end

function P.ranking_of(game)
    local override = P.storage:get_string("ranking:" .. game)
    if override == "time" or override == "score" then return override end
    local def = P.games[game]
    return def and def.ranking or "time"
end

function P.set_ranking(game, mode)
    P.storage:set_string("ranking:" .. game, mode)
end

function P.get_board(game, mode)
    mode = mode or P.ranking_of(game)
    return core.deserialize(P.storage:get_string(board_key(game, mode))) or {}
end

function P.clear_board(game)
    P.storage:set_string(board_key(game, "time"), "")
    P.storage:set_string(board_key(game, "score"), "")
end

local function better(mode, a, b)
    if mode == "time" then return a < b end
    return a > b
end

-- Returns the new rank (1 = best) or nil when the result does not enter the
-- board or does not beat the team's previous best.
function P.record(game, names, value, mode)
    mode = mode or P.ranking_of(game)
    local team = table.copy(names)
    table.sort(team)
    local id = table.concat(team, ",")
    local board = P.get_board(game, mode)

    for i, entry in ipairs(board) do
        if entry.id == id then
            if not better(mode, value, entry.value) then return nil end
            table.remove(board, i)
            break
        end
    end
    local entry = { id = id, names = team, value = value, date = os.time() }
    table.insert(board, entry)
    table.sort(board, function(a, b)
        if a.value == b.value then return a.date < b.date end
        return better(mode, a.value, b.value)
    end)
    while #board > SIZE do table.remove(board) end
    P.storage:set_string(board_key(game, mode), core.serialize(board))

    for rank, e in ipairs(board) do
        if e == entry then return rank end
    end
end

function P.format_value(mode, value)
    if mode == "time" then
        local whole = math.floor(value)
        return string.format("%02d:%02d.%d", math.floor(whole / 60), whole % 60,
            math.floor((value - whole) * 10))
    end
    return tostring(value)
end
