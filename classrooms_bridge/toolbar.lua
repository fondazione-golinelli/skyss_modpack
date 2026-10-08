-- Dedicated hotbar slots for classroom tools (Class Panel, BlockExchange).
--
-- Luanti can only wield items from the "main" list and the hotbar always shows
-- main[1..N], so tools cannot live in a separate list. Instead the hotbar is
-- extended past whatever size the game or another mod set (Mineclonia: 9,
-- hub lobby: its item count) and the tools occupy the extra slots. Slots
-- 1..N stay free for game items and arena_lib tools.
--
-- While arena_lib owns the player's inventory (editor or match) the toolbar is
-- suspended; arena_lib restores the extended hotbar when it hands it back.

local SLOT_TEXTURES = {
    mcl = {
        base = "mcl_inventory_hotbar.png",
        base_slots = 9,
        pitch = 20,
        height = 22,
        slot = "classrooms_bridge_hotbar_slot_mcl.png",
        first = "classrooms_bridge_hotbar_slot_mcl_first.png",
    },
    arena_lib = {
        pitch = 37,
        height = 39,
        slot = "classrooms_bridge_hotbar_slot_al.png",
        first = "classrooms_bridge_hotbar_slot_al_first.png",
    },
}
local MAX_HOTBAR = 32

local toolbar = {}
local tools = {}        -- { {id, item, order} }, sorted by order
local tool_by_item = {}
local players = {}      -- [name] = { enabled = {[id]=true}, base_count, base_image, applied_count, applied_image }

function toolbar.register_tool(id, item, order)
    local def = { id = id, item = item, order = order }
    table.insert(tools, def)
    table.sort(tools, function(a, b) return a.order < b.order end)
    tool_by_item[item] = def
end

local function is_suspended(name)
    return minetest.global_exists("arena_lib")
        and ((arena_lib.is_player_in_edit_mode and arena_lib.is_player_in_edit_mode(name))
            or (arena_lib.is_player_in_arena and arena_lib.is_player_in_arena(name)))
end

local function active_tools(state)
    local list = {}
    for _, def in ipairs(tools) do
        if state.enabled[def.id] then
            table.insert(list, def)
        end
    end
    return list
end

-- Append highlighted tool slots to a known hotbar background. Unknown
-- backgrounds are kept as-is (the engine stretches them over the slots).
local function hotbar_image(base_image, base_count, extra)
    local style, slots
    if base_image == SLOT_TEXTURES.mcl.base and base_count == SLOT_TEXTURES.mcl.base_slots then
        style, slots = SLOT_TEXTURES.mcl, base_count
    else
        local n = tonumber(base_image:match("^arenalib_gui_hotbar(%d+)%.png$") or "")
        if n and n == base_count then
            style, slots = SLOT_TEXTURES.arena_lib, n
        end
    end
    if not style then
        return base_image
    end

    local parts = {
        string.format("[combine:%dx%d", style.pitch * (slots + extra) + 2, style.height),
        "0,0=" .. base_image,
    }
    for i = 0, extra - 1 do
        table.insert(parts, string.format("%d,0=%s", style.pitch * (slots + i),
            i == 0 and style.first or style.slot))
    end
    return table.concat(parts, ":")
end

local function remove_item_everywhere(inv, item)
    for index = 1, inv:get_size("main") do
        if inv:get_stack("main", index):get_name() == item then
            inv:set_stack("main", index, "")
        end
    end
end

local function restore_hotbar(player, state)
    if state.applied_count
            and player:hud_get_hotbar_itemcount() == state.applied_count then
        player:hud_set_hotbar_itemcount(state.base_count)
        if state.base_image then
            player:hud_set_hotbar_image(state.base_image)
        end
    end
    state.applied_count = nil
    state.applied_image = nil
end

