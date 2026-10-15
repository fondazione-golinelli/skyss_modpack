local S = core.get_translator("hub")

hub.chat = true



core.register_on_chat_message(function(p_name, message)
  if not hub.is_in_game(p_name) and not hub.chat and not core.get_player_privs(p_name)["hub_admin"] then
    hub.print_error(p_name, S("Chat in the hub is temporarily disabled"))
    return true
  end
end)
