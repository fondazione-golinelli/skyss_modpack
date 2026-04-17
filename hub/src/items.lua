local S = core.get_translator("hub")



core.register_tool("hub:settings", {
  description = S("Settings"),
  inventory_image = "hub_settings.png",
  groups = {not_in_creative_inventory = 1, oddly_breakable_by_hand = 2},
  on_place = function() end,
  on_drop = function() end,

  on_use = function(itemstack, user, pointed_thing)
    core.chat_send_player(user:get_player_name(), "Coming soon")
  end
})