local function sync(player)
    local name = player:get_player_name()
    local state = players[name]
    if not state or is_suspended(name) then return end

    local inv = player:get_inventory()
    if not inv then return end
    local active = active_tools(state)
    if #active == 0 then
        restore_hotbar(player, state)
        return
    end

    -- Anything other than our own value means a game/mod (re)defined the
    -- hotbar: treat it as the new base and append the tools after it.
    local count = player:hud_get_hotbar_itemcount()
    if count ~= state.applied_count then
        state.base_count = count
        state.base_image = player:hud_get_hotbar_image()
    end

    local size = inv:get_size("main")
    local wanted = state.base_count + #active
    if wanted > size or wanted > MAX_HOTBAR then
        minetest.log("warning", "[classrooms_bridge] No room for tool slots for " .. name
            .. " (hotbar " .. state.base_count .. ", main " .. size .. ")")
        return
    end

    local displaced = {}
    for i, def in ipairs(active) do
        local slot = state.base_count + i
        local current = inv:get_stack("main", slot)
        if current:get_name() ~= def.item then
            local found
            for index = 1, size do
                if index ~= slot and inv:get_stack("main", index):get_name() == def.item then
                    found = index
                    break
                end
            end
            if found then
                inv:set_stack("main", found, current)
            elseif not current:is_empty() then
                table.insert(displaced, current)
            end
            inv:set_stack("main", slot, ItemStack(def.item))
        elseif current:get_count() ~= 1 then
            inv:set_stack("main", slot, ItemStack(def.item))
        end
    end

    -- Drop duplicates outside the dedicated slots (e.g. restored inventories).
    for index = 1, size do
        local def = tool_by_item[inv:get_stack("main", index):get_name()]
        if def then
            local expected
            for i, active_def in ipairs(active) do
                if active_def == def then expected = state.base_count + i end
            end
            if index ~= expected then
                inv:set_stack("main", index, "")
            end
        end
    end

    for _, stack in ipairs(displaced) do
        local leftover = inv:add_item("main", stack)
        if not leftover:is_empty() then
            minetest.add_item(player:get_pos(), leftover)
        end
    end

    if player:hud_get_hotbar_itemcount() ~= wanted then
        player:hud_set_hotbar_itemcount(wanted)
    end
    state.applied_count = wanted

    local image = hotbar_image(state.base_image or "", state.base_count, #active)
    if image ~= "" and player:hud_get_hotbar_image() ~= image then
        player:hud_set_hotbar_image(image)
    end
    state.applied_image = image
end

function toolbar.set_enabled(player, id, enabled)
    if not player or not player:is_player() then return end
    local name = player:get_player_name()
    local state = players[name]

    if enabled then
        if not state then
            state = { enabled = {} }
            players[name] = state
        end
        state.enabled[id] = true
    elseif state then
        state.enabled[id] = nil
    end

    if not enabled then
        local inv = player:get_inventory()
        for _, def in ipairs(tools) do
            if def.id == id and inv then
                remove_item_everywhere(inv, def.item)
            end
        end
    end

    if state then
        sync(player)
        if not next(state.enabled) then
            players[name] = nil
        end
    end
end

function toolbar.ensure(player)
    if player then sync(player) end
end

function toolbar.clear_player(name)
    players[name] = nil
end

-- True when (list, index) is one of the player's dedicated tool slots.
function toolbar.is_tool_slot(name, list, index)
    local state = players[name]
    if not state or not state.applied_count or list ~= "main" or is_suspended(name) then
        return false
    end
    return index > state.base_count and index <= state.applied_count
end

-- The client removes a dropped item locally before the server answers. The
-- server's undo resends an unchanged stack, which the multiserver proxy diffs
-- away, so the slot looks empty while the tool is still there. Touching the
-- tool stacks' metadata makes the proxy send them again.
local function resend_tools(name)
    local player = minetest.get_player_by_name(name)
    local state = players[name]
    if not player or not state or not state.applied_count then return end

    local inv = player:get_inventory()
    for index = state.base_count + 1, state.applied_count do
        local stack = inv:get_stack("main", index)
        if tool_by_item[stack:get_name()] then
            local meta = stack:get_meta()
            meta:set_int("classrooms_sync", (meta:get_int("classrooms_sync") + 1) % 2)
            inv:set_stack("main", index, stack)
        end
    end
end

-- Classroom tools must never leave the inventory. On death Mineclonia passes
-- each stack through on_drop and spawns the result, so return nothing then;
-- the toolbar puts the tool back after respawn.
function toolbar.on_drop(itemstack, dropper)
    if not dropper or not dropper:is_player() then
        return itemstack
    end
    if dropper:get_hp() <= 0 then
        return ItemStack("")
    end
    local name = dropper:get_player_name()
    minetest.after(0, resend_tools, name)
    return itemstack
end

-- Refusing here also covers Q on a tool: the engine rejects the "take" before
-- on_drop runs, so the resend is scheduled from both places.
minetest.register_allow_player_inventory_action(function(player, action, _, info)
    local name = player:get_player_name()
    local locked
    if action == "move" then
        locked = toolbar.is_tool_slot(name, info.from_list, info.from_index)
            or toolbar.is_tool_slot(name, info.to_list, info.to_index)
    elseif action == "put" or action == "take" then
        locked = toolbar.is_tool_slot(name, info.listname, info.index)
    end
    if locked then
        minetest.after(0, resend_tools, name)
        return 0
    end
end)

-- Stale tools from a previous session are re-granted by the proxy if still
-- authorised.
minetest.register_on_joinplayer(function(player)
    local inv = player:get_inventory()
    if not inv then return end
    for _, def in ipairs(tools) do
        remove_item_everywhere(inv, def.item)
    end
end)

minetest.register_on_respawnplayer(function(player)
    local name = player:get_player_name()
    minetest.after(0, function()
        local current = minetest.get_player_by_name(name)
        if current then sync(current) end
    end)
end)

minetest.register_on_leaveplayer(function(player)
    players[player:get_player_name()] = nil
end)

local timer = 0
minetest.register_globalstep(function(dtime)
    timer = timer + dtime
    if timer < 1 then return end
    timer = 0

    for name in pairs(players) do
        local player = minetest.get_player_by_name(name)
        if player then
            sync(player)
        end
    end
end)

return toolbar
