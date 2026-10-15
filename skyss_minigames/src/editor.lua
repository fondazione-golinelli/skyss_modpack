local P = ...
local S = P.S
local UI = P.UI
local esc = core.formspec_escape

-- Admin editor (/minigames edit, Edit in a launcher menu, or right-click with
-- the Select tool). Every change is written to arenas.json at once. The game
-- and arena selected here are also the target of the edit tools (tools.lua).

local FORM = "skyss_minigames:editor"
local context = {}  -- [admin] = { game, arena, tab, confirm, message, new_arena }

local function sorted_games()
    local list = {}
    for game_name in pairs(P.games) do table.insert(list, game_name) end
    table.sort(list)
    return list
end

-- The admin's selection, shared with the edit tools.
function P.editor_context(name)
    local ctx = context[name]
    if not ctx then
        ctx = { tab = "game", game = sorted_games()[1] }
        context[name] = ctx
    end
    if not P.games[ctx.game or ""] then ctx.game = sorted_games()[1] end
    if ctx.arena and not P.raw_arena(ctx.arena) then ctx.arena = nil end
    if not ctx.arena then
        local first = P.arenas_of(ctx.game)[1]
        ctx.arena = first and first.name
    end
    return ctx
end

local function dropdown(x, y, w, h, name, items, selected)
    local escaped = {}
    for i, item in ipairs(items) do escaped[i] = esc(item) end
    return ("dropdown[%g,%g;%g,%g;%s;%s;%d;true]"):format(x, y, w, h, name, table.concat(escaped, ","), selected)
end

local function pos_text(pos)
    return pos and core.pos_to_string(pos) or "-"
end

local function busy(arena)
    return arena and (arena.match or arena.resetting)
end

-- Names of the game's arenas, including ones not usable yet (no spawn).
local function arena_names(game_name)
    local names = {}
    for _, arena in ipairs(P.arenas_of(game_name)) do table.insert(names, arena.name) end
    for _, name in ipairs(P.raw_arena_names()) do
        local raw = P.raw_arena(name)
        if raw.game == game_name and not P.arenas[name] then table.insert(names, name) end
    end
    return names
end
P.editor_arena_names = arena_names

local function field(f, x, y, w, name, value)
    f:slot(x, y, w, 0.65)
    f:add(("field[%g,%g;%g,0.65;%s;;%s]"):format(x + 0.1, y, w - 0.15, name, esc(tostring(value))))
    f:add(("field_close_on_enter[%s;false]"):format(name))
end

local function game_tab(f, ctx)
    local game = P.games[ctx.game]
    local min, max = P.game_limits(ctx.game)
    local limit = tonumber(P.game_setting(ctx.game, "time_limit")) or 0
    f:add(("checkbox[1.1,3.6;enabled;%s;%s]"):format(esc(S("Switched on (players can start it)")),
        tostring(P.game_enabled(ctx.game))))
    f:text(1.1, 4.0, 3.0, 0.5, S("Minutes"), { bold = true, size = 14 })
    field(f, 1.1, 4.5, 2.0, "minutes", math.floor(limit / 60 * 10 + 0.5) / 10)
    f:text(3.25, 4.5, 1.6, 0.65, S("0 = no limit"), { size = 12, color = UI.soft })
    if game.mode == "solo" then
        f:text(5.2, 4.5, 7.6, 0.65, S("Solo game: one player per arena."), { color = UI.soft })
    else
        f:text(5.2, 4.0, 3.6, 0.5, S("Min players"), { bold = true, size = 14 })
        field(f, 5.2, 4.5, 1.8, "min_players", min)
        f:text(9.0, 4.0, 3.9, 0.5, S("Max players"), { bold = true, size = 14 })
        field(f, 9.0, 4.5, 1.8, "max_players", max)
    end
    f:text(1.1, 5.35, 5.0, 0.5, S("Leaderboard ranks by"), { bold = true, size = 14 })
    f:add(dropdown(1.1, 5.85, 4.2, 0.65, "ranking", { S("best times"), S("best scores") },
        P.ranking_of(ctx.game) == "time" and 1 or 2))
    f:add(("checkbox[6.0,5.75;can_dig;%s;%s]"):format(esc(S("Players can break blocks")),
        tostring(P.game_setting(ctx.game, "can_dig") == true)))
    f:add(("checkbox[6.0,6.25;can_place;%s;%s]"):format(esc(S("Players can place blocks")),
        tostring(P.game_setting(ctx.game, "can_place") == true)))
    f:text(1.1, 6.75, 11.8, 0.5, S("Defaults come from the game; Reset brings them back."), { size = 13, color = UI.soft })
    f:button(1.1, 7.45, 3.0, 0.75, "save_game", S("Save"), "green")
    f:button(4.3, 7.45, 3.0, 0.75, "reset_game", S("Reset"), "wood")
    f:button(7.5, 7.45, 4.4, 0.75, "clear_board",
        ctx.confirm == "board" and S("Click again to confirm") or S("Clear leaderboard"), "red")
