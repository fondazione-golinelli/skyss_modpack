local S = core.get_translator("serverguide")

local function get_adapted_font_size_to_screen(pl_name)
  local window_info = core.get_player_window_information(pl_name)

  if not window_info then return 15 end

  local real_gui_scaling = window_info.real_gui_scaling or 1
  local screen_w, screen_h = window_info.size.x or 1280, window_info.size.y or 720
  local ref_w, ref_h = 1280, 720
  local base_size = 13

  local res_factor = ((screen_w / ref_w) + (screen_h / ref_h)) / 2
  local final_factor = res_factor * 0.85
  local size = math.floor(base_size * final_factor / real_gui_scaling + 0.5)
  size = math.max(7, math.min(size, 20))

  return size
end

local DEFAULT_RULES = table.concat({
  S("Be respectful to other players and staff."),
  S("Keep chat friendly and appropriate."),
  S("Do not grief, cheat, exploit bugs, or disrupt other players."),
  S("Follow teacher and admin instructions."),
  S("Protect your account and do not share personal information.")
}, "\n\n")

local function get_rules_text()
  local text = core.settings:get("serverguide.rules_text")
  if text and text:match("%S") then
    return text:gsub("\\n", "\n")
  end

  return DEFAULT_RULES
end

local function split_rule_sections(text)
  local rules = {}
  for rule in text:gmatch("[^\n][^\n]*") do
    if rule:match("%S") then
      table.insert(rules, rule)
    end
  end

  if #rules == 0 then
    return {"", "", ""}
  end

  if #rules <= 3 then
    return {
      rules[1] or "",
      rules[2] or "",
      rules[3] or "",
    }
  end

  return {
    rules[1] or "",
    table.concat({rules[2] or "", rules[3] or ""}, " "),
    table.concat({rules[4] or "", rules[5] or ""}, " "),
  }
end

local function escape_hypertext(text)
  return core.formspec_escape(text:gsub("%s+", " "))
end

local function get_formspec(p_name)
  local title = core.formspec_escape(core.settings:get("serverguide.rules_title") or S("Server Rules"))
  local rule_sections = split_rule_sections(get_rules_text())
  local txt_size = get_adapted_font_size_to_screen(p_name)

  return table.concat({
    "formspec_version[9]",
    "size[14,18]",
    "position[0.5,0.47]",
    "no_prepend[]",
    "allow_close[false]",
    "bgcolor[;true]",
    "style_type[button;border=false]",
    "background[0,0;1,1;aesguide_first_steps.png;true]",
    "hypertext[4.3,4.2;8,3;name;<global valign=middle size=" .. txt_size .. " font=mono color=#ffffff>1. " .. escape_hypertext(rule_sections[1]) .. "]",
    "hypertext[1.75,8.5;9.2,3;name;<global valign=middle size=" .. txt_size .. " font=mono color=#ffffff>2. " .. escape_hypertext(rule_sections[2]) .. "]",
    "hypertext[4.3,12.7;8,3;name;<global valign=middle size=" .. txt_size .. " font=mono color=#ffffff>3. " .. escape_hypertext(rule_sections[3]) .. "]",
    "hypertext[1.3,16.3;2.5,0.55;name;<global valign=middle size=" .. txt_size .. " font=mono color=#eea160>" .. title .. "]",
    "button_exit[9.82,16.1;3.8,0.97;confirm;" .. S("Close") .. "]"
  }, "")
end

function serverguide.show_rules(p_name)
  core.show_formspec(p_name, "serverguide:rules", get_formspec(p_name))
end
