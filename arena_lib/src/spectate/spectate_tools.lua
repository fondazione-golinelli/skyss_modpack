local S = core.get_translator("arena_lib")

local function get_blind_confirm_formspec() end



core.register_tool("arena_lib:spectate_changeplayer", {

    description = S("Change player"),
    inventory_image = "arenalib_spectate_changeplayer.png",
    groups = {not_in_creative_inventory = 1},
    on_drop = function() end,

    on_use = function(itemstack, user)
      arena_lib.find_and_spectate_player(user:get_player_name())
    end,

    on_secondary_use = function(itemstack, user)
      arena_lib.find_and_spectate_player(user:get_player_name(), false, true)
    end,

    on_place = function(itemstack, user)
      arena_lib.find_and_spectate_player(user:get_player_name(), false, true)
    end
})



core.register_tool("arena_lib:spectate_changeplayerparty", {

  description = S("Change player"),
  inventory_image = "arenalib_spectate_changeplayerparty.png",
  groups = {not_in_creative_inventory = 1},
  on_drop = function() end,

  on_use = function(itemstack, user)
    arena_lib.find_and_spectate_player(user:get_player_name(), false, false, true)
  end,

  on_secondary_use = function(itemstack, user)
    arena_lib.find_and_spectate_player(user:get_player_name(), false, true, true)
  end,

  on_place = function(itemstack, user)
    arena_lib.find_and_spectate_player(user:get_player_name(), false, true, true)
  end
})



core.register_tool("arena_lib:spectate_changeteam", {

    description = S("Change team"),
    inventory_image = "arenalib_spectate_changeteam.png",
    groups = {not_in_creative_inventory = 1},
    on_drop = function() end,

    on_use = function(itemstack, user)
      local p_name = user:get_player_name()
      local arena = arena_lib.get_arena_by_player(p_name)

      -- non far cambiare se c'è rimasto solo una squadra da seguire
      if arena_lib.get_active_teams(arena) == 1 then return end

      arena_lib.find_and_spectate_player(p_name, true)
    end,

    on_secondary_use = function(itemstack, user)
      local p_name = user:get_player_name()
      local arena = arena_lib.get_arena_by_player(p_name)

      -- non far cambiare se c'è rimasto solo una squadra da seguire
      if arena_lib.get_active_teams(arena) == 1 then return end

      arena_lib.find_and_spectate_player(p_name, true, true)
    end,

    on_place = function(itemstack, user)
      local p_name = user:get_player_name()
      local arena = arena_lib.get_arena_by_player(p_name)

      -- non far cambiare se c'è rimasto solo una squadra da seguire
      if arena_lib.get_active_teams(arena) == 1 then return end

      arena_lib.find_and_spectate_player(p_name, true, true)
    end
})



core.register_tool("arena_lib:spectate_changeentity", {

    description = S("Change entity"),
    inventory_image = "arenalib_spectate_changeentity.png",
    groups = {not_in_creative_inventory = 1},
    on_drop = function() end,

    on_use = function(itemstack, user)
      local p_name = user:get_player_name()
      local mod = arena_lib.get_mod_by_player(p_name)
      local arena = arena_lib.get_arena_by_player(p_name)

      arena_lib.find_and_spectate_entity(mod, arena, p_name)
    end,

    on_secondary_use = function(itemstack, user)
      local p_name = user:get_player_name()
      local mod = arena_lib.get_mod_by_player(p_name)
      local arena = arena_lib.get_arena_by_player(p_name)

      arena_lib.find_and_spectate_entity(mod, arena, p_name, true)
    end,

    on_place = function(itemstack, user)
      local p_name = user:get_player_name()
      local mod = arena_lib.get_mod_by_player(p_name)
      local arena = arena_lib.get_arena_by_player(p_name)

      arena_lib.find_and_spectate_entity(mod, arena, p_name, true)
    end
})



core.register_tool("arena_lib:spectate_changearea", {

    description = S("Change area"),
    inventory_image = "arenalib_spectate_changearea.png",
    groups = {not_in_creative_inventory = 1},
    on_drop = function() end,

    on_use = function(itemstack, user)
      local p_name = user:get_player_name()
      local mod = arena_lib.get_mod_by_player(p_name)
      local arena = arena_lib.get_arena_by_player(p_name)

      arena_lib.find_and_spectate_area(mod, arena, p_name)
    end,

    on_secondary_use = function(itemstack, user)
      local p_name = user:get_player_name()
      local mod = arena_lib.get_mod_by_player(p_name)
      local arena = arena_lib.get_arena_by_player(p_name)

      arena_lib.find_and_spectate_area(mod, arena, p_name, true)
    end,

    on_place = function(itemstack, user)
      local p_name = user:get_player_name()
      local mod = arena_lib.get_mod_by_player(p_name)
      local arena = arena_lib.get_arena_by_player(p_name)

      arena_lib.find_and_spectate_area(mod, arena, p_name, true)
    end
})



core.register_tool("arena_lib:spectate_join", {

    description = S("Enter the match"),
    inventory_image = "arenalib_spectate_join.png",
    groups = {not_in_creative_inventory = 1},
    on_place = function() end,
    on_drop = function() end,

    on_use = function(itemstack, user)
      local p_name = user:get_player_name()
      local mod = arena_lib.get_mod_by_player(p_name)
      local arena_id = arena_lib.get_arenaID_by_player(p_name)

      arena_lib.join_arena(mod, p_name, arena_id)
    end
})



core.register_tool("arena_lib:spectate_quit", {

    description = S("Leave"),
    inventory_image = "arenalib_editor_quit.png",
    groups = {not_in_creative_inventory = 1},
    on_place = function() end,
    on_drop = function() end,

    on_use = function(itemstack, user)
      local p_name = user:get_player_name()
      local mod_ref = arena_lib.mods[arena_lib.get_mod_by_player(p_name)]

      if mod_ref.spectate_mode == "blind" then
        core.show_formspec(p_name, "arena_lib:quit_blind", get_blind_confirm_formspec())
      else
        arena_lib.remove_player_from_arena(p_name, 3)
      end
    end
})



core.register_tool("arena_lib:spectate_quit_wait", {

  description = S("Leave"),
  inventory_image = "arenalib_editor_quit.png^[hsl:0:-100",
  groups = {not_in_creative_inventory = 1},
  on_use = function() end,
  on_place = function() end,
  on_drop = function() end,
})





function get_blind_confirm_formspec()
  local fs = {
    "formspec_version[4]",
    "size[6,2.5]",
    "style[quit;bgcolor=red]",
    "style[confirm;bgcolor=green]",
    "hypertext[0.5,0.15;5,1.2;msg;<global halign=center valign=middle>" .. S("Are you sure you want to quit?\nIf you leave, you can't re-enter") .. "]",
    "button[3.25,1.5;1.75,0.7;confirm;" .. S("Confirm") .. "]",
    "button_exit[1,1.5;1.75,0.7;quit;" .. S("Cancel") .. "]",
    "field_close_on_enter[;false]"
  }

  return table.concat(fs, "")
end





core.register_on_player_receive_fields(function(player, formname, fields)
  if formname ~= "arena_lib:quit_blind" then return end

  local p_name = player:get_player_name()

  if fields.confirm and arena_lib.is_player_in_arena(p_name) then
    arena_lib.remove_player_from_arena(p_name, 3)
    core.close_formspec(p_name, "arena_lib:quit_blind")
  end
end)