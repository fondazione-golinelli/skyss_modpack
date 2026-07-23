local S = core.get_translator("hub")

core.register_privilege("hub_admin", {
  description = S("It allows you to use /hub")
})

local function is_hub_admin(name)
  if not name or name == "" then return false end
  return core.check_player_privs(name, {
    hub_admin = true,
  }) or core.check_player_privs(name, {
    server = true,
  }) or core.check_player_privs(name, {
    protection_bypass = true,
  })
end
hub.is_admin = is_hub_admin

-- This mod is loaded only by the HUB server. Wrap the final protection
-- function after all mods load so existing arena protection remains intact.
core.register_on_mods_loaded(function()
  local previous_is_protected = core.is_protected
  core.is_protected = function(pos, name)
    if not is_hub_admin(name) then
      return true
    end
    return previous_is_protected(pos, name)
  end
end)
