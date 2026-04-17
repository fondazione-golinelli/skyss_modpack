if not hub.settings.run_unit_tests then return end

local function sort_by_priority() end



----------------------------------------------
---------------------TEST---------------------
----------------------------------------------

local function unit_test_arenastatus_sorting()
  local arenas_test = {
    {
      name = "8. In game can't access (5/8)",
      in_game = true,
      mod = {},
      players_amount = 5,
      teams = {-1},
      max_players = 8
    },
    {
      name = "2. In game can access (4/5)",
      in_queue = false,
      in_game = true,
      mod = {join_while_in_progress = true},
      players_amount = 4,
      teams = {-1},
      max_players = 5
    },
    {
      name = "3. In game can access (2/5)",
      in_queue = false,
      in_game = true,
      mod = {join_while_in_progress = true},
      players_amount = 2,
      teams = {-1},
      max_players = 5
    },
    {
      name = "5. Waiting space left (2/8)",
      in_queue = false,
      in_game = false,
      mod = {},
      players_amount = 2,
      teams = {-1},
      max_players = 8
    },
    {
      name = "4. Waiting space left (6/8)",
      in_queue = false,
      in_game = false,
      mod = {},
      players_amount = 6,
      teams = {-1},
      max_players = 8
    },
    {
      name = "1. Queuing space left (7/8)",
      in_queue = true,
      in_game = false,
      mod = {},
      players_amount = 7,
      teams = {-1},
      max_players = 8
    },
    {
      name = "7. In game can access full (4/4)",
      in_queue = false,
      in_game = true,
      mod = {join_while_in_progress = true},
      players_amount = 4,
      teams = {-1},
      max_players = 4
    },
    {
      name = "6. Queuing full (8/8)",
      in_queue = true,
      in_game = false,
      mod = {},
      players_amount = 8,
      teams = {-1},
      max_players = 8
    },
  }

  table.sort(arenas_test, function(a, b) return sort_by_priority(a, b, true) end)

  local names = ""
  for i = 1, #arenas_test do
      names = names .. "\n" .. i .. ". " .. arenas_test[i].name
  end

  core.log("warning", "Sorted = " .. names)
end





----------------------------------------------
---------------FUNZIONI LOCALI----------------
----------------------------------------------

-- copy of the function in hud_arenastatus.lua
function sort_by_priority(a, b)
  local arena_a = a
  local arena_b = b
  local mod_ref_a = arena_a.mod
  local mod_ref_b = arena_b.mod

  local started_and_inaccessible_a = arena_a.in_game and not mod_ref_a.join_while_in_progress
  local started_and_inaccessible_b = arena_b.in_game and not mod_ref_b.join_while_in_progress

  if started_and_inaccessible_a ~= started_and_inaccessible_b then -- se una è inaccessibile in corso
    return started_and_inaccessible_b
  end

  local is_arena_a_full = arena_a.players_amount == arena_a.max_players * #arena_a.teams
  local is_arena_b_full = arena_b.players_amount == arena_b.max_players * #arena_b.teams

  if is_arena_a_full ~= is_arena_b_full then -- se solo una è piena
    return is_arena_b_full

  elseif (not arena_a.in_queue and not arena_a.in_game) ~= (not arena_b.in_queue and not arena_b.in_game) then -- se nessuna è in coda né in partita
    return not arena_b.in_queue and not arena_b.in_game

  elseif arena_a.in_game ~= arena_b.in_game then -- se solo una è in partita
    return arena_b.in_game

  else  -- se son uguali, ordina per giocanti
    return arena_a.players_amount > arena_b.players_amount
  end
end






core.after(0.1, function()
  unit_test_arenastatus_sorting()
end)