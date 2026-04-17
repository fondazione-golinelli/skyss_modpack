-- Spectate Fix
-- Patches ObjectRef:get_yaw() so it returns a valid number for player objects.
--
-- Problem: In Luanti, get_yaw() returns nil for players (only works on
-- entities). Mineclonia's mcl_player animation code calls parent:get_yaw()
-- assuming the parent is always an entity (boat, horse, etc.), but arena_lib
-- attaches spectators to other players, causing math.deg(nil) -> server crash.
--
-- Fix: wrap get_yaw() to fall back to get_look_horizontal() for players.

local patched = false

core.register_on_joinplayer(function(player)
	if patched then return end

	local mt = getmetatable(player)
	if not mt then return end

	-- Methods may live directly on the metatable or in __index.
	local index = mt.__index or mt
	local orig = index.get_yaw
	if not orig then return end

	index.get_yaw = function(self)
		local val = orig(self)
		if val == nil and self.is_player and self:is_player() then
			return self:get_look_horizontal() or 0
		end
		return val
	end

	patched = true
	core.log("action", "[spectate_fix] Patched ObjectRef:get_yaw() for player-attached-to-player safety")
end)
