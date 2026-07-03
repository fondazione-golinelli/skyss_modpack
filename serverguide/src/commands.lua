local S = minetest.get_translator("serverguide")

core.register_chatcommand("tutorial", {
  description = S("Show an introduction to the server"),
  func = function(name, param)
    -- se è in arena, annullo
    if arena_lib.is_player_in_arena(name) then return false end

    serverguide.get_firststeps_formspec(name)
    return true
  end
})



core.register_chatcommand("rules", {
  description = S("Show the rules of the server"),
  func = function(name, param)
    -- se è in arena, annullo
    if arena_lib.is_player_in_arena(name) then return false end

    serverguide.show_rules(name)
    return true
  end
})
