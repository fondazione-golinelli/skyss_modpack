-- Teacher-facing BlockExchange browser and placement controls.
--
-- Access is granted only by the classrooms proxy. The official BlockExchange
-- mod still owns position markers, allocation checks, downloads, HUD progress,
-- and schematic placement.

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
    label(fs, 0.4, 0.35, "BlockExchange Library")
    table.insert(fs, "style[bx_home_link;font_size=15]")
    table.insert(fs, "hypertext[0.38,0.55;6.5,0.45;bx_home_link;"
        .. "<global background=none margin=0 color=#8fb8de hovercolor=#c5dcf0>"
        .. "<action name=home url='" .. esc(EXCHANGE_URL) .. "'><u>"
        .. esc(EXCHANGE_URL) .. "</u></action>]")
    table.insert(fs, "image_button_exit[12.35,0.2;0.65,0.65;clear.png;bx_close;]")
    table.insert(fs, "tooltip[bx_close;Close]")

    local sharing = view.tab == "share"
    styled_button(fs, 0.35, 1.3, 3.2, 0.62, "bx_tab_browse", "Find & place",
        sharing and C.tab_idle or C.accent)
    styled_button(fs, 3.65, 1.3, 3.2, 0.62, "bx_tab_share", "Share a build",
        sharing and C.accent or C.tab_idle)

    if sharing then
        local claims = claims_for(name)
        if not claims or not claims.username then
            table.insert(fs, "box[0.35,2.2;12.5,3.1;" .. C.card .. "]")
            label(fs, 0.65, 2.55, "To share builds, connect your BlockExchange account once.")
            step_badge(fs, 0.65, 3.0, 1, false)
            label(fs, 1.4, 3.28, "Open your profile and create an access token.")
            table.insert(fs, ("style[bx_profile;bgcolor=%s]"):format(C.button))
            table.insert(fs, "button_url[9.3,2.95;3.3,0.62;bx_profile;Open my profile;"
                .. esc(EXCHANGE_URL .. "/profile") .. "]")
            step_badge(fs, 0.65, 3.95, 2, false)
            label(fs, 1.4, 4.23, "Enter your BlockExchange username and the token.")
            label(fs, 1.4, 4.7, "Your game name and BlockExchange name may differ.", C.muted)

            table.insert(fs, "box[0.35,5.5;12.5,1.6;" .. C.card .. "]")
            table.insert(fs, "field[0.65,6.15;4.6,0.65;bx_login_username;BlockExchange username;"
                .. esc(view.login_username or "") .. "]")
            table.insert(fs, "pwdfield[5.45,6.15;4.2,0.65;bx_access_token;Access token]")
            styled_button(fs, 9.85, 6.15, 2.75, 0.65, "bx_login", "Sign in", C.primary)
            if view.login_status then
                table.insert(fs, "textarea[0.65,7.35;12.0,1.0;;;" .. esc(view.login_status) .. "]")
            end
            label(fs, 0.65, 9.9, "The token is exchanged for a session and never stored.", C.muted)
        else
            local pos1 = blockexchange.get_pos and blockexchange.get_pos(1, name)
            local pos2 = blockexchange.get_pos and blockexchange.get_pos(2, name)

            label(fs, 7.3, 1.61, "Signed in as " .. claims.username, C.muted)
            icon_button(fs, 12.2, 1.3, 0.62, "bx_logout", "clear.png", "Sign out")

            -- Step 1: corners.
            table.insert(fs, "box[0.35,2.2;12.5,2.75;" .. C.card .. "]")
            step_badge(fs, 0.65, 2.45, 1, pos1 ~= nil and pos2 ~= nil)
            label(fs, 1.4, 2.73, "Stand on two opposite corners of your build and mark them.")
            styled_button(fs, 0.65, 3.25, 2.9, 0.65, "bx_pos1", "Mark corner 1")
            label(fs, 3.75, 3.58, pos1 and minetest.pos_to_string(pos1) or "not set",
                pos1 and C.ok or C.muted)
            styled_button(fs, 6.55, 3.25, 2.9, 0.65, "bx_pos2", "Mark corner 2")
            label(fs, 9.65, 3.58, pos2 and minetest.pos_to_string(pos2) or "not set",
                pos2 and C.ok or C.muted)
            if pos1 and pos2 then
                label(fs, 0.65, 4.45, "Selected size: " .. format_size({
                    size_x = math.abs(pos2.x - pos1.x) + 1,
                    size_y = math.abs(pos2.y - pos1.y) + 1,
                    size_z = math.abs(pos2.z - pos1.z) + 1,
                }) .. " blocks", C.muted)
            end

            -- Step 2: name.
            local named = (view.schema_name or "") ~= ""
            table.insert(fs, "box[0.35,5.15;12.5,1.55;" .. C.card .. "]")
            step_badge(fs, 0.65, 5.4, 2, named)
            label(fs, 1.4, 5.68, "Give it a name (letters, numbers, - _ .)")
            table.insert(fs, "field[1.4,5.95;11.2,0.6;bx_schema_name;;"
                .. esc(view.schema_name or "") .. "]")
            table.insert(fs, "field_close_on_enter[bx_schema_name;false]")

            -- Step 3: publish.
            table.insert(fs, "box[0.35,6.9;12.5,1.25;" .. C.card .. "]")
            step_badge(fs, 0.65, 7.25, 3, false)
            styled_button(fs, 1.4, 7.2, 4.2, 0.7, "bx_upload", "Publish to the library", C.primary)
            table.insert(fs, ("style[bx_search_page;bgcolor=%s]"):format(C.button))
            table.insert(fs, "button_url[8.6,7.2;4.0,0.7;bx_search_page;Open web library;"
                .. esc(EXCHANGE_URL .. "/search") .. "]")

            local upload_status = view.upload_status
                or "Mark both corners, choose a name, then publish."
            if view.uploading then
                upload_status = "Uploading… follow the progress bar on screen."
            end
            table.insert(fs, "textarea[0.35,8.4;12.5,1.6;;;" .. esc(upload_status) .. "]")
        end

        minetest.show_formspec(name, FORM_NAME, table.concat(fs))
        return
    end

    -- Find & place.
    table.insert(fs, "field[0.35,2.2;10.85,0.7;bx_query;;" .. esc(view.query) .. "]")
    table.insert(fs, "field_close_on_enter[bx_query;false]")
    table.insert(fs, "tooltip[bx_query;Type a word (e.g. house, bridge) and press Enter]")
    icon_button(fs, 11.35, 2.2, 0.7, "bx_search", "search.png", "Search")
    icon_button(fs, 12.15, 2.2, 0.7, "bx_refresh", "refresh.png", "Reload the list")

    if not bx_available() then
        table.insert(fs, "textarea[0.35,3.15;12.5,2.2;;BlockExchange unavailable;")
        table.insert(fs, esc("The official blockexchange mod must be installed, enabled, online, and configured for "
            .. EXCHANGE_URL .. "."))
        table.insert(fs, "]")
    elseif not http then
        table.insert(fs, "textarea[0.35,3.15;12.5,2.2;;Catalogue unavailable;")
        table.insert(fs, esc("Add classrooms_bridge to secure.http_mods, then restart this instance."))
        table.insert(fs, "]")
    elseif view.loading then
        table.insert(fs, "image[0.45,3.2;0.5,0.5;refresh.png]")
        label(fs, 1.15, 3.45, "Loading structures…", C.muted)
    elseif view.error then
        table.insert(fs, "textarea[0.35,3.15;12.5,1.5;;Could not load structures;")
        table.insert(fs, esc(view.error))
        table.insert(fs, "]")
    elseif #view.rows == 0 then
        label(fs, 0.45, 3.45, "No structures found. Try another word.", C.muted)
    else
        table.insert(fs, "box[0.35,3.1;12.5,0.5;#D7DDE2]")
        table.insert(fs, "label[0.5,3.35;" .. colored("#1a1a2e", "Owner") .. "]")
        table.insert(fs, "label[3.5,3.35;" .. colored("#1a1a2e", "Structure") .. "]")
        table.insert(fs, "label[8.15,3.35;" .. colored("#1a1a2e", "Size") .. "]")
        table.insert(fs, "label[10.75,3.35;" .. colored("#1a1a2e", "Downloads") .. "]")
        table.insert(fs, "tableoptions[background=#1B1B1B;border=true;highlight=#356A91;highlight_text=#FFFFFF]")
        table.insert(fs, "tablecolumns[text,width=15,padding=0.5;"
            .. "text,width=23,padding=0.5;"
            .. "text,width=13,align=center,padding=0.5;"
            .. "text,width=8,align=right,padding=0.5]")
        table.insert(fs, "table[0.35,3.65;12.5,3.2;bx_structures;")
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
    end

    icon_button(fs, 0.35, 6.95, 0.55, "bx_prev", "prev_icon.png", "Previous page")
    label(fs, 1.05, 7.22, "Page " .. tostring(view.page + 1), C.muted)
    icon_button(fs, 2.15, 6.95, 0.55, "bx_next", "next_icon.png", "Next page")

    -- Guided placement.
    local selected = view.rows[view.selected or 0]
    local origin = bx_available() and blockexchange.get_pos and blockexchange.get_pos(1, name)
    table.insert(fs, "box[0.35,7.7;12.5,2.45;" .. C.card .. "]")

    step_badge(fs, 0.6, 7.9, 1, selected ~= nil)
    label(fs, 1.3, 8.05, "Pick a structure")
    label(fs, 1.3, 8.45, selected and (selected.username .. " / " .. selected.schema.name)
        or "Click a row in the list", selected and C.ok or C.muted)

    step_badge(fs, 0.6, 9.0, 2, origin ~= nil)
    label(fs, 1.3, 9.15, "Go to the start spot")
    label(fs, 1.3, 9.55, origin and ("Start: " .. minetest.pos_to_string(origin)) or "Start not set",
        origin and C.ok or C.muted)
    styled_button(fs, 5.15, 8.95, 2.35, 0.65, "bx_origin", "Set start here")
    table.insert(fs, "tooltip[bx_origin;The structure is built from your current position]")

    step_badge(fs, 7.75, 7.9, 3, false)
    label(fs, 8.45, 8.05, "Build it")
    styled_button(fs, 8.45, 8.35, 4.15, 0.6, "bx_allocate", "Check the space")
    table.insert(fs, "tooltip[bx_allocate;Shows how big it is and whether it fits, without building]")
    styled_button(fs, 8.45, 9.05, 4.15, 0.75, "bx_load", "Build here", C.primary)

    minetest.show_formspec(name, FORM_NAME, table.concat(fs))
