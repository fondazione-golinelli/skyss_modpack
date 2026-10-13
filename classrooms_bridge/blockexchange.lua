-- Teacher-facing BlockExchange browser and placement controls.
--
-- Access is granted only by the classrooms proxy. The official BlockExchange
-- mod still owns position markers, allocation checks, downloads, HUD progress,
-- and schematic placement.

local S = minetest.get_translator("classrooms_bridge")

local ITEM_NAME = "classrooms_bridge:blockexchange"
local TOOL_ID = "blockexchange"
local FORM_NAME = "classrooms_bridge:blockexchange"
local PAGE_SIZE = 20
local EXCHANGE_URL = minetest.settings:get("classrooms.blockexchange_url")
    or minetest.settings:get("blockexchange.url")
    or "https://exchange.golinelli.live"

-- Supplied privately by init.lua, where Luanti requires request_http_api() to
-- be called directly from the mod's top-level scope. The toolbar owns the
-- dedicated hotbar slot of the library item.
local http, toolbar = ...
local access = {}
local views = {}

-- Structure previews are the isometric renders BlockExchange keeps for every
-- schematic. The PNG travels inside the formspec as a `[png:` texture: dynamic
-- media is not delivered reliably through the multiserver proxy.
local PREVIEW_PIXELS = 256
local PREVIEW_CACHE_SIZE = 64
local PREVIEW_RETRY_SECONDS = 60
local PNG_SIGNATURE = "\137PNG\r\n\26\n"
-- previews[key] = { state = "loading"|"ready"|"missing", texture, w, h, at, waiters }
local previews = {}
local preview_count = 0
local storage = minetest.get_mod_storage()

local integration = {}

if http then
    minetest.log("action", "[classrooms_bridge] BlockExchange catalogue HTTP access enabled")
else
    minetest.log("warning", "[classrooms_bridge] BlockExchange catalogue HTTP access unavailable")
end

local function notify(name, message, color)
    minetest.chat_send_player(name, minetest.colorize(color or "#00CCFF",
        "[BlockExchange] " .. message))
end

local function bx_available()
    return type(blockexchange) == "table"
        and blockexchange.is_online
        and type(blockexchange.allocate) == "function"
        and type(blockexchange.load) == "function"
        and type(blockexchange.set_pos) == "function"
end

local function claims_for(name)
    if not bx_available() or type(blockexchange.get_claims) ~= "function" then
        return nil
    end
    return blockexchange.get_claims(name)
end

local function marker_key(name)
    return "blockexchange_original_priv_" .. name
end

local function grant_upload_privilege(name)
    local key = marker_key(name)
    if storage:get_string(key) == "" then
        local original = minetest.get_player_privs(name).blockexchange == true
        storage:set_string(key, original and "true" or "false")
    end

    local privs = minetest.get_player_privs(name)
    privs.blockexchange = true
    minetest.set_player_privs(name, privs)
end

local function restore_upload_privilege(name)
    local key = marker_key(name)
    local original = storage:get_string(key)
    if original == "" then return end

    local privs = minetest.get_player_privs(name)
    privs.blockexchange = original == "true" and true or nil
    minetest.set_player_privs(name, privs)
    storage:set_string(key, "")
end

local function table_escape(value)
    -- string.gsub returns both the resulting string and a replacement count.
    -- Store the result first so callers (notably table.insert) receive exactly
    -- one value.
    local escaped = minetest.formspec_escape(tostring(value or "")):gsub(",", "\\,")
    return escaped
end

local function format_size(schema)
    return string.format("%d × %d × %d",
        tonumber(schema.size_x) or 0,
        tonumber(schema.size_y) or 0,
        tonumber(schema.size_z) or 0)
end

-- Layout helpers. Icons are Luanti client textures that the multiserver
-- proxy also ships in every media pool.
local C = {
    bg = "#141a2a",
    header = "#0f3460",
    accent = "#e94560",
    card = "#202a44",
    button = "#34446a",
    primary = "#2a8c7f",
    tab_idle = "#26304c",
    muted = "#aaaaaa",
    light = "#f0f0f0",
    ok = "#44ff44",
    warn = "#ffcc00",
}

local function esc(text)
    return minetest.formspec_escape(tostring(text or ""))
end

local function colored(color, text)
    return esc(minetest.colorize(color, text))
end

local function label(fs, x, y, text, color)
    table.insert(fs, ("label[%s,%s;%s]"):format(x, y, colored(color or C.light, text)))
end

local function styled_button(fs, x, y, w, h, name, text, color)
    table.insert(fs, ("style[%s;bgcolor=%s]"):format(name, color or C.button))
    table.insert(fs, ("button[%s,%s;%s,%s;%s;%s]"):format(x, y, w, h, name, esc(text)))
end

local function icon_button(fs, x, y, size, name, icon, tooltip)
    table.insert(fs, ("image_button[%s,%s;%s,%s;%s;%s;]"):format(x, y, size, size, icon, name))
    if tooltip then
        table.insert(fs, ("tooltip[%s;%s]"):format(name, esc(tooltip)))
    end
end

-- Numbered step marker; a done step shows a check mark instead.
local function step_badge(fs, x, y, number, done)
    if done then
        table.insert(fs, ("box[%s,%s;0.55,0.55;%s]"):format(x, y, C.primary))
        table.insert(fs, ("image[%s,%s;0.45,0.45;checkbox_64.png]"):format(x + 0.05, y + 0.05))
    else
        table.insert(fs, ("box[%s,%s;0.55,0.55;%s]"):format(x, y, C.button))
        label(fs, x + 0.19, y + 0.28, tostring(number), C.warn)
    end
end

local function preview_key(schema)
    local uid = schema.uid
    if type(uid) ~= "string" or not uid:find("^[%w_%-]+$") then return nil end
    return uid .. "_" .. tostring(tonumber(schema.mtime) or 0)
end

-- Preview card next to the structure list.
local function render_preview(fs, name, selected, x, y, w, h)
    table.insert(fs, ("box[%s,%s;%s,%s;%s]"):format(x, y, w, h, C.card))

    local key = selected and preview_key(selected.schema)
    local entry = key and previews[key]
    if entry and entry.state == "ready" then
        local max_w, max_h = w - 0.3, h - 0.3
        local scale = math.min(max_w / entry.w, max_h / entry.h)
        local img_w, img_h = entry.w * scale, entry.h * scale
        table.insert(fs, ("image[%.2f,%.2f;%.2f,%.2f;%s]"):format(
            x + (w - img_w) / 2, y + (h - img_h) / 2, img_w, img_h, esc(entry.texture)))
        return
    end

    local caption = S("Click a row to see its preview")
    if selected then
        caption = entry and entry.state == "loading" and S("Loading preview…")
            or S("No preview available")
    end
    table.insert(fs, ("hypertext[%s,%s;%s,%s;bx_preview_caption;"):format(x + 0.15, y, w - 0.3, h)
        .. "<global background=none halign=center valign=middle color=" .. C.muted .. ">"
        .. esc(caption) .. "]")
