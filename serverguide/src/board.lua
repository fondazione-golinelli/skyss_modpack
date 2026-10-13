local S = core.get_translator("serverguide")

-- "TEMP": https://github.com/luanti-org/luanti/issues/13568. Fixing the fs size
-- won't fix this issue, so fonts are resized manually or mobile players will
-- see everything huge
function serverguide.get_adapted_font_size(p_name)
  local window_info = core.get_player_window_information(p_name)

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



-- Wooden board shared by the rules and the first steps: a title, a numbered
-- list and a button. `title`, `items`, `hint` and `button` must already be
-- formspec-escaped
function serverguide.get_board_formspec(p_name, def)
  local txt_size = serverguide.get_adapted_font_size(p_name)
  local list = {}

  for i, item in ipairs(def.items) do
    list[i] = "<style color=#3f7a33><b>" .. i .. ".</b></style> " .. item
  end

  return table.concat({
    "formspec_version[9]",
    "size[14,17.47]",
    "position[0.5,0.47]",
    "no_prepend[]",
    def.allow_close == false and "allow_close[false]" or "",
    "bgcolor[;true]",
    "style_type[button;border=false;textcolor=#f9f3df]",
    "background[0,0;1,1;serverguide_board_bg.png;true]",
    "hypertext[3.2,2.07;7.6,1.4;title;<global halign=center valign=middle size=" .. (txt_size + 3) .. " font=mono color=#302c2e><b>" .. def.title .. "</b>]",
    "hypertext[1.2,3.8;11.6,10.4;list;<global valign=top size=" .. (txt_size + 2) .. " font=mono color=#302c2e>" .. table.concat(list, "\n\n") .. "]",
    "hypertext[1.2,15;7,1.13;hint;<global valign=middle size=" .. txt_size .. " font=mono color=#6e4a2a>" .. def.hint .. "]",
    "button_exit[8.6,15;4.2,1.13;confirm;" .. def.button .. "]"
  }, "")
end
