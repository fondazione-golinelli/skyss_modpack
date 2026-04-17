controls.register_on_press(function(user, key)
	if key == "aux1" and not arena_lib.is_player_in_arena(user:get_player_name()) then
		playerlist.HUD_show(user:get_player_name())
	end
end)

controls.register_on_release(function(user, key)
	if key == "aux1" and not arena_lib.is_player_in_arena(user:get_player_name()) then
		playerlist.HUD_hide(user:get_player_name())
	end
end)
