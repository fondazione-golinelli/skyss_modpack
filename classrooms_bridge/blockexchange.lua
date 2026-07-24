-- Teacher-facing BlockExchange browser and placement controls.
--
-- Access is granted only by the classrooms proxy. The official BlockExchange
-- mod still owns position markers, allocation checks, downloads, HUD progress,
-- and schematic placement.

local ITEM_NAME = "classrooms_bridge:blockexchange"
local FORM_NAME = "classrooms_bridge:blockexchange"
local ITEM_SLOT = 2
local PAGE_SIZE = 20
local EXCHANGE_URL = minetest.settings:get("classrooms.blockexchange_url")
    or minetest.settings:get("blockexchange.url")
    or "https://exchange.golinelli.live"

-- Supplied privately by init.lua, where Luanti requires request_http_api() to
-- be called directly from the mod's top-level scope.
local http = ...
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

local function remove_item(player)
    local inv = player and player:get_inventory()
    if not inv then return end

    for index = 1, inv:get_size("main") do
        if inv:get_stack("main", index):get_name() == ITEM_NAME then
            inv:set_stack("main", index, "")
        end
    end
end

local function ensure_item(player)
    if not player or not player:is_player() then return end
    local name = player:get_player_name()
    if not access[name] then return end

    local inv = player:get_inventory()
    if not inv or inv:get_size("main") < ITEM_SLOT then return end

    local target = inv:get_stack("main", ITEM_SLOT)
    if target:get_name() == ITEM_NAME then
        target:set_count(1)
        inv:set_stack("main", ITEM_SLOT, target)
        return
    end

    for index = 1, inv:get_size("main") do
        if index ~= ITEM_SLOT and inv:get_stack("main", index):get_name() == ITEM_NAME then
            inv:set_stack("main", index, target)
            inv:set_stack("main", ITEM_SLOT, ItemStack(ITEM_NAME))
            return
        end
    end

    inv:set_stack("main", ITEM_SLOT, ItemStack(ITEM_NAME))
    if not target:is_empty() then
        local leftover = inv:add_item("main", target)
        if not leftover:is_empty() then
            minetest.add_item(player:get_pos(), leftover)
        end
    end
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
        "size[13.2,9.2]",
        "bgcolor[#101820;true]",
        "label[0.45,0.45;",
        minetest.formspec_escape("BlockExchange Library"),
        "]",
        "label[0.45,0.85;",
        minetest.formspec_escape(EXCHANGE_URL),
        "]",
        "button[8.05,0.35;1.55,0.65;bx_tab_browse;Browse]",
        "button[9.75,0.35;1.55,0.65;bx_tab_share;Share]",
        "button_exit[11.5,0.35;1.25,0.65;bx_close;Close]",
    }

    if view.tab == "share" then
        table.insert(fs, "label[0.45,1.55;Share a structure]")
        local claims = claims_for(name)
        if not claims or not claims.username then
            table.insert(fs, "textarea[0.45,2.0;12.3,1.25;;;")
            table.insert(fs, minetest.formspec_escape(
                "Create an access token on your BlockExchange profile, then sign in here. "
                .. "The access token is exchanged by BlockExchange and is not stored."))
            table.insert(fs, "]")
            table.insert(fs, "field[0.45,3.55;4.0,0.65;bx_login_username;BlockExchange username;")
            table.insert(fs, minetest.formspec_escape(view.login_username or ""))
            table.insert(fs, "]")
            table.insert(fs, "pwdfield[4.7,3.55;4.0,0.65;bx_access_token;Access token]")
            table.insert(fs, "button[8.95,3.55;1.7,0.65;bx_login;Sign in]")
            table.insert(fs, "button_url[10.9,3.55;1.85,0.65;bx_profile;Open profile;")
            table.insert(fs, minetest.formspec_escape(EXCHANGE_URL .. "/profile"))
            table.insert(fs, "]")
            table.insert(fs, "textarea[0.45,4.55;12.3,1.2;;;")
            table.insert(fs, minetest.formspec_escape(
                "Your Luanti teacher name and BlockExchange username may be different. "
                .. "Use the username shown on your BlockExchange profile."))
            table.insert(fs, "]")
            if view.login_status then
                table.insert(fs, "textarea[0.45,5.8;12.3,0.8;;;")
                table.insert(fs, minetest.formspec_escape(view.login_status))
                table.insert(fs, "]")
            end
        else
            local pos1 = blockexchange.get_pos and blockexchange.get_pos(1, name)
            local pos2 = blockexchange.get_pos and blockexchange.get_pos(2, name)
            local pos1_label = pos1 and minetest.pos_to_string(pos1) or "Not set"
            local pos2_label = pos2 and minetest.pos_to_string(pos2) or "Not set"

            table.insert(fs, "label[0.45,2.05;Signed in as ")
            table.insert(fs, minetest.formspec_escape(claims.username))
            table.insert(fs, "]")
            table.insert(fs, "button[10.9,1.75;1.85,0.65;bx_logout;Sign out]")
            table.insert(fs, "button[0.45,2.75;2.2,0.65;bx_pos1;Set corner 1]")
            table.insert(fs, "label[2.9,2.98;")
            table.insert(fs, minetest.formspec_escape(pos1_label))
            table.insert(fs, "]")
            table.insert(fs, "button[0.45,3.65;2.2,0.65;bx_pos2;Set corner 2]")
            table.insert(fs, "label[2.9,3.88;")
            table.insert(fs, minetest.formspec_escape(pos2_label))
            table.insert(fs, "]")

            if pos1 and pos2 then
                local minp = vector.new(
                    math.min(pos1.x, pos2.x),
                    math.min(pos1.y, pos2.y),
                    math.min(pos1.z, pos2.z))
                local maxp = vector.new(
                    math.max(pos1.x, pos2.x),
                    math.max(pos1.y, pos2.y),
                    math.max(pos1.z, pos2.z))
                table.insert(fs, "label[0.45,4.55;Selected volume: ")
                table.insert(fs, minetest.formspec_escape(format_size({
                    size_x = maxp.x - minp.x + 1,
                    size_y = maxp.y - minp.y + 1,
                    size_z = maxp.z - minp.z + 1,
                })))
                table.insert(fs, "]")
            end

            table.insert(fs, "field[0.45,5.55;6.6,0.65;bx_schema_name;Structure name;")
            table.insert(fs, minetest.formspec_escape(view.schema_name or ""))
            table.insert(fs, "]")
            table.insert(fs, "button[7.3,5.55;2.5,0.65;bx_upload;Upload structure]")
            table.insert(fs, "button_url[10.05,5.55;2.7,0.65;bx_search_page;Open web library;")
            table.insert(fs, minetest.formspec_escape(EXCHANGE_URL .. "/search"))
            table.insert(fs, "]")

            local upload_status = view.upload_status
                or "Set opposite corners, choose a name, then upload."
            if view.uploading then
                upload_status = "Upload in progress. Follow the BlockExchange HUD."
            end
            table.insert(fs, "textarea[0.45,6.65;12.3,1.25;;;")
            table.insert(fs, minetest.formspec_escape(upload_status))
            table.insert(fs, "]")
        end

        minetest.show_formspec(name, FORM_NAME, table.concat(fs))
        return
    end

    table.insert(fs, "field[0.45,1.45;7.65,0.65;bx_query;Search structures;")
    table.insert(fs, minetest.formspec_escape(view.query))
    table.insert(fs, "]")
    table.insert(fs, "button[8.3,1.45;1.45,0.65;bx_search;Search]")
    table.insert(fs, "button[9.9,1.45;1.45,0.65;bx_refresh;Refresh]")

    if not bx_available() then
        table.insert(fs, "textarea[0.45,2.45;12.3,2.2;;BlockExchange unavailable;")
        table.insert(fs, minetest.formspec_escape(
            "The official blockexchange mod must be installed, enabled, online, and configured for "
            .. EXCHANGE_URL .. "."))
        table.insert(fs, "]")
    elseif not http then
        table.insert(fs, "textarea[0.45,2.45;12.3,2.2;;Catalogue unavailable;")
        table.insert(fs, minetest.formspec_escape(
            "Add classrooms_bridge to secure.http_mods, then restart this instance."))
        table.insert(fs, "]")
    elseif view.loading then
        table.insert(fs, "label[0.55,2.6;Loading structures…]")
    elseif view.error then
        table.insert(fs, "textarea[0.45,2.35;12.3,1.5;;Could not load structures;")
        table.insert(fs, minetest.formspec_escape(view.error))
        table.insert(fs, "]")
    elseif #view.rows == 0 then
        table.insert(fs, "label[0.55,2.6;No structures found.]")
    else
        table.insert(fs, "label[0.6,2.35;Owner]")
        table.insert(fs, "label[3.65,2.35;Structure]")
        table.insert(fs, "label[6.7,2.35;Size]")
        table.insert(fs, "label[9.75,2.35;Downloads]")
        table.insert(fs, "tablecolumns[text;text;text;text]")
        table.insert(fs, "table[0.45,2.65;12.3,4.35;bx_structures;")
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

    local page_label = "Page " .. tostring(view.page + 1)
    table.insert(fs, "button[0.45,7.25;1.25,0.65;bx_prev;Previous]")
    table.insert(fs, "label[1.95,7.48;" .. minetest.formspec_escape(page_label) .. "]")
    table.insert(fs, "button[3.1,7.25;1.25,0.65;bx_next;Next]")
    table.insert(fs, "button[5.05,7.25;2.15,0.65;bx_origin;Set origin]")
    table.insert(fs, "button[7.45,7.25;2.15,0.65;bx_allocate;Allocate]")
    table.insert(fs, "button[9.85,7.25;2.9,0.65;bx_load;Load structure]")

    local selected = view.rows[view.selected or 0]
    local status = "Select a structure, set the origin, allocate to preview its bounds, then load."
    if selected then
        status = "Selected: " .. selected.username .. " / " .. selected.schema.name
    end
    table.insert(fs, "textarea[0.45,8.15;12.3,0.7;;;")
    table.insert(fs, minetest.formspec_escape(status))
    table.insert(fs, "]")

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
    description = "BlockExchange Library",
    inventory_image = "classrooms_bridge_teacher_panel.png^[colorize:#00A6A6:155",
    wield_image = "classrooms_bridge_teacher_panel.png^[colorize:#00A6A6:155",
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
    on_drop = function()
        return ItemStack("")
    end,
})

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

minetest.register_allow_player_inventory_action(function(player, action, _, info)
    if not access[player:get_player_name()] then return end

    if action == "move" then
        if (info.from_list == "main" and info.from_index == ITEM_SLOT)
                or (info.to_list == "main" and info.to_index == ITEM_SLOT) then
            return 0
        end
    elseif (action == "put" or action == "take")
            and info.listname == "main" and info.index == ITEM_SLOT then
        return 0
    end
end)

local item_timer = 0
minetest.register_globalstep(function(dtime)
    item_timer = item_timer + dtime
    if item_timer < 1 then return end
    item_timer = 0

    for name in pairs(access) do
        ensure_item(minetest.get_player_by_name(name))
    end
end)

function integration.set_access(player, enabled)
    if not player or not player:is_player() then return end
    local name = player:get_player_name()
    if enabled then
        access[name] = true
        grant_upload_privilege(name)
        ensure_item(player)
    else
        access[name] = nil
        views[name] = nil
        restore_upload_privilege(name)
        remove_item(player)
    end
end

function integration.ensure_item(player)
    ensure_item(player)
end

function integration.clear_player(name)
    access[name] = nil
    views[name] = nil
    restore_upload_privilege(name)
end

return integration
