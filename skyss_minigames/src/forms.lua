local P = ...
local S = P.S
local UI = P.UI
local esc = core.formspec_escape

local GAME_FORM = "skyss_minigames:game"
local STAFF_FORM = "skyss_minigames:staff"
local LEAVE_FORM = "skyss_minigames:leave"
local BOARD_FORM = "skyss_minigames:board"
local STAFF_RADIUS = 48
local STAFF_MAX = 40

local context = {}  -- [player name] = { game = name, selected = {}, candidates = {}, time_limit }

local function minutes_text(seconds)
    if not seconds or seconds <= 0 then return S("No time limit") end
    if seconds % 60 == 0 then return S("@1 min", seconds / 60) end
    return P.format_time(seconds)
end

-- Status line, its colour, and extra lines for the game menu.
local function game_status(name, game_name)
    local arenas = P.arenas_of(game_name)
    local free = #P.free_arenas(game_name)
    local queue = P.queue_list(game_name)
    local min, max = P.game_limits(game_name)
    local lines = {}
    local playing = 0
    for _, arena in ipairs(arenas) do
        if arena.match then playing = playing + #arena.match.player_list end
    end
    if playing > 0 then table.insert(lines, S("Playing now: @1", playing)) end
    if P.games[game_name].mode == "solo" then
        table.insert(lines, S("Free places: @1 of @2", free, #arenas))
    elseif #arenas > 1 then
        table.insert(lines, S("Free arenas: @1 of @2", free, #arenas))
    end

    if not P.game_enabled(game_name) then
        return S("This minigame is switched off."), UI.soft, lines
    elseif #arenas == 0 then
        return S("This minigame has no arena yet."), UI.soft, lines
    elseif P.playing[name] then
        return S("You are playing!"), UI.good, lines
    elseif P.queued[name] == game_name then
        local left = P.queue_seconds_left(game_name)
        if left then
            table.insert(lines, 1, table.concat(queue, ", "))
            return S("In line (@1/@2): starting in @3 s.", #queue, max, left), UI.good, lines
        elseif free == 0 then
            return S("In line: waiting for a free arena."), UI.warn, lines
        end
        table.insert(lines, 1, table.concat(queue, ", "))
        return S("In line (@1/@2): at least @3 players are needed.", #queue, max, min), UI.warn, lines
    elseif #queue > 0 then
        table.insert(lines, 1, table.concat(queue, ", "))
        return S("@1 in line: join them!", #queue), UI.warn, lines
    elseif free == 0 then
        return S("Every arena is busy: get in line."), UI.warn, lines
    end
    return S("Free: start a match!"), UI.good, lines
end

function P.show_game_form(name, game_name)
    local game = P.games[game_name]
    if not game then return end
    context[name] = context[name] and context[name].game == game_name and context[name] or { game = game_name }
    local min, max = P.game_limits(game_name)
    local limit = tonumber(P.game_setting(game_name, "time_limit")) or 0

    local f = P.ui_form("game")
    f:title(game.icon, game.title, game.mode == "solo" and S("Solo game") or S("Team game: everybody together"), game.color)

    local how = f:panel("how")
    f:tab("how", S("HOW TO PLAY"))
    f:text(how[1] + 0.25, how[2] + 0.38, how[3] - 0.5, how[4] - 0.5, game.description or "", { valign = "top" })

    local chips = {
        { game.mode == "solo" and "skyss_minigames_ui_solo.png" or "skyss_minigames_ui_coop.png",
            game.mode == "solo" and S("Solo") or S("Cooperative") },
        { "skyss_minigames_ui_people.png", game.mode == "solo" and S("@1 places", #P.arenas_of(game_name))
            or min == max and S("@1 player(s)", max) or S("@1-@2 players", min, max) },
        { "skyss_minigames_ui_clock.png", minutes_text(limit) },
    }
    for i, chip in ipairs(chips) do
        local r = f.lay.slots["chip" .. i]
        f:image(r[1] + 0.12, r[2] + 0.2, 0.4, 0.4, chip[1])
        f:text(r[1] + 0.56, r[2], r[3] - 0.6, r[4], chip[2], { size = 12, bold = true })
    end

    local status, color, lines = game_status(name, game_name)
    local now = f:panel("now")
    f:tab("now", S("RIGHT NOW"))
    f:image(now[1] + 0.25, now[2] + 0.55, 0.28, 0.28, "skyss_minigames_ui_dot.png^[multiply:" .. color)
    f:text(now[1] + 0.65, now[2] + 0.4, now[3] - 0.85, 0.58, status, { bold = true, color = color })
    for i, line in ipairs(lines) do
        if i > 2 then break end
        f:text(now[1] + 0.25, now[2] + 0.98 + (i - 1) * 0.4, now[3] - 0.5, 0.4, P.ui_cut(line, 60),
            { size = 13, color = UI.soft })
    end

    f:board(game_name)

    -- Buttons: the main action first.
    local buttons = {}
    local queued_here = P.queued[name] == game_name
    local enabled = P.game_enabled(game_name) and #P.arenas_of(game_name) > 0
    if P.playing[name] then
        table.insert(buttons, { "leave_match", S("Leave the match"), "red" })
    elseif queued_here then
        table.insert(buttons, { "leave_queue", S("Leave the line"), "red" })
        if game.mode ~= "solo" and #P.queue_list(game_name) >= min and #P.free_arenas(game_name) > 0 then
            table.insert(buttons, { "start_now", S("Start now!"), "green" })
        end
    elseif enabled then
        local label = S("Get in line")
        if P.joinable_match(game_name) then
            label = S("Join the match")
        elseif game.mode == "solo" and #P.free_arenas(game_name) > 0 then
            label = S("Play")
        end
        table.insert(buttons, { "join", label, "green" })
    end
    if P.is_staff(name) and enabled then
        table.insert(buttons, { "staff", S("Start for players..."), "blue" })
    end
    if P.is_admin(name) then
        table.insert(buttons, { "edit", S("Edit"), "wood" })
    end
    f:button_row(buttons)
    core.show_formspec(name, GAME_FORM, f:render())
end

-- Online players a teacher can pick: nearest to the launcher first.
local function staff_candidates(game_name, staff_name)
    local launcher = P.launchers[game_name]
    local staff = core.get_player_by_name(staff_name)
    local origin = launcher and launcher.pos or (staff and staff:get_pos())
    local list = {}
    for _, player in ipairs(core.get_connected_players()) do
        local n = player:get_player_name()
        if not P.playing[n] and n ~= staff_name then
            local d = origin and vector.distance(player:get_pos(), origin) or 0
            if d <= STAFF_RADIUS or P.queued[n] == game_name then
                table.insert(list, { name = n, d = d })
            end
        end
    end
    table.sort(list, function(a, b) return a.d < b.d end)
    local names = {}
    for i = 1, math.min(#list, STAFF_MAX) do names[i] = list[i].name end
    return names
end

function P.show_staff_form(name, game_name, message)
    local game = P.games[game_name]
    local ctx = context[name]
    if not ctx or ctx.game ~= game_name or not ctx.selected then
        ctx = { game = game_name, selected = {} }
        context[name] = ctx
        for _, n in ipairs(P.queue_list(game_name)) do ctx.selected[n] = true end
    end
    ctx.candidates = staff_candidates(game_name, name)
    local min, max = P.game_limits(game_name)
    local limit = ctx.time_limit or tonumber(P.game_setting(game_name, "time_limit")) or 0
    local selected = 0
    for _, n in ipairs(ctx.candidates) do
        if ctx.selected[n] then selected = selected + 1 end
    end

    local f = P.ui_form("staff")
    f:title(game.icon, game.title, S("Start a match for your students"), game.color)

    local pl = f:panel("players")
    f:tab("players", S("WHO PLAYS (NEAREST FIRST)"))
    local tab = f.lay.tabs.players
    f:text(tab[1] + tab[3] + 0.1, tab[2], pl[1] + pl[3] - tab[1] - tab[3] - 0.3, tab[4],
        S("Selected: @1", selected), { size = 13, bold = true, color = UI.soft, halign = "right" })
    local list_h = pl[4] - 1.1
    f:add(("scroll_container[%g,%g;%g,%g;players;vertical]"):format(pl[1] + 0.2, pl[2] + 0.2, pl[3] - 0.65, list_h))
    if #ctx.candidates == 0 then
        f:text(0.1, 0.1, pl[3] - 0.9, 0.6, S("Nobody is near this launcher."), { color = UI.soft })
    end
    local col_w = (pl[3] - 0.65) / 2
    for i, n in ipairs(ctx.candidates) do
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        f:add(("checkbox[%g,%g;pl_%d;%s;%s]"):format(col * col_w + 0.1, row * 0.5 + 0.25, i,
            esc(P.ui_cut(n, 20)), ctx.selected[n] and "true" or "false"))
    end
    f:add("scroll_container_end[]")
    local rows = math.ceil(#ctx.candidates / 2)
    local visible = math.floor(list_h / 0.5)
    if rows > visible then
        f:add(("scrollbaroptions[max=%d]scrollbar[%g,%g;0.25,%g;vertical;players;0]")
            :format((rows - visible) * 5, pl[1] + pl[3] - 0.4, pl[2] + 0.2, list_h))
    end
    f:button(pl[1] + 0.2, pl[2] + pl[4] - 0.8, 2.2, 0.6, "all", S("All"), "wood")
    f:button(pl[1] + 2.55, pl[2] + pl[4] - 0.8, 2.2, 0.6, "none", S("Nobody"), "wood")

    local st = f:panel("settings")
    f:tab("settings", S("SETTINGS"))
    local slot = f.lay.slots.minutes
    f:text(st[1] + 0.2, st[2] + 0.35, st[3] - 0.4, 0.5, S("Minutes"), { bold = true, size = 14 })
    f:add(("field[%g,%g;%g,%g;minutes;;%s]"):format(slot[1] + 0.1, slot[2], slot[3] - 0.15, slot[4],
        esc(tostring(math.floor(limit / 60 * 10 + 0.5) / 10))))
    f:add("field_close_on_enter[minutes;false]")
    f:text(slot[1] + slot[3] + 0.15, slot[2], st[1] + st[3] - slot[1] - slot[3] - 0.3, slot[4], S("0 = no limit"),
        { size = 12, color = UI.soft })
    f:text(st[1] + 0.2, slot[2] + slot[4] + 0.1, st[3] - 0.4, 0.6, game.mode == "solo"
        and S("One arena per student.") or S("@1-@2 players together.", min, max), { size = 13, color = UI.soft })

    local ma = f:panel("matches")
    f:tab("matches", S("MATCHES"))
    local y = ma[2] + 0.3
    for _, arena in ipairs(P.arenas_of(game_name)) do
        if arena.match and y < ma[2] + ma[4] - 0.5 then
            f:text(ma[1] + 0.2, y, ma[3] - 1.8, 0.5, S("@1: @2 playing", arena.name, #arena.match.player_list), { size = 13 })
            f:button(ma[1] + ma[3] - 1.5, y + 0.03, 1.3, 0.45, "stop_" .. arena.name, S("Stop"), "red")
            y = y + 0.55
        end
    end
    if y == ma[2] + 0.3 then
        f:text(ma[1] + 0.2, y, ma[3] - 0.4, 0.5, S("No match is being played."), { size = 13, color = UI.soft })
    end

    if message then
        f:text(0.85, f.lay.buttons_y, 6.6, 0.85, message, { bold = true, color = UI.bad, size = 14 })
    end
    f:button_row({ { "start", S("Start"), "green" }, { "back", S("Back"), "wood" } }, 7.6)
    core.show_formspec(name, STAFF_FORM, f:render())
end

function P.show_leave_form(name)
    local match = P.playing[name]
    local game = match and match.game
    local f = P.ui_form("leave")
    f:title(game and game.icon or "skyss_minigames_leave.png", S("Leave the minigame"))
    f:text(0.85, 2.35, 7.3, 0.6, S("Do you want to leave the minigame?"), { bold = true, halign = "center", size = 16 })
    f:text(0.85, 2.95, 7.3, 0.5, S("You will go back to the hub."), { halign = "center", color = UI.soft, size = 14 })
    f:button_row({ { "no", S("Keep playing"), "green", true }, { "yes", S("Leave"), "red", true } })
    core.show_formspec(name, LEAVE_FORM, f:render())
end

function P.show_board_form(name, game_name)
    local game = P.games[game_name]
    if not game then return end
    local f = P.ui_form("board")
    f:title(game.icon, game.title)
    f:board(game_name)
    f:button_row({ { "close", S("Close"), "wood", true } })
    core.show_formspec(name, BOARD_FORM, f:render())
end

local function minutes_field(fields)
    local text = (fields.minutes or ""):gsub(",", ".")
    local minutes = tonumber(text)
    if minutes and minutes >= 0 and minutes <= 120 then
        return math.floor(minutes * 60 + 0.5)
    end
end

local function tell(name, text)
    core.chat_send_player(name, core.colorize("#ff8a7a", text))
end

core.register_on_player_receive_fields(function(player, formname, fields)
    local name = player:get_player_name()
    if formname == LEAVE_FORM then
        if fields.yes then P.leave(name, "quit") end
        return true
    elseif formname == BOARD_FORM then
        return true
    elseif formname ~= GAME_FORM and formname ~= STAFF_FORM then
        return false
    end

    local ctx = context[name]
    local game_name = ctx and ctx.game
    if not game_name or not P.games[game_name] or fields.quit or fields.ui_close then
        context[name] = nil
        return true
    end

    if formname == GAME_FORM then
        if fields.join then
            local ok, err = P.queue_join(name, game_name)
            if not ok and err then tell(name, err) end
            if P.playing[name] then
                core.close_formspec(name, GAME_FORM)
                return true
            end
        elseif fields.leave_queue then
            P.queue_leave(name)
        elseif fields.leave_match then
            P.leave(name, "quit")
            core.close_formspec(name, GAME_FORM)
            return true
        elseif fields.start_now and P.queued[name] == game_name then
            if P.queue_try_start(game_name, true) then
                core.close_formspec(name, GAME_FORM)
                return true
            end
        elseif fields.staff and P.is_staff(name) then
            ctx.selected = nil
            P.show_staff_form(name, game_name)
            return true
        elseif fields.edit and P.is_admin(name) then
            P.show_editor(name, game_name)
            return true
        end
        if not P.playing[name] then P.show_game_form(name, game_name) end
        return true
    end

    -- Teacher's player picker.
    if not P.is_staff(name) then return true end
    ctx.time_limit = minutes_field(fields) or ctx.time_limit
    ctx.selected = ctx.selected or {}
    for key, value in pairs(fields) do
        local index = tonumber(key:match("^pl_(%d+)$") or "")
        local target = index and ctx.candidates and ctx.candidates[index]
        if target then ctx.selected[target] = value == "true" end
        local arena = P.arenas[key:match("^stop_(.+)$") or ""]
        if arena then
            P.stop(arena)
            P.show_staff_form(name, game_name)
            return true
        end
    end
    if fields.back then
        P.show_game_form(name, game_name)
    elseif fields.all or fields.none then
        for _, n in ipairs(ctx.candidates or {}) do ctx.selected[n] = fields.all ~= nil end
        P.show_staff_form(name, game_name)
    elseif fields.start or fields.key_enter_field == "minutes" then
        local names = {}
        for _, n in ipairs(ctx.candidates or {}) do
            if ctx.selected[n] then table.insert(names, n) end
        end
        local ok, msg = P.start_game(game_name, names, { time_limit = minutes_field(fields), by = name })
        if ok then
            context[name] = nil
            core.close_formspec(name, STAFF_FORM)
            core.chat_send_player(name, msg)
        else
            P.show_staff_form(name, game_name, msg)
        end
    end
    return true
end)

core.register_on_leaveplayer(function(player)
    context[player:get_player_name()] = nil
end)

-- ── Launcher node ──────────────────────────────────────────────────────────

local function open_launcher(pos, clicker)
    if not clicker or not clicker:is_player() then return end
    local name = clicker:get_player_name()
    local game_name = P.game_of_launcher(pos)
    if not game_name or not P.games[game_name] then
        core.chat_send_player(name, S("This launcher is not linked to a minigame."))
        return
    end
    P.show_game_form(name, game_name)
end

core.register_node("skyss_minigames:launcher", {
    description = S("Minigame launcher"),
    drawtype = "nodebox",
    paramtype = "light",
    paramtype2 = "facedir",
    light_source = 8,
    node_box = {
        type = "fixed",
        fixed = {
            { -0.4, -0.5, -0.4, 0.4, -0.3, 0.4 },
            { -0.2, -0.3, -0.2, 0.2, 0.6, 0.2 },
            { -0.35, 0.6, -0.35, 0.35, 0.8, 0.35 },
        },
    },
    selection_box = { type = "fixed", fixed = { -0.4, -0.5, -0.4, 0.4, 0.8, 0.4 } },
    tiles = {
        "skyss_minigames_launcher_top.png",
        "skyss_minigames_launcher_side.png",
        "skyss_minigames_launcher_side.png",
    },
    groups = { not_in_creative_inventory = 1, unbreakable = 1 },
    diggable = false,
    pointable = true,
    is_ground_content = false,
    drop = "",
    on_blast = function() end,
    can_dig = function() return false end,
    on_rightclick = function(pos, _, clicker)
        open_launcher(pos, clicker)
    end,
    on_punch = function(pos, _, puncher)
        open_launcher(pos, puncher)
    end,
})

-- A floating label above each launcher, so players find it from afar.
core.register_entity("skyss_minigames:launcher_label", {
    initial_properties = {
        visual = "sprite",
        textures = { "blank.png" },
        visual_size = { x = 0, y = 0 },
        physical = false,
        pointable = false,
        static_save = false,
        nametag_color = "#ffd43b",
        nametag_bgcolor = "#141b2ecc",
    },
    on_activate = function(self, staticdata)
        self.game = staticdata
        local game = P.games[staticdata]
        if not game then
            self.object:remove()
            return
        end
        self.object:set_properties({ nametag = game.title })
    end,
})

local function label_launchers()
    for game_name, launcher in pairs(P.launchers) do
        if P.games[game_name] then
            local pos = vector.offset(launcher.pos, 0, 1.3, 0)
            local found = false
            for _, obj in ipairs(core.get_objects_inside_radius(pos, 0.6)) do
                local entity = obj:get_luaentity()
                if entity and entity.name == "skyss_minigames:launcher_label" then
                    if entity.game == game_name then found = true else obj:remove() end
                end
            end
            if not found then core.add_entity(pos, "skyss_minigames:launcher_label", game_name) end
        end
    end
end
P.label_launchers = label_launchers

-- Labels are not saved with the map: add them while someone is nearby.
local label_timer = 0
core.register_globalstep(function(dtime)
    label_timer = label_timer + dtime
    if label_timer < 5 then return end
    label_timer = 0
    label_launchers()
end)
