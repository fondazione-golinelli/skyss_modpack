local S = core.get_translator("magic_compass")

local function load_folder()
  local wrld_dir = core.get_worldpath() .. "/magic_compass"
  local content = core.get_dir_list(wrld_dir)

  local modpath = core.get_modpath("magic_compass")

  -- se la cartella della bussola non esiste/è vuota, copio la cartella base `IGNOREME`
  if not next(content) then
    local src_dir = modpath .. "/IGNOREME"
    core.cpdir(src_dir, wrld_dir)
    os.remove(wrld_dir .. "/README.md")
  end

  --v------------------ LEGACY UPDATE, to remove in 4.0 -------------------v
  local txtr_dir = modpath .. "/textures/locations"
  local i18n_dir = modpath .. "/locale/locations"

  if next(core.get_dir_list(txtr_dir)) then
    core.rmdir(i18n_dir)
    core.rmdir(modpath .. "/textures/menu")
    core.rmdir(txtr_dir)
  end

  local close_icon = io.open(wrld_dir .. "/menu/magiccompass_gui_close.png", "r")

  if not close_icon then
    local close_icon_orig = io.open(modpath .. "/IGNOREME/menu/magiccompass_gui_close.png")
    core.safe_file_write(wrld_dir .. "/menu/magiccompass_gui_close.png", close_icon_orig:read("*a"))
  else
    close_icon:close()
  end

  for _, dir_name in ipairs(core.get_dir_list(modpath .. "/locale", true)) do
    if dir_name == "locations" then
      core.rmdir(i18n_dir, true)
    end
  end

  local tr_script = io.open(wrld_dir .. "/po_translation_updater.py", "r")

  if not tr_script then
    local orig = io.open(modpath .. "/IGNOREME/po_translation_updater.py")
    local instructions = io.open(modpath .. "/IGNOREME/instructions.txt")
    os.remove(wrld_dir .. "instructions.txt")
    core.safe_file_write(wrld_dir .. "/po_translation_updater.py", orig:read("*a"))
    core.safe_file_write(wrld_dir .. "/instructions.txt", instructions:read("*a"))
  else
    tr_script:close()
  end
  --^------------------ LEGACY UPDATE, to remove in 4.0 -------------------^

  -- carico quel che posso dalla cartella del mondo (non davvero media dinamici,
  -- dato che vengon eseguiti all'avvio del server)
  local function iterate_dirs(dir)
    for _, f_name in pairs(core.get_dir_list(dir, false)) do
      core.dynamic_add_media({filepath = dir .. "/" .. f_name}, function(name) end)
    end
    for _, subdir in pairs(core.get_dir_list(dir, true)) do
      iterate_dirs(dir .. "/" .. subdir)
    end
  end

  -- TEMP MT 5.9: per ora non si possono aggiungere contenuti dinamici all'avvio
  -- del server. Poi rimuovi anche 2° param da dynamic_add_media qui in alto
  core.after(0.1, function()
    iterate_dirs(wrld_dir .. "/icons")
    iterate_dirs(wrld_dir .. "/locale")
    iterate_dirs(wrld_dir .. "/menu")
  end)
end

load_folder()

dofile(core.get_worldpath() .. "/magic_compass/SETTINGS.lua")





----------------------------------------------
------------------AUDIO_LIB-------------------
----------------------------------------------

if not core.get_modpath("audio_lib") then return end

audio_lib.register_sound("sfx", "magiccompass_teleport", S("Teleport beeps"))
audio_lib.register_sound("sfx", "magiccompass_teleport_deny", S("Action forbidden"))