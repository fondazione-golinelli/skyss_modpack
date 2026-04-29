-- Formspec Command Fix
--
-- Some clients can send the Enter key used to submit a chat command to the
-- formspec opened by that same command. Mineclonia makes this especially easy
-- to notice with command-opened UIs such as /map. Delay only those formspecs,
-- while leaving normal item/node/formspec navigation untouched.

local delay = tonumber(core.settings:get("formspec_command_fix.delay")) or 0.15
local command_depth = {}
local pending_tokens = {}

local original_show_formspec = core.show_formspec
local original_register_chatcommand = core.register_chatcommand
local original_override_chatcommand = core.override_chatcommand
local original_register_on_chatcommand = core.register_on_chatcommand

local wrapped = setmetatable({}, { __mode = "k" })

local function push_command_context(player_name)
	if type(player_name) ~= "string" or player_name == "" then
		return
	end

	command_depth[player_name] = (command_depth[player_name] or 0) + 1
end

local function pop_command_context(player_name)
	if type(player_name) ~= "string" or player_name == "" then
		return
	end

	local depth = (command_depth[player_name] or 0) - 1
	if depth > 0 then
		command_depth[player_name] = depth
	else
		command_depth[player_name] = nil
	end
end

local function next_pending_token(player_name)
	local token = (pending_tokens[player_name] or 0) + 1
	pending_tokens[player_name] = token
	return token
end

function core.show_formspec(player_name, formname, formspec)
	if not command_depth[player_name] or not core.get_player_by_name(player_name) then
		if player_name then
			pending_tokens[player_name] = nil
		end
		return original_show_formspec(player_name, formname, formspec)
	end

	local token = next_pending_token(player_name)

	core.after(delay, function()
		if pending_tokens[player_name] ~= token then
			return
		end
		pending_tokens[player_name] = nil

		if core.get_player_by_name(player_name) then
			original_show_formspec(player_name, formname, formspec)
		end
	end)
end

minetest.show_formspec = core.show_formspec

local function wrap_player_command_func(func)
	if type(func) ~= "function" then
		return func
	end
	if wrapped[func] == true then
		return func
	end
	if wrapped[func] then
		return wrapped[func]
	end

	local function wrapped_func(player_name, ...)
		push_command_context(player_name)
		local ok, ret1, ret2, ret3 = pcall(func, player_name, ...)
		pop_command_context(player_name)

		if not ok then
			error(ret1, 0)
		end

		return ret1, ret2, ret3
	end

	wrapped[func] = wrapped_func
	wrapped[wrapped_func] = true
	return wrapped_func
end

local function wrap_registered_chatcommand(command_name)
	local def = core.registered_chatcommands and core.registered_chatcommands[command_name]
	if type(def) == "table" then
		def.func = wrap_player_command_func(def.func)
	end
end

function core.register_chatcommand(command_name, def)
	original_register_chatcommand(command_name, def)
	wrap_registered_chatcommand(command_name)
end

minetest.register_chatcommand = core.register_chatcommand

if original_override_chatcommand then
	function core.override_chatcommand(command_name, redefinition)
		original_override_chatcommand(command_name, redefinition)
		wrap_registered_chatcommand(command_name)
	end

	minetest.override_chatcommand = core.override_chatcommand
end

local function wrap_on_chatcommand_callback(func)
	if type(func) ~= "function" then
		return func
	end
	if wrapped[func] == true then
		return func
	end
	if wrapped[func] then
		return wrapped[func]
	end

	local function wrapped_func(player_name, command, params)
		push_command_context(player_name)
		local ok, ret = pcall(func, player_name, command, params)
		pop_command_context(player_name)

		if not ok then
			error(ret, 0)
		end

		return ret
	end

	wrapped[func] = wrapped_func
	wrapped[wrapped_func] = true
	return wrapped_func
end

function core.register_on_chatcommand(func)
	local wrapped_func = wrap_on_chatcommand_callback(func)
	original_register_on_chatcommand(wrapped_func)
end

minetest.register_on_chatcommand = core.register_on_chatcommand

core.register_on_mods_loaded(function()
	for command_name in pairs(core.registered_chatcommands or {}) do
		wrap_registered_chatcommand(command_name)
	end

	for index, func in ipairs(core.registered_on_chatcommands or {}) do
		local wrapped_func = wrap_on_chatcommand_callback(func)
		if wrapped_func ~= func then
			core.registered_on_chatcommands[index] = wrapped_func
			if core.callback_origins then
				core.callback_origins[wrapped_func] = core.callback_origins[func]
			end
		end
	end

	core.log("action", "[formspec_command_fix] Delaying command-opened formspecs by " .. delay .. "s")
end)
