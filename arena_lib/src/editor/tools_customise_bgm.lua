local S = core.get_translator("arena_lib")

local function get_bgm_formspec() end
local function calc_gain() end
local function calc_pitch() end

-- Uso una tabella e non continue_bgm perché potrebbe lanciare più di una traccia
-- da dentro la finestra, quindi non ricorderebbe più quella iniziale
local track_before_entering = {}     -- KEY p_name; VALUE track_name



core.register_tool("arena_lib:customise_bgm", {
    description = S("Background music"),
    inventory_image = "arenalib_customise_bgm.png",
    groups = {not_in_creative_inventory = 1},
    on_place = function() end,
    on_drop = function() end,

    on_use = function(itemstack, user, pointed_thing)
      local mod         = user:get_meta():get_string("arena_lib_editor.mod")
      local arena_name  = user:get_meta():get_string("arena_lib_editor.arena")
      local _, arena    = arena_lib.get_arena_by_name(mod, arena_name)
      local p_name      = user:get_player_name()

      track_before_entering[p_name] = audio_lib.get_player_bgm(p_name)
      audio_lib.stop_bgm(p_name)

      core.show_formspec(p_name, "arena_lib:bgm", get_bgm_formspec(arena))
    end
})





----------------------------------------------
---------------FUNZIONI LOCALI----------------
----------------------------------------------

function get_bgm_formspec(arena)
  local bgm = ""
  local bgm_desc = ""
  local bgm_title = ""
  local bgm_author = ""
  local bgm_volume = 100
  local bgm_pitch = 50

  if arena.bgm then
    bgm = arena.bgm.track
    bgm_desc = arena.bgm.description or ""
    bgm_title = arena.bgm.title or ""
    bgm_author = arena.bgm.author or ""
    bgm_volume = arena.bgm.gain * 100
    bgm_pitch = arena.bgm.pitch * 50
  end

  local formspec = {
    "formspec_version[4]",
    "size[7,8.85]",
    "bgcolor[;neither]",
    "style_type[image_button;border=false;bgimg=blank.png]",
    -- area attributi
    "container[0.5,0.5]",
    "label[0,0;" .. S("Audio file") .. "]",
    "field[0,0.41;6,0.6;bgm;;" .. bgm .. "]",
    "hypertext[-0.05,0.13;6,0.3;audio_info;<style size=12 font=mono color=#b7aca3>(" .. S("leave empty to remove the current track") .. ")</style>]",
    "label[0,1.35;" .. S("Description") .. "]",
    "field[0,1.76;6,0.6;description;;" .. bgm_desc .. "]",
    "hypertext[-0.05,1.48;6,0.3;audio_desc;<style size=12 font=mono color=#b7aca3>(" .. S("used for accessibility purposes") .. ")</style>]",
    "container[0,2.7]",
    "label[0,0;" .. S("Title") .. "]",
    "field[0,0.2;2.99,0.6;title;;" .. bgm_title .. "]",
    "label[3,0;" .. S("Author") .. "]",
    "field[3,0.2;3,0.6;author;;" .. bgm_author .. "]",
    "container_end[]",
    "container_end[]",
    -- area ritocchi
    "container[0.5,4.85]",
    "label[0,0;" .. S("Volume") .. "]",
    "label[0,0.41;0]",
    "label[5.64,0.41;100]",
    "scrollbaroptions[max=100;smallstep=1;largestep=10;arrows=hide]",
    "scrollbar[0.4,0.3;5.2,0.2;;gain;" .. bgm_volume .. "]",
    "label[0,1;" .. S("Pitch") .. "]",
    "label[0,1.41;0]",
    "label[5.9,1.41;2]",
    "scrollbar[0.4,1.3;5.2,0.2;;pitch;" .. bgm_pitch .. "]",
    "container[2.55,2.1]",
    "image_button[0,0;0.4,0.4;arenalib_tool_bgm_test.png;play;]",
    "image_button[0.5,0;0.4,0.4;arenalib_tool_bgm_test_stop.png;stop;]",
    "container_end[]",
    "container_end[]",
    "button[2.75,8.05;1.5,0.5;apply;" .. S("Apply") .."]",
    "field_close_on_enter[bgm;false]",
    "field_close_on_enter[gain;false]",
    "field_close_on_enter[pitch;false]"
  }

  return table.concat(formspec, "")
end



function calc_gain(field)
  return core.explode_scrollbar_event(field).value / 100
end



function calc_pitch(field)
  return core.explode_scrollbar_event(field).value / 50
end


----------------------------------------------
---------------GESTIONE CAMPI-----------------
----------------------------------------------

core.register_on_player_receive_fields(function(player, formname, fields)
  if formname ~= "arena_lib:bgm" then return end

  local p_name = player:get_player_name()

  -- se premo su icona "riproduci", riproduco audio
  if fields.play then
    if not audio_lib.is_sound_registered(fields.bgm, "bgm") then
      arena_lib.print_error(p_name, S("File not found!"))
      return end

    audio_lib.play_bgm(p_name, fields.bgm, {
      to_player = p_name,
      gain      = calc_gain(fields.gain),
      pitch     = calc_pitch(fields.pitch)
    })

  -- se abbandono o premo stop, l'eventuale audio si interrompe
  elseif fields.stop or fields.quit then
    audio_lib.stop_bgm(p_name)

    if fields.quit then
      audio_lib.play_bgm(p_name, track_before_entering[p_name])
      track_before_entering[p_name] = nil
    end

  -- applico il tutto
  elseif fields.apply then
    local mod         = player:get_meta():get_string("arena_lib_editor.mod")
    local arena_name  = player:get_meta():get_string("arena_lib_editor.arena")
    local bgm_table

    if fields.bgm ~= "" then
      bgm_table = {
        track       = fields.bgm,
        description = fields.description ~= "" and fields.description or nil,
        title       = fields.title ~= "" and core.formspec_escape(fields.title) or nil,
        author      = fields.author ~= "" and core.formspec_escape(fields.author) or nil,
        gain        = calc_gain(fields.gain),
        pitch       = calc_pitch(fields.pitch)
      }
    end

    arena_lib.set_bgm(p_name, mod, arena_name, bgm_table, true)
    audio_lib.stop_bgm(p_name)
    audio_lib.play_bgm(p_name, track_before_entering[p_name])

    track_before_entering[p_name] = nil
    core.close_formspec(p_name, "arena_lib:bgm")
  end
end)
