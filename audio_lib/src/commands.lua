local S = core.get_translator("audio_lib")

core.register_chatcommand("audiosettings", {
  description = S("Open the audio settings menu"),
  func = function(name, param)
    audio_lib.open_settings(name)
  end
})