-- Teacher guide: a handbook for class staff, in a dedicated toolbar slot.
--
-- Chapters and pages come from guide_pages.lua. Each page has a title, an
-- optional figure drawn with formspec elements (keyboard, farm, panel
-- sketch, item and picture strips) and a scrolling hypertext body. Texts are
-- translated here, on the server, so they can be escaped for hypertext.
--
-- The proxy prefixes texture names everywhere in a formspec but item names
-- only inside item_image[], so game items are drawn as item_image elements in
-- the figures, never as <item> tags in the hypertext.

local modpath, toolbar, is_staff = ...

local S = minetest.get_translator("classrooms_bridge")
local G = minetest.get_translator("classrooms_guide")

local FORM = "classrooms_bridge:guide"
local ITEM = "classrooms_bridge:guide"
local TOOL = "guide"
local PAGE_META = "classrooms_bridge:guide_page"

local W, H = 18.5, 11.6
local SIDE_W = 5.0
local CX = 0.25 + SIDE_W + 0.25
local CW = W - CX - 0.25
local C = { bg = "#141a2a", header = "#0f3460", accent = "#e94560", card = "#202a44", row = "#28334f",
    button = "#34446a", primary = "#2a8c7f", danger = "#9b2c3c", muted = "#aaaaaa", light = "#f0f0f0",
    lit = "#4a5a8a", lit_edge = "#ffd43b", gold = "#ffd43b", teal = "#7fd6c8", tip = "#3cc4b0",
    key = "#2c3654", key_text = "#8a93ad", key_lit = "#ffd43b", key_lit_text = "#141a2a" }

-- ── Pages ────────────────────────────────────────────────────────────────────

local chapters = dofile(modpath .. "/guide_pages.lua")
local pages, page_by_id = {}, {}
for _, chapter in ipairs(chapters) do
    for _, page in ipairs(chapter.pages) do
        page.chapter = chapter
        table.insert(pages, page)
        page.index = #pages
        page_by_id[page.id] = page
    end
end
for _, page in ipairs(pages) do
    for _, block in ipairs(page.body) do
        if block[1] == "links" then
            for _, id in ipairs(block[2]) do
                assert(page_by_id[id], "[classrooms_bridge] guide: unknown page " .. id)
            end
        end
    end
end

-- ── Helpers ──────────────────────────────────────────────────────────────────

local function translate_for(name, text)
    local info = minetest.get_player_information(name)
    return minetest.get_translated_string(info and info.lang_code or "", text)
end

local function esc(s) return minetest.formspec_escape(tostring(s)) end

local function hesc(s)
    return (tostring(s):gsub("[\\<>]", { ["\\"] = "\\\\", ["<"] = "\\<", [">"] = "\\>" }))
end

-- The item itself when the game has it (aliases resolved), else nil.
local function known_item(item)
    item = minetest.registered_aliases[item] or item
    return minetest.registered_items[item] and item or nil
end

-- A decorative button (figures): the click is ignored. The text shrinks to
-- fit the width (about 0.16 units per character at normal size).
local deco_count = 0
local function deco_button(fs, x, y, w, h, text, bg, fg, scale)
    deco_count = deco_count + 1
    local id = "fig_" .. deco_count
    local chars = select(2, text:gsub("[^\128-\191]", ""))
    local fit = (w - 0.12) / (math.max(chars, 1) * 0.16)
    scale = math.max(0.55, math.min(scale or 0.8, fit))
    table.insert(fs, ("style[%s;bgcolor=%s;textcolor=%s;border=false;font_size=*%.2f]button[%g,%g;%g,%g;%s;%s]"):format(
        id, bg, fg or C.light, scale, x, y, w, h, id, esc(text)))
end

-- Centered, wrapping caption.
local function caption(fs, x, y, w, h, text, color, size)
    deco_count = deco_count + 1
    table.insert(fs, ("hypertext[%g,%g;%g,%g;cap_%d;%s]"):format(x, y, w, h, deco_count,
        esc(("<global background=none margin=0 halign=center valign=top size=%d color=%s>%s"):format(
            size or 14, color or C.light, hesc(text)))))
