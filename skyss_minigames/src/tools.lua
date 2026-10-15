local P = ...
local S = P.S

-- Edit mode for admins: the inventory is put aside and the hotbar holds one
-- tool per job. Spawn points, corners and the return point show up as
-- numbered markers only the admin sees; the arena's edges glow. Tools work
-- on the game and arena selected with the Select tool (or in the editor).

local EDIT_KEY = "skyss_minigames:edit_saved"
local MARKER = "skyss_minigames:marker"

P.editing = {}  -- [admin] = { markers = {objects} }

local TOOLS = {
    { id = "select", title = S("Select"),
      help = S("Left-click an arena or a launcher to select it. Right-click: open the editor.") },
    { id = "corners", title = S("Corners"),
      help = S("Left-click a block: corner 1. Right-click a block: corner 2.") },
    { id = "spawn", title = S("Spawn points"),
      help = S("Right-click a block: add a spawn point. Left-click a spawn marker: remove it.") },
    { id = "launcher", title = S("Launcher"),
      help = S("Right-click a block twice: put the game's launcher there. Left-click a launcher twice: destroy it.") },
    { id = "exit", title = S("Return point"),
      help = S("Right-click a block: players come back here after the match.") },
    { id = "done", title = S("Done"),
      help = S("Click: leave edit mode and get your inventory back.") },
}
local TOOL_BY_ITEM = {}

local function item_name(id) return "skyss_minigames:tool_" .. id end

function skyss_minigames.is_editing(name)
    return P.editing[name] ~= nil
end

local function tell(name, ok, text)
    core.chat_send_player(name, core.colorize(ok and "#7be08a" or "#ff8a7a", text))
end

-- ── Markers ────────────────────────────────────────────────────────────────

core.register_entity(MARKER, {
    initial_properties = {
        visual = "sprite",
        textures = { "skyss_minigames_marker.png" },
        visual_size = { x = 0.45, y = 0.45 },
        physical = false,
        pointable = true,
        collisionbox = { -0.25, -0.25, -0.25, 0.25, 0.25, 0.25 },
        selectionbox = { -0.3, -0.3, -0.3, 0.3, 0.3, 0.3 },
        static_save = false,
        glow = 14,
        nametag_color = "#ffffff",
        nametag_bgcolor = "#302c2ecc",
    },
    on_activate = function(self, staticdata)
        local data = core.deserialize(staticdata or "") or {}
        self.owner, self.kind, self.index = data.owner, data.kind, data.index
        if not self.owner then self.object:remove() end
    end,
    on_punch = function()
        return true  -- no damage, no knockback; tools handle the click
    end,
})

local function clear_markers(name)
    local state = P.editing[name]
    if not state then return end
    for _, obj in ipairs(state.markers or {}) do
        if obj:get_pos() then obj:remove() end
    end
    state.markers = {}
end

local function add_marker(name, pos, kind, index, label, color)
    local obj = core.add_entity(pos, MARKER, core.serialize({ owner = name, kind = kind, index = index }))
    if not obj then return end
    obj:set_properties({
        nametag = label,
        nametag_color = color,
        textures = { "skyss_minigames_marker.png^[multiply:" .. color },
    })
    if obj.set_observers then obj:set_observers({ [name] = true }) end
    table.insert(P.editing[name].markers, obj)
end

function P.refresh_markers(name)
    local state = P.editing[name]
    if not state then return end
    clear_markers(name)
    local ctx = P.editor_context(name)
    local raw = ctx.arena and P.raw_arena(ctx.arena)
    if raw then
        for i, spec in ipairs(type(raw.spawns) == "table" and raw.spawns or {}) do
            local point = P.parse_point(spec)
            if point then
                add_marker(name, vector.offset(point.pos, 0, 0.6, 0), "spawn", i, S("Spawn @1", i), "#5fd35f")
            end
        end
        for i, key in ipairs({ "pos1", "pos2" }) do
            local pos = P.to_vec(raw[key])
            if pos then add_marker(name, pos, "corner", i, S("Corner @1", i), "#ffd43b") end
        end
    end
    local launcher = ctx.game and P.launchers[ctx.game]
    if launcher and launcher.exit then
        add_marker(name, vector.offset(launcher.exit.pos, 0, 0.6, 0), "exit", 1, S("Return point"), "#6fb7ff")
    end
end

function P.refresh_all_markers()
    for name in pairs(P.editing) do P.refresh_markers(name) end
end

-- ── Edit mode ──────────────────────────────────────────────────────────────