end

local function render(name)
    if not access[name] then return end

    local view = views[name] or {
        page = 0,
        query = "",
        rows = {},
        loading = false,
        has_next = false,
    }
    views[name] = view

    local fs = {
        "formspec_version[6]",
        "size[13.2,10.4]",
        "bgcolor[" .. C.bg .. ";true]",
        -- Paint over the game's formspec_prepend (Mineclonia background and
        -- text colors).
        "box[0,0;13.2,10.4;" .. C.bg .. "]",
        "style_type[button,image_button;bgcolor=" .. C.button .. ";border=false;textcolor=" .. C.light .. "]",
        "style_type[label,checkbox;textcolor=" .. C.light .. "]",
        "style_type[field,pwdfield,textarea;textcolor=" .. C.light .. "]",
        "box[0,0;13.2,1.05;" .. C.header .. "]",
        "box[0,1.05;13.2,0.05;" .. C.accent .. "]",
    }
    label(fs, 0.4, 0.35, S("BlockExchange Library"))
    table.insert(fs, "style[bx_home_link;font_size=15]")
    table.insert(fs, "hypertext[0.38,0.55;6.5,0.45;bx_home_link;"
        .. "<global background=none margin=0 color=#8fb8de hovercolor=#c5dcf0>"
        .. "<action name=home url='" .. esc(EXCHANGE_URL) .. "'><u>"
        .. esc(EXCHANGE_URL) .. "</u></action>]")
    table.insert(fs, "image_button_exit[12.35,0.2;0.65,0.65;clear.png;bx_close;]")
    table.insert(fs, "tooltip[bx_close;" .. esc(S("Close")) .. "]")

    local sharing = view.tab == "share"
    styled_button(fs, 0.35, 1.3, 3.2, 0.62, "bx_tab_browse", S("Find & place"),
        sharing and C.tab_idle or C.accent)
    styled_button(fs, 3.65, 1.3, 3.2, 0.62, "bx_tab_share", S("Share a build"),
        sharing and C.accent or C.tab_idle)

    if sharing then
        local claims = claims_for(name)
        if not claims or not claims.username then
            table.insert(fs, "box[0.35,2.2;12.5,3.1;" .. C.card .. "]")
            label(fs, 0.65, 2.55, S("To share builds, connect your BlockExchange account once."))
            step_badge(fs, 0.65, 3.0, 1, false)
            label(fs, 1.4, 3.28, S("Open your profile and create an access token."))
            table.insert(fs, ("style[bx_profile;bgcolor=%s]"):format(C.button))
            table.insert(fs, "button_url[9.3,2.95;3.3,0.62;bx_profile;" .. esc(S("Open my profile")) .. ";"
                .. esc(EXCHANGE_URL .. "/profile") .. "]")
            step_badge(fs, 0.65, 3.95, 2, false)
            label(fs, 1.4, 4.23, S("Enter your BlockExchange username and the token."))
            label(fs, 1.4, 4.7, S("Your game name and BlockExchange name may differ."), C.muted)

            table.insert(fs, "box[0.35,5.5;12.5,1.6;" .. C.card .. "]")
            table.insert(fs, "field[0.65,6.15;4.6,0.65;bx_login_username;" .. esc(S("BlockExchange username")) .. ";"
                .. esc(view.login_username or "") .. "]")
            table.insert(fs, "pwdfield[5.45,6.15;4.2,0.65;bx_access_token;" .. esc(S("Access token")) .. "]")
            styled_button(fs, 9.85, 6.15, 2.75, 0.65, "bx_login", S("Sign in"), C.primary)
            if view.login_status then
                table.insert(fs, "textarea[0.65,7.35;12.0,1.0;;;" .. esc(view.login_status) .. "]")
            end
            label(fs, 0.65, 9.9, S("The token is exchanged for a session and never stored."), C.muted)
        else
            local pos1 = blockexchange.get_pos and blockexchange.get_pos(1, name)
            local pos2 = blockexchange.get_pos and blockexchange.get_pos(2, name)

            label(fs, 7.3, 1.61, S("Signed in as @1", claims.username), C.muted)
            icon_button(fs, 12.2, 1.3, 0.62, "bx_logout", "clear.png", S("Sign out"))

            -- Step 1: corners.
            table.insert(fs, "box[0.35,2.2;12.5,2.75;" .. C.card .. "]")
            step_badge(fs, 0.65, 2.45, 1, pos1 ~= nil and pos2 ~= nil)
            label(fs, 1.4, 2.73, S("Stand on two opposite corners of your build and mark them."))
            styled_button(fs, 0.65, 3.25, 2.9, 0.65, "bx_pos1", S("Mark corner 1"))
            label(fs, 3.75, 3.58, pos1 and minetest.pos_to_string(pos1) or S("not set"),
                pos1 and C.ok or C.muted)
            styled_button(fs, 6.55, 3.25, 2.9, 0.65, "bx_pos2", S("Mark corner 2"))
            label(fs, 9.65, 3.58, pos2 and minetest.pos_to_string(pos2) or S("not set"),
                pos2 and C.ok or C.muted)
            if pos1 and pos2 then
                label(fs, 0.65, 4.45, S("Selected size: @1 blocks", format_size({
                    size_x = math.abs(pos2.x - pos1.x) + 1,
                    size_y = math.abs(pos2.y - pos1.y) + 1,
                    size_z = math.abs(pos2.z - pos1.z) + 1,
                })), C.muted)
            end

            -- Step 2: name.
            local named = (view.schema_name or "") ~= ""
            table.insert(fs, "box[0.35,5.15;12.5,1.55;" .. C.card .. "]")
            step_badge(fs, 0.65, 5.4, 2, named)
            label(fs, 1.4, 5.68, S("Give it a name (letters, numbers, - _ .)"))
            table.insert(fs, "field[1.4,5.95;11.2,0.6;bx_schema_name;;"
                .. esc(view.schema_name or "") .. "]")
            table.insert(fs, "field_close_on_enter[bx_schema_name;false]")

            -- Step 3: publish.
            table.insert(fs, "box[0.35,6.9;12.5,1.25;" .. C.card .. "]")
            step_badge(fs, 0.65, 7.25, 3, false)
            styled_button(fs, 1.4, 7.2, 4.2, 0.7, "bx_upload", S("Publish to the library"), C.primary)
            table.insert(fs, ("style[bx_search_page;bgcolor=%s]"):format(C.button))
            table.insert(fs, "button_url[8.6,7.2;4.0,0.7;bx_search_page;" .. esc(S("Open web library")) .. ";"
                .. esc(EXCHANGE_URL .. "/search") .. "]")

            local upload_status = view.upload_status
                or S("Mark both corners, choose a name, then publish.")
            if view.uploading then
                upload_status = S("Uploading… follow the progress bar on screen.")
            end
            table.insert(fs, "textarea[0.35,8.4;12.5,1.6;;;" .. esc(upload_status) .. "]")
        end

        minetest.show_formspec(name, FORM_NAME, table.concat(fs))
        return
    end

    -- Find & place.
    table.insert(fs, "field[0.35,2.2;10.85,0.7;bx_query;;" .. esc(view.query) .. "]")
    table.insert(fs, "field_close_on_enter[bx_query;false]")
    table.insert(fs, "tooltip[bx_query;" .. esc(S("Type a word (e.g. house, bridge) and press Enter")) .. "]")
    icon_button(fs, 11.35, 2.2, 0.7, "bx_search", "search.png", S("Search"))
    icon_button(fs, 12.15, 2.2, 0.7, "bx_refresh", "refresh.png", S("Reload the list"))

    if not bx_available() then
        table.insert(fs, "textarea[0.35,3.15;12.5,2.2;;" .. esc(S("BlockExchange unavailable")) .. ";")
        table.insert(fs, esc(S("The official blockexchange mod must be installed, enabled, online, and configured for @1.",
            EXCHANGE_URL)))
        table.insert(fs, "]")
    elseif not http then
        table.insert(fs, "textarea[0.35,3.15;12.5,2.2;;" .. esc(S("Catalogue unavailable")) .. ";")
        table.insert(fs, esc(S("Add classrooms_bridge to secure.http_mods, then restart this instance.")))
        table.insert(fs, "]")
    elseif view.loading then
        table.insert(fs, "image[0.45,3.2;0.5,0.5;refresh.png]")
        label(fs, 1.15, 3.45, S("Loading structures…"), C.muted)
    elseif view.error then
        table.insert(fs, "textarea[0.35,3.15;12.5,1.5;;" .. esc(S("Could not load structures")) .. ";")
        table.insert(fs, esc(view.error))
        table.insert(fs, "]")
    elseif #view.rows == 0 then
        label(fs, 0.45, 3.45, S("No structures found. Try another word."), C.muted)
    else
        -- The header is a one-row table sharing the list's columns, so the
        -- titles stay aligned whatever the client's font size is. The right
        -- third of the row belongs to the preview card.
        local columns = "tablecolumns[text,width=12,padding=0.5;"
            .. "text,width=20,padding=0.5;"
            .. "text,width=12,align=center,padding=0.5;"
            .. "text,width=7,align=right,padding=0.5]"
        table.insert(fs, "tableoptions[background=#D7DDE2;color=#1a1a2e;border=false;"
            .. "highlight=#D7DDE2;highlight_text=#1a1a2e]")
        table.insert(fs, columns)
        table.insert(fs, "table[0.35,3.1;9.05,0.5;bx_header;" .. table_escape(S("Owner")) .. ","
            .. table_escape(S("Structure")) .. "," .. table_escape(S("Size")) .. ","
            .. table_escape(S("Downloads")) .. ";0]")
        table.insert(fs, "tableoptions[background=#1B1B1B;border=true;highlight=#356A91;highlight_text=#FFFFFF]")
        table.insert(fs, columns)
        table.insert(fs, "table[0.35,3.65;9.05,3.2;bx_structures;")
        local first = true
        for _, row in ipairs(view.rows) do
            if not first then
                table.insert(fs, ",")
            end
            first = false
            table.insert(fs, table_escape(row.username))
            table.insert(fs, ",")
            table.insert(fs, table_escape(row.schema.name))
            table.insert(fs, ",")
            table.insert(fs, table_escape(format_size(row.schema)))
            table.insert(fs, ",")
            table.insert(fs, table_escape(row.schema.downloads or 0))
        end
        table.insert(fs, ";")
        table.insert(fs, tostring(view.selected or 0))
        table.insert(fs, "]")

        render_preview(fs, name, view.rows[view.selected or 0], 9.55, 3.1, 3.3, 3.75)
    end

    icon_button(fs, 0.35, 6.95, 0.55, "bx_prev", "prev_icon.png", S("Previous page"))
    label(fs, 1.05, 7.22, S("Page @1", view.page + 1), C.muted)
    icon_button(fs, 2.15, 6.95, 0.55, "bx_next", "next_icon.png", S("Next page"))

    -- Guided placement.
    local selected = view.rows[view.selected or 0]
    local origin = bx_available() and blockexchange.get_pos and blockexchange.get_pos(1, name)
    table.insert(fs, "box[0.35,7.7;12.5,2.45;" .. C.card .. "]")

    step_badge(fs, 0.6, 7.9, 1, selected ~= nil)
    label(fs, 1.3, 8.05, S("Pick a structure"))
    label(fs, 1.3, 8.45, selected and (selected.username .. " / " .. selected.schema.name)
        or S("Click a row in the list"), selected and C.ok or C.muted)

    step_badge(fs, 0.6, 9.0, 2, origin ~= nil)
    label(fs, 1.3, 9.15, S("Go to the start spot"))
    label(fs, 1.3, 9.55, origin and S("Start: @1", minetest.pos_to_string(origin)) or S("Start not set"),
        origin and C.ok or C.muted)
    styled_button(fs, 5.15, 8.95, 2.35, 0.65, "bx_origin", S("Set start here"))
    table.insert(fs, "tooltip[bx_origin;" .. esc(S("The structure is built from your current position")) .. "]")

    step_badge(fs, 7.75, 7.9, 3, false)
    label(fs, 8.45, 8.05, S("Build it"))
    styled_button(fs, 8.45, 8.35, 4.15, 0.6, "bx_allocate", S("Check the space"))
    table.insert(fs, "tooltip[bx_allocate;" .. esc(S("Shows how big it is and whether it fits, without building")) .. "]")
    styled_button(fs, 8.45, 9.05, 4.15, 0.75, "bx_load", S("Build here"), C.primary)

    minetest.show_formspec(name, FORM_NAME, table.concat(fs))
