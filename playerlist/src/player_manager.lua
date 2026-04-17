core.register_on_joinplayer(function(player)
  playerlist.HUD_create(player:get_player_name())
end)

core.register_on_leaveplayer(function(player)
  playerlist.HUD_remove_player(player:get_player_name())
end)
