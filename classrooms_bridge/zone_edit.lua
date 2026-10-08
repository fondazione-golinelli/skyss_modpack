-- In-world zone editor.
--
-- The proxy starts it with "zone_edit_start" after the teacher pressed
-- "Create zone" in the World Tools menu. The teacher flies through blocks and
-- uses five hotbar tools: point 1, point 2, teleport point, cancel, confirm.
-- Confirm sends "zone_edit_done" with the points to the proxy, which saves
-- the zone; cancel sends "zone_edit_cancelled".
--
-- The teacher's inventory, hotbar and fly/fast/noclip privileges are saved in
-- player meta while editing and restored on exit, on leave, and on the next
-- join after a crash.

local toolbar, zones, send = ...

local META_KEY = "classrooms_zone_edit"
local MODE_HOTBAR = "[combine:102x22"
    .. ":0,0=classrooms_bridge_hotbar_slot_mcl.png:20,0=classrooms_bridge_hotbar_slot_mcl.png"
    .. ":40,0=classrooms_bridge_hotbar_slot_mcl.png:60,0=classrooms_bridge_hotbar_slot_mcl.png"
    .. ":80,0=classrooms_bridge_hotbar_slot_mcl.png"

local editing = {} -- [name] = { name, who, p1, p2, tp, yaw, huds }

local zone_edit = {}

local function fmt_pos(p)
    return p and ("(" .. p.x .. ", " .. p.z .. ")") or "—"
end

local function update_hud(player)
    local name = player:get_player_name()
    local state = editing[name]
    if not state then return end
    local lines = {
        "ZONE EDITOR: " .. state.name .. "  (" .. state.who .. ")",
        "Point 1: " .. fmt_pos(state.p1) .. "    Point 2: " .. fmt_pos(state.p2)
            .. "    Teleport: " .. (state.tp and fmt_pos(state.tp) or "point 1"),
        "Fly to the corners and use the tools below. Confirm when done.",
    }
    if state.p1 and state.p2 then
        lines[3] = ("Area %d × %d blocks, full height. Press Confirm to save."):format(
            math.abs(state.p1.x - state.p2.x) + 1, math.abs(state.p1.z - state.p2.z) + 1)
    end
    if not state.huds then
        state.huds = {}
        for i, text in ipairs(lines) do
            state.huds[i] = player:hud_add({
                type = "text",
                position = { x = 0.5, y = 0.06 },
                offset = { x = 0, y = (i - 1) * 24 },
                text = text,
                number = i == 1 and 0xFFE066 or 0xEEEEEE,
                size = i == 1 and { x = 1.3 } or { x = 1 },
                style = i == 1 and 1 or 0,
                alignment = { x = 0, y = 0 },
                z_index = 100,
            })
        end
    else
        for i, text in ipairs(lines) do
            player:hud_change(state.huds[i], "text", text)
        end
    end
end

local function save_state(player)
    local inv = player:get_inventory()
    local main = {}
    for i, stack in ipairs(inv:get_list("main") or {}) do
        -- Classroom tools are re-granted by the toolbar; don't duplicate them.
        main[i] = toolbar.is_tool_item(stack:get_name()) and "" or stack:to_string()
    end
    local privs = minetest.get_player_privs(player:get_player_name())
    player:get_meta():set_string(META_KEY, minetest.write_json({
        main = main,
        hotbar = player:hud_get_hotbar_itemcount(),
        image = player:hud_get_hotbar_image(),
        fly = privs.fly == true,
        fast = privs.fast == true,
        noclip = privs.noclip == true,
    }))
end

