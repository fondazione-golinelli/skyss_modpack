local S = core.get_translator("arena_lib")



core.register_node("arena_lib:barrier", {
  description = S("Barrier"),
  drawtype = "airlike",
  paramtype = "light",
  sunlight_propagates = true,
  drop = "",
  inventory_image = "arenalib_node_barrier.png",
  wield_image = "arenalib_node_barrier.png",
  groups = {oddly_breakable_by_hand = 2},

  -- piazzabile in creativa e con arenalib_admin
  on_place = function(itemstack, placer, pointed_thing)
    if not placer:is_player() or core.settings:get_bool("creative_mode") then
      return core.item_place(itemstack, placer, pointed_thing)
    end

    local p_name = placer:get_player_name()
    local p_privs = core.get_player_privs(p_name)

    if not p_privs.creative and not p_privs.arenalib_admin then
      arena_lib.print_error(placer:get_player_name(), S("You need either the `arenalib_admin` or `creative` privilege to perform this action!"))
      return end

    return core.item_place(itemstack, placer, pointed_thing)
  end,

  -- idem come sopra
  can_dig = function(pos, player)
    local p_privs = core.get_player_privs(player:get_player_name())

    return core.settings:get_bool("creative_mode") or p_privs.arenalib_admin or p_privs.creative
  end
})