end

local function box(fs, x, y, w, h, color)
    table.insert(fs, ("box[%g,%g;%g,%g;%s]"):format(x, y, w, h, color))
end

local function label(fs, x, y, text, color)
    table.insert(fs, ("label[%g,%g;%s]"):format(x, y, esc(minetest.colorize(color or C.light, text))))
end

-- ── Figures ──────────────────────────────────────────────────────────────────
-- Each draws into the area (x, y, w, h); tr translates for the player.

local figures = {}

local KEYBOARD = {
    { y = 0, keys = { { "Esc", 0 }, { "F1", 1.5 }, { "F2", 2.5 }, { "F3", 3.5 }, { "F4", 4.5 },
        { "F5", 6 }, { "F6", 7 }, { "F7", 8 }, { "F8", 9 }, { "F9", 10.5 }, { "F10", 11.5 },
        { "F11", 12.5 }, { "F12", 13.5 } } },
    { y = 1.15, keys = { { "1", 1 }, { "2", 2 }, { "3", 3 }, { "4", 4 }, { "5", 5 }, { "6", 6 },
        { "7", 7 }, { "8", 8 }, { "9", 9 }, { "0", 10 }, { "-", 11 }, { "+", 12 } } },
    { y = 2.15, keys = { { "Q", 1.5 }, { "W", 2.5 }, { "E", 3.5 }, { "R", 4.5 }, { "T", 5.5 },
        { "Y", 6.5 }, { "U", 7.5 }, { "I", 8.5 }, { "O", 9.5 }, { "P", 10.5 } } },
    { y = 3.15, keys = { { "A", 1.75 }, { "S", 2.75 }, { "D", 3.75 }, { "F", 4.75 }, { "G", 5.75 },
        { "H", 6.75 }, { "J", 7.75 }, { "K", 8.75 }, { "L", 9.75 } } },
    { y = 4.15, keys = { { "Shift", 0, 2.2 }, { "Z", 2.3 }, { "X", 3.3 }, { "C", 4.3 }, { "V", 5.3 },
        { "B", 6.3 }, { "N", 7.3 }, { "M", 8.3 }, { ",", 9.3 }, { ".", 10.3 }, { "/", 11.3 } } },
    { y = 5.15, keys = { { "Space", 4, 6 } } },
}

function figures.keyboard(fs, x, y, w, h, fig, tr)
    local lit = {}
    for _, key in ipairs(fig.keys or {}) do lit[key] = true end
    local unit = 0.56
    local labels = { Space = tr(G("Space")), Shift = tr(G("Shift")) }
    for _, row in ipairs(KEYBOARD) do
        for _, key in ipairs(row.keys) do
            local id, col, span = key[1], key[2], key[3] or 1
            local on = lit[id]
            deco_button(fs, x + col * unit, y + row.y * unit, span * unit - 0.06, unit - 0.06,
                labels[id] or id, on and C.key_lit or C.key, on and C.key_lit_text or C.key_text,
                on and 0.85 or 0.7)
        end
    end

    local mouse = fig.mouse
    if not mouse then return end
    local mx, my, mw, mh = x + 15.2 * unit, y + 0.15, 1.5, 2.6
    box(fs, mx, my, mw, mh, C.key)
    box(fs, mx, my, mw / 2 - 0.03, 1.0, mouse.left and C.key_lit or C.row)
    box(fs, mx + mw / 2 + 0.03, my, mw / 2 - 0.03, 1.0, mouse.right and C.key_lit or C.row)
    box(fs, mx + mw / 2 - 0.12, my + 0.2, 0.24, 0.55, mouse.wheel and C.accent or C.key_text)
    local lines = {}
    if mouse.left then table.insert(lines, { G("Left click"), C.gold }) end
    if mouse.right then table.insert(lines, { G("Right click"), C.gold }) end
    if mouse.wheel then table.insert(lines, { G("Wheel"), C.accent }) end
    for i, line in ipairs(lines) do
        label(fs, mx + mw + 0.25, my + 0.25 + (i - 1) * 0.45, tr(line[1]), line[2])
    end
end

-- A 9×9 field with water in the middle, then the steps as item pictures.
function figures.farm(fs, x, y, w, h, fig, tr)
    local cell = 0.38
    box(fs, x, y, 9 * cell + 0.2, 9 * cell + 0.2, "#3f6b2a")
    for row = 0, 8 do
        for col = 0, 8 do
            local cx, cy = x + 0.1 + col * cell, y + 0.1 + row * cell
            if row == 4 and col == 4 then
                box(fs, cx, cy, cell - 0.04, cell - 0.04, "#3a6fd8")
            else
                box(fs, cx, cy, cell - 0.04, cell - 0.04, "#5b3a1f")
                box(fs, cx + 0.09, cy + 0.09, cell - 0.22, cell - 0.22,
                    (row + col) % 3 == 0 and "#d8b847" or "#7fbf3f")
            end
        end
    end
    -- Reach of the water: from the middle to the edge.
    local mid = y + 0.1 + 4.5 * cell - 0.02
    box(fs, x + 0.1 + 5 * cell, mid - 0.03, 4 * cell - 0.04, 0.06, C.light)
    caption(fs, x, y + 9 * cell + 0.3, 9 * cell + 0.2, 0.5, tr(G("Water reaches 4 blocks")), C.light, 13)

    local steps = {
        { "mcl_farming:hoe_stone", G("Hoe") },
        { "mcl_buckets:bucket_water", G("Water") },
        { "mcl_farming:wheat_seeds", G("Seeds") },
        { "mcl_torches:torch", G("Light") },
        { "mcl_bone_meal:bone_meal", G("Bone meal") },
        { "mcl_farming:wheat_item", G("Harvest") },
    }
    local sx = x + 9 * cell + 0.7
    local pitch = math.min(1.55, (x + w - sx) / #steps)
    for i, step in ipairs(steps) do
        local ix = sx + (i - 1) * pitch
        box(fs, ix, y + 0.5, 1.15, 1.15, C.row)
        local item = known_item(step[1])
        if item then
            table.insert(fs, ("item_image[%g,%g;0.95,0.95;%s]"):format(ix + 0.1, y + 0.6, item))
        end
        caption(fs, ix - 0.15, y + 1.75, 1.45, 0.9, tr(step[2]), C.light, 13)
        if i < #steps then
            label(fs, ix + 1.2, y + 1.07, "►", C.gold)
        end
    end
end

-- A strip of game items with captions.
function figures.items(fs, x, y, w, h, fig, tr)
    for i, entry in ipairs(fig.items) do
        local ix = x + (i - 1) * 1.9
        box(fs, ix + 0.3, y + 0.05, 1.25, 1.25, C.row)
        local item = known_item(entry[1])
        if item then
            table.insert(fs, ("item_image[%g,%g;1.05,1.05;%s]"):format(ix + 0.4, y + 0.15, item))
        end
        caption(fs, ix, y + 1.4, 1.85, 0.6, tr(entry[2]), C.light, 13)
    end
end

-- A strip of pictures (textures) with captions.
function figures.images(fs, x, y, w, h, fig, tr)
    for i, entry in ipairs(fig.images) do
        local ix = x + (i - 1) * 2.0
        box(fs, ix + 0.3, y + 0.05, 1.35, 1.35, C.row)
        table.insert(fs, ("image[%g,%g;1.15,1.15;%s]"):format(ix + 0.4, y + 0.15, esc(entry[1])))
        caption(fs, ix, y + 1.5, 1.95, 0.6, tr(entry[2]), C.light, 13)
    end
end

-- The hotbar: free slots 1-9, then the staff tools.
function figures.toolbar(fs, x, y, w, h, fig, tr)
    local slot, pitch = 0.8, 0.86
    local tools = { "classrooms_bridge_class_panel.png", "classrooms_bridge_blockexchange.png",
        "classrooms_bridge_world_tools.png", "classrooms_bridge_guide.png" }
    caption(fs, x, y, 9 * pitch, 0.45, tr(G("Slots 1-9: blocks and items")), C.muted, 13)
    caption(fs, x + 9 * pitch, y, #tools * pitch + 0.2, 0.45, tr(G("Staff tools")), C.gold, 13)
    for i = 1, 9 + #tools do
        local sx = x + (i - 1) * pitch + (i > 9 and 0.2 or 0)
        local tool = tools[i - 9]
        if tool then
            box(fs, sx - 0.04, y + 0.51, slot + 0.08, slot + 0.08, C.gold)
        end
        box(fs, sx, y + 0.55, slot, slot, tool and C.lit or C.row)
        if tool then
            table.insert(fs, ("image[%g,%g;%g,%g;%s]"):format(sx + 0.1, y + 0.65, slot - 0.2, slot - 0.2, tool))
        else
            label(fs, sx + 0.08, y + 0.72, tostring(i), C.key_text)
        end
    end
end

-- A sketch of the class view with numbered parts and their legend.
function figures.class_view(fs, x, y, w, h, fig, tr)
    local fw, fh = 9.0, 4.2
    box(fs, x, y, fw, fh, C.bg)
    box(fs, x, y, fw, 0.55, C.header)
    box(fs, x, y + 0.55, fw, 0.03, C.accent)
    label(fs, x + 0.2, y + 0.28, tr(G("3B Science")))
    deco_button(fs, x + 4.6, y + 0.1, 2.0, 0.36, tr(G("Minigames")), C.primary)
    deco_button(fs, x + 6.75, y + 0.1, 2.1, 0.36, tr(G("Return to HUB")), C.danger)

    -- Left: live controls and students.
    box(fs, x + 0.1, y + 0.7, 4.4, 3.4, C.card)
    label(fs, x + 0.25, y + 0.92, tr(G("LIVE CONTROLS")), C.muted)
    local tiles = { G("Freeze"), G("Bring here"), G("Look at me") }
    for i, text in ipairs(tiles) do
        deco_button(fs, x + 0.25 + (i - 1) * 1.4, y + 1.15, 1.3, 0.55, tr(text), i == 1 and "#c77a2a" or C.button)
    end
    label(fs, x + 0.25, y + 2.0, tr(G("STUDENTS")), C.muted)
    deco_button(fs, x + 2.05, y + 1.83, 2.3, 0.34, tr(G("Manage people")), C.button)
    local students = { "Anna", "Luca", "Sara" }
    for i, student in ipairs(students) do
        local ry = y + 2.3 + (i - 1) * 0.55
        box(fs, x + 0.25, ry, 4.1, 0.45, C.row)
        box(fs, x + 0.38, ry + 0.15, 0.15, 0.15, i < 3 and "#5fd36a" or C.key_text)
        label(fs, x + 0.65, ry + 0.22, student)
        box(fs, x + 3.4, ry + 0.08, 0.3, 0.3, C.button)
        box(fs, x + 3.85, ry + 0.08, 0.3, 0.3, C.button)
    end

    -- Right: the world you are in and the class worlds.
    box(fs, x + 4.6, y + 0.7, 4.3, 3.4, C.card)
    box(fs, x + 4.7, y + 0.8, 4.1, 1.25, C.lit)
    box(fs, x + 4.7, y + 0.8, 0.06, 1.25, C.lit_edge)
    label(fs, x + 4.9, y + 1.02, tr(G("YOU ARE IN THIS WORLD")), C.gold)
    local world_buttons = { G("Rules"), G("Time & weather"), G("Tools") }
    local bx = x + 4.85
    for i, text in ipairs(world_buttons) do
        local bw = i == 2 and 1.6 or 1.1
        deco_button(fs, bx, y + 1.45, bw, 0.4, tr(text), C.button, nil, 0.7)
        bx = bx + bw + 0.08
    end
    label(fs, x + 4.75, y + 2.3, tr(G("CLASS WORLDS")), C.muted)
    for i = 1, 2 do
        local ry = y + 2.5 + (i - 1) * 0.55
        box(fs, x + 4.7, ry, 4.1, 0.45, C.row)
        label(fs, x + 4.85, ry + 0.22, tr(G("World")) .. " " .. i)
        deco_button(fs, x + 6.6, ry + 0.06, 0.9, 0.33, tr(G("Join")), C.primary, nil, 0.7)
        deco_button(fs, x + 7.55, ry + 0.06, 1.15, 0.33, tr(G("Bring class")), C.button, nil, 0.7)
    end
    deco_button(fs, x + 4.7, y + 3.65, 4.1, 0.35, tr(G("+ New class world")), C.primary)

    -- Numbered parts and their legend.
    local marks = {
        { 0.05, 0.95, G("Live controls for the online students") },
        { 0.05, 2.0, G("Students and Manage people") },
        { 4.55, 1.0, G("The world you are in: rules, time, tools") },
        { 4.55, 2.3, G("Class worlds: Join, Bring class, settings") },
        { 4.4, 0.05, G("Minigames and Return to HUB") },
    }
    for i, mark in ipairs(marks) do
        deco_button(fs, x + mark[1], y + mark[2] - 0.2, 0.36, 0.36, tostring(i), C.accent, C.light, 0.75)
        local ly = y + 0.1 + (i - 1) * 0.8
        deco_button(fs, x + fw + 0.3, ly, 0.36, 0.36, tostring(i), C.accent, C.light, 0.75)
        caption(fs, x + fw + 0.75, ly - 0.02, w - fw - 0.8, 0.8, tr(mark[3]), C.light, 13)
    end
end

-- The zone editor hotbar.
function figures.zone_editor(fs, x, y, w, h, fig, tr)
    local tools = {
        { "classrooms_bridge_zone_point1.png", G("Set point 1") },
        { "classrooms_bridge_zone_point2.png", G("Set point 2") },
        { "classrooms_bridge_zone_teleport.png", G("Set teleport point") },
        { "classrooms_bridge_zone_cancel.png", G("Cancel") },
        { "classrooms_bridge_zone_confirm.png", G("Confirm") },
    }
    for i, tool in ipairs(tools) do
        local ix = x + (i - 1) * 2.3
        box(fs, ix + 0.5, y + 0.05, 1.2, 1.2, C.row)
        table.insert(fs, ("image[%g,%g;1.0,1.0;%s]"):format(ix + 0.6, y + 0.15, tool[1]))
        caption(fs, ix, y + 1.35, 2.2, 0.8, tr(tool[2]), C.light, 13)
    end
end

-- The three steps of Find & place.
function figures.bx_steps(fs, x, y, w, h, fig, tr)
    table.insert(fs, ("image[%g,%g;1.3,1.3;classrooms_bridge_blockexchange.png]"):format(x, y + 0.3))
    local steps = { G("Pick a structure"), G("Set start here"), G("Check the space, then Build here") }
    local bw = 3.2
    for i, text in ipairs(steps) do
        local bx = x + 1.7 + (i - 1) * (bw + 0.55)
        box(fs, bx, y + 0.1, bw, 1.8, C.card)
        box(fs, bx, y + 0.1, bw, 0.06, C.gold)
        caption(fs, bx, y + 0.25, bw, 0.55, tostring(i), C.gold, 22)
        caption(fs, bx + 0.1, y + 0.85, bw - 0.2, 1.0, tr(text), C.light, 14)
        if i < #steps then
            label(fs, bx + bw + 0.15, y + 1.0, "►", C.gold)
        end
    end
end

-- ── Body (hypertext) ─────────────────────────────────────────────────────────

local function body_text(page, tr)
    local out = { "<global background=none margin=12 valign=top color=#e6e9f2 hovercolor=" .. C.gold .. ">",
        "<tag name=action color=#6fb8ff hovercolor=" .. C.gold .. ">" }
    local function add(s) table.insert(out, s) end
    local function t(s) return hesc(tr(s)) end
    for _, block in ipairs(page.body) do
        local kind, value = block[1], block[2]
        if kind == "h" then
            add("<big><b><style color=" .. C.gold .. ">" .. t(value) .. "</style></b></big>\n")
        elseif kind == "p" then
            add(t(value) .. "\n\n")
        elseif kind == "steps" then
            for i, step in ipairs(value) do
                add("<style color=" .. C.gold .. "><b>" .. i .. ".</b></style>  " .. t(step) .. "\n")
            end
            add("\n")
        elseif kind == "keys" then
            for _, row in ipairs(value) do
                add("<mono><b><style color=" .. C.gold .. ">[ " .. t(row[1]) .. " ]</style></b></mono>  "
                    .. t(row[2]) .. "\n")
            end
            add("\n")
        elseif kind == "defs" then
            for _, row in ipairs(value) do
                add("<b><style color=" .. C.teal .. ">" .. t(row[1]) .. "</style></b>  —  " .. t(row[2]) .. "\n")
            end
            add("\n")
        elseif kind == "imgs" then
            for _, row in ipairs(value) do
                add("<img name=" .. row[1] .. " width=32 height=32>  " .. t(row[2]) .. "\n")
            end
            add("\n")
        elseif kind == "tip" then
            add("<style color=" .. C.tip .. "><b>" .. t(G("Tip:")) .. "</b></style> " .. t(value) .. "\n\n")
        elseif kind == "links" then
            for _, id in ipairs(value) do
                add("<action name=go_" .. id .. ">► " .. t(page_by_id[id].title) .. "</action>\n")
            end
            add("\n")
        end
    end
    return table.concat(out)
end

-- ── Formspec ─────────────────────────────────────────────────────────────────

local current = {}   -- [name] = page

local function show(player)
    local name = player:get_player_name()
    local page = current[name] or page_by_id[player:get_meta():get_string(PAGE_META)] or pages[1]
    current[name] = page
    local tr = function(text) return translate_for(name, text) end
    deco_count = 0

    local fs = {
        ("formspec_version[6]size[%g,%g]"):format(W, H),
        "bgcolor[" .. C.bg .. ";true]",
        ("box[0,0;%g,%g;%s]"):format(W, H, C.bg),
        "style_type[button;bgcolor=" .. C.button .. ";border=false;textcolor=" .. C.light .. "]",
        "style_type[label;textcolor=" .. C.light .. "]",
        ("box[0,0;%g,1.0;%s]box[0,1.0;%g,0.05;%s]"):format(W, C.header, W, C.accent),
        "image[0.3,0.17;0.66,0.66;classrooms_bridge_guide.png]",
        ("hypertext[1.15,0.1;%g,0.8;guide_title;%s]"):format(W - 4.2,
            esc("<global background=none margin=0 valign=middle size=22 color=" .. C.light .. "><b>"
                .. hesc(tr(G("Teacher guide"))) .. "</b>")),
        ("style[guide_close;bgcolor=%s]button_exit[%g,0.2;2.4,0.6;guide_close;%s]"):format(
            C.danger, W - 2.7, esc(tr(G("Close")))),
    }

    -- Sidebar: chapters; the open one lists its pages. Hypertext links wrap
    -- long titles instead of cutting them.
    box(fs, 0.25, 1.25, SIDE_W, H - 1.5, C.card)
    local nav = { "<global background=none margin=12 valign=top color=" .. C.light .. " hovercolor=" .. C.gold .. ">",
        "<tag name=action color=#dfe4ef hovercolor=" .. C.gold .. ">" }
    for i, chapter in ipairs(chapters) do
        local title = hesc(i .. "  " .. tr(chapter.title))
        if chapter == page.chapter then
            table.insert(nav, "<b><style color=" .. C.gold .. ">" .. title .. "</style></b>\n")
            for _, p in ipairs(chapter.pages) do
                if p == page then
                    table.insert(nav, "<style size=15 color=" .. C.gold .. "><b>► " .. hesc(tr(p.title)) .. "</b></style>\n")
                else
                    table.insert(nav, "<style size=15 color=#b8c0d4>• </style><style size=15><action name=pg_"
                        .. p.id .. ">" .. hesc(tr(p.title)) .. "</action></style>\n")
                end
            end
        else
            table.insert(nav, "<b><action name=ch_" .. chapter.id .. ">" .. title .. "</action></b>\n")
        end
        table.insert(nav, "<style size=7>\n</style>")
    end
    table.insert(fs, ("hypertext[0.25,1.3;%g,%g;guide_nav;%s]"):format(SIDE_W, H - 1.6, esc(table.concat(nav))))

    -- Page title, figure and text.
    table.insert(fs, ("hypertext[%g,1.2;%g,0.8;guide_page_title;%s]"):format(CX, CW,
        esc("<global background=none margin=6 valign=middle size=22 color=" .. C.gold .. "><b>"
            .. hesc(tr(page.title)) .. "</b>")))
    local body_y = 2.05
    if page.figure then
        local fig = page.figure
        figures[fig[1]](fs, CX + 0.15, body_y, CW - 0.3, fig.h, fig, tr)
        body_y = body_y + fig.h + 0.15
    end
    local footer_y = H - 0.85
    box(fs, CX, body_y, CW, footer_y - 0.15 - body_y, C.card)
    table.insert(fs, ("hypertext[%g,%g;%g,%g;guide_body;%s]"):format(CX, body_y, CW,
        footer_y - 0.15 - body_y, esc(body_text(page, tr))))

    -- Footer: previous, position, next.
    if page.index > 1 then
        table.insert(fs, ("button[%g,%g;3.2,0.6;guide_prev;%s]"):format(CX, footer_y, esc("◄ " .. tr(G("Previous")))))
    end
    caption(fs, CX + 3.4, footer_y + 0.12, CW - 6.8, 0.5,
        tr(G("Page @1 of @2", page.index, #pages)), C.muted, 14)
    if page.index < #pages then
        table.insert(fs, ("style[guide_next;bgcolor=%s]button[%g,%g;3.2,0.6;guide_next;%s]"):format(
            C.primary, CX + CW - 3.2, footer_y, esc(tr(G("Next")) .. " ►")))
    end

    minetest.show_formspec(name, FORM, table.concat(fs))
end

local function go(player, page)
    if not page then return end
    current[player:get_player_name()] = page
    player:get_meta():set_string(PAGE_META, page.id)
    show(player)
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= FORM then return end
    if fields.quit or fields.guide_close then return true end
    local page = current[player:get_player_name()] or pages[1]
    local action = (fields.guide_body or fields.guide_nav or ""):match("^action:(.+)$") or ""
    local kind, id = action:match("^(%a+)_(.+)$")
    if fields.guide_prev then
        go(player, pages[page.index - 1])
    elseif fields.guide_next then
        go(player, pages[page.index + 1])
    elseif kind == "go" or kind == "pg" then
        go(player, page_by_id[id])
    elseif kind == "ch" then
        for _, chapter in ipairs(chapters) do
            if chapter.id == id then go(player, chapter.pages[1]) end
        end
    end
    return true
end)

minetest.register_on_leaveplayer(function(player)
    current[player:get_player_name()] = nil
end)

-- ── Item ─────────────────────────────────────────────────────────────────────

local function open_guide(user)
    if not user or not user:is_player() or not is_staff(user:get_player_name()) then return end
    show(user)
end

minetest.register_craftitem(ITEM, {
    description = S("Teacher guide") .. "\n" .. minetest.colorize("#aaaaaa",
        S("Use to read the handbook: controls, game basics and the class panel")),
    inventory_image = "classrooms_bridge_guide.png",
    wield_image = "classrooms_bridge_guide.png",
    range = 0,
    stack_max = 1,
    groups = { not_in_creative_inventory = 1 },
    on_place = function(itemstack, placer) open_guide(placer) return itemstack end,
    on_use = function(itemstack, user) open_guide(user) return itemstack end,
    on_secondary_use = function(itemstack, user) open_guide(user) return itemstack end,
    on_drop = toolbar.on_drop,
})
toolbar.register_tool(TOOL, ITEM, 6)

return {
    set_access = function(player, enabled) toolbar.set_enabled(player, TOOL, enabled) end,
}
