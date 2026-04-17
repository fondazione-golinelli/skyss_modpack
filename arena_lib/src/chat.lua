local format = function(a,b) return core.format_chat_message(a,b) end
local col = function(a,b) return core.colorize(a,b) end

-- nel caso arena_lib venisse registrata prima di altre mod che interferiscono
-- con la chat (ponti IRC, chat di clan ecc.), i controlli che seguono verrebbero
-- eseguiti prima delle mod sopracitate, annullandole a priori (perché i controlli
-- vanno in ordine di registrazione). Evito ciò registrando i controlli della chat
-- delle arene solo dopo che tutte le mod sono già state caricate (e quindi registrate)
core.register_on_mods_loaded(function()
  core.register_on_chat_message(function(p_name, message)

    if not arena_lib.is_player_in_arena(p_name) or not arena_lib.mods[arena_lib.get_mod_by_player(p_name)].chat_settings.isolate_chat then
      for _, pl_stats in pairs(core.get_connected_players()) do
        local pl_name = pl_stats:get_player_name()
        if not arena_lib.is_player_in_arena(pl_name) or not arena_lib.mods[arena_lib.get_mod_by_player(pl_name)].chat_settings.isolate_chat then
          core.chat_send_player(pl_name, core.format_chat_message(p_name, message))
        end
      end

    else
      local mod_ref = arena_lib.mods[arena_lib.get_mod_by_player(p_name)]
      local arena = arena_lib.get_arena_by_player(p_name)
      local chat = mod_ref.chat_settings

      -- se è in celebrazione, tuttз posson parlare con tuttз
      if arena.in_celebration then
        local color, prefix
        if arena_lib.is_player_spectating(p_name) then
          color = chat.color_spectate
          prefix = chat.prefix_spectate
        else
          color = chat.color_all
          prefix = chat.prefix_all
        end

        arena_lib.send_message_in_arena(arena, "both", col(color, prefix .. format(p_name, message)))
        return true
      end

      if arena_lib.is_player_spectating(p_name) then
        local recipient = chat.can_interact_with_spectators and "both" or "spectators"
        arena_lib.send_message_in_arena(arena, recipient, col(chat.color_spectate, chat.prefix_spectate .. format(p_name, message)))

      else
        if arena.teams_enabled then
          if chat.is_team_chat_default then
            arena_lib.send_message_in_arena(arena, "players", col(chat.color_team, chat.prefix_team .. format(p_name, message)), arena.players[p_name].teamID)
          else
            arena_lib.send_message_in_arena(arena, "players", chat.prefix_all .. format(p_name, message), arena.players[p_name].teamID)
            arena_lib.send_message_in_arena(arena, "players", col("#ffdddd", chat.prefix_all .. format(p_name, message)), arena.players[p_name].teamID, true)

            if chat.can_interact_with_spectators then
              arena_lib.send_message_in_arena(arena, "spectators", chat.prefix_all .. format(p_name, message))
            end
          end
        else
          local recipient = chat.can_interact_with_spectators and "both" or "players"
          arena_lib.send_message_in_arena(arena, recipient, col(chat.color_all, chat.prefix_all .. format(p_name, message)))
        end
        return true
      end
    end

    return true
  end)
end)