function P.enter_edit_mode(player)
    local name = player:get_player_name()
    if P.editing[name] then return true end
    if P.playing[name] then return false, S("@1 is already playing.", name) end
    P.queue_leave(name)
    local meta = player:get_meta()
    local inv = player:get_inventory()
    if meta:get_string(EDIT_KEY) == "" then
        meta:set_string(EDIT_KEY, core.serialize({
            main = P.item_strings(inv:get_list("main")),
            hotbar_count = player:hud_get_hotbar_itemcount(),
            hotbar_image = player:hud_get_hotbar_image(),
        }))
    end
    inv:set_list("main", {})
    for i, tool in ipairs(TOOLS) do inv:set_stack("main", i, item_name(tool.id)) end
    -- A plain hotbar of known size: classrooms_bridge's toolbar is suspended
    -- while editing and finds its own hotbar again afterwards.
    player:hud_set_hotbar_itemcount(9)
    if core.get_modpath("mcl_inventory") then player:hud_set_hotbar_image("mcl_inventory_hotbar.png") end
    P.editing[name] = { markers = {} }
    P.refresh_markers(name)
    tell(name, true, S("Edit mode: hold a tool to see what it does. Use Done to finish."))
    return true
end

-- at_join: the join callbacks of hub and classrooms_bridge have just set
-- up a fresh hotbar; only the items come back.
local function restore_inventory(player, at_join)
    local meta = player:get_meta()
    local raw = meta:get_string(EDIT_KEY)
    if raw == "" then return false end
    local saved = core.deserialize(raw) or {}
    player:get_inventory():set_list("main", saved.main or {})
    if at_join then
        meta:set_string(EDIT_KEY, "")
        return true
    end
    if saved.hotbar_count then player:hud_set_hotbar_itemcount(saved.hotbar_count) end
    if saved.hotbar_image and saved.hotbar_image ~= "" then player:hud_set_hotbar_image(saved.hotbar_image) end
    meta:set_string(EDIT_KEY, "")
    return true
end

function P.leave_edit_mode(player)
    local name = player:get_player_name()
    clear_markers(name)
    P.editing[name] = nil
    restore_inventory(player)
    P.hud_status(player, nil)
end

core.register_on_joinplayer(function(player)
    restore_inventory(player, true)
end)

core.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    clear_markers(name)
    P.editing[name] = nil  -- the inventory comes back at the next join
end)

-- ── Tools ──────────────────────────────────────────────────────────────────

local function admin_of(user)
    if not user or not user:is_player() then return nil end
    local name = user:get_player_name()
    if not P.is_admin(name) then
        tell(name, false, S("Only admins can do this."))
        return nil
    end
    return name
end

-- An arena whose box (from the raw data, usable or not) contains pos.
local function raw_arena_at(pos)
    for _, arena_name in ipairs(P.raw_arena_names()) do
        local raw = P.raw_arena(arena_name)
        local a, b = P.to_vec(raw.pos1), P.to_vec(raw.pos2)
        if a and b then
            local p1, p2 = vector.sort(a, b)
            if P.inside(pos, p1, p2) then return arena_name, raw.game end
        end
    end
end

local function after_change(name, ok, msg)
    tell(name, ok, msg)
    if ok then P.refresh_all_markers() end
end

local actions = {}

actions.select = {
    left = function(name, ctx, pointed)
        if pointed.type ~= "node" then return end
        local game_name = P.game_of_launcher(pointed.under)
        if game_name then
            ctx.game, ctx.arena = game_name, nil
            P.editor_context(name)
            tell(name, true, S("Selected: @1 (launcher).", P.games[game_name].title))
        else
            local arena_name, arena_game = raw_arena_at(pointed.under)
            if not arena_name then
                tell(name, false, S("There is no arena here."))
                return
            end
            ctx.game, ctx.arena = arena_game, arena_name
            tell(name, true, S("Selected: arena @1.", arena_name))
        end
        P.refresh_markers(name)
    end,
    right = function(name)
        P.show_editor(name)
    end,
}

actions.corners = {
    left = function(name, ctx, pointed)
        if pointed.type ~= "node" then return end
        after_change(name, P.edit_arena(ctx, "corner1", pointed.under, 0))
    end,
    right = function(name, ctx, pointed)
        if pointed.type ~= "node" then return end
        after_change(name, P.edit_arena(ctx, "corner2", pointed.under, 0))
    end,
}

actions.spawn = {
    left = function(name, ctx, pointed)
        local index
        if pointed.type == "object" then
            local entity = pointed.ref:get_luaentity()
            if entity and entity.name == MARKER and entity.kind == "spawn" then index = entity.index end
        elseif pointed.type == "node" then
            -- Clicking the block a spawn stands on also works.
            local raw = ctx.arena and P.raw_arena(ctx.arena)
            for i, spec in ipairs(raw and type(raw.spawns) == "table" and raw.spawns or {}) do
                local point = P.parse_point(spec)
                if point and vector.distance(point.pos, pointed.above) < 1.1 then index = i end
            end
        end
        if not index then
            tell(name, false, S("Left-click a green spawn marker to remove it."))
            return
        end
        after_change(name, P.edit_arena(ctx, "spawn_remove", nil, nil, index))
    end,
    right = function(name, ctx, pointed, user)
        if pointed.type ~= "node" then return end
        after_change(name, P.edit_arena(ctx, "spawn_add", pointed.above, user:get_look_horizontal()))
    end,
}