end

local function safe_render(name, context)
    local ok, err = pcall(render, name)
    if ok then return true end

    minetest.log("error", "[classrooms_bridge] BlockExchange form render failed"
        .. (context and " during " .. context or "") .. ": " .. tostring(err))
    notify(name, S("The library could not be displayed. The error was logged."), "#FF5555")
    return false
end

local function fetch_rows(name)
    local view = views[name]
    if not view or not access[name] or not http then
        safe_render(name, "fetch setup")
        return
    end

    view.loading = true
    view.error = nil
    view.selected = nil
    safe_render(name, "loading")

    local payload = {
        complete = true,
        type = 0,
        order_column = "mtime",
        order_direction = "desc",
        limit = PAGE_SIZE + 1,
        offset = view.page * PAGE_SIZE,
    }
    if view.query:find("[%w]") then
        payload.keywords = view.query
    end

    http.fetch({
        url = EXCHANGE_URL .. "/api/search/schema",
        method = "POST",
        timeout = 15,
        extra_headers = {
            "Content-Type: application/json",
            "Accept: application/json",
        },
        data = minetest.write_json(payload),
    }, function(result)
        local handled, callback_error = pcall(function()
            local current = views[name]
            if not current or not access[name] then return end
            current.loading = false

            if not result.succeeded or result.code ~= 200 then
                current.rows = {}
                current.has_next = false
                current.error = S("The server returned HTTP @1.", tostring(result.code or 0))
                safe_render(name, "HTTP error")
                return
            end

            local rows = minetest.parse_json(result.data)
            if type(rows) ~= "table" then
                current.rows = {}
                current.has_next = false
                current.error = S("The server response was not a structure list.")
                safe_render(name, "response validation")
                return
            end

            current.has_next = #rows > PAGE_SIZE
            if current.has_next then
                rows[PAGE_SIZE + 1] = nil
            end
            current.rows = {}
            for _, row in ipairs(rows) do
                if type(row) == "table"
                        and type(row.username) == "string"
                        and type(row.schema) == "table"
                        and type(row.schema.name) == "string" then
                    table.insert(current.rows, row)
                end
            end
            safe_render(name, "catalogue response")
        end)
        if not handled then
            minetest.log("error", "[classrooms_bridge] BlockExchange catalogue callback failed: "
                .. tostring(callback_error))
            notify(name, S("The catalogue response could not be processed. The error was logged."),
                "#FF5555")
        end
    end)
