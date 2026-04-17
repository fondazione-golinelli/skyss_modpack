core.register_on_joinplayer(function(player)
  local p_name = player:get_player_name()
  local i_count = #hub.get_additional_items()

  player:get_inventory():set_list("main", {})
  player:get_inventory():set_list("craft", {})
  player:hud_set_hotbar_image("arenalib_gui_hotbar" .. i_count .. ".png")
  player:hud_set_hotbar_itemcount(i_count)

  local hud_flags = player:hud_get_flags()

  hud_flags.minimap = false
  player:hud_set_flags(hud_flags)

  local p_armor_groups = player:get_armor_groups()

  p_armor_groups.fall_damage_add_percent = -100 -- tolgo effetto danno rosso
  player:set_armor_groups(p_armor_groups)

  if hub.settings.join_rotation_x then
    player:set_look_horizontal(math.rad(hub.settings.join_rotation_x))
  end

  if hub.settings.join_rotation_y then
    player:set_look_vertical(math.rad(hub.settings.join_rotation_y))
  end

  player:set_pos(hub.get_hub_spawn_point())
  player:set_hp(core.PLAYER_MAX_HP_DEFAULT)

  hub.set_items(player)
  hub.set_hub_physics(player)
  hub.HUD_arstatus_create(player:get_player_name())

  if hub.celestial_vault then
    local cvault = hub.celestial_vault
    -- TEMP: waiting for https://github.com/minetest/minetest/pull/12181 to make it simpler
    player:set_sky(cvault.sky)
    player:set_sun(cvault.sun)
    player:set_moon(cvault.moon)
    player:set_stars(cvault.stars)
    player:set_clouds(cvault.clouds)
  end

  if next(hub.settings.music) then
    audio_lib.play_bgm(p_name, hub.settings.music.track)
  end

  local pl_in_hub = hub.get_players_in_hub()

  if #pl_in_hub > 10 then return end

  for _, pl_name in pairs(pl_in_hub) do
    audio_lib.play_sound("arenalib_match_join", {to_player = pl_name, gain = 0.8})
  end
end)



core.register_on_leaveplayer(function(ObjectRef, timed_out)
  local pl_in_hub = hub.get_players_in_hub()

  if #pl_in_hub > 10 then return end

  for _, pl_name in pairs(pl_in_hub) do
    audio_lib.play_sound("arenalib_match_leave", {to_player = pl_name})
  end
end)



core.register_on_player_hpchange(function(player, hp_change, reason)
  reason = reason.type

  -- se non è in arena, disabilito danno da caduta, da affogamento e PvP
  if not arena_lib.is_player_in_arena(player:get_player_name()) and (reason == "fall" or reason == "punch" or reason == "drown") then
    return 0
  end

  return hp_change
end, true)



core.register_on_respawnplayer(function(player)
  if arena_lib.is_player_in_arena(player:get_player_name()) then return end

  player:set_pos(hub.get_hub_spawn_point())
  return true
end)
