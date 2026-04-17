local S = core.get_translator("audio_lib")



core.register_tool("audio_lib:settings", {
  description = S("Audio Settings"),
  inventory_image = "audiolib_settings.png",
  on_place = function() end,
  on_drop = function() end,

  on_use = function(itemstack, user, pointed_thing)
    local p_name = user:get_player_name()
    audio_lib.open_settings(p_name)
  end
})