end

-- Placement review. A freshly built structure stays provisional: the terrain
-- it replaced is kept in memory so the teacher can rotate the structure around
-- its start corner, or undo the placement, before confirming it. While
-- reviewing, the hotbar is replaced by five tools (like the zone editor) so
-- the teacher can walk around the result; the inventory and hotbar are saved
-- in player meta and restored on exit, on leave, and on the next join after a
-- crash.
local REVIEW_MAX_VOLUME = 1000000
local REVIEW_META_KEY = "classrooms_bx_review"
local REVIEW_ITEM_PREFIX = "classrooms_bridge:bx_review_"
local REVIEW_HOTBAR = "[combine:102x22"
    .. ":0,0=classrooms_bridge_hotbar_slot_mcl.png:20,0=classrooms_bridge_hotbar_slot_mcl.png"
    .. ":40,0=classrooms_bridge_hotbar_slot_mcl.png:60,0=classrooms_bridge_hotbar_slot_mcl.png"
    .. ":80,0=classrooms_bridge_hotbar_slot_mcl.png"
local REVIEW_TOOLS = {
    { id = "rotate_left", desc = S("Rotate −90°"), tip = S("Turns the structure counter-clockwise"),
        texture = "classrooms_bridge_bx_rotate_left.png" },
    { id = "rotate_half", desc = S("Rotate 180°"), tip = S("Turns the structure around"),
        texture = "classrooms_bridge_bx_rotate_half.png" },
    { id = "rotate_right", desc = S("Rotate +90°"), tip = S("Turns the structure clockwise"),
        texture = "classrooms_bridge_bx_rotate_right.png" },
    { id = "undo", desc = S("Undo"), tip = S("Removes the structure and restores the area"),
        texture = "classrooms_bridge_zone_cancel.png" },
    { id = "confirm", desc = S("Save and confirm"), tip = S("Keeps the structure as it is now"),
        texture = "classrooms_bridge_zone_confirm.png" },
}
-- sessions[player] = { state = "loading"|"review", pmin, label, rotation,
--                      snapshot = box, structure = box, huds }
local sessions = {}
local c_air = minetest.get_content_id("air")
local c_ignore = minetest.get_content_id("ignore")

-- Reads a box of the map into flat arrays ordered z, y, x.
local function read_box(pmin, size)
    local pmax = vector.add(pmin, vector.subtract(size, 1))
    local vm = minetest.get_voxel_manip()
    local emin, emax = vm:read_from_map(pmin, pmax)
    local area = VoxelArea:new({ MinEdge = emin, MaxEdge = emax })
    local vdata, vparam2 = vm:get_data(), vm:get_param2_data()
    local data, param2, n = {}, {}, 0
    for z = pmin.z, pmax.z do
        for y = pmin.y, pmax.y do
            local vi = area:index(pmin.x, y, z)
            for _ = 1, size.x do
                n = n + 1
                data[n], param2[n] = vdata[vi], vparam2[vi]
                vi = vi + 1
            end
        end
    end
    local metas = {}
    for _, pos in ipairs(minetest.find_nodes_with_meta(pmin, pmax)) do
        table.insert(metas, {
            pos = vector.subtract(pos, pmin),
            meta = minetest.get_meta(pos):to_table(),
        })
    end
    return { size = size, data = data, param2 = param2, metas = metas }
end

local function write_box(pmin, box)
    local size = box.size
    local pmax = vector.add(pmin, vector.subtract(size, 1))
    local vm = minetest.get_voxel_manip()
    local emin, emax = vm:read_from_map(pmin, pmax)
    local area = VoxelArea:new({ MinEdge = emin, MaxEdge = emax })
    local vdata, vparam2 = vm:get_data(), vm:get_param2_data()
    local n = 0
    for z = pmin.z, pmax.z do
        for y = pmin.y, pmax.y do
            local vi = area:index(pmin.x, y, z)
            for _ = 1, size.x do
                n = n + 1
                local id = box.data[n]
                vdata[vi] = id == c_ignore and c_air or id
                vparam2[vi] = box.param2[n]
                vi = vi + 1
            end
        end
    end
    vm:set_data(vdata)
    vm:set_param2_data(vparam2)
    vm:write_to_map(true)
    vm:update_liquids()

    for _, pos in ipairs(minetest.find_nodes_with_meta(pmin, pmax)) do
        minetest.get_meta(pos):from_table(nil)
    end
    for _, entry in ipairs(box.metas) do
        minetest.get_meta(vector.add(pmin, entry.pos)):from_table(entry.meta)
    end
end

-- Quarter turns are clockwise seen from above: +z -> +x -> -z -> -x.
local function rotate_xz(x, z, sx, sz, turns)
    if turns == 1 then
        return z, sx - 1 - x
    elseif turns == 2 then
        return sx - 1 - x, sz - 1 - z
    elseif turns == 3 then
        return sz - 1 - z, x
    end
    return x, z
end