-- Restores what save_state() stored. `skip_hud` leaves the hotbar alone
-- (leaving players, or a fresh join where the game rebuilds it).
local function restore_state(player, skip_hud)
    local meta = player:get_meta()
    local raw = meta:get_string(META_KEY)
    if raw == "" then return end
    meta:set_string(META_KEY, "")
    local ok, saved = pcall(minetest.parse_json, raw)
    if not ok or type(saved) ~= "table" then return end

    local inv = player:get_inventory()
    local size = inv:get_size("main")
    for i = 1, size do
        inv:set_stack("main", i, ItemStack(saved.main and saved.main[i] or ""))
    end
    local name = player:get_player_name()
    local privs = minetest.get_player_privs(name)
    privs.fly = saved.fly and true or nil
    privs.fast = saved.fast and true or nil
    privs.noclip = saved.noclip and true or nil
    minetest.set_player_privs(name, privs)
    if not skip_hud then
        if tonumber(saved.hotbar) then
            player:hud_set_hotbar_itemcount(tonumber(saved.hotbar))
        end
        if type(saved.image) == "string" and saved.image ~= "" then
            player:hud_set_hotbar_image(saved.image)
        end
    end
end

local function finish(player, is_leaving)
    local name = player:get_player_name()
    local state = editing[name]
    editing[name] = nil
    if state and state.huds and not is_leaving then
        for _, id in ipairs(state.huds) do
            player:hud_remove(id)
        end
    end
    zones.clear_draft(name)
    restore_state(player, is_leaving)
    toolbar.set_suspended(name, false)
    if not is_leaving then
        toolbar.ensure(player)
    end
end

local EDITOR_ITEM_PREFIX = "classrooms_bridge:zone_"

