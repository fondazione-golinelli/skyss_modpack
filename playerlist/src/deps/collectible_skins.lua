if not core.get_modpath("collectible_skins") then return end



collectible_skins.register_on_set_skin(function(p_name, skin_ID)
  playerlist.HUD_update("avatar", p_name)
end)