local FACEDIR_AXIS_CW = { [1] = 3, [3] = 2, [2] = 4, [4] = 1 }
local WALLMOUNTED_CW = { [4] = 2, [2] = 5, [5] = 3, [3] = 4 }
local PARAM2_KINDS = {
    facedir = "facedir", colorfacedir = "facedir",
    ["4dir"] = "4dir", color4dir = "4dir",
    wallmounted = "wallmounted", colorwallmounted = "wallmounted",
}
local param2_kind_cache = {}

local function param2_kind(id)
    local kind = param2_kind_cache[id]
    if kind == nil then
        local def = minetest.registered_nodes[minetest.get_name_from_content_id(id)]
        kind = def and PARAM2_KINDS[def.paramtype2] or false
        param2_kind_cache[id] = kind
    end
    return kind
end

local function rotate_param2(id, param2, turns)
    local kind = turns ~= 0 and param2_kind(id)
    if not kind then
        return param2
    elseif kind == "facedir" then
        local facedir = param2 % 32
        local axis, rot = math.floor(facedir / 4), facedir % 4
        if axis == 0 then
            rot = (rot + turns) % 4
        elseif axis == 5 then
            rot = (rot - turns) % 4
        else
            for _ = 1, turns do
                axis = FACEDIR_AXIS_CW[axis] or axis
            end
        end
        return param2 - facedir + axis * 4 + rot
    elseif kind == "4dir" then
        local dir = param2 % 4
        return param2 - dir + (dir + turns) % 4
    end
    local wall = param2 % 8
    local turned = wall
    for _ = 1, turns do
        turned = WALLMOUNTED_CW[turned] or turned
    end
    return param2 - wall + turned
end

-- The terrain snapshot with the structure laid over it in its current rotation.
local function compose(session)
    local snap, st, turns = session.snapshot, session.structure, session.rotation
    local side, sy = snap.size.x, snap.size.y
    local sx, sz = st.size.x, st.size.z
    local data, param2 = table.copy(snap.data), table.copy(snap.param2)
    local covered, n = {}, 0
    for z = 0, sz - 1 do
        for y = 0, sy - 1 do
            for x = 0, sx - 1 do
                n = n + 1
                if st.parts[st.part_of(x, y, z)] then
                    local rx, rz = rotate_xz(x, z, sx, sz, turns)
                    local i = (rz * sy + y) * side + rx + 1
                    data[i] = st.data[n]
                    param2[i] = rotate_param2(st.data[n], st.param2[n], turns)
                    covered[i] = true
                end
            end
        end
    end

    local metas = {}
    for _, entry in ipairs(snap.metas) do
        if not covered[(entry.pos.z * sy + entry.pos.y) * side + entry.pos.x + 1] then
            table.insert(metas, entry)
        end
    end
    for _, entry in ipairs(st.metas) do
        local rx, rz = rotate_xz(entry.pos.x, entry.pos.z, sx, sz, turns)
        table.insert(metas, { pos = vector.new(rx, entry.pos.y, rz), meta = entry.meta })
    end
    return { size = snap.size, data = data, param2 = param2, metas = metas }
end

