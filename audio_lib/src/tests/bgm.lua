local S = core.get_translator("audio_lib")

audio_lib.register_sound("bgm", "audiolib_test_bgm1", "Audio_lib bgm test #1" )
audio_lib.register_sound("bgm", "audiolib_test_bgm2", "Audio_lib bgm test #2" )



core.register_tool("audio_lib:testbgm1", {
  description = S("Audio Lib BGM test #1\n\n1. Play BGM #1 in loop.\n\nRight click to stop any BGM"),
  inventory_image = "audiolib_test_bgm1.png",
  on_drop = function() end,

  on_use = function(itemstack, user, pointed_thing)
    local p_name = user:get_player_name()
    audio_lib.play_bgm(p_name, "audiolib_test_bgm1")
    core.chat_send_player(p_name, "► " .. audio_lib.get_player_bgm(p_name) .. " (↻)")
  end,

  on_secondary_use = function(itemstack, user, pointed_thing)
    local p_name = user:get_player_name()
    audio_lib.stop_bgm(p_name)
    core.chat_send_player(p_name, "■ -------")
  end,

  on_place = function(itemstack, placer, pointed_thing)
    local p_name = placer:get_player_name()
    audio_lib.stop_bgm(p_name)
    core.chat_send_player(p_name, "■ -------")
  end
})



core.register_tool("audio_lib:testbgm2", {
  description = S("Audio Lib BGM test #2\n\n1. Play BGM #1 for 1s\n2. Play BGM #2 for 3s, gain 0.3\n3. Play BGM #1 for 4s from where it stopped\n4. Stop BGM #1 after 2s"),
  inventory_image = "audiolib_test_bgm2.png",
  on_place = function() end,
  on_drop = function() end,

  on_use = function(itemstack, user, pointed_thing)
    local p_name = user:get_player_name()
    audio_lib.play_bgm(p_name, "audiolib_test_bgm1")
    core.chat_send_player(p_name, "► " .. audio_lib.get_player_bgm(p_name))

      core.after(3, function()
        if not core.get_player_by_name(p_name) then return end
        audio_lib.play_bgm(p_name, "audiolib_test_bgm2", {gain = 0.3})
        local now_playing = audio_lib.get_player_bgm(p_name, true)
        core.chat_send_player(p_name, "► " .. now_playing.name .. " (♪ " .. now_playing.params.gain * 100 .. "%)")

        core.after(4, function()
          if not core.get_player_by_name(p_name) then return end
          audio_lib.continue_bgm(p_name)
          core.chat_send_player(p_name, "► " .. audio_lib.get_player_bgm(p_name))

          core.after(2, function()
            audio_lib.stop_bgm(p_name)
            core.chat_send_player(p_name, "■ -------")
          end)
        end)
      end)
  end,
})



core.register_tool("audio_lib:testbgm3", {
  description = S("Audio Lib BGM test #3\n\n1. Play BGM #2 for 2s\n2. Gradually change (1s) gain to 0.5 for 3s\n3. Change gain to 1.4 for 2s\n4. Fade it out in 2s"),
  inventory_image = "audiolib_test_bgm3.png",
  on_place = function() end,
  on_drop = function() end,

  on_use = function(itemstack, user, pointed_thing)
    local p_name = user:get_player_name()
    audio_lib.play_bgm(p_name, "audiolib_test_bgm2")
    core.chat_send_player(p_name, "► " .. audio_lib.get_player_bgm(p_name))

      core.after(2, function()
        if not core.get_player_by_name(p_name) then return end
        audio_lib.change_bgm_volume(p_name, 0.5, 1)
        core.chat_send_player(p_name, S("Starts changing volume"))

        core.after(1.1, function()
          if not core.get_player_by_name(p_name) then return end
          local now_playing = audio_lib.get_player_bgm(p_name, true)
          core.chat_send_player(p_name, "► " .. now_playing.name .. " (♪ " .. now_playing.params.gain * 100 .. "%)")
        end)

        core.after(3, function()
          if not core.get_player_by_name(p_name) then return end
          audio_lib.change_bgm_volume(p_name, 1.4)
          local now_playing = audio_lib.get_player_bgm(p_name, true)
          core.chat_send_player(p_name, "► " .. now_playing.name .. " (♪ " .. now_playing.params.gain * 100 .. "%)")

          core.after(2, function()
            audio_lib.stop_bgm(p_name, 3)
            core.chat_send_player(p_name, S("Starts fading"))
            core.after(3, function()
              core.chat_send_player(p_name, "■ -------")
            end)
          end)
        end)
      end)
  end,
})