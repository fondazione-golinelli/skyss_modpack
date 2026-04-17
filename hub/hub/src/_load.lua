local function load_world_folder()

  local wrld_dir = core.get_worldpath() .. "/hub"

  -- se la cartella di hub non esiste/è vuota, copio la cartella base `IGNOREME`
  if not core.path_exists(wrld_dir) then
    local src_dir = core.get_modpath("hub") .. "/IGNOREME"

    core.cpdir(src_dir, wrld_dir)
    os.remove(wrld_dir .. "/README.md")
    os.remove(wrld_dir .. "/BGM/.gitkeep")

  else
    -- aggiungi musiche come contenuti dinamici per non appesantire il server
    local function iterate_dirs(dir)
      for _, f_name in pairs(core.get_dir_list(dir, false)) do
        -- NOT REALLY DYNAMIC MEDIA, since it's run when the server launches and there are no players online
        -- it's just to load these tracks from the world folder (so that `sound_play` recognises them without the full path)
        core.dynamic_add_media({filepath = dir .. "/" .. f_name})

      end
      for _, subdir in pairs(core.get_dir_list(dir, true)) do
        iterate_dirs(dir .. "/" .. subdir)
      end
    end

    iterate_dirs(wrld_dir .. "/BGM")
  end
end

load_world_folder()

-- SETTINGS.lua viene caricato dopo, quindi after
core.after(0, function()
  if next(hub.settings.music) then
    local bgm = hub.settings.music
    audio_lib.register_sound("bgm", bgm.track, bgm.description, bgm.params)
  end
end)



-- TODO: aggiornamento file SETTINGS una volta che la mod sarà rilasciata pubblicamente
