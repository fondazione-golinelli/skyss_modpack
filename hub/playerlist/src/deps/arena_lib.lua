arena_lib.register_on_join_queue(function(mod, arena, p_name, has_queue_status_changed)
  if p_name:find(" ") then return end -- TEMP: per vedere se son fantocci (a cui non viene mai creata l'HUD). Servirebbe https://github.com/luanti-org/luanti/issues/13430

  playerlist.HUD_update("minigame", p_name)
end)



arena_lib.register_on_leave_queue(function(mod, arena, p_name, has_queue_status_changed)
  if p_name:find(" ") then return end -- TEMP: idem come sopra

  playerlist.HUD_update("minigame", p_name)
end)



arena_lib.register_on_load(function(mod, arena)
  for pl_name, _ in pairs (arena.players) do
    if not pl_name:find(" ") then -- TEMP: idem come sopra
      if panel_lib.get_panel(pl_name, "playerlist_data"):is_visible() then
        playerlist.HUD_hide(pl_name)
      end

      playerlist.HUD_update("minigame", pl_name)
    end
  end
end)



arena_lib.register_on_join(function(mod, arena, p_name, as_spectator)
  if p_name:find(" ") then return end -- TEMP: idem come sopra

  if panel_lib.get_panel(p_name, "playerlist_data"):is_visible() then
    playerlist.HUD_hide(p_name)
  end

  playerlist.HUD_update("minigame", p_name, {spectator = as_spectator})
end)



arena_lib.register_on_quit(function(mod, arena, p_name, is_spectator, reason)
  if p_name:find(" ") then return end -- TEMP: idem come sopra

  playerlist.HUD_update("minigame", p_name)
end)



arena_lib.register_on_end(function(mod, arena, winners, is_forced)
  for psp_name, _ in pairs(arena.players_and_spectators) do
    if not psp_name:find(" ") then -- TEMP: idem come sopra
      playerlist.HUD_update("minigame", psp_name)
    end
  end
end)
