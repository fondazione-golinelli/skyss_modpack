local function load_world_folder()

  local wrld_dir = core.get_worldpath() .. "/hub"
  local content = core.get_dir_list(wrld_dir)

  -- se la cartella di audio_lib non esiste/è vuota, copio la cartella base `IGNOREME`
  if not next(content) then
    local src_dir = core.get_modpath("hub") .. "/IGNOREME"

    core.cpdir(src_dir, wrld_dir)
    os.remove(wrld_dir .. "/README.md")

    content = core.get_dir_list(wrld_dir)
  end
end

load_world_folder()

dofile(core.get_worldpath() .. "/audio_lib/SETTINGS.lua")