end

local function arena_tab(f, ctx)
    local names = arena_names(ctx.game)
    local idx = 1
    for i, n in ipairs(names) do if n == ctx.arena then idx = i end end
    ctx.arena = names[idx]

    if #names == 0 then
        f:text(1.1, 3.45, 11.8, 0.6, S("This minigame has no arena yet."), { color = UI.soft })
    else
        f:add(dropdown(1.1, 3.45, 3.6, 0.65, "arena", names, idx))
        local arena = P.arenas[ctx.arena]
        local raw = P.raw_arena(ctx.arena) or {}
        local p1, p2 = P.to_vec(raw.pos1), P.to_vec(raw.pos2)
        local size = p1 and p2 and vector.add(vector.apply(vector.subtract(p2, p1), math.abs), 1)
        f:text(5.0, 3.35, 7.9, 0.45, S("Corner 1: @1   Corner 2: @2", pos_text(p1), pos_text(p2)), { size = 13 })
        f:text(5.0, 3.8, 7.9, 0.45, S("Size: @1   Spawn points: @2",
            size and ("%dx%dx%d"):format(size.x, size.y, size.z) or "-",
            type(raw.spawns) == "table" and #raw.spawns or 0), { size = 13 })
        if busy(arena) then
            f:text(5.0, 4.25, 7.9, 0.45, S("A match is being played here: changes wait until it ends."),
                { size = 13, bold = true, color = UI.bad })
        elseif not arena then
            f:text(5.0, 4.25, 7.9, 0.45, S("Not usable yet: add at least one spawn point."),
                { size = 13, bold = true, color = UI.warn })
        end
        local w, gap = 2.85, 0.15
        local row1 = { { "corner1", S("Corner 1 here") }, { "corner2", S("Corner 2 here") },
            { "spawn_add", S("Add spawn here") }, { "spawn_remove", S("Remove last spawn") } }
        local row2 = { { "show_area", S("Show area"), "green" }, { "goto_arena", S("Go there") },
            { "exit_here", S("Return point here") },
            { "delete_arena", ctx.confirm == "delete" and S("Click again to confirm") or S("Delete arena"), "red" } }
        for i, b in ipairs(row1) do f:button(1.1 + (i - 1) * (w + gap), 4.95, w, 0.7, b[1], b[2], b[3]) end
        for i, b in ipairs(row2) do f:button(1.1 + (i - 1) * (w + gap), 5.8, w, 0.7, b[1], b[2], b[3]) end
    end
    f:text(1.1, 6.7, 11.8, 0.45, S("New arena of this minigame, starting where you stand:"), { size = 13, color = UI.soft })
    field(f, 1.1, 7.25, 3.8, "new_arena", ctx.new_arena or "")
    f:button(5.1, 7.22, 2.85, 0.7, "create_arena", S("Create here"), "green")
end

local function launcher_tab(f, ctx)
    local launcher = P.launchers[ctx.game]
    f:text(1.1, 3.35, 11.8, 0.8,
        S("Players queue at the launcher and come back to its return point after the match."), { size = 14, valign = "top" })
    f:text(1.1, 4.15, 11.8, 0.45, S("Launcher: @1", launcher and pos_text(launcher.pos) or S("none")), { size = 14, bold = true })
    f:text(1.1, 4.6, 11.8, 0.45, S("Return point: @1", launcher and launcher.exit and pos_text(launcher.exit.pos)
        or S("in front of the launcher")), { size = 14, bold = true })
    f:button(1.1, 5.3, 3.8, 0.75, "launcher_here", S("Move the launcher here"), "green")
    f:button(5.05, 5.3, 3.8, 0.75, "launcher_exit", S("Return point here"), "wood")
    f:button(9.0, 5.3, 3.9, 0.75, "goto_launcher", S("Go to the launcher"), "wood")
    f:button(1.1, 6.2, 3.8, 0.75, "launcher_remove",
        ctx.confirm == "launcher" and S("Click again to confirm") or S("Remove the launcher"), "red")
    f:text(5.05, 6.2, 7.85, 2.0, S("Tip: Edit tools gives you a Launcher tool: right-click a block to move the launcher there."),
        { size = 13, color = UI.soft, valign = "top" })
end

function P.show_editor(name, game_name)
    local games = sorted_games()
    if #games == 0 then return end
    local ctx = P.editor_context(name)
    if game_name and P.games[game_name] and ctx.game ~= game_name then
        ctx.game, ctx.arena = game_name, nil
        ctx = P.editor_context(name)
    end
    local game = P.games[ctx.game]

    local titles, idx = {}, 1
    for i, g in ipairs(games) do
        titles[i] = P.games[g].title
        if g == ctx.game then idx = i end
    end

    local f = P.ui_form("editor")
    f:title(game.icon, S("Minigame editor"))
    if P.undo_count() > 0 then
        f:button(11.1, 1.2, 1.5, 0.7, "undo", S("Undo (@1)", P.undo_count()), "red")
    end
    local tabs = { { "game", S("Game") }, { "arenas", S("Arenas") }, { "launcher", S("Launcher") } }
    for i, t in ipairs(tabs) do
        f:button(0.85 + (i - 1) * 2.75, 2.28, 2.6, 0.72, "tab_" .. t[1], t[2], ctx.tab == t[1] and "green" or "wood")
    end
    f:add(dropdown(9.0, 2.3, 4.15, 0.7, "game", titles, idx))
    if ctx.tab == "arenas" then
        arena_tab(f, ctx)
    elseif ctx.tab == "launcher" then
        launcher_tab(f, ctx)
    else
        game_tab(f, ctx)
    end
    if ctx.message then
        f:text(0.85, f.lay.buttons_y, 6.3, 0.85, ctx.message[1],
            { bold = true, size = 14, color = ctx.message[2] and UI.good or UI.bad })
    end
    f:button_row({ { "edit_tools", P.editing[name] and S("Stop editing") or S("Edit tools"), "blue" },
        { "to_game", S("Open the menu"), "wood" } }, 6.2)
    core.show_formspec(name, FORM, f:render())
end

-- ── Changes (shared with the edit tools) ───────────────────────────────────

local function save_and_reload()
    if not P.save_arenas() then return false end
    P.load_arenas()
    for game_name in pairs(P.launchers) do P.ensure_launcher(game_name) end
    for _, arena in pairs(P.arenas) do P.ensure_arena_nodes(arena) end
    P.label_launchers()
    if P.refresh_all_markers then P.refresh_all_markers() end
    return true
end

local function remove_launcher_node(launcher)
    if not launcher then return end
    local pos = launcher.pos
    core.load_area(pos)
    if core.get_node(pos).name == "skyss_minigames:launcher" then
        core.remove_node(pos)
    end
    for _, obj in ipairs(core.get_objects_inside_radius(vector.offset(pos, 0, 1.3, 0), 0.6)) do
        local entity = obj:get_luaentity()
        if entity and entity.name == "skyss_minigames:launcher_label" then obj:remove() end
    end
end

-- Edits of the selected arena. what: "corner1", "corner2", "spawn_add",
-- "spawn_remove" (index, default the last one), "exit". Returns ok, message.
function P.edit_arena(ctx, what, pos, yaw, index)
    local raw = ctx.arena and P.raw_arena(ctx.arena)
    if not raw then return false, S("Select an arena first (editor, Arenas).") end
    if busy(P.arenas[ctx.arena]) then return false, S("A match is being played here: changes wait until it ends.") end
    if what == "corner1" then raw.pos1 = P.vec_to_json(pos) end
    if what == "corner2" then raw.pos2 = P.vec_to_json(pos) end
    if what == "exit" then raw.exit = P.point_to_json({ pos = pos, yaw = yaw }) end
    raw.spawns = type(raw.spawns) == "table" and raw.spawns or {}
    if what == "spawn_add" then table.insert(raw.spawns, P.point_to_json({ pos = pos, yaw = yaw })) end
    if what == "spawn_remove" then
        if #raw.spawns == 0 then return false, S("This arena has no spawn points.") end
        index = index or #raw.spawns
        table.remove(raw.spawns, index)
    end
    if not save_and_reload() then return false, "Could not write arenas.json" end
    if what == "spawn_remove" then return true, S("Spawn point @1 of @2 removed.", index, ctx.arena) end
    if what == "corner1" then return true, S("Corner 1 of @1: @2", ctx.arena, core.pos_to_string(pos)) end
    if what == "corner2" then return true, S("Corner 2 of @1: @2", ctx.arena, core.pos_to_string(pos)) end
    if what == "spawn_add" then return true, S("Spawn point @1 of @2 added.", #raw.spawns, ctx.arena) end
    return true, S("Saved.")
end

function P.remove_launcher(game_name)
    if not P.raw_launcher(game_name) then return false, S("This minigame has no launcher.") end
    remove_launcher_node(P.launchers[game_name])
    P.set_raw_launcher(game_name, nil)
    save_and_reload()
    return true, S("Launcher removed.")
end

function P.set_launcher_exit(ctx, pos, yaw)
    local raw = P.raw_launcher(ctx.game)
    if not raw then return false, S("Place the launcher first.") end
    raw.exit = P.point_to_json({ pos = pos, yaw = yaw })
    save_and_reload()
    return true, S("Return point saved.")
end

function P.move_launcher(ctx, pos, yaw)
    remove_launcher_node(P.launchers[ctx.game])
    local raw = P.raw_launcher(ctx.game) or {}
    raw.pos, raw.yaw, raw.look = P.vec_to_json(pos), math.floor(math.deg(yaw) + 0.5) % 360, nil
    P.set_raw_launcher(ctx.game, raw)
    save_and_reload()
    return true, S("Launcher moved.")
end

-- Particles along the 12 edges of an arena, for one player. density: points
-- per edge at most (100 by default).
function P.show_area(name, arena_name, seconds, density)
    local raw = P.raw_arena(arena_name) or {}
    local a, b = P.to_vec(raw.pos1), P.to_vec(raw.pos2)
    if not a or not b then return end
    local p1, p2 = vector.sort(a, b)
    p1, p2 = vector.offset(p1, -0.5, -0.5, -0.5), vector.offset(p2, 0.5, 0.5, 0.5)
    local corners = {}
    for _, x in ipairs({ p1.x, p2.x }) do
        for _, y in ipairs({ p1.y, p2.y }) do
            for _, z in ipairs({ p1.z, p2.z }) do table.insert(corners, vector.new(x, y, z)) end
        end
    end
    for i = 1, #corners do
        for j = i + 1, #corners do
            local c1, c2 = corners[i], corners[j]
            local differ = (c1.x ~= c2.x and 1 or 0) + (c1.y ~= c2.y and 1 or 0) + (c1.z ~= c2.z and 1 or 0)
            if differ == 1 then
                local length = vector.distance(c1, c2)
                local step = math.max(1, length / (density or 100))
                local dir = vector.direction(c1, c2)
                for d = 0, length, step do
                    core.add_particle({
                        pos = vector.add(c1, vector.multiply(dir, d)),
                        expirationtime = seconds or 15,
                        size = 3,
                        texture = "skyss_minigames_marker.png",
                        glow = 14,
                        playername = name,
                    })
                end
            end
        end
    end
    -- Spawn points as green markers.
    for _, spec in ipairs(type(raw.spawns) == "table" and raw.spawns or {}) do
        local point = P.parse_point(spec)
        if point then
            core.add_particle({
                pos = vector.offset(point.pos, 0, 0.5, 0), expirationtime = seconds or 15, size = 6,
                texture = "skyss_minigames_marker.png^[multiply:#5fd35f", glow = 14, playername = name,
            })
        end
    end
end

local function int_field(text)
    local n = tonumber(text or "")
    return n and math.floor(n + 0.5)
end

local function here(player)
    return vector.round(player:get_pos()), player:get_look_horizontal()
end

core.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= FORM then return false end
    local name = player:get_player_name()
    if not P.is_admin(name) then return true end
    local ctx = P.editor_context(name)
    if fields.quit or fields.ui_close then
        ctx.message, ctx.confirm = nil, nil
        return true
    end
    local games = sorted_games()
    local idx = tonumber(fields.game or "")
    if idx and games[idx] and games[idx] ~= ctx.game then
        ctx.game, ctx.arena, ctx.confirm, ctx.message = games[idx], nil, nil, nil
        P.show_editor(name)
        return true
    end
    if fields.arena then
        local names = arena_names(ctx.game)
        local i = tonumber(fields.arena)
        if i and names[i] and names[i] ~= ctx.arena then ctx.arena, ctx.confirm = names[i], nil end
    end
    ctx.new_arena = fields.new_arena or ctx.new_arena
    for _, tab in ipairs({ "game", "arenas", "launcher" }) do
        if fields["tab_" .. tab] then
            ctx.tab, ctx.confirm, ctx.message = tab, nil, nil
            P.show_editor(name)
            return true
        end
    end
    if fields.to_game then
        P.show_game_form(name, ctx.game)
        return true
    end
    if fields.undo then
        if P.undo_arenas() then
            ctx.arena = nil
            P.editor_context(name)
            ctx.message = { S("Last change undone."), true }
        else
            ctx.message = { S("Nothing to undo."), false }
        end
        P.show_editor(name)
        return true
    end
    if fields.edit_tools then
        if P.editing[name] then
            P.leave_edit_mode(player)
            P.show_editor(name)
        else
            local ok, err = P.enter_edit_mode(player)
            if ok then
                core.close_formspec(name, FORM)
            else
                ctx.message = { err, false }
                P.show_editor(name)
            end
        end
        return true
    end

    local confirm = ctx.confirm
    ctx.confirm, ctx.message = nil, nil
    local function done(ok, text)
        ctx.message = { text, ok }
        if ok then save_and_reload() end
    end
    local pos, yaw = here(player)

    -- Game tab
    if fields.enabled then
        P.raw_game(ctx.game).enabled = fields.enabled == "true"
        done(true, S("Saved."))
    elseif fields.can_dig or fields.can_place then
        local key = fields.can_dig and "can_dig" or "can_place"
        P.raw_game(ctx.game)[key] = fields[key] == "true"
        done(true, S("Saved."))
    elseif fields.save_game then
        local raw = P.raw_game(ctx.game)
        local minutes = tonumber((fields.minutes or ""):gsub(",", ".") or "")
        if minutes and minutes >= 0 and minutes <= 120 then raw.time_limit = math.floor(minutes * 60 + 0.5) end
        if P.games[ctx.game].mode ~= "solo" then
            local min, max = int_field(fields.min_players), int_field(fields.max_players)
            if not (min and max and min >= 1 and max >= min and max <= 64) then
                ctx.message = { S("Players: the minimum must be at least 1 and not above the maximum."), false }
                P.show_editor(name)
                return true
            end
            raw.min_players, raw.max_players = min, max
        end
        local ranking = tonumber(fields.ranking or "")
        if ranking == 1 or ranking == 2 then P.set_ranking(ctx.game, ranking == 1 and "time" or "score") end
        done(true, S("Saved."))
    elseif fields.reset_game then
        P.reset_raw_game(ctx.game)
        P.set_ranking(ctx.game, "")
        done(true, S("Back to the game's defaults."))
    elseif fields.clear_board then
        if confirm == "board" then
            P.clear_board(ctx.game)
            ctx.message = { S("Leaderboard cleared."), true }
        else
            ctx.confirm = "board"
        end

    -- Arena tab
    elseif fields.create_arena or fields.key_enter_field == "new_arena" then
        local arena_name = (ctx.new_arena or ""):lower():gsub("[^%w_]", "_")
        if arena_name == "" then
            ctx.message = { S("Write a name for the new arena."), false }
        elseif P.raw_arena(arena_name) then
            ctx.message = { S("The arena already exists."), false }
        else
            P.set_raw_arena(arena_name, {
                game = ctx.game,
                pos1 = P.vec_to_json(vector.offset(pos, -5, -1, -5)),
                pos2 = P.vec_to_json(vector.offset(pos, 5, 8, 5)),
                spawns = { P.point_to_json({ pos = pos, yaw = yaw }) },
            })
            ctx.arena, ctx.new_arena = arena_name, ""
            done(true, S("Arena created around you: now set its corners."))
            P.show_area(name, arena_name)
        end
    elseif fields.delete_arena and ctx.arena then
        if busy(P.arenas[ctx.arena]) then
            ctx.message = { S("A match is being played here: changes wait until it ends."), false }
        elseif confirm == "delete" then
            P.set_raw_arena(ctx.arena, nil)
            ctx.arena = nil
            done(true, S("Arena deleted."))
        else
            ctx.confirm = "delete"
        end
    elseif fields.corner1 or fields.corner2 or fields.spawn_add or fields.spawn_remove or fields.exit_here then
        local what = fields.corner1 and "corner1" or fields.corner2 and "corner2" or fields.spawn_add and "spawn_add"
            or fields.spawn_remove and "spawn_remove" or "exit"
        local ok, msg = P.edit_arena(ctx, what, pos, yaw)
        ctx.message = { msg, ok }
    elseif fields.show_area and ctx.arena then
        P.show_area(name, ctx.arena)
        ctx.message = { S("The edges of the arena glow for 15 seconds."), true }
    elseif fields.goto_arena and ctx.arena then
        local arena = P.arenas[ctx.arena]
        local raw = P.raw_arena(ctx.arena)
        local spawn = arena and arena.spawns[1] or (raw and P.parse_point((raw.spawns or {})[1] or raw.pos1))
        if spawn then P.teleport(player, spawn) end

    -- Launcher tab
    elseif fields.launcher_here then
        ctx.message = { select(2, P.move_launcher(ctx, pos, yaw)), true }
        player:set_pos(vector.offset(pos, 0, 1, 0))
    elseif fields.launcher_exit then
        local ok, msg = P.set_launcher_exit(ctx, pos, yaw)
        ctx.message = { msg, ok }
    elseif fields.goto_launcher then
        if P.launchers[ctx.game] then P.teleport(player, P.exit_point({ game = ctx.game, spawns = {} })) end
    elseif fields.launcher_remove then
        if confirm == "launcher" then
            local ok, msg = P.remove_launcher(ctx.game)
            ctx.message = { msg, ok }
        else
            ctx.confirm = "launcher"
        end
    end
    P.show_editor(name)
    return true
end)

core.register_on_leaveplayer(function(player)
    context[player:get_player_name()] = nil
end)