local function update_review_hud(player, session)
    local lines = {
        S("STRUCTURE REVIEW: @1", session.label),
        S("Rotation: @1°", tostring(session.rotation * 90)),
        S("Walk around and use the tools below. Confirm to keep it, Undo to remove it."),
    }
    if not session.huds then
        session.huds = {}
        for i, text in ipairs(lines) do
            session.huds[i] = player:hud_add({
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
            player:hud_change(session.huds[i], "text", text)
        end
    end
end

local function save_review_inventory(player)
    local main = {}
    for i, stack in ipairs(player:get_inventory():get_list("main") or {}) do
        -- Classroom tools are re-granted by the toolbar; don't duplicate them.
        main[i] = toolbar.is_tool_item(stack:get_name()) and "" or stack:to_string()
    end
    player:get_meta():set_string(REVIEW_META_KEY, minetest.write_json({
        main = main,
        hotbar = player:hud_get_hotbar_itemcount(),
        image = player:hud_get_hotbar_image(),
    }))
end

-- `skip_hud` leaves the hotbar alone (leaving players, or a fresh join where
-- the game rebuilds it).
local function restore_review_inventory(player, skip_hud)
    local meta = player:get_meta()
    local raw = meta:get_string(REVIEW_META_KEY)
    if raw == "" then return end
    meta:set_string(REVIEW_META_KEY, "")
    local ok, saved = pcall(minetest.parse_json, raw)
    if not ok or type(saved) ~= "table" then return end

    local inv = player:get_inventory()
    for i = 1, inv:get_size("main") do
        inv:set_stack("main", i, ItemStack(saved.main and saved.main[i] or ""))
    end
    if not skip_hud then
        if tonumber(saved.hotbar) then
            player:hud_set_hotbar_itemcount(tonumber(saved.hotbar))
        end
        if type(saved.image) == "string" and saved.image ~= "" then
            player:hud_set_hotbar_image(saved.image)
        end
    end
end

local function fill_review_tools(player)
    local inv = player:get_inventory()
    for i = 1, inv:get_size("main") do
        local tool = REVIEW_TOOLS[i]
        local stack = ItemStack(tool and (REVIEW_ITEM_PREFIX .. tool.id) or "")
        if tool then
            -- Changing metadata forces the multiserver proxy to resend the
            -- slot, undoing any client-side drop prediction.
            local current = inv:get_stack("main", i)
            stack:get_meta():set_int("sync", 1 - current:get_meta():get_int("sync"))
        end
        inv:set_stack("main", i, stack)
    end
end

-- Removes review tools left in an inventory outside a review.
local function purge_review_items(player)
    local inv = player:get_inventory()
    if not inv then return end
    for _, list in ipairs({ "main", "craft", "offhand" }) do
        for i = 1, inv:get_size(list) do
            if inv:get_stack(list, i):get_name():sub(1, #REVIEW_ITEM_PREFIX) == REVIEW_ITEM_PREFIX then
                inv:set_stack(list, i, "")
            end
        end
    end
end

local function enter_review_mode(player, session)
    local name = player:get_player_name()
    toolbar.set_suspended(name, true)
    save_review_inventory(player)
    fill_review_tools(player)
    player:hud_set_hotbar_itemcount(#REVIEW_TOOLS)
    player:hud_set_hotbar_image(REVIEW_HOTBAR)
    update_review_hud(player, session)
end

-- Ends the session, keeping the map as it currently is.
local function leave_review_mode(player, is_leaving)
    local name = player:get_player_name()
    local session = sessions[name]
    sessions[name] = nil
    if not session or session.state ~= "review" then return end
    if session.huds and not is_leaving then
        for _, id in ipairs(session.huds) do
            player:hud_remove(id)
        end
    end
    restore_review_inventory(player, is_leaving)
    toolbar.set_suspended(name, false)
    if not is_leaving then
        toolbar.ensure(player)
    end
end

-- Snapshots the terrain every rotation of the structure can touch. Returns nil
-- when the structure is too large to keep in memory.
local function begin_review(name, pos1, schema, review_label)
    local sx = math.floor(tonumber(schema.size_x) or 0)
    local sy = math.floor(tonumber(schema.size_y) or 0)
    local sz = math.floor(tonumber(schema.size_z) or 0)
    local side = math.max(sx, sz)
    if sx < 1 or sy < 1 or sz < 1 or side * side * sy > REVIEW_MAX_VOLUME then
        return nil
    end

    local session = {
        state = "loading",
        pmin = vector.new(pos1),
        label = review_label,
        rotation = 0,
        snapshot = read_box(pos1, vector.new(side, sy, side)),
    }
    sessions[name] = session
    return session
end

-- Captures the structure BlockExchange just placed and opens the review menu.
local function start_review(name, session, schema)
    local player = minetest.get_player_by_name(name)
    if not player then
        sessions[name] = nil
        return
    end
    local snap = session.snapshot
    local size = vector.new(schema.size_x, schema.size_y, schema.size_z)
    if size.y ~= snap.size.y or math.max(size.x, size.z) > snap.size.x then
        sessions[name] = nil
        return
    end

    local st = read_box(session.pmin, size)
    -- BlockExchange writes whole 16-node parts and skips empty ones; parts it
    -- left untouched keep showing the terrain instead of moving with the build.
    st.part_of = function(x, y, z)
        return (math.floor(z / 16) * 64 + math.floor(y / 16)) * 64 + math.floor(x / 16)
    end
    st.parts = {}
    local side, n = snap.size.x, 0
    for z = 0, size.z - 1 do
        for y = 0, size.y - 1 do
            for x = 0, size.x - 1 do
                n = n + 1
                local i = (z * size.y + y) * side + x + 1
                if st.data[n] ~= snap.data[i] or st.param2[n] ~= snap.param2[i] then
                    st.parts[st.part_of(x, y, z)] = true
                end
            end
        end
    end
    session.structure = st
    session.state = "review"
    enter_review_mode(player, session)
end

local function rotate_review(name, turns)
    local session = sessions[name]
    local rotation = (session.rotation + turns) % 4
    local st = session.structure
    local sx, sz = st.size.x, st.size.z
    if rotation % 2 == 1 then
        sx, sz = sz, sx
    end
    local pmax = vector.add(session.pmin, vector.new(sx - 1, st.size.y - 1, sz - 1))
    if minetest.is_area_protected(session.pmin, pmax, name) then
        notify(name, S("The rotated structure would overlap a protected area."), "#FF9900")
        return
    end
    session.rotation = rotation
    write_box(session.pmin, compose(session))
end

local function use_review_tool(id, user)
    if not user or not user:is_player() then return end
    local name = user:get_player_name()
    local session = sessions[name]
    if not session or session.state ~= "review" then
        purge_review_items(user)
        return
    end

    local handled, review_error = pcall(function()
        if id == "confirm" then
            leave_review_mode(user)
            notify(name, S("Structure confirmed."), "#00CC66")
        elseif id == "undo" then
            write_box(session.pmin, session.snapshot)
            leave_review_mode(user)
            notify(name, S("Placement undone; the area was restored."), "#00CC66")
        else
            rotate_review(name, id == "rotate_left" and 3 or id == "rotate_half" and 2 or 1)
            update_review_hud(user, session)
        end
    end)
    if not handled then
        minetest.log("error", "[classrooms_bridge] BlockExchange review failed: " .. tostring(review_error))
        notify(name, S("The review could not be completed. The error was logged."), "#FF5555")
    end
end

for _, tool in ipairs(REVIEW_TOOLS) do
    minetest.register_craftitem(REVIEW_ITEM_PREFIX .. tool.id, {
        description = tool.desc .. "\n" .. minetest.colorize("#aaaaaa", tool.tip),
        inventory_image = tool.texture,
        wield_image = tool.texture,
        stack_max = 1,
        range = 0,
        groups = { not_in_creative_inventory = 1 },
        -- Return nothing: Undo/Confirm restore the inventory inside the
        -- callback, and a returned stack would be written back into the
        -- wielded slot afterwards, leaving the tool behind.
        on_use = function(_, user)
            use_review_tool(tool.id, user)
        end,
        on_place = function(_, user)
            use_review_tool(tool.id, user)
        end,
        on_secondary_use = function(_, user)
            use_review_tool(tool.id, user)
        end,
        on_drop = function(itemstack, dropper)
            local session = dropper and dropper:is_player() and sessions[dropper:get_player_name()]
            if not session or session.state ~= "review" or dropper:get_hp() <= 0 then
                return ItemStack("")
            end
            return itemstack
        end,
    })
end

local function is_reviewing(name)
    local session = sessions[name]
    return session ~= nil and session.state == "review"
end

minetest.register_allow_player_inventory_action(function(player, action)
    local name = player:get_player_name()
    if is_reviewing(name) then
        if action == "take" or action == "move" then
            minetest.after(0, function()
                local current = minetest.get_player_by_name(name)
                if current and is_reviewing(name) then
                    fill_review_tools(current)
                end
            end)
        end
        return 0
    end
end)

-- Q on a review tool: the engine already refuses it through on_drop; refresh
-- the slots so the client shows the tool again.
local review_tick = 0
minetest.register_globalstep(function(dtime)
    review_tick = review_tick + dtime
    if review_tick < 1 then return end
    review_tick = 0
    for name in pairs(sessions) do
        local player = is_reviewing(name) and minetest.get_player_by_name(name)
        if player then
            local inv = player:get_inventory()
            for i, tool in ipairs(REVIEW_TOOLS) do
                if inv:get_stack("main", i):get_name() ~= REVIEW_ITEM_PREFIX .. tool.id then
                    fill_review_tools(player)
                    break
                end
            end
        end
    end
end)

minetest.register_on_leaveplayer(function(player)
    leave_review_mode(player, true)
end)

-- Crash recovery (a review that never finished) and cleanup of stray tools.
minetest.register_on_joinplayer(function(player)
    local name = player:get_player_name()
    minetest.after(0.5, function()
        local current = minetest.get_player_by_name(name)
        if not current or is_reviewing(name) then return end
        if current:get_meta():get_string(REVIEW_META_KEY) ~= "" then
            restore_review_inventory(current, true)
        end
        purge_review_items(current)
    end)
end)

local function open_browser(user)
    if not user or not user:is_player() then return end
    local name = user:get_player_name()
    if not access[name] then return end

    if sessions[name] then
        notify(name, is_reviewing(name) and S("Finish reviewing the placed structure first.")
            or S("The structure is still being built."), "#FF9900")
        return
    end

    views[name] = {
        page = 0,
        query = "",
        rows = {},
        loading = false,
        has_next = false,
    }
    if bx_available() and http then
        fetch_rows(name)
    else
        safe_render(name, "open")
    end
end

local function selected_structure(name)
    local view = views[name]
    if not view then return nil end
    return view.rows[view.selected or 0]
end

-- Fetches the preview of the selected structure; the result is shared by
-- every player browsing the library.
local function request_preview(name)
    local selected = selected_structure(name)
    local key = http and selected and preview_key(selected.schema)
    if not key then return end

    local entry = previews[key]
    if entry and entry.state == "loading" then
        entry.waiters[name] = true
        return
    elseif entry and (entry.state == "ready"
            or os.time() - entry.at < PREVIEW_RETRY_SECONDS) then
        return
    end

    if not entry then
        if preview_count >= PREVIEW_CACHE_SIZE then
            previews, preview_count = {}, 0
        end
        preview_count = preview_count + 1
    end
    entry = { state = "loading", waiters = { [name] = true } }
    previews[key] = entry

    local function finish(state)
        entry.state = state
        entry.at = os.time()
        local waiters = entry.waiters
        entry.waiters = nil
        for waiter in pairs(waiters) do
            local view = views[waiter]
            local current = view and view.tab ~= "share" and view.rows[view.selected or 0]
            if current and preview_key(current.schema) == key then
                safe_render(waiter, "preview")
            end
        end
    end

    http.fetch({
        url = ("%s/api/schema/%s/screenshot?width=%d&height=%d"):format(
            EXCHANGE_URL, selected.schema.uid, PREVIEW_PIXELS, PREVIEW_PIXELS),
        timeout = 15,
    }, function(result)
        local handled, callback_error = pcall(function()
            local data = result.succeeded and result.code == 200 and result.data
            -- A PNG starts with its signature, then the IHDR chunk whose first
            -- two fields are the big-endian width and height.
            if type(data) ~= "string" or #data < 24 or data:sub(1, 8) ~= PNG_SIGNATURE then
                finish("missing")
                return
            end
            local b = { data:byte(17, 24) }
            entry.w = ((b[1] * 256 + b[2]) * 256 + b[3]) * 256 + b[4]
            entry.h = ((b[5] * 256 + b[6]) * 256 + b[7]) * 256 + b[8]
            if entry.w < 1 or entry.h < 1 then
                finish("missing")
                return
            end
            entry.texture = "[png:" .. minetest.encode_base64(data)
            finish("ready")
        end)
        if not handled then
            minetest.log("error", "[classrooms_bridge] BlockExchange preview callback failed: "
                .. tostring(callback_error))
            entry.state, entry.at, entry.waiters = "missing", os.time(), nil
        end
    end)
end

local function set_origin(name)
    local player = minetest.get_player_by_name(name)
    if not player then return end

    local pos = vector.round(player:get_pos())
    blockexchange.set_pos(1, name, pos)
    notify(name, S("Origin set to @1.", minetest.pos_to_string(pos)), "#00CC66")
end

local function allocate(name, selected)
    local pos1 = blockexchange.get_pos and blockexchange.get_pos(1, name)
    if not pos1 then
        notify(name, S("Set the origin before allocating a structure."), "#FF9900")
        return
    end

    notify(name, S("Checking @1…", selected.username .. "/" .. selected.schema.name))
    blockexchange.allocate(name, pos1, selected.username, selected.schema.name)
        :next(function(result)
            local message = S("Allocation fits from origin; size @1.", format_size(result.schema))
            if result.missing_mods and result.missing_mods ~= "" then
                message = message .. " " .. S("Missing mods: @1", result.missing_mods)
                notify(name, message, "#FF9900")
            else
                notify(name, message, "#00CC66")
            end
        end)
        :catch(function(err)
            notify(name, S("Allocation failed: @1", tostring(err)), "#FF5555")
        end)
end

-- Returns true when the build is under review and the library should close.
local function load_structure(name, selected)
    local pos1 = blockexchange.get_pos and blockexchange.get_pos(1, name)
    if not pos1 then
        notify(name, S("Set the origin before loading a structure."), "#FF9900")
        return false
    end
    if sessions[name] then
        notify(name, S("Finish reviewing the placed structure first."), "#FF9900")
        return false
    end

    local structure_label = selected.username .. "/" .. selected.schema.name
    local session = begin_review(name, pos1, selected.schema, structure_label)
    if not session then
        notify(name, S("This structure is too large to rotate or undo; it is being built directly."),
            "#FF9900")
    end
    notify(name, S("Loading @1. Progress appears in the BlockExchange HUD.", structure_label))
    blockexchange.load(name, pos1, selected.username, selected.schema.name)
        :next(function(result)
            notify(name, S("Load complete (@1 parts).",
                tostring(result.schema.total_parts or 0)), "#00CC66")
            if session and sessions[name] == session then
                start_review(name, session, result.schema)
            end
        end)
        :catch(function(err)
            notify(name, S("Load failed: @1", tostring(err)), "#FF5555")
            if session and sessions[name] == session then
                sessions[name] = nil
                if session.state == "loading" then
                    write_box(session.pmin, session.snapshot)
                    notify(name, S("Placement undone; the area was restored."), "#FF9900")
                end
            end
        end)
    return session ~= nil
end

local function login(name, username, access_token)
    local view = views[name]
    if not view or view.login_pending then return end

    username = tostring(username or ""):match("^%s*(.-)%s*$")
    access_token = tostring(access_token or ""):match("^%s*(.-)%s*$")
    view.login_username = username
    if username == "" or access_token == "" then
        view.login_status = S("Enter both your BlockExchange username and access token.")
        safe_render(name, "login validation")
        return
    end

    view.login_pending = true
    view.login_status = S("Signing in…")
    safe_render(name, "login start")

    blockexchange.api.get_token(username, access_token)
        :next(function(token)
            local current = views[name]
            if not current or not access[name] then return end

            local claims = blockexchange.parse_token(token)
            if not claims or not claims.user_uid or not claims.username then
                current.login_pending = false
                current.login_status = S("BlockExchange returned an invalid login token.")
                safe_render(name, "login response")
                return
            end

            local settings = blockexchange.get_player_settings(name)
            settings.token = token
            blockexchange.set_player_settings(name, settings)
            current.login_pending = false
            current.login_status = nil
            notify(name, S("Signed in as @1.", claims.username), "#00CC66")
            safe_render(name, "login success")
        end)
        :catch(function(err)
            local current = views[name]
            if current then
                current.login_pending = false
                current.login_status = S("Sign-in failed: @1", tostring(err))
                safe_render(name, "login failure")
            end
        end)
end

local function logout(name)
    local settings = blockexchange.get_player_settings(name)
    settings.token = nil
    blockexchange.set_player_settings(name, settings)
    local view = views[name]
    if view then
        view.login_status = S("Signed out.")
    end
    notify(name, S("Signed out."), "#00CC66")
end

local function set_corner(name, corner)
    local player = minetest.get_player_by_name(name)
    if not player then return end

    local pos = vector.round(player:get_pos())
    blockexchange.set_pos(corner, name, pos)
    notify(name, S("Corner @1 set to @2.", corner, minetest.pos_to_string(pos)),
        "#00CC66")
end

local function upload_structure(name, schema_name)
    local view = views[name]
    if not view or view.uploading then return end

    schema_name = tostring(schema_name or ""):match("^%s*(.-)%s*$")
    view.schema_name = schema_name

    if not claims_for(name) then
        view.upload_status = S("Sign in to BlockExchange before uploading.")
        safe_render(name, "upload validation")
        return
    end
    if not blockexchange.validate_name(schema_name) then
        view.upload_status =
            S("Names may contain only letters, numbers, hyphens, underscores, and periods.")
        safe_render(name, "upload validation")
        return
    end

    local pos1 = blockexchange.get_pos and blockexchange.get_pos(1, name)
    local pos2 = blockexchange.get_pos and blockexchange.get_pos(2, name)
    if not pos1 or not pos2 then
        view.upload_status = S("Set both opposite corners before uploading.")
        safe_render(name, "upload validation")
        return
    end
    if not blockexchange.check_size(pos1, pos2) then
        view.upload_status = S("The selected volume exceeds BlockExchange's @1-node axis limit.",
            tostring(blockexchange.max_size))
        safe_render(name, "upload validation")
        return
    end

    view.uploading = true
    view.upload_status = S("Uploading @1…", schema_name)
    safe_render(name, "upload start")
    notify(name, S("Uploading @1. Progress appears in the BlockExchange HUD.", schema_name))

    blockexchange.save(name, pos1, pos2, schema_name)
        :next(function(result)
            local current = views[name]
            if current then
                current.uploading = false
                current.upload_status = S("Published @1 with @2 parts (@3 bytes).", schema_name,
                    tostring(result.total_parts or 0), tostring(result.total_size or 0))
                safe_render(name, "upload success")
            end
            notify(name, S("Published @1 successfully.", schema_name), "#00CC66")
        end)
        :catch(function(err)
            local current = views[name]
            if current then
                current.uploading = false
                current.upload_status = S("Upload failed: @1", tostring(err))
                safe_render(name, "upload failure")
            end
            notify(name, S("Upload failed: @1", tostring(err)), "#FF5555")
        end)
end

minetest.register_craftitem(ITEM_NAME, {
    description = S("BlockExchange Library") .. "\n"
        .. minetest.colorize("#aaaaaa", S("Use to place shared structures or share your builds")),
    inventory_image = "classrooms_bridge_blockexchange.png",
    wield_image = "classrooms_bridge_blockexchange.png",
    stack_max = 1,
    groups = { not_in_creative_inventory = 1 },
    on_place = function(itemstack, placer)
        open_browser(placer)
        return itemstack
    end,
    on_use = function(itemstack, user)
        open_browser(user)
        return itemstack
    end,
    on_secondary_use = function(itemstack, user)
        open_browser(user)
        return itemstack
    end,
    on_drop = toolbar.on_drop,
})
toolbar.register_tool(TOOL_ID, ITEM_NAME, 2)

minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= FORM_NAME then return false end
    local name = player:get_player_name()
    if not access[name] then return true end

    local view = views[name]
    if not view then return true end

    if fields.bx_close or fields.quit then
        views[name] = nil
        return true
    end

    if fields.bx_tab_share then
        view.tab = "share"
        safe_render(name, "share tab")
        return true
    elseif fields.bx_tab_browse then
        view.tab = "browse"
        if #view.rows == 0 and bx_available() and http then
            fetch_rows(name)
        else
            safe_render(name, "browse tab")
        end
        return true
    end

    if view.tab == "share" then
        if fields.bx_schema_name ~= nil then
            view.schema_name = fields.bx_schema_name
        end
        if fields.bx_login_username ~= nil then
            view.login_username = fields.bx_login_username
        end

        if fields.bx_login then
            login(name, fields.bx_login_username, fields.bx_access_token)
            return true
        elseif fields.bx_logout then
            logout(name)
        elseif fields.bx_pos1 then
            set_corner(name, 1)
        elseif fields.bx_pos2 then
            set_corner(name, 2)
        elseif fields.bx_upload then
            upload_structure(name, fields.bx_schema_name)
            return true
        end

        safe_render(name, "share field handling")
        return true
    end

    if fields.bx_structures then
        local event = minetest.explode_table_event(fields.bx_structures)
        if event.type == "CHG" or event.type == "DCL" then
            view.selected = event.row
            request_preview(name)
        end
    end

    if fields.bx_search or fields.key_enter_field == "bx_query" then
        view.query = tostring(fields.bx_query or ""):match("^%s*(.-)%s*$")
        view.page = 0
        fetch_rows(name)
        return true
    elseif fields.bx_refresh then
        fetch_rows(name)
        return true
    elseif fields.bx_prev and view.page > 0 then
        view.page = view.page - 1
        fetch_rows(name)
        return true
    elseif fields.bx_next and view.has_next then
        view.page = view.page + 1
        fetch_rows(name)
        return true
    elseif fields.bx_origin then
        if bx_available() then
            set_origin(name)
        else
            notify(name, S("The BlockExchange mod is unavailable."), "#FF5555")
        end
    elseif fields.bx_allocate or fields.bx_load then
        local selected = selected_structure(name)
        if not selected then
            notify(name, S("Select a structure first."), "#FF9900")
        elseif not bx_available() then
            notify(name, S("The BlockExchange mod is unavailable."), "#FF5555")
        elseif fields.bx_allocate then
            allocate(name, selected)
        elseif load_structure(name, selected) then
            minetest.close_formspec(name, FORM_NAME)
            views[name] = nil
            return true
        end
    end

    safe_render(name, "field handling")
    return true
end)

function integration.set_access(player, enabled)
    if not player or not player:is_player() then return end
    local name = player:get_player_name()
    if enabled then
        access[name] = true
        grant_upload_privilege(name)
    else
        access[name] = nil
        views[name] = nil
        leave_review_mode(player)
        restore_upload_privilege(name)
    end
    toolbar.set_enabled(player, TOOL_ID, enabled)
end

function integration.clear_player(name)
    access[name] = nil
    views[name] = nil
    sessions[name] = nil
    restore_upload_privilege(name)
end

return integration
