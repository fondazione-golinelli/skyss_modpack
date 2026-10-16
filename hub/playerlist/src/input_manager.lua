-- The list shows while the key is held. Not E (aux1): in Mineclonia that is
-- the sprint key. Default: zoom (Z), free in the hub (only the spyglass and
-- the bow use it). Change it with playerlist_key in luanti.conf.
local KEY = core.settings:get("playerlist_key") or "zoom"
if KEY == "" then KEY = "zoom" end

local function in_game(p_name)
	if hub and hub.is_in_game then return hub.is_in_game(p_name) end
	return arena_lib.is_player_in_arena(p_name)
end

controls.register_on_press(function(user, key)
	if key == KEY and not in_game(user:get_player_name()) then
		playerlist.HUD_show(user:get_player_name())
	end
end)

controls.register_on_release(function(user, key)
	if key == KEY and not in_game(user:get_player_name()) then
		playerlist.HUD_hide(user:get_player_name())
	end
end)
