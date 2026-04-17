local S = core.get_translator("hub")

local al_blocked_cmds = table.key_value_swap(arena_lib.BLOCKED_CMDS)
local blocked_cmds = table.key_value_swap(hub.settings.blocked_cmds)
local blocked_cmds_both = {}

for k, _ in pairs(blocked_cmds) do
  if al_blocked_cmds[k] then
    blocked_cmds_both[k] = true
  end
end



core.register_on_chatcommand(function(name, command, params)
  if not core.check_player_privs(name, "hub_admin") then
    if blocked_cmds_both[command] then
      hub.print_error(name, S("Admins have blocked this command"))
      return true
    end

    if blocked_cmds[command] and not arena_lib.is_player_in_arena(name) then
      hub.print_error(name, S("Admins have blocked this command whilst in the lobby"))
      return true
    end
  end

  if al_blocked_cmds[command] and arena_lib.is_player_in_arena(name) then
    arena_lib.print_error(name, S("There's a time and place for everything. But not now!"))
    return true
  end
end)



local cmd = chatcmdbuilder.register("hub", {
  description = [[
    - celvault
    - chat off/on
    ]],
  privs = { hub_admin = true }
})



cmd:sub("celvault", function(sender)
  hub.edit_celvault(sender)
end)

cmd:sub("chat off", function(sender)
  core.chat_send_player(sender, "Hub chat is now off")
  hub.chat = false
end)

cmd:sub("chat on", function(sender)
  core.chat_send_player(sender, "Hub chat is now on")
  hub.chat = true
end)