end

local function safe_render(name, context)
    local ok, err = pcall(render, name)
    if ok then return true end

    minetest.log("error", "[classrooms_bridge] BlockExchange form render failed"
        .. (context and " during " .. context or "") .. ": " .. tostring(err))
    notify(name, "The library could not be displayed. The error was logged.", "#FF5555")
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
                current.error = "The server returned HTTP " .. tostring(result.code or 0) .. "."
                safe_render(name, "HTTP error")
                return
            end

            local rows = minetest.parse_json(result.data)
            if type(rows) ~= "table" then
                current.rows = {}
                current.has_next = false
                current.error = "The server response was not a structure list."
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
            notify(name, "The catalogue response could not be processed. The error was logged.",
                "#FF5555")
        end
    end)
end

local function open_browser(user)
    if not user or not user:is_player() then return end
    local name = user:get_player_name()
    if not access[name] then return end

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

local function set_origin(name)
    local player = minetest.get_player_by_name(name)
    if not player then return end

    local pos = vector.round(player:get_pos())
    blockexchange.set_pos(1, name, pos)
    notify(name, "Origin set to " .. minetest.pos_to_string(pos) .. ".", "#00CC66")
end

local function allocate(name, selected)
    local pos1 = blockexchange.get_pos and blockexchange.get_pos(1, name)
    if not pos1 then
        notify(name, "Set the origin before allocating a structure.", "#FF9900")
        return
    end

    notify(name, "Checking " .. selected.username .. "/" .. selected.schema.name .. "…")
    blockexchange.allocate(name, pos1, selected.username, selected.schema.name)
        :next(function(result)
            local message = "Allocation fits from origin; size "
                .. format_size(result.schema) .. "."
            if result.missing_mods and result.missing_mods ~= "" then
                message = message .. " Missing mods: " .. result.missing_mods
                notify(name, message, "#FF9900")
            else
                notify(name, message, "#00CC66")
            end
        end)
        :catch(function(err)
            notify(name, "Allocation failed: " .. tostring(err), "#FF5555")
        end)
end

local function load_structure(name, selected)
    local pos1 = blockexchange.get_pos and blockexchange.get_pos(1, name)
    if not pos1 then
        notify(name, "Set the origin before loading a structure.", "#FF9900")
        return
    end

    notify(name, "Loading " .. selected.username .. "/" .. selected.schema.name
        .. ". Progress appears in the BlockExchange HUD.")
    blockexchange.load(name, pos1, selected.username, selected.schema.name)
        :next(function(result)
            notify(name, "Load complete (" .. tostring(result.schema.total_parts or 0)
                .. " parts).", "#00CC66")
        end)
        :catch(function(err)
            notify(name, "Load failed: " .. tostring(err), "#FF5555")
        end)
end

local function login(name, username, access_token)
    local view = views[name]
    if not view or view.login_pending then return end

    username = tostring(username or ""):match("^%s*(.-)%s*$")
    access_token = tostring(access_token or ""):match("^%s*(.-)%s*$")
    view.login_username = username
    if username == "" or access_token == "" then
        view.login_status = "Enter both your BlockExchange username and access token."
        safe_render(name, "login validation")
        return
    end

    view.login_pending = true
    view.login_status = "Signing in…"
    safe_render(name, "login start")

    blockexchange.api.get_token(username, access_token)
        :next(function(token)
            local current = views[name]
            if not current or not access[name] then return end

            local claims = blockexchange.parse_token(token)
            if not claims or not claims.user_uid or not claims.username then
                current.login_pending = false
                current.login_status = "BlockExchange returned an invalid login token."
                safe_render(name, "login response")
                return
            end

            local settings = blockexchange.get_player_settings(name)
            settings.token = token
            blockexchange.set_player_settings(name, settings)
            current.login_pending = false
            current.login_status = nil
            notify(name, "Signed in as " .. claims.username .. ".", "#00CC66")
            safe_render(name, "login success")
        end)
        :catch(function(err)
            local current = views[name]
            if current then
                current.login_pending = false
                current.login_status = "Sign-in failed: " .. tostring(err)
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
        view.login_status = "Signed out."
    end
    notify(name, "Signed out.", "#00CC66")
end

local function set_corner(name, corner)
    local player = minetest.get_player_by_name(name)
    if not player then return end

    local pos = vector.round(player:get_pos())
    blockexchange.set_pos(corner, name, pos)
    notify(name, "Corner " .. corner .. " set to " .. minetest.pos_to_string(pos) .. ".",
        "#00CC66")
end

local function upload_structure(name, schema_name)
    local view = views[name]
    if not view or view.uploading then return end

    schema_name = tostring(schema_name or ""):match("^%s*(.-)%s*$")
    view.schema_name = schema_name

    if not claims_for(name) then
        view.upload_status = "Sign in to BlockExchange before uploading."
        safe_render(name, "upload validation")
        return
    end
    if not blockexchange.validate_name(schema_name) then
        view.upload_status =
            "Names may contain only letters, numbers, hyphens, underscores, and periods."
        safe_render(name, "upload validation")
        return
    end

    local pos1 = blockexchange.get_pos and blockexchange.get_pos(1, name)
    local pos2 = blockexchange.get_pos and blockexchange.get_pos(2, name)
    if not pos1 or not pos2 then
        view.upload_status = "Set both opposite corners before uploading."
        safe_render(name, "upload validation")
        return
    end
    if not blockexchange.check_size(pos1, pos2) then
        view.upload_status = "The selected volume exceeds BlockExchange's "
            .. tostring(blockexchange.max_size) .. "-node axis limit."
        safe_render(name, "upload validation")
        return
    end

    view.uploading = true
    view.upload_status = "Uploading " .. schema_name .. "…"
    safe_render(name, "upload start")
    notify(name, "Uploading " .. schema_name .. ". Progress appears in the BlockExchange HUD.")

    blockexchange.save(name, pos1, pos2, schema_name)
        :next(function(result)
            local current = views[name]
            if current then
                current.uploading = false
                current.upload_status = "Published " .. schema_name .. " with "
                    .. tostring(result.total_parts or 0) .. " parts ("
                    .. tostring(result.total_size or 0) .. " bytes)."
                safe_render(name, "upload success")
            end
            notify(name, "Published " .. schema_name .. " successfully.", "#00CC66")
        end)
        :catch(function(err)
            local current = views[name]
            if current then
                current.uploading = false
                current.upload_status = "Upload failed: " .. tostring(err)
                safe_render(name, "upload failure")
            end
            notify(name, "Upload failed: " .. tostring(err), "#FF5555")
        end)
end

minetest.register_craftitem(ITEM_NAME, {
    description = "BlockExchange Library\n" .. minetest.colorize("#aaaaaa", "Use to place shared structures or share your builds"),
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
            notify(name, "The BlockExchange mod is unavailable.", "#FF5555")
        end
    elseif fields.bx_allocate or fields.bx_load then
        local selected = selected_structure(name)
        if not selected then
            notify(name, "Select a structure first.", "#FF9900")
        elseif not bx_available() then
            notify(name, "The BlockExchange mod is unavailable.", "#FF5555")
        elseif fields.bx_allocate then
            allocate(name, selected)
        else
            load_structure(name, selected)
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
        restore_upload_privilege(name)
    end
    toolbar.set_enabled(player, TOOL_ID, enabled)
end

function integration.clear_player(name)
    access[name] = nil
    views[name] = nil
    restore_upload_privilege(name)
end

return integration
