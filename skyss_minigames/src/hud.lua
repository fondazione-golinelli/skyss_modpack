local P = ...

-- Per player: a status line at the top (match timer or queue state), a big
-- title in the middle of the screen and a hint line above the hotbar.

local huds = {}  -- [name] = { status = id, status_text, [slot] = { id, token } }

local MESSAGE_SLOTS = {
    title = { position = { x = 0.5, y = 0.3 }, offset = { x = 0, y = 0 }, size = 3 },
    hint = { position = { x = 0.5, y = 1 }, offset = { x = 0, y = -130 }, size = 1.5 },
}

local function state(player)
    local name = player:get_player_name()
    huds[name] = huds[name] or {}
    return huds[name]
end

function P.hud_status(player, text)
    local h = state(player)
    if text == nil or text == "" then
        if h.status then player:hud_remove(h.status) end
        h.status, h.status_text = nil, nil
        return
    end
    if h.status_text == text then return end
    if h.status then
        player:hud_change(h.status, "text", text)
    else
        h.status = player:hud_add({
            [P.hud_type] = "text",
            position = { x = 0.5, y = 0 },
            offset = { x = 0, y = 70 },
            alignment = { x = 0, y = 1 },
            text = text,
            number = 0xffffff,
            size = { x = 2, y = 2 },
            style = 1,
            z_index = 100,
        })
    end
    h.status_text = text
end

-- slot: "title" or "hint".
function P.hud_message(player, slot, text, seconds, color)
    local h = state(player)
    local layout = MESSAGE_SLOTS[slot]
    if h[slot] then player:hud_remove(h[slot].id) end
    local entry = {
        id = player:hud_add({
            [P.hud_type] = "text",
            position = layout.position,
            offset = layout.offset,
            alignment = { x = 0, y = 0 },
            text = text,
            number = color or 0xffffff,
            size = { x = layout.size, y = layout.size },
            style = 1,
            z_index = 100,
        }),
    }
    h[slot] = entry
    local name = player:get_player_name()
    core.after(seconds or 3, function()
        local current = huds[name]
        local p = core.get_player_by_name(name)
        if current and current[slot] == entry and p then
            p:hud_remove(entry.id)
            current[slot] = nil
        end
    end)
end

function P.hud_title(player, text, seconds, color)
    P.hud_message(player, "title", text, seconds, color)
end

function P.hud_clear(player)
    local name = player:get_player_name()
    local h = huds[name]
    if not h then return end
    if h.status then player:hud_remove(h.status) end
    for slot in pairs(MESSAGE_SLOTS) do
        if h[slot] then player:hud_remove(h[slot].id) end
    end
    huds[name] = nil
end

core.register_on_leaveplayer(function(player)
    huds[player:get_player_name()] = nil
end)
