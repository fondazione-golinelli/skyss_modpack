-- Portal Override
-- Replaces nether/end portal teleportation with custom hub behavior.

local function notify_portal_entry(player, portal_type)
	if not player:is_player() then return end
	local name = player:get_player_name()
	core.chat_send_player(name,
		core.colorize("#ff6fff", name .. " entered portal: " .. portal_type))
	core.log("action", "[portal_override] " .. name .. " entered " .. portal_type)
end

-- Override nether portal: replace _on_object_in so stepping in no longer
-- teleports to the Nether.
core.override_item("mcl_portals:portal", {
	_on_object_in = function(pos, node, obj)
		notify_portal_entry(obj, "nether")
	end,
})

-- Override end portal teleport. The end portal ABM captured a reference to
-- mcl_portals.end_portal_teleport at registration, which in turn calls the
-- local end_portal_teleport_1, which calls mcl_portals.end_teleport via the
-- global table at runtime. Replacing this function intercepts end portal
-- teleportation.
mcl_portals.end_teleport = function(obj, pos)
	notify_portal_entry(obj, "end")
end

-- Note: End gateway portals (the small bedrock ones in the End dimension)
-- use a local teleport function captured in an inline ABM and cannot be
-- overridden without modifying the game source. If you need to override
-- those too, the gateway ABM's action would need to be patched.
