local S = core.get_translator("serverguide")
local FS = function(...) return core.formspec_escape(S(...)) end

local DEFAULT_RULES = {
  FS("Be respectful to other players and staff."),
  FS("Keep chat friendly and appropriate."),
  FS("Do not grief, cheat, exploit bugs, or disrupt other players."),
  FS("Follow teacher and admin instructions."),
  FS("Protect your account and do not share personal information.")
}

local function escape_hypertext(text)
  return core.formspec_escape(text:gsub("%s+", " "):gsub("\\", "\\\\"):gsub("<", "\\<"))
end

-- one rule per line
local function get_rules()
  local text = core.settings:get("serverguide.rules_text")
  if not text or not text:match("%S") then
    return DEFAULT_RULES
  end

  local rules = {}
  for rule in text:gsub("\\n", "\n"):gmatch("[^\n]+") do
    if rule:match("%S") then
      table.insert(rules, escape_hypertext(rule))
    end
  end

  return rules
end

local function get_formspec(p_name)
  local title = core.settings:get("serverguide.rules_title")

  return serverguide.get_board_formspec(p_name, {
    title = title and escape_hypertext(title) or FS("SERVER RULES"),
    items = get_rules(),
    hint = "/rules",
    button = FS("Close")
  })
end

function serverguide.show_rules(p_name)
  core.show_formspec(p_name, "serverguide:rules", get_formspec(p_name))
end
