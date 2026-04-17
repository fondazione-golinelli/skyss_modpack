function hub.print_error(name, msg)
  core.chat_send_player(name, core.colorize("#e6482e", "[!] " .. msg))
end