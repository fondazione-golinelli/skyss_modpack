local function play_music() end



arena_lib.register_on_join_queue(function(mod, arena, p_name, has_status_changed)
  if arena_lib.mods[mod].endless or hub.HUD_is_ignored(mod, arena.name) then return end

  local slot_ID = hub.get_arenastatus_slot(mod, arena.name)

  if not slot_ID then
    hub.HUD_arstatus_add(mod, arena)
  else
    local skip_status = not has_status_changed and arena.players_amount < arena.max_players * #arena.teams
    hub.HUD_arstatus_update(slot_ID, true, true, skip_status)
  end
end)



arena_lib.register_on_leave_queue(function(mod, arena, p_name, has_status_changed)
  if arena_lib.mods[mod].endless or hub.HUD_is_ignored(mod, arena.name) then return end

  local slot_ID = hub.get_arenastatus_slot(mod, arena.name)

  if not slot_ID then return end -- se sono in gruppo, va lanciato solo una volta (anche perché la casella viene rimossa alla prima iterazione e alla seconda farebbe crashare)

  if arena.players_amount == 0 then
    hub.HUD_arstatus_remove(mod, arena.name)
  else
    local skip_status = not has_status_changed and arena.players_amount < arena.max_players * #arena.teams
    hub.HUD_arstatus_update(slot_ID, true, true, skip_status)
  end
end)



arena_lib.register_on_load(function(mod, arena)
  if arena_lib.mods[mod].endless then return end

  if not hub.HUD_is_ignored(mod, arena.name) then
    local slot_ID = hub.get_arenastatus_slot(mod, arena.name)
    hub.HUD_arstatus_update(slot_ID, true, true, false, true)
  end

  for pl_name in pairs(arena.players) do
    if not pl_name:find(" ") then -- TEMP: per vedere se son fantocci (a cui non viene mai creata l'HUD). Servirebbe https://github.com/luanti-org/luanti/issues/13430
      hub.HUD_arstatus_hide(pl_name)
    end
  end
end)



arena_lib.register_on_start(function(mod, arena)
  local mod_ref = arena_lib.mods[mod]

  if mod_ref.endless or hub.HUD_is_ignored(mod, arena.name) or
     not mod_ref.join_while_in_progress or arena.players_amount == arena.max_players * #arena.teams
     then return end

  if not arena.in_game then return end -- in caso di force_end su on_start di qualche mod (es. Arcade Party)

  local slot_ID = hub.get_arenastatus_slot(mod, arena.name)
  hub.HUD_arstatus_update(slot_ID, true, true, false, true, true)
end)



arena_lib.register_on_join(function(mod, arena, p_name, as_spectator)
  if arena_lib.mods[mod].endless then return end

  if not p_name:find(" ") then -- TEMP: per vedere se son fantocci (a cui non viene mai creata l'HUD). Servirebbe https://github.com/luanti-org/luanti/issues/13430
    hub.HUD_arstatus_hide(p_name)
  end

  if as_spectator then return end
  if hub.HUD_is_ignored(mod, arena.name) then return end

  local slot_ID = hub.get_arenastatus_slot(mod, arena.name)
  hub.HUD_arstatus_update(slot_ID, true, true)
end)



arena_lib.register_on_eliminate(function(mod, arena, p_name)
  local mod_ref = arena_lib.mods[mod]
  -- se non c'è la spettatore se ne occupa direttamente on_quit
  if mod_ref.endless or not mod_ref.spectate_mode or hub.HUD_is_ignored(mod, arena.name) then return end

  local slot_ID = hub.get_arenastatus_slot(mod, arena.name)
  hub.HUD_arstatus_update(slot_ID)
end)



arena_lib.register_on_quit(function(mod, arena, p_name, is_spectator, reason, p_properties)
  if reason ~= 0 then
    hub.HUD_arstatus_show(p_name)
    play_music(p_name)
  end

  if arena_lib.mods[mod].endless or hub.HUD_is_ignored(mod, arena.name) then return end

  -- inizialmente finivo qua se erano spettatori (perché non modificano i numeri
  -- della partita), ma così facendo non aggiornerebbe l'HUD dello spettatore.
  -- Piuttosto che mettere un ulteriore parametro alla funzione di aggiornamento,
  -- la aggiorno a tutti (che tanto è leggera) e amen

  -- ritardo di uno step perché la mod non sa ancora se l'arena stia finendo o sia
  -- addirittura già finita
  core.after(0, function()
    -- se è finita, lo slot non esiste più: evito il crash
    if not arena.in_game then return end

    local slot_ID = hub.get_arenastatus_slot(mod, arena.name)
    hub.HUD_arstatus_update(slot_ID, true, true)
  end)
end)



arena_lib.register_on_end(function(mod, arena, winners, is_forced)
  if not arena_lib.mods[mod].endless and not hub.HUD_is_ignored(mod, arena.name) then
    hub.HUD_arstatus_remove(mod, arena.name)
  end

  for psp_name, _ in pairs(arena.players_and_spectators) do
    hub.HUD_arstatus_show(psp_name)
    play_music(psp_name)
  end
end)





----------------------------------------------
---------------FUNZIONI LOCALI----------------
----------------------------------------------

function play_music(p_name)
  if not next(hub.settings.music) then return end

  if core.get_player_by_name(p_name) then
    audio_lib.play_bgm(p_name, hub.settings.music.track)
  end
end