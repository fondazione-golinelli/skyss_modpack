function magic_compass.play_sound(track_name, p_name)
  if core.get_modpath("audio_lib") then
    audio_lib.play_sound(track_name, {to_player = p_name})
  else
    core.sound_play(track_name, { to_player = p_name })
  end
end