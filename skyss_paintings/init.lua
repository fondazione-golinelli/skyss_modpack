-- Pixel-art paintings.
--
-- The painting frame (right click) asks for a size from 1x1 to 3x3 blocks,
-- then opens a pixel editor with a colour palette. Saving gives a painting
-- item holding the pixels, the author and an optional title. A painting
-- hangs on a wall with enough free solid blocks: the block clicked is its
-- bottom-left corner. Everyone can look at a hung painting (right click);
-- its author and the class staff can also edit or remove it.
--
-- In the world a painting is one invisible "canvas" node per block in front
-- of the wall (the first one, bottom left, holds the data in its meta) and
-- an entity showing the picture, created again whenever its block loads.
-- mission.lua adds the "Painting exhibition" special mission to
-- classrooms_bridge when that mod is loaded.

local S = minetest.get_translator("skyss_paintings")
local MODNAME = "skyss_paintings"
local P = MODNAME .. ":"
local storage = minetest.get_mod_storage()

local paintings = {}
skyss_paintings = paintings

local FRAME, MISSION_FRAME = P .. "frame", P .. "mission_frame"
local PAINTING, CANVAS, PICTURE = P .. "painting", P .. "canvas", P .. "picture"
local MAX_BLOCKS = 3
local MAX_TITLE = 40
local MAX_UNDO = 30
local DRAFT_KEY = MODNAME .. ":draft"
local REGISTRY_KEY = "registry"

paintings.FRAME, paintings.MISSION_FRAME, paintings.PAINTING = FRAME, MISSION_FRAME, PAINTING

-- Pixels per block: a bigger painting gets fewer per block, so the editor
-- never has more than 24 pixels on a side.
local function pixels_per_block(w, h)
    local m = math.max(w, h)
    return m == 1 and 16 or m == 2 and 12 or 8
end
paintings.pixels_per_block = pixels_per_block

-- ── Palette ──────────────────────────────────────────────────────────────────
-- Pixels are stored as one character each, the colour's index in ALPHABET.

local PALETTE = {
    "#ffffff", "#c7cfdd", "#92a1b9", "#657392", "#424c6e", "#2a2f4e", "#1a1932", "#000000",
    "#f9d2b3", "#e8a87c", "#c27c4e", "#8a5230", "#5b3a29", "#f04a4a", "#b4202a", "#73172d",
    "#f98e2c", "#fad64a", "#fff7a0", "#a3e048", "#4cb848", "#1e7d3a", "#134c2c", "#8cc7a0",
    "#7ae7f0", "#36a6e0", "#2156c2", "#2a2c8f", "#8a4fd0", "#d27fe8", "#f58fc0", "#c2367f",
}
local ALPHABET = "0123456789abcdefghijklmnopqrstuv"
local CHAR_INDEX = {}
for i = 1, #ALPHABET do CHAR_INDEX[ALPHABET:sub(i, i)] = i end
local ARGB = {}
for i, hex in ipairs(PALETTE) do ARGB[i] = 0xFF000000 + tonumber(hex:sub(2), 16) end

local function decode(px, n)
    local out = {}
    for i = 1, n do out[i] = CHAR_INDEX[px:sub(i, i)] or 1 end
    return out
end

local function encode(list)
    local chars = {}
    for i, c in ipairs(list) do chars[i] = ALPHABET:sub(c, c) end
    return table.concat(chars)
end

-- ── Images ───────────────────────────────────────────────────────────────────

local FRAME_DARK, FRAME_WOOD, FRAME_LIGHT, FRAME_SHADE = 0xFF3B2412, 0xFFA0703C, 0xFFC99A5B, 0xFF6B4423

-- The picture as a [png texture. scale: image pixels per painting pixel;
-- border: frame thickness in image pixels (0: no frame).
local function render(pw, ph, pixels, scale, border)
    local tw, th = pw * scale + 2 * border, ph * scale + 2 * border
    local data, n = {}, 0
    for y = 0, th - 1 do
        local row = math.floor((y - border) / scale) * pw
        for x = 0, tw - 1 do
            local c
            local edge = math.min(x, y, tw - 1 - x, th - 1 - y)
            if edge < border then
                if edge == 0 or (border >= 3 and edge == border - 1) then
                    c = FRAME_DARK
                elseif (x == edge and y >= x and th - 1 - y >= x) or (y == edge and x >= y and tw - 1 - x >= y) then
                    c = FRAME_LIGHT -- top and left: lit
                elseif edge == 1 then
                    c = FRAME_SHADE -- bottom and right: in shadow
                else
                    c = FRAME_WOOD
                end
            else
                c = ARGB[pixels[row + math.floor((x - border) / scale) + 1]] or ARGB[1]
            end
            n = n + 1
            data[n] = c
        end
    end
    return "[png:" .. minetest.encode_base64(minetest.encode_png(tw, th, data, 9))
end

-- Entity textures go through a 16-bit length string: keep them well below.
-- Returns the texture and its scale (the frame is one painting pixel thick).
local function render_for_world(pw, ph, pixels)
    local scale = math.max(2, math.floor(192 / math.max(pw, ph)))
    while true do
        local tex = render(pw, ph, pixels, scale, scale)
        if #tex < 60000 or scale <= 2 then return tex, scale end
        scale = scale - 2
    end
end

-- ── Who may do what ──────────────────────────────────────────────────────────

local function is_staff(name)
    if minetest.global_exists("classrooms_bridge") and classrooms_bridge.is_staff
            and classrooms_bridge.is_staff(name) then
        return true
    end
    return minetest.check_player_privs(name, { protection_bypass = true })
        or minetest.check_player_privs(name, { server = true })
end
paintings.is_staff = is_staff

local function can_manage(name, owner)
    return name == owner or is_staff(name)
end

-- ── Registry of hung paintings (used by the mission) ─────────────────────────

local function load_registry()
    local raw = storage:get_string(REGISTRY_KEY)
    return raw ~= "" and minetest.parse_json(raw) or {}
end

local function save_registry(reg)
    storage:set_string(REGISTRY_KEY, minetest.write_json(reg))
end

local function registry_set(pos, entry)
    local reg = load_registry()
    reg[minetest.pos_to_string(pos)] = entry
    save_registry(reg)
end

-- Hung paintings: { [pos string] = { owner, placer, placed, uid } }. Entries
-- whose node is loaded and is no longer the same painting are dropped.
function paintings.registry()
    local reg, changed = load_registry(), false
    for key, entry in pairs(reg) do
        local pos = minetest.string_to_pos(key)
        local node = pos and minetest.get_node_or_nil(pos)
        if not pos or (node and (node.name ~= CANVAS
                or minetest.get_meta(pos):get_string("uid") ~= entry.uid)) then
            reg[key] = nil
            changed = true
        end
    end
    if changed then save_registry(reg) end
    return reg
end

-- Called after a painting is hung: function(anchor pos, placer, data).
paintings.on_hang = {}

-- ── Geometry ─────────────────────────────────────────────────────────────────
-- dir points from the free cell into the wall; "right" is the right hand of
-- someone looking at the wall.

local function right_of(dir)
    return { x = dir.z, y = 0, z = -dir.x }
end

local function cell(base, dir, i, j)
    local r = right_of(dir)
    return { x = base.x + r.x * i, y = base.y + j, z = base.z + r.z * i }
end

local function anchor_of(pos)
    if minetest.get_node(pos).name ~= CANVAS then return nil end
    local meta = minetest.get_meta(pos)
    if meta:get_string("px") ~= "" then return pos end
    local anchor = minetest.string_to_pos(meta:get_string("anchor"))
    if anchor and minetest.get_node(anchor).name == CANVAS
            and minetest.get_meta(anchor):get_string("px") ~= "" then
        return anchor
    end
end

-- Everything about the painting anchored at pos.
local function read_painting(pos)
    local meta = minetest.get_meta(pos)
    local w, h = meta:get_int("w"), meta:get_int("h")
    if w < 1 or h < 1 or meta:get_string("px") == "" then return nil end
    local ppb = pixels_per_block(w, h)
    return {
        w = w, h = h, pw = w * ppb, ph = h * ppb,
        px = meta:get_string("px"),
        owner = meta:get_string("owner"),
        title = meta:get_string("title"),
        uid = meta:get_string("uid"),
        dir = minetest.facedir_to_dir(minetest.get_node(pos).param2 % 4),
    }
end

local function painting_label(title, owner)
    if title ~= "" then return S("\"@1\" by @2", title, owner) end
    return S("Painting by @1", owner)
end

-- ── Entity ───────────────────────────────────────────────────────────────────

minetest.register_entity(PICTURE, {
    initial_properties = {
        visual = "upright_sprite",
        textures = { "skyss_paintings_blank.png", "skyss_paintings_blank.png" },
        physical = false,
        pointable = false,
        collide_with_objects = false,
        static_save = false,
    },
})

local function objects_near(pos, radius)
    if minetest.objects_inside_radius then
        local out = {}
        for obj in minetest.objects_inside_radius(pos, radius) do table.insert(out, obj) end
        return out
    end
    return minetest.get_objects_inside_radius(pos, radius)
end

-- Just in front of the wall, in the middle of the painting.
local function picture_center(pos, info)
    local r = right_of(info.dir)
    local off = 0.5 - 0.03
    return {
        x = pos.x + r.x * (info.w - 1) / 2 + info.dir.x * off,
        y = pos.y + (info.h - 1) / 2,
        z = pos.z + r.z * (info.w - 1) / 2 + info.dir.z * off,
    }
end

local function find_pictures(pos, info)
    local key = minetest.pos_to_string(pos)
    local found = {}
    for _, obj in ipairs(objects_near(picture_center(pos, info), 0.5)) do
        local ent = obj:get_luaentity()
        if ent and ent.name == PICTURE and ent.anchor == key then table.insert(found, obj) end
    end
    return found
end

local function remove_pictures(pos)
    local info = read_painting(pos)
    if not info then return end
    for _, obj in ipairs(find_pictures(pos, info)) do obj:remove() end
end

-- Shows the painting anchored at pos, creating its entity if missing. The
-- canvas covers the wall exactly; the frame sticks out a little.
local function show_picture(pos)
    local info = read_painting(pos)
    if not info then return end
    local tex, scale = render_for_world(info.pw, info.ph, decode(info.px, info.pw * info.ph))
    local props = {
        textures = { tex, tex },
        visual_size = {
            x = info.w * (info.pw + 2) / info.pw,
            y = info.h * (info.ph + 2) / info.ph,
            z = 1,
        },
    }
    local list = find_pictures(pos, info)
    for i = 2, #list do list[i]:remove() end
    local obj = list[1]
    if not obj then
        obj = minetest.add_entity(picture_center(pos, info), PICTURE)
        if not obj then return end
        obj:get_luaentity().anchor = minetest.pos_to_string(pos)
    end
    obj:set_yaw(minetest.dir_to_yaw(info.dir))
    obj:set_properties(props)
    return scale
end

-- ── Canvas node ──────────────────────────────────────────────────────────────

local show_viewer -- defined below

minetest.register_node(CANVAS, {
    description = S("Painting"),
    drawtype = "airlike",
    paramtype = "light",
    paramtype2 = "facedir",
    sunlight_propagates = true,
    walkable = false,
    pointable = true,
    diggable = false,
    buildable_to = false,
    floodable = false,
    is_ground_content = false,
    drop = "",
    selection_box = { type = "fixed", fixed = { -0.5, -0.5, 0.5 - 1 / 16, 0.5, 0.5, 0.5 } },
    groups = { not_in_creative_inventory = 1, unmovable_by_piston = 1 },
    _mcl_blast_resistance = 1200,
    _mcl_hardness = -1,
    on_blast = function() end,
    can_dig = function() return false end,
    on_rightclick = function(pos, _, clicker, itemstack)
        local anchor = anchor_of(pos)
        if anchor and clicker and clicker:is_player() then show_viewer(clicker, anchor) end
        return itemstack
    end,
    on_destruct = function(pos)
        if minetest.get_meta(pos):get_string("px") ~= "" then remove_pictures(pos) end
    end,
})

minetest.register_lbm({
    label = "Show hung paintings",
    name = P .. "show_pictures",
    nodenames = { CANVAS },
    run_at_every_load = true,
    action = function(pos)
        if minetest.get_meta(pos):get_string("px") ~= "" then show_picture(pos) end
    end,
})

-- ── Painting item ────────────────────────────────────────────────────────────

local function painting_description(title, owner, w, h)
    local first = title ~= "" and S("Painting \"@1\"", title) or S("Painting")
    return first .. "\n" .. minetest.colorize("#aaaaaa", S("by @1", owner) .. "\n" .. S("@1 × @2 blocks", w, h))
end

-- A painting item from its data { w, h, px, owner, title }.
function paintings.make_item(data)
    local stack = ItemStack(PAINTING)
    local meta = stack:get_meta()
    meta:set_int("w", data.w)
    meta:set_int("h", data.h)
    meta:set_string("px", data.px)
    meta:set_string("owner", data.owner)
    meta:set_string("title", data.title or "")
    meta:set_string("description", painting_description(data.title or "", data.owner, data.w, data.h))
    local ppb = pixels_per_block(data.w, data.h)
    local pw, ph = data.w * ppb, data.h * ppb
    -- The multiserver proxy prefixes the whole inventory_image value with
    -- its media pool name, so it must start with a file name: [png goes on
    -- top of a transparent base.
    -- wield_image is passed through untouched, so it stays a bare [png.
    local picture = render(pw, ph, decode(data.px, pw * ph), 1, 1)
    meta:set_string("inventory_image", ("skyss_paintings_blank.png^[resize:%dx%d^(%s)"):format(pw + 2, ph + 2, picture))
    meta:set_string("wield_image", picture)
    return stack
end

local function item_data(stack)
    local meta = stack:get_meta()
    local w, h = meta:get_int("w"), meta:get_int("h")
    local px = meta:get_string("px")
    if w < 1 or h < 1 or w > MAX_BLOCKS or h > MAX_BLOCKS then return nil end
    local ppb = pixels_per_block(w, h)
    if #px ~= w * ppb * h * ppb then return nil end
    return { w = w, h = h, px = px, owner = meta:get_string("owner"), title = meta:get_string("title") }
end

local function give(player, stack)
    local leftover = player:get_inventory():add_item("main", stack)
    if not leftover:is_empty() then minetest.add_item(player:get_pos(), leftover) end
end

local function notify(name, text)
    minetest.chat_send_player(name, minetest.colorize("#ffb347", S("[Paintings]") .. " " .. text))
end

-- Marks a cell where the painting does not fit, for the placer only.
local function mark_bad(name, pos, dir)
    minetest.add_particlespawner({
        amount = 6, time = 1.5,
        minpos = { x = pos.x - 0.2, y = pos.y - 0.2, z = pos.z - 0.2 },
        maxpos = { x = pos.x + 0.2, y = pos.y + 0.2, z = pos.z + 0.2 },
        minvel = { x = -dir.x * 0.2, y = 0, z = -dir.z * 0.2 },
        maxvel = { x = -dir.x * 0.4, y = 0.1, z = -dir.z * 0.4 },
        minexptime = 1, maxexptime = 1.5,
        minsize = 3, maxsize = 4,
        texture = "skyss_paintings_bad.png",
        glow = 14,
        playername = name,
    })
end

local function solid_wall(pos)
    local node = minetest.get_node_or_nil(pos)
    local def = node and minetest.registered_nodes[node.name]
    return def ~= nil and node.name ~= CANVAS and def.walkable ~= false and not def.buildable_to
end

local function free_cell(pos)
    local node = minetest.get_node_or_nil(pos)
    local def = node and minetest.registered_nodes[node.name]
    return def ~= nil and node.name ~= CANVAS and (node.name == "air" or def.buildable_to == true)
end

-- Hangs the painting of stack on the wall clicked; returns true on success.
local function hang(stack, placer, pointed)
    local name = placer:get_player_name()
    local data = item_data(stack)
    if not data then
        notify(name, S("This painting is damaged."))
        return false
    end
    local under, above = pointed.under, pointed.above
    local dir = vector.subtract(under, above)
    if dir.y ~= 0 then
        notify(name, S("Paintings hang on walls: click the side of a block."))
        return false
    end
    local fits = true
    for i = 0, data.w - 1 do
        for j = 0, data.h - 1 do
            local front = cell(above, dir, i, j)
            local ok = solid_wall(cell(under, dir, i, j)) and free_cell(front)
                and not minetest.is_protected(front, name)
            if not ok then
                fits = false
                mark_bad(name, front, dir)
            end
        end
    end
    if not fits then
        notify(name, S("This painting needs a free wall of @1 × @2 blocks; the block you click is its bottom-left corner.",
            data.w, data.h))
        return false
    end
    local param2 = minetest.dir_to_facedir(dir)
    local uid = string.format("%s:%d:%d", name, os.time(), math.random(1, 1e6))
    local anchor_str = minetest.pos_to_string(above)
    local infotext = painting_label(data.title, data.owner)
    for i = 0, data.w - 1 do
        for j = 0, data.h - 1 do
            local pos = cell(above, dir, i, j)
            minetest.set_node(pos, { name = CANVAS, param2 = param2 })
            local meta = minetest.get_meta(pos)
            meta:set_string("infotext", infotext)
            if i > 0 or j > 0 then meta:set_string("anchor", anchor_str) end
        end
    end
    local meta = minetest.get_meta(above)
    meta:set_int("w", data.w)
    meta:set_int("h", data.h)
    meta:set_string("px", data.px)
    meta:set_string("owner", data.owner)
    meta:set_string("title", data.title)
    meta:set_string("placer", name)
    meta:set_string("uid", uid)
    show_picture(above)
    registry_set(above, { owner = data.owner, placer = name, placed = os.time(), uid = uid })
    for _, callback in ipairs(paintings.on_hang) do callback(above, placer, data) end
    minetest.log("action", ("[skyss_paintings] %s hung a %dx%d painting by %s at %s"):format(
        name, data.w, data.h, data.owner, anchor_str))
    return true
end

-- Takes the painting at anchor off the wall.
local function take_down(anchor)
    local info = read_painting(anchor)
    if not info then return nil end
    local data = { w = info.w, h = info.h, px = info.px, owner = info.owner, title = info.title }
    remove_pictures(anchor)
    local key = minetest.pos_to_string(anchor)
    for i = 0, info.w - 1 do
        for j = 0, info.h - 1 do
            local pos = cell(anchor, info.dir, i, j)
            if minetest.get_node(pos).name == CANVAS
                    and (pos == anchor or vector.equals(pos, anchor)
                        or minetest.get_meta(pos):get_string("anchor") == key) then
                minetest.remove_node(pos)
            end
        end
    end
    local reg = load_registry()
    reg[key] = nil
    save_registry(reg)
    return data
end

-- ── Editor sessions and drafts ───────────────────────────────────────────────
-- sessions[name] = { w, h, pw, ph, px (list), color, tool, title, undo,
--   grid, owner, target = anchor pos when editing a hung painting, uid }

local sessions = {}
local size_choice = {} -- [name] = { w, h }
local viewing = {}     -- [name] = anchor pos, or false for an item preview

local function new_session(w, h, owner)
    local ppb = pixels_per_block(w, h)
    local pw, ph = w * ppb, h * ppb
    local px = {}
    for i = 1, pw * ph do px[i] = 1 end
    return { w = w, h = h, pw = pw, ph = ph, px = px, color = 8, tool = "pencil",
        title = "", undo = {}, grid = true, owner = owner }
end

local function load_draft(player)
    local raw = player:get_meta():get_string(DRAFT_KEY)
    local d = raw ~= "" and minetest.parse_json(raw)
    if type(d) ~= "table" then return nil end
    local w, h = tonumber(d.w), tonumber(d.h)
    if not w or not h or w < 1 or h < 1 or w > MAX_BLOCKS or h > MAX_BLOCKS then return nil end
    local s = new_session(w, h, player:get_player_name())
    if type(d.px) == "string" and #d.px == s.pw * s.ph then s.px = decode(d.px, s.pw * s.ph) end
    s.title = type(d.title) == "string" and d.title:sub(1, MAX_TITLE) or ""
    return s
end

local function save_draft(player, s)
    if s.target then return end
    player:get_meta():set_string(DRAFT_KEY, minetest.write_json({
        w = s.w, h = s.h, px = encode(s.px), title = s.title }))
end

local function clear_draft(player)
    player:get_meta():set_string(DRAFT_KEY, "")
end

local function push_undo(s)
    table.insert(s.undo, encode(s.px))
    if #s.undo > MAX_UNDO then table.remove(s.undo, 1) end
end

local function flood_fill(s, start, color)
    local from = s.px[start]
    if from == color then return end
    local stack = { start }
    while #stack > 0 do
        local i = table.remove(stack)
        if s.px[i] == from then
            s.px[i] = color
            local x = (i - 1) % s.pw
            if x > 0 then table.insert(stack, i - 1) end
            if x < s.pw - 1 then table.insert(stack, i + 1) end
            if i > s.pw then table.insert(stack, i - s.pw) end
            if i <= s.pw * (s.ph - 1) then table.insert(stack, i + s.pw) end
        end
    end
end

-- Line and rectangle: drawn between two clicked pixels (formspecs send
-- clicks only, so there is no dragging).
local function draw_line(s, from, to, color)
    local x0, y0 = (from - 1) % s.pw, math.floor((from - 1) / s.pw)
    local x1, y1 = (to - 1) % s.pw, math.floor((to - 1) / s.pw)
    local dx, dy = math.abs(x1 - x0), -math.abs(y1 - y0)
    local sx, sy = x0 < x1 and 1 or -1, y0 < y1 and 1 or -1
    local err = dx + dy
    while true do
        s.px[y0 * s.pw + x0 + 1] = color
        if x0 == x1 and y0 == y1 then return end
        local e2 = 2 * err
        if e2 >= dy then err, x0 = err + dy, x0 + sx end
        if e2 <= dx then err, y0 = err + dx, y0 + sy end
    end
end

local function draw_rect(s, from, to, color)
    local x0, y0 = (from - 1) % s.pw, math.floor((from - 1) / s.pw)
    local x1, y1 = (to - 1) % s.pw, math.floor((to - 1) / s.pw)
    x0, x1 = math.min(x0, x1), math.max(x0, x1)
    y0, y1 = math.min(y0, y1), math.max(y0, y1)
    for x = x0, x1 do
        s.px[y0 * s.pw + x + 1] = color
        s.px[y1 * s.pw + x + 1] = color
    end
    for y = y0, y1 do
        s.px[y * s.pw + x0 + 1] = color
        s.px[y * s.pw + x1 + 1] = color
    end
end

-- ── Formspecs ────────────────────────────────────────────────────────────────

local esc = minetest.formspec_escape
local BG = "#1d2130"
local BTN, BTN_ON, BTN_EDGE = "#3a4566", "#c99a5b", "#14182a"
local BLANK = "skyss_paintings_blank.png"
local function icon(name) return "skyss_paintings_icon_" .. name .. ".png" end

-- Short numbers: the editor sends one button per pixel.
local function f(n)
    local text = string.format("%.3f", n):gsub("0+$", ""):gsub("%.$", "")
    return text
end

-- Mineclonia gives every image_button an opaque pane (formspec prepend):
-- ours have no image and a transparent pane, so they are click areas over
-- boxes and images, lit when hovered.
local function header(w, h, title)
    return {
        "formspec_version[6]",
        ("size[%s,%s]"):format(f(w), f(h)),
        ("bgcolor[%s;true]"):format(BG .. "f0"),
        ("box[0,0;%s,%s;%s]"):format(f(w), f(h), BG),
        ("box[0,0;%s,0.9;#2b3147]"):format(f(w)),
        "style_type[label;textcolor=#eef0f6]",
        "style_type[button;bgcolor=#3a4566;textcolor=#ffffff]",
        "style_type[button:hovered;bgcolor=#4b5a86]",
        ("style_type[image_button;border=false;bgimg=%s;bgimg_hovered=skyss_paintings_hover.png;"
            .. "bgimg_pressed=skyss_paintings_hover.png;bgimg_middle=0]"):format(BLANK),
        ("label[0.4,0.45;%s]"):format(esc(title)),
    }
end

-- A button drawn with boxes, an icon and a label, under an invisible
-- image_button that takes the click.
local function icon_button(fs, x, y, w, h, name, icon_name, text, bg, tip)
    table.insert(fs, ("box[%s,%s;%s,%s;%s]"):format(f(x), f(y), f(w), f(h), BTN_EDGE))
    table.insert(fs, ("box[%s,%s;%s,%s;%s]"):format(f(x + 0.04), f(y + 0.04), f(w - 0.08), f(h - 0.08), bg or BTN))
    local size = math.min(h - 0.24, 0.7)
    if text and text ~= "" then
        table.insert(fs, ("image[%s,%s;%s,%s;%s]"):format(f(x + 0.18), f(y + (h - size) / 2), f(size), f(size),
            icon(icon_name)))
        table.insert(fs, ("label[%s,%s;%s]"):format(f(x + 0.32 + size), f(y + h / 2), esc(text)))
    else
        table.insert(fs, ("image[%s,%s;%s,%s;%s]"):format(f(x + (w - size) / 2), f(y + (h - size) / 2),
            f(size), f(size), icon(icon_name)))
    end
    table.insert(fs, ("image_button[%s,%s;%s,%s;;%s;]"):format(f(x), f(y), f(w), f(h), name))
    if tip then table.insert(fs, ("tooltip[%s;%s]"):format(name, esc(tip))) end
end

local function shape_word(w, h)
    if w == h then return S("square") end
    return w > h and S("horizontal") or S("vertical")
end

-- Mission information for the frame panel (filled in by mission.lua).
paintings.panel_extra = nil

local function size_formspec(player)
    local name = player:get_player_name()
    local choice = size_choice[name] or { w = 1, h = 1 }
    size_choice[name] = choice
    local draft = load_draft(player)
    local extra = paintings.panel_extra and paintings.panel_extra(player) or nil
    local W, H = 11.5, extra and 11.8 or 8.6
    local fs = header(W, H, S("Painting frame"))
    table.insert(fs, ("label[0.4,1.4;%s]"):format(esc(S("Choose the size of your painting (in blocks):"))))
    -- 3x3 picker: column = width, row from the bottom = height. The chosen
    -- area is coloured; the pin marks the corner that goes on the clicked block.
    local CELL, X0, Y0 = 1.3, 0.6, 1.9
    table.insert(fs, ("box[%s,%s;%s,%s;#11141f]"):format(f(X0 - 0.1), f(Y0 - 0.1),
        f(CELL * MAX_BLOCKS + 0.1), f(CELL * MAX_BLOCKS + 0.1)))
    for cw = 1, MAX_BLOCKS do
        for ch = 1, MAX_BLOCKS do
            local x = X0 + (cw - 1) * CELL
            local y = Y0 + (MAX_BLOCKS - ch) * CELL
            local on = cw <= choice.w and ch <= choice.h
            table.insert(fs, ("box[%s,%s;%s,%s;%s]"):format(f(x), f(y), f(CELL - 0.1), f(CELL - 0.1),
                on and "#e8b86a" or "#3a4054"))
            if on then
                table.insert(fs, ("box[%s,%s;%s,%s;#f9d2b3]"):format(f(x + 0.12), f(y + 0.12), f(CELL - 0.34), f(CELL - 0.34)))
            end
            if cw == 1 and ch == 1 then
                table.insert(fs, ("image[%s,%s;0.6,0.6;%s]"):format(f(x + 0.3), f(y + 0.3), icon("pivot")))
            end
            table.insert(fs, ("image_button[%s,%s;%s,%s;;size_%d_%d;]"):format(
                f(x), f(y), f(CELL - 0.1), f(CELL - 0.1), cw, ch))
            table.insert(fs, ("tooltip[size_%d_%d;%s]"):format(cw, ch, esc(S("@1 × @2", cw, ch))))
        end
    end
    local tx = X0 + CELL * MAX_BLOCKS + 0.5
    table.insert(fs, "style_type[label;font_size=*1.6]")
    table.insert(fs, ("label[%s,2.4;%s]"):format(f(tx), esc(S("@1 × @2", choice.w, choice.h))))
    table.insert(fs, "style_type[label;font_size=*1]")
    table.insert(fs, ("label[%s,3.1;%s]"):format(f(tx), esc(shape_word(choice.w, choice.h))))
    local ppb = pixels_per_block(choice.w, choice.h)
    table.insert(fs, ("label[%s,3.6;%s]"):format(f(tx),
        esc(S("@1 × @2 pixels", choice.w * ppb, choice.h * ppb))))
    table.insert(fs, ("image[%s,4.1;0.45,0.45;%s]"):format(f(tx), icon("pivot")))
    table.insert(fs, ("textarea[%s,4.0;%s,1.6;;;%s]"):format(f(tx + 0.5), f(W - tx - 0.8),
        esc(S("To hang it you need a free wall this big: the block you click is the bottom-left corner."))))
    icon_button(fs, 0.4, 6.1, 5.2, 0.9, "start", "new", S("New painting"), "#3f8f4a")
    if draft then
        icon_button(fs, 5.9, 6.1, 5.2, 0.9, "continue", "draft", S("Continue draft (@1 × @2)", draft.w, draft.h))
        table.insert(fs, ("label[0.4,7.4;%s]"):format(
            minetest.colorize("#aab0c4", esc(S("A new painting replaces your draft.")))))
    end
    if extra then
        table.insert(fs, ("box[0,8.0;%s,0.06;#3a4054]"):format(f(W)))
        table.insert(fs, ("label[0.4,8.5;%s]"):format(esc(extra.title)))
        table.insert(fs, ("textlist[0.4,8.9;%s,2.6;mission_list;%s;0;true]"):format(
            f(W - 0.8), table.concat(extra.lines, ",")))
    end
    return table.concat(fs)
end

local function editor_formspec(name)
    local s = sessions[name]
    local W, H = 20.5, 13.6
    local title = s.target and S("Edit painting — @1 × @2 blocks", s.w, s.h)
        or S("New painting — @1 × @2 blocks", s.w, s.h)
    local fs = header(W, H, title)
    -- Canvas: the picture as one image, an invisible button over each pixel.
    local AREA_X, AREA_Y, AREA_W, AREA_H = 0.4, 1.2, 12.0, 12.0
    local size = math.min(AREA_W / s.pw, AREA_H / s.ph)
    local cx = AREA_X + (AREA_W - size * s.pw) / 2
    local cy = AREA_Y + (AREA_H - size * s.ph) / 2
    table.insert(fs, ("box[%s,%s;%s,%s;#6b4423]"):format(f(cx - 0.15), f(cy - 0.15),
        f(size * s.pw + 0.3), f(size * s.ph + 0.3)))
    table.insert(fs, ("image[%s,%s;%s,%s;%s]"):format(f(cx), f(cy), f(size * s.pw), f(size * s.ph),
        esc(render(s.pw, s.ph, s.px, 1, 0))))
    if s.grid then
        local ppb = pixels_per_block(s.w, s.h)
        for x = 1, s.pw - 1 do
            local strong = x % ppb == 0
            table.insert(fs, ("box[%s,%s;%s,%s;%s]"):format(f(cx + x * size - 0.01), f(cy),
                strong and "0.04" or "0.02", f(size * s.ph), strong and "#00000099" or "#00000040"))
        end
        for y = 1, s.ph - 1 do
            local strong = y % ppb == 0
            table.insert(fs, ("box[%s,%s;%s,%s;%s]"):format(f(cx), f(cy + y * size - 0.01),
                f(size * s.pw), strong and "0.04" or "0.02", strong and "#00000099" or "#00000040"))
        end
    end
    -- First point of a line or rectangle.
    if s.start then
        local x, y = (s.start - 1) % s.pw, math.floor((s.start - 1) / s.pw)
        table.insert(fs, ("box[%s,%s;%s,%s;#ffffff]"):format(f(cx + x * size - 0.05), f(cy + y * size - 0.05),
            f(size + 0.1), f(size + 0.1)))
        table.insert(fs, ("box[%s,%s;%s,%s;%s]"):format(f(cx + x * size + 0.05), f(cy + y * size + 0.05),
            f(math.max(size - 0.1, 0.05)), f(math.max(size - 0.1, 0.05)), PALETTE[s.color]))
    end
    table.insert(fs, ("container[%s,%s]"):format(f(cx), f(cy)))
    local bs = f(size)
    for i = 1, s.pw * s.ph do
        local x, y = (i - 1) % s.pw, math.floor((i - 1) / s.pw)
        table.insert(fs, ("image_button[%s,%s;%s,%s;;p%d;]"):format(f(x * size), f(y * size), bs, bs, i))
    end
    table.insert(fs, "container_end[]")

    -- Palette, with the colour in use next to its title.
    local PX = 13.0
    table.insert(fs, ("label[%s,1.5;%s]"):format(f(PX), esc(S("Colours"))))
    table.insert(fs, ("box[%s,1.18;1.2,0.6;#ffffff]"):format(f(PX + 5.3)))
    table.insert(fs, ("box[%s,1.22;1.12,0.52;%s]"):format(f(PX + 5.34), PALETTE[s.color]))
    local SW = 0.82
    for i, hex in ipairs(PALETTE) do
        local x = PX + ((i - 1) % 8) * SW
        local y = 2.0 + math.floor((i - 1) / 8) * SW
        table.insert(fs, ("box[%s,%s;%s,%s;%s]"):format(f(x - 0.05), f(y - 0.05), f(SW - 0.04), f(SW - 0.04),
            i == s.color and "#ffffff" or "#11141f"))
        table.insert(fs, ("box[%s,%s;%s,%s;%s]"):format(f(x), f(y), f(SW - 0.14), f(SW - 0.14), hex))
        table.insert(fs, ("image_button[%s,%s;%s,%s;;c%d;]"):format(f(x), f(y), f(SW - 0.14), f(SW - 0.14), i))
    end
    -- Tools.
    local TY = 5.6
    table.insert(fs, ("label[%s,%s;%s]"):format(f(PX), f(TY), esc(S("Tools"))))
    icon_button(fs, PX + 5.85, TY - 0.35, 0.75, 0.6, "grid", "grid", nil, s.grid and BTN_ON or nil,
        s.grid and S("Hide grid") or S("Show grid"))
    local tools = {
        { "pencil", S("Pencil"), S("Colour one pixel at a time") },
        { "line", S("Line"), S("Click where the line starts, then where it ends") },
        { "rect", S("Rectangle"), S("Click one corner, then the opposite corner") },
        { "fill", S("Fill"), S("Colour a whole area of the same colour") },
    }
    for i, t in ipairs(tools) do
        local bx, by = PX + ((i - 1) % 2) * 3.4, TY + 0.35 + math.floor((i - 1) / 2) * 1.0
        icon_button(fs, bx, by, 3.2, 0.85, "tool_" .. t[1], t[1], t[2], s.tool == t[1] and BTN_ON or nil, t[3])
    end
    icon_button(fs, PX, TY + 2.4, 3.2, 0.85, "undo", "undo", S("Undo"))
    icon_button(fs, PX + 3.4, TY + 2.4, 3.2, 0.85, "clear", "clear", S("Clear"), nil, S("Start again with a white canvas"))
    if s.start then
        local text = s.tool == "line" and S("Now click where the line ends.") or S("Now click the opposite corner.")
        table.insert(fs, ("label[%s,%s;%s]"):format(f(PX), f(TY + 3.55), minetest.colorize("#fad64a", esc(text))))
    end
    -- Title and author.
    table.insert(fs, "field_close_on_enter[title;false]")
    table.insert(fs, ("field[%s,9.75;6.6,0.8;title;%s;%s]"):format(f(PX), esc(S("Title (optional)")), esc(s.title)))
    table.insert(fs, ("label[%s,10.85;%s]"):format(f(PX), esc(S("by @1", s.owner))))
    if not s.target then
        icon_button(fs, PX + 3.4, 10.5, 3.2, 0.75, "resize", "resize", S("Change size"))
    end
    icon_button(fs, PX, 11.9, 3.2, 0.9, "save", "save", S("Save"), "#3f8f4a")
    icon_button(fs, PX + 3.4, 11.9, 3.2, 0.9, "cancel", "close", S("Close"))
    return table.concat(fs)
end

local function viewer_formspec(name, data, manage)
    local ppb = pixels_per_block(data.w, data.h)
    local pw, ph = data.w * ppb, data.h * ppb
    local AREA = 9.0
    local size = math.min(AREA / pw, AREA / ph)
    local W = math.max(10.4, size * pw + 1.4)
    local H = size * ph + 4.2
    local fs = header(W, H, data.title ~= "" and data.title or S("Painting"))
    local x, y = (W - size * pw) / 2, 1.4
    table.insert(fs, ("box[%s,%s;%s,%s;#6b4423]"):format(f(x - 0.2), f(y - 0.2), f(size * pw + 0.4), f(size * ph + 0.4)))
    table.insert(fs, ("image[%s,%s;%s,%s;%s]"):format(f(x), f(y), f(size * pw), f(size * ph),
        esc(render(pw, ph, decode(data.px, pw * ph), 1, 0))))
    local by = y + size * ph + 0.65
    table.insert(fs, ("label[0.4,%s;%s]"):format(f(by), esc(S("by @1", data.owner) .. "   ·   "
        .. S("@1 × @2 blocks", data.w, data.h))))
    if manage then
        icon_button(fs, 0.4, by + 0.6, 3, 0.9, "edit", "edit", S("Edit"))
        icon_button(fs, 3.6, by + 0.6, 3, 0.9, "remove", "remove", S("Remove"), "#8f3a3a")
    end
    icon_button(fs, W - 3.0, by + 0.6, 2.6, 0.9, "close", "close", S("Close"))
    return table.concat(fs)
end

local function confirm_formspec(data, own)
    local W, H = 10.4, 4.2
    local fs = header(W, H, S("Remove painting"))
    local text = own and S("Take this painting off the wall? It goes back to your inventory.")
        or S("Remove this painting by @1? It will be deleted.", data.owner)
    table.insert(fs, ("textarea[0.4,1.2;9.6,1.6;;;%s]"):format(esc(text)))
    icon_button(fs, 0.4, 3.0, 4.6, 0.9, "yes", "remove", own and S("Take it down") or S("Delete"), "#8f3a3a")
    icon_button(fs, 5.4, 3.0, 4.6, 0.9, "no", "close", S("Cancel"))
    return table.concat(fs)
end

local function open_size(player)
    minetest.show_formspec(player:get_player_name(), P .. "size", size_formspec(player))
end

local function open_editor(player)
    minetest.show_formspec(player:get_player_name(), P .. "edit", editor_formspec(player:get_player_name()))
end

show_viewer = function(player, anchor)
    local name = player:get_player_name()
    local info = read_painting(anchor)
    if not info then return end
    viewing[name] = anchor
    minetest.show_formspec(name, P .. "view", viewer_formspec(name, info, can_manage(name, info.owner)))
end

local function show_item_preview(player, stack)
    local data = item_data(stack)
    if not data then return end
    local name = player:get_player_name()
    viewing[name] = false
    minetest.show_formspec(name, P .. "view", viewer_formspec(name, data, false))
end

-- ── Items ────────────────────────────────────────────────────────────────────

-- Right click on a node: its own action first (doors, chests, paintings).
local function node_rightclick(itemstack, user, pointed)
    if pointed.type ~= "node" or user:get_player_control().sneak then return nil end
    local node = minetest.get_node(pointed.under)
    local def = minetest.registered_nodes[node.name]
    if def and def.on_rightclick then
        return def.on_rightclick(pointed.under, node, user, itemstack, pointed) or itemstack
    end
end

local function frame_def(description, image, extra_groups)
    local function use(itemstack, user, pointed)
        if not user or not user:is_player() then return itemstack end
        local handled = node_rightclick(itemstack, user, pointed)
        if handled then return handled end
        open_size(user)
        return itemstack
    end
    return {
        description = description .. "\n" .. minetest.colorize("#aaaaaa", S("Right click to paint a picture")),
        short_description = description,
        inventory_image = image,
        wield_image = image,
        stack_max = 1,
        groups = extra_groups,
        on_place = use,
        on_secondary_use = use,
    }
end

minetest.register_craftitem(FRAME, frame_def(S("Painting frame"), "skyss_paintings_frame.png", {}))
minetest.register_craftitem(MISSION_FRAME, frame_def(S("Painting frame (mission)"),
    "skyss_paintings_frame_mission.png", { not_in_creative_inventory = 1 }))

minetest.register_craftitem(PAINTING, {
    description = S("Painting"),
    inventory_image = "skyss_paintings_painting.png",
    wield_image = "skyss_paintings_painting.png",
    stack_max = 1,
    groups = { not_in_creative_inventory = 1 },
    on_place = function(itemstack, placer, pointed)
        if not placer or not placer:is_player() then return itemstack end
        local handled = node_rightclick(itemstack, placer, pointed)
        if handled then return handled end
        if pointed.type ~= "node" then return itemstack end
        if hang(itemstack, placer, pointed) then itemstack:take_item() end
        return itemstack
    end,
    on_secondary_use = function(itemstack, user)
        if user and user:is_player() then show_item_preview(user, itemstack) end
        return itemstack
    end,
})

if minetest.registered_items["mcl_core:stick"] and minetest.registered_items["mcl_core:paper"] then
    minetest.register_craft({
        output = FRAME,
        recipe = {
            { "mcl_core:stick", "mcl_core:stick", "mcl_core:stick" },
            { "mcl_core:stick", "mcl_core:paper", "mcl_core:stick" },
            { "mcl_core:stick", "mcl_core:stick", "mcl_core:stick" },
        },
    })
end

-- ── Form handling ────────────────────────────────────────────────────────────

local function clean_title(text)
    text = tostring(text or ""):gsub("[%c]", " "):gsub("^%s+", ""):gsub("%s+$", "")
    return text:sub(1, MAX_TITLE)
end

local function save_session(player, s)
    local name = player:get_player_name()
    local px = encode(s.px)
    if s.target then
        local anchor = s.target
        local info = minetest.get_node(anchor).name == CANVAS and read_painting(anchor)
        if not info or info.uid ~= s.uid then
            notify(name, S("This painting is no longer on the wall."))
            return
        end
        if not can_manage(name, info.owner) then return end
        local meta = minetest.get_meta(anchor)
        meta:set_string("px", px)
        meta:set_string("title", s.title)
        local infotext = painting_label(s.title, info.owner)
        for i = 0, info.w - 1 do
            for j = 0, info.h - 1 do
                local pos = cell(anchor, info.dir, i, j)
                if minetest.get_node(pos).name == CANVAS then
                    minetest.get_meta(pos):set_string("infotext", infotext)
                end
            end
        end
        show_picture(anchor)
        minetest.log("action", ("[skyss_paintings] %s edited the painting by %s at %s"):format(
            name, info.owner, minetest.pos_to_string(anchor)))
        notify(name, S("Painting saved."))
    else
        give(player, paintings.make_item({ w = s.w, h = s.h, px = px, owner = name, title = s.title }))
        clear_draft(player)
        notify(name, S("Painting saved in your inventory: hang it on a wall (the block you click is its bottom-left corner)."))
    end
    sessions[name] = nil
end

local function handle_size(player, fields)
    local name = player:get_player_name()
    for key in pairs(fields) do
        local w, h = key:match("^size_(%d)_(%d)$")
        if w then
            size_choice[name] = { w = tonumber(w), h = tonumber(h) }
            open_size(player)
            return
        end
    end
    if fields.start then
        local c = size_choice[name] or { w = 1, h = 1 }
        sessions[name] = new_session(c.w, c.h, name)
        save_draft(player, sessions[name])
        open_editor(player)
    elseif fields.continue then
        local s = load_draft(player)
        if s then
            sessions[name] = s
            open_editor(player)
        end
    end
end

local function handle_editor(player, fields)
    local name = player:get_player_name()
    local s = sessions[name]
    if not s then return end
    if fields.title then s.title = clean_title(fields.title) end
    if fields.quit or fields.cancel then
        save_draft(player, s)
        if fields.cancel then minetest.close_formspec(name, P .. "edit") end
        return
    end
    if fields.save then
        save_session(player, s)
        minetest.close_formspec(name, P .. "edit")
        return
    end
    if fields.resize then
        save_draft(player, s)
        size_choice[name] = { w = s.w, h = s.h }
        open_size(player)
        return
    end
    local changed = false
    for key in pairs(fields) do
        local p = key:match("^p(%d+)$")
        local c = key:match("^c(%d+)$")
        local t = key:match("^tool_(%a+)$")
        if p then
            local i = tonumber(p)
            if i >= 1 and i <= #s.px then
                if s.tool == "line" or s.tool == "rect" then
                    if not s.start then
                        s.start = i
                    else
                        push_undo(s)
                        if s.tool == "line" then
                            draw_line(s, s.start, i, s.color)
                        else
                            draw_rect(s, s.start, i, s.color)
                        end
                        s.start = nil
                        changed = true
                    end
                elseif s.tool == "fill" then
                    if s.px[i] ~= s.color then
                        push_undo(s)
                        flood_fill(s, i, s.color)
                        changed = true
                    end
                elseif s.px[i] ~= s.color then
                    push_undo(s)
                    s.px[i] = s.color
                    changed = true
                end
            end
        elseif c then
            local i = tonumber(c)
            if PALETTE[i] then s.color = i end
        elseif t == "pencil" or t == "fill" or t == "line" or t == "rect" then
            s.tool, s.start = t, nil
        end
    end
    if fields.undo or fields.clear then s.start = nil end
    if fields.undo and #s.undo > 0 then
        s.px = decode(table.remove(s.undo), s.pw * s.ph)
        changed = true
    elseif fields.clear then
        push_undo(s)
        for i = 1, #s.px do s.px[i] = 1 end
        changed = true
    elseif fields.grid then
        s.grid = not s.grid
    end
    if changed or fields.title then save_draft(player, s) end
    if fields.key_enter_field then return end
    open_editor(player)
end

local function handle_viewer(player, fields)
    local name = player:get_player_name()
    local anchor = viewing[name]
    if not anchor then return end
    local info = read_painting(anchor)
    if not info or minetest.get_node(anchor).name ~= CANVAS then return end
    if not can_manage(name, info.owner) then return end
    if fields.edit then
        local s = sessions[name]
        if not (s and s.target and vector.equals(s.target, anchor) and s.uid == info.uid) then
            s = new_session(info.w, info.h, info.owner)
            s.px = decode(info.px, s.pw * s.ph)
            s.title = info.title
            s.target, s.uid = anchor, info.uid
            sessions[name] = s
        end
        open_editor(player)
    elseif fields.remove then
        minetest.show_formspec(name, P .. "confirm", confirm_formspec(info, name == info.owner))
    end
end

local function handle_confirm(player, fields)
    local name = player:get_player_name()
    local anchor = viewing[name]
    if not anchor then return end
    if fields.no then
        show_viewer(player, anchor)
        return
    end
    if not fields.yes then return end
    local info = read_painting(anchor)
    if not info or minetest.get_node(anchor).name ~= CANVAS or not can_manage(name, info.owner) then return end
    local data = take_down(anchor)
    viewing[name] = nil
    minetest.close_formspec(name, P .. "confirm")
    if not data then return end
    minetest.log("action", ("[skyss_paintings] %s removed the painting by %s at %s"):format(
        name, data.owner, minetest.pos_to_string(anchor)))
    if name == data.owner then
        give(player, paintings.make_item(data))
        notify(name, S("The painting is back in your inventory."))
    else
        notify(name, S("Painting removed."))
    end
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname == P .. "size" then
        handle_size(player, fields)
    elseif formname == P .. "edit" then
        handle_editor(player, fields)
    elseif formname == P .. "view" then
        handle_viewer(player, fields)
    elseif formname == P .. "confirm" then
        handle_confirm(player, fields)
    else
        return false
    end
    return true
end)

-- Paintings saved before the proxy-safe icon kept a bare [png icon.
minetest.register_on_joinplayer(function(player)
    local inv = player:get_inventory()
    for _, list in ipairs({ "main", "offhand" }) do
        for i, stack in ipairs(inv:get_list(list) or {}) do
            if stack:get_name() == PAINTING
                    and stack:get_meta():get_string("inventory_image"):sub(1, 5) == "[png:" then
                local data = item_data(stack)
                if data then inv:set_stack(list, i, paintings.make_item(data)) end
            end
        end
    end
end)

minetest.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    local s = sessions[name]
    if s then save_draft(player, s) end
    sessions[name], size_choice[name], viewing[name] = nil, nil, nil
end)

-- Exposed for mission.lua and tests.
paintings.hang = hang
paintings.take_down = take_down
paintings.read_painting = read_painting
paintings.open_size = open_size
paintings.render = render

if minetest.global_exists("classrooms_bridge") and classrooms_bridge.register_special_mission then
    dofile(minetest.get_modpath(MODNAME) .. "/mission.lua")
end
