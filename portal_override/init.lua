-- Portal Override
-- Replaces nether/end portal teleportation with the active classroom browser.

local CHANNEL_NAME = "classrooms:cmd"
local channel
local last_request = {}

core.register_on_mods_loaded(function()
	channel = core.mod_channel_join(CHANNEL_NAME)
	core.log("action", "[portal_override] Joined mod channel: " .. CHANNEL_NAME)
end)

local function open_world_browser(player, portal_type)
	if not player:is_player() then return end
	local name = player:get_player_name()
	local now = core.get_us_time()
	if last_request[name] and now - last_request[name] < 2000000 then return end
	last_request[name] = now

	if not channel then
		core.chat_send_player(name, core.colorize("#ff6fff",
			"[Classrooms] The world portal is still connecting. Please try again."))
		return
	end

	channel:send_all(core.write_json({
		action = "open_portal_worlds",
		player = name,
		portal = portal_type,
	}))
	core.log("action", "[portal_override] requested active worlds for " .. name
		.. " via " .. portal_type .. " portal")
end

-- Override nether portal: replace _on_object_in so stepping in no longer
-- teleports to the Nether.
core.override_item("mcl_portals:portal", {
	_on_object_in = function(pos, node, obj)
		open_world_browser(obj, "nether")
	end,
})

-- Override end portal teleport. The end portal ABM captured a reference to
-- mcl_portals.end_portal_teleport at registration, which in turn calls the
-- local end_portal_teleport_1, which calls mcl_portals.end_teleport via the
-- global table at runtime. Replacing this function intercepts end portal
-- teleportation.
mcl_portals.end_teleport = function(obj, pos)
	open_world_browser(obj, "end")
end

core.register_on_leaveplayer(function(player)
	last_request[player:get_player_name()] = nil
end)

-- Note: End gateway portals (the small bedrock ones in the End dimension)
-- use a local teleport function captured in an inline ABM and cannot be
-- overridden without modifying the game source. If you need to override
-- those too, the gateway ABM's action would need to be patched.