-- Removes editor tools left in a player's inventory outside the editor
-- (e.g. from older versions). Returns true when something was removed.
local function purge_editor_items(player)
    local inv = player:get_inventory()
    if not inv then return false end
    local removed = false
    for _, list in ipairs({ "main", "craft", "offhand" }) do
        for i = 1, inv:get_size(list) do
            if inv:get_stack(list, i):get_name():sub(1, #EDITOR_ITEM_PREFIX) == EDITOR_ITEM_PREFIX then
                inv:set_stack(list, i, "")
                removed = true
            end
        end
    end
    return removed
end

function zone_edit.is_editing(name)
    return editing[name] ~= nil
end

-- ── Mode tools ───────────────────────────────────────────────────────────────

local TOOLS = {
    { id = "point1", desc = "Set point 1", tip = "Marks the first corner where you are" },
    { id = "point2", desc = "Set point 2", tip = "Marks the opposite corner where you are" },
    { id = "teleport", desc = "Set teleport point", tip = "Where players arrive when teleported to this zone" },
    { id = "cancel", desc = "Cancel", tip = "Leave the editor without saving" },
    { id = "confirm", desc = "Confirm", tip = "Save the zone" },
}

local function use_tool(id, user)
    if not user or not user:is_player() then return end
    local name = user:get_player_name()
    local state = editing[name]
    if not state then
        purge_editor_items(user)
        return
    end
    local pos = vector.round(user:get_pos())

    if id == "point1" or id == "point2" then
        local corner = id == "point1" and 1 or 2
        state["p" .. corner] = pos
        zones.mark_corner(user, corner, pos)
    elseif id == "teleport" then
        state.tp = pos
        state.yaw = user:get_look_horizontal()
        zones.mark_teleport(user, pos)
    elseif id == "cancel" then
        finish(user)
        send({ action = "zone_edit_cancelled", player = name }, "zone_edit_cancelled")
        return
    elseif id == "confirm" then
        if not (state.p1 and state.p2) then
            minetest.chat_send_player(name, minetest.colorize("#FFB347",
                "[Zone] Set point 1 and point 2 first."))
            return
        end
        local message = {
            action = "zone_edit_done",
            player = name,
            p1 = state.p1,
            p2 = state.p2,
            tp = state.tp or state.p1,
            yaw = state.yaw or user:get_look_horizontal(),
        }
        finish(user)
        send(message, "zone_edit_done")
        return
    end
    update_hud(user)
end

for _, tool in ipairs(TOOLS) do
    local item = "classrooms_bridge:zone_" .. tool.id
    local texture = "classrooms_bridge_zone_" .. tool.id .. ".png"
    minetest.register_craftitem(item, {
        description = tool.desc .. "\n" .. minetest.colorize("#aaaaaa", tool.tip),
        inventory_image = texture,
        wield_image = texture,
        stack_max = 1,
        range = 0,
        groups = { not_in_creative_inventory = 1 },
        -- Return nothing: Cancel/Confirm restore the inventory inside the
        -- callback, and a returned stack would be written back into the
        -- wielded slot afterwards, leaving the tool behind.
        on_use = function(_, user)
            use_tool(tool.id, user)
        end,
        on_place = function(_, user)
            use_tool(tool.id, user)
        end,
        on_secondary_use = function(_, user)
            use_tool(tool.id, user)
        end,
        on_drop = function(itemstack, dropper)
            if not dropper or not dropper:is_player() or dropper:get_hp() <= 0
                    or not editing[dropper:get_player_name()] then
                return ItemStack("")
            end
            return itemstack
        end,
    })
end

local function fill_tools(player)
    local inv = player:get_inventory()
    for i = 1, inv:get_size("main") do
        local tool = TOOLS[i]
        local stack = ItemStack(tool and ("classrooms_bridge:zone_" .. tool.id) or "")
        if tool then
            -- Changing metadata forces the multiserver proxy to resend the
            -- slot, undoing any client-side drop prediction.
            local current = inv:get_stack("main", i)
            stack:get_meta():set_int("sync", 1 - current:get_meta():get_int("sync"))
        end
        inv:set_stack("main", i, stack)
    end
end

-- ── Start / lifecycle ────────────────────────────────────────────────────────

function zone_edit.start(player, data)
    local name = player:get_player_name()
    if editing[name] then
        finish(player)
    end
    toolbar.set_suspended(name, true)
    save_state(player)

    local privs = minetest.get_player_privs(name)
    privs.fly, privs.fast, privs.noclip = true, true, true
    minetest.set_player_privs(name, privs)

    editing[name] = {
        name = tostring(data.name or "New zone"),
        who = tostring(data.who or "Teachers only"),
    }
    fill_tools(player)
    player:hud_set_hotbar_itemcount(#TOOLS)
    player:hud_set_hotbar_image(MODE_HOTBAR)
    update_hud(player)
    minetest.chat_send_player(name, minetest.colorize("#FFE066",
        "[Zone] Editor on: you can fly through blocks (toggle fly/noclip with K/H)."))
end

minetest.register_allow_player_inventory_action(function(player, action)
    if editing[player:get_player_name()] then
        if action == "take" or action == "move" then
            minetest.after(0, function()
                local current = minetest.get_player_by_name(player:get_player_name())
                if current and editing[current:get_player_name()] then
                    fill_tools(current)
                end
            end)
        end
        return 0
    end
end)

-- Q on a mode tool: the engine already refuses it through on_drop; refresh
-- the slots so the client shows the tool again.
local tick = 0
minetest.register_globalstep(function(dtime)
    tick = tick + dtime
    if tick < 1 then return end
    tick = 0
    for name in pairs(editing) do
        local player = minetest.get_player_by_name(name)
        if player then
            local inv = player:get_inventory()
            for i, tool in ipairs(TOOLS) do
                if inv:get_stack("main", i):get_name() ~= "classrooms_bridge:zone_" .. tool.id then
                    fill_tools(player)
                    break
                end
            end
        end
    end
end)

minetest.register_on_leaveplayer(function(player)
    if editing[player:get_player_name()] then
        finish(player, true)
    end
end)

-- Crash recovery (an editor session that never finished) and cleanup of
-- editor tools left over from older versions.
minetest.register_on_joinplayer(function(player)
    local name = player:get_player_name()
    minetest.after(0.5, function()
        local current = minetest.get_player_by_name(name)
        if not current or editing[name] then return end
        if current:get_meta():get_string(META_KEY) ~= "" then
            -- Inventory and privileges only: the game and the toolbar
            -- rebuild the hotbar on join.
            restore_state(current, true)
        end
        purge_editor_items(current)
    end)
end)

return zone_edit