-- Moving a launcher needs a second right-click on the same block within a
-- few seconds, so a stray click does not move it.
local CONFIRM_US = 5000000

-- True on the second click on the same spot within a few seconds.
local function confirmed(name, key, pos)
    local state = P.editing[name]
    local now = core.get_us_time()
    local pending = state.confirm
    if pending and pending.key == key and vector.equals(pending.pos, pos) and now - pending.at < CONFIRM_US then
        state.confirm = nil
        return true
    end
    state.confirm = { key = key, pos = pos, at = now }
    return false
end

actions.launcher = {
    left = function(name, ctx, pointed)
        if pointed.type ~= "node" then return end
        local game_name = P.game_of_launcher(pointed.under)
        if not game_name then
            tell(name, false, S("Left-click a launcher (twice) to destroy it."))
            return
        end
        if not confirmed(name, "destroy", pointed.under) then
            tell(name, false, S("Left-click the launcher again to destroy the launcher of @1.", P.games[game_name].title))
            return
        end
        after_change(name, P.remove_launcher(game_name))
    end,
    right = function(name, ctx, pointed, user)
        if pointed.type ~= "node" then return end
        if not confirmed(name, "move", pointed.above) then
            tell(name, false, S("Right-click the same block again to move the launcher of @1 there.",
                P.games[ctx.game] and P.games[ctx.game].title or "-"))
            return
        end
        after_change(name, P.move_launcher(ctx, pointed.above, user:get_look_horizontal() + math.pi))
    end,
}

actions.exit = {
    right = function(name, ctx, pointed, user)
        if pointed.type ~= "node" then return end
        after_change(name, P.set_launcher_exit(ctx, pointed.above, user:get_look_horizontal()))
    end,
}

actions.done = {
    left = function(name, ctx, pointed, user) P.leave_edit_mode(user) end,
    right = function(name, ctx, pointed, user) P.leave_edit_mode(user) end,
}

local function use(id, side)
    return function(itemstack, user, pointed)
        local name = admin_of(user)
        if not name then return itemstack end
        if not P.editing[name] and id ~= "done" then
            P.enter_edit_mode(user)
            return
        end
        local action = actions[id] and actions[id][side]
        if action then action(name, P.editor_context(name), pointed, user) end
        -- Tools never leave the hotbar or change.
    end
end

for _, tool in ipairs(TOOLS) do
    local item = item_name(tool.id)
    TOOL_BY_ITEM[item] = tool
    core.register_tool(item, {
        description = tool.title .. "\n" .. core.colorize("#9aa3b5", tool.help),
        inventory_image = "skyss_minigames_tool_" .. tool.id .. ".png",
        range = 24,
        groups = { not_in_creative_inventory = 1 },
        on_use = use(tool.id, "left"),
        on_place = use(tool.id, "right"),
        on_secondary_use = use(tool.id, "right"),
        on_drop = function(itemstack) return itemstack end,
    })
end

-- The old single wand opens edit mode with the new tools.
core.register_alias("skyss_minigames:wand", item_name("select"))
P.WAND = item_name("select")

-- ── While editing: status, help of the tool in hand, glowing edges ─────────

local timer = 0
core.register_globalstep(function(dtime)
    timer = timer + dtime
    if timer < 1 then return end
    timer = 0
    for name, state in pairs(P.editing) do
        local player = core.get_player_by_name(name)
        if player then
            local ctx = P.editor_context(name)
            local game = P.games[ctx.game]
            P.hud_status(player, S("EDIT MODE - @1 - arena @2", game and game.title or "-", ctx.arena or "-"))
            local tool = TOOL_BY_ITEM[player:get_wielded_item():get_name()]
            if tool then P.hud_message(player, "hint", tool.title .. ": " .. tool.help, 1.2, 0xffd43b) end
            if ctx.arena then P.show_area(name, ctx.arena, 1.1, 40) end
            -- Markers vanish when their area unloads (or could not be added
            -- far away): put them back.
            if #state.markers == 0 and ctx.arena then P.refresh_markers(name) end
            for _, obj in ipairs(state.markers) do
                if not obj:get_pos() then
                    P.refresh_markers(name)
                    break
                end
            end
        end
    end
end)
