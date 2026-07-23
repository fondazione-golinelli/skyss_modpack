core.register_allow_player_inventory_action(function(player, action, inventory, inventory_info)
   local pl_name = player:get_player_name()
   local arena = arena_lib.get_arena_by_player(pl_name)

   if (not arena or arena_lib.is_player_in_queue(pl_name))
         and not (hub.is_admin and hub.is_admin(pl_name)) then
      return 0
   end
end)
