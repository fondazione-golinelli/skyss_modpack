local S = minetest.get_translator("serverguide")

local function get_formspec() end
local function get_adapted_font_size_to_screen() end



function serverguide.get_firststeps_formspec(p_name)
  minetest.show_formspec(p_name, "serverguide:steps", get_formspec(p_name))
end




----------------------------------------------
---------------FUNZIONI LOCALI----------------
----------------------------------------------

function get_formspec(p_name)
  -- "TEMP": https://github.com/luanti-org/luanti/issues/13568. Fixing the fs size
  -- won't fix this issue, so I need to resize fonts manually or mobile players will
  -- see everything huge. Meh
  local txt_size = get_adapted_font_size_to_screen(p_name)
  local formspec = {
  "formspec_version[9]",
  "size[14,18]",
  "position[0.5,0.47]",
  "no_prepend[]",
  "allow_close[false]",
  "bgcolor[;true]",
  "style_type[button;border=false]",
  "background[0,0;1,1;aesguide_first_steps.png;true]",
  "hypertext[4.3,4.2;8,3;name;<global valign=middle size=" .. txt_size .. " font=mono color=#ffffff>1. " .. S("Use your free hand to hit an arena sign and enter a minigame (/quit to leave)") .. "]",
  "hypertext[1.75,8.5;9.2,3;name;<global valign=middle size=" .. txt_size .. " font=mono color=#ffffff>2. " .. S("Use the compass to teleport and reach places more quickly") .. "]",
  "hypertext[4.3,12.7;8,3;name;<global valign=middle size=" .. txt_size .. " font=mono color=#ffffff>3. " .. S("Complete many challenges and unlock content to make your adventure more magical!") .. "]",
  "hypertext[1.3,16.3;2.5,0.55;name;<global valign=middle size=" .. txt_size .. " font=mono color=#eea160>/tutorial]",
  "button_exit[9.82,16.1;3.8,0.97;confirm;" .. S("LET'S GO!") .. "]"
  }

  return table.concat(formspec, "")
end



function get_adapted_font_size_to_screen(pl_name)
  local window_info = core.get_player_window_information(pl_name)

  if not window_info then return 15 end

  local real_gui_scaling = window_info.real_gui_scaling or 1
  local screen_w, screen_h = window_info.size.x or 1280, window_info.size.y or 720
  local ref_w, ref_h = 1280, 720
  local base_size = 13 -- magic numbers by try and error, don't even ask

  -- Invert the average ratio for bigger resolutions to reduce size
  local res_factor = ((screen_w / ref_w) + (screen_h / ref_h)) / 2
  local final_factor = res_factor * 0.85
  local size = math.floor(base_size * final_factor / real_gui_scaling + 0.5)
  size = math.max(7, math.min(size, 20))

  return size
end






----------------------------------------------
---------------GESTIONE CAMPI-----------------
----------------------------------------------


core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "serverguide:steps" then return end

	if fields.quit and not fields.confirm then
    local p_name = player:get_player_name()
    core.show_formspec(p_name, "serverguide:steps", get_formspec(p_name))
    return
  end
end)