function arena_lib.sound_play_all(arena, sound, override_params, skip_spectators)
  local to_players ={}

  if skip_spectators then
    for pl_name, _ in pairs(arena.players) do
      to_players[#to_players+1] = pl_name
    end

  else
    for psp_name, _ in pairs(arena.players_and_spectators) do
      to_players[#to_players+1] = psp_name
    end
  end

  override_params = override_params or {}
  override_params.to_players = to_players

  audio_lib.play_sound(sound, override_params)
end



function arena_lib.sound_play_team(arena, teamID, sound, override_params, skip_spectators)
  local to_players = {}

  for t_name, t_data in pairs(arena.players) do
    if t_data.teamID == teamID then
      to_players[#to_players+1] = t_name

      if not skip_spectators then
        for sp_name, _ in pairs(arena_lib.get_player_spectators(t_name)) do
          to_players[#to_players +1] = sp_name
        end
      end
    end
  end

  override_params = override_params or {}
  override_params.to_players = to_players

  audio_lib.play_sound(sound, override_params)
end



function arena_lib.sound_play(p_name, sound, override_params, skip_spectators)
  if not arena_lib.is_player_in_arena(p_name) then return end

  override_params = override_params or {}

  if skip_spectators then
    override_params.to_player = p_name

  else
    local to_players = {p_name}

    if arena_lib.is_player_playing(p_name) then
      for sp_name, _ in pairs(arena_lib.get_player_spectators(p_name)) do
        to_players[#to_players+1] = sp_name
      end
    end

    override_params.to_players = to_players
  end

  audio_lib.play_sound(sound, override_params)
end