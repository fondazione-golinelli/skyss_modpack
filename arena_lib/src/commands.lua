local S = core.get_translator("arena_lib")

local function get_minigames_by_arena() end
local function args() end

local blocked_cmds = table.key_value_swap(arena_lib.BLOCKED_CMDS)
local is_hub_present = core.get_modpath("hub")



core.register_on_chatcommand(function(name, command, params)
  if is_hub_present then return end -- let hub handle it

  if blocked_cmds[command] and arena_lib.is_player_in_arena(name) then
      arena_lib.print_error(name, S("There's a time and place for everything. But not now!"))
      return true
  end
end)



----------------------------------------------
-----------------ADMINS ONLY------------------
----------------------------------------------

local cmd_arenas = chatcmdbuilder.register("arenas", {
  params = "help",
  description = S("Manage arena_lib arenas; it requires arenalib_admin"),
  privs = { arenalib_admin = true }
})

-- gestione arena
cmd_arenas:sub("create :minigame :arena", function(sender, minigame, arena)
  arena_lib.create_arena(sender, minigame, arena)
end)

cmd_arenas:sub("create :minigame :arena :pmin:int :pmax:int", function(sender, minigame, arena, min, max)
  arena_lib.create_arena(sender, minigame, arena, min, max)
end)

cmd_arenas:sub("edit :minigame :arena", function(sender, minigame, arena)
  arena_lib.enter_editor(sender, minigame, arena)
end)

cmd_arenas:sub("edit :arena", function(sender, arena)
  local minigames = get_minigames_by_arena(arena)
  if #minigames > 1 then
    arena_lib.print_error(sender, S("There are more minigames having an arena called @1: please specify the name of the minigame before the name of the arena, separating them with a space", arena))
    return end

  arena_lib.enter_editor(sender, minigames[1], arena)
end)

cmd_arenas:sub("remove :minigame :arena", function(sender, minigame, arena)
  arena_lib.remove_arena(sender, minigame, arena)
end)

cmd_arenas:sub("remove :arena", function(sender, arena)
  local minigames = get_minigames_by_arena(arena)
  if #minigames > 1 then
    arena_lib.print_error(sender, S("There are more minigames having an arena called @1: please specify the name of the minigame before the name of the arena, separating them with a space", arena))
    return end

  arena_lib.remove_arena(sender, minigames[1], arena)
end)

-- abilita/disabilita
cmd_arenas:sub("enable :minigame :arena", function(sender, minigame, arena)
  arena_lib.enable_arena(sender, minigame, arena)
end)

cmd_arenas:sub("enable :arena", function(sender, arena)
  local minigames = get_minigames_by_arena(arena)
  if #minigames > 1 then
    arena_lib.print_error(sender, S("There are more minigames having an arena called @1: please specify the name of the minigame before the name of the arena, separating them with a space", arena))
    return end

  arena_lib.enable_arena(sender, minigames[1], arena)
end)

cmd_arenas:sub("disable :minigame :arena", function(sender, minigame, arena)
  arena_lib.disable_arena(sender, minigame, arena)
end)

cmd_arenas:sub("disable :arena", function(sender, arena)
  local minigames = get_minigames_by_arena(arena)
  if #minigames > 1 then
    arena_lib.print_error(sender, S("There are more minigames having an arena called @1: please specify the name of the minigame before the name of the arena, separating them with a space", arena))
    return end

  arena_lib.disable_arena(sender, minigames[1], arena)
end)

-- utilità arene
cmd_arenas:sub("info :minigame :arena", function(sender, minigame, arena)
  arena_lib.print_arena_info(sender, minigame, arena)
end)

cmd_arenas:sub("info :arena", function(sender, arena)
  local minigames = get_minigames_by_arena(arena)
  if #minigames > 1 then
    arena_lib.print_error(sender, S("There are more minigames having an arena called @1: please specify the name of the minigame before the name of the arena, separating them with a space", arena))
    return end

  arena_lib.print_arena_info(sender, minigames[1], arena)
end)

cmd_arenas:sub("list :minigame", function(sender, minigame)
  arena_lib.print_arenas(sender, minigame)
end)

cmd_arenas:sub("flush :minigame :arena", function(sender, minigame, arena)
  arena_lib.flush_arena(minigame, arena, sender)
end)

cmd_arenas:sub("flush :arena", function(sender, arena)
  local minigames = get_minigames_by_arena(arena)
  if #minigames > 1 then
    arena_lib.print_error(sender, S("There are more minigames having an arena called @1: please specify the name of the minigame before the name of the arena, separating them with a space", arena))
    return end

  arena_lib.flush_arena(minigames[1], arena, sender)
end)

cmd_arenas:sub("check_resources", function(sender)
  arena_lib.check_for_unused_resources(sender)
end)

cmd_arenas:sub("forcestart :minigame :arena", function(sender, minigame, arena)
  local _, ar = arena_lib.get_arena_by_name(minigame, arena)

  arena_lib.force_start(sender, minigame, ar)
end)

cmd_arenas:sub("forcestart :arena", function(sender, arena)
  local minigames = get_minigames_by_arena(arena)
  if #minigames > 1 then
    arena_lib.print_error(sender, S("There are more minigames having an arena called @1: please specify the name of the minigame before the name of the arena, separating them with a space", arena))
    return end

  local _, ar = arena_lib.get_arena_by_name(minigames[1], arena)

  arena_lib.force_start(sender, minigames[1], ar)
end)

cmd_arenas:sub("forceend :minigame :arena", function(sender, minigame, arena)
  local _, ar = arena_lib.get_arena_by_name(minigame, arena)

  arena_lib.force_end(sender, minigame, ar)
end)

cmd_arenas:sub("forceend :arena", function(sender, arena)
  local minigames = get_minigames_by_arena(arena)
  if #minigames > 1 then
    arena_lib.print_error(sender, S("There are more minigames having an arena called @1: please specify the name of the minigame before the name of the arena, separating them with a space", arena))
    return end

  local _, ar = arena_lib.get_arena_by_name(minigames[1], arena)

  arena_lib.force_end(sender, minigames[1], ar)
end)

-- gestione minigiochi
cmd_arenas:sub("entrances :minigame", function(sender, minigame)
  arena_lib.enter_entrance_settings(sender, minigame)
end)

cmd_arenas:sub("settings :minigame", function(sender, minigame)
  arena_lib.enter_minigame_settings(sender, minigame)
end)

cmd_arenas:sub("glist", function(sender)
  arena_lib.print_minigames(sender)
end)

cmd_arenas:sub("gamelist", function(sender)
  arena_lib.print_minigames(sender)
end)

-- gestione utenti
cmd_arenas:sub("kick :player", function(sender, p_name)
  -- se il giocatore non è online, annullo
  if not core.get_player_by_name(p_name) then
    arena_lib.print_error(sender, S("This player is not online!"))
    return end

  -- se il giocatore non è in partita, annullo
  if not arena_lib.is_player_in_arena(p_name) then
    arena_lib.print_error(sender, S("The player must be in a game to perform this action!"))
    return end

  arena_lib.remove_player_from_arena(p_name, 2, sender)
  arena_lib.print_info(sender, S("Player successfully kicked"))
end)

-- aiuto
cmd_arenas:sub("help", function(sender)
  core.chat_send_player(sender,
    core.colorize("#ffff00", S("COMMANDS")) .. "\n"
    .. core.colorize("#00ffff", "/arenas check_resources") .. ": " .. S("check if there is any unused resource inside the arena_lib world folder (inside BGM and Thumbnails)") .. "\n"
    .. core.colorize("#00ffff", "/arenas create")     .. args(" <" .. S("minigame") .. "> <" .. S("arena") .. "> (<pmin> <pmax>)") .. S("creates an arena for the specified minigame") .. "\n"
    .. core.colorize("#00ffff", "/arenas disable")    .. args(" (<" .. S("minigame") .. ">) <" .. S("arena") .. ">") .. S("disables an arena") .. "\n"
    .. core.colorize("#00ffff", "/arenas edit")       .. args(" (<" .. S("minigame") .. ">) <" .. S("arena") .. ">") .. S("enters the arena editor") .. "\n"
    .. core.colorize("#00ffff", "/arenas enable")     .. args(" (<" .. S("minigame") .. ">) <" .. S("arena") .. ">") .. S("enables an arena") .. "\n"
    .. core.colorize("#00ffff", "/arenas entrances")  .. args(" <" .. S("minigame") .. ">") .. S("changes the entrance types of the specified minigame") .. "\n"
    .. core.colorize("#00ffff", "/arenas flush")      .. args(" (<" .. S("minigame") .. ">) <" .. S("arena") .. ">") .. S("DEBUG ONLY - resets the properties of a bugged arena") .. "\n"
    .. core.colorize("#00ffff", "/arenas forceend")   .. args(" (<" .. S("minigame") .. ">) <" .. S("arena") .. ">") .. S("forcibly ends an ongoing game") .. "\n"
    .. core.colorize("#00ffff", "/arenas forcestart") .. args(" (<" .. S("minigame") .. ">) <" .. S("arena") .. ">") .. S("forcibly loads (if in queue) or starts (if in the loading phase) a game") .. "\n"
    .. core.colorize("#00ffff", "/arenas gamelist")   .. ": " .. S("lists all the installed minigames, alphabetically sorted") .. "\n"
    .. core.colorize("#00ffff", "/arenas glist")      .. ": " .. S("see @1", "gamelist") .. "\n"
    .. core.colorize("#00ffff", "/arenas info")       .. args(" (<" .. S("minigame") .. ">) <" .. S("arena") .. ">") .. S("prints all the arena's info") .. "\n"
    .. core.colorize("#00ffff", "/arenas kick")       .. args(" <" .. S("player") .. ">") .. S("kicks a player from an ongoing game. When kicked, they must wait 2 minutes before re-entering a match") .. "\n"
    .. core.colorize("#00ffff", "/arenas list")       .. args(" <" .. S("minigame") .. ">") .. S("lists all the arenas of the specified minigame") .. "\n"
    .. core.colorize("#00ffff", "/arenas remove")     .. args(" (<" .. S("minigame") .. ">) <" .. S("arena") .. ">") .. S("deletes an arena") .. "\n"
    .. core.colorize("#00ffff", "/arenas settings")   .. args(" <" .. S("minigame") .. ">") .. S("tweaks the minigame settings for the current server") .. "\n\n"

    .. core.colorize("#ffff00", S("UTILS")) .. "\n"
    .. S("Barrier node: use it to fence your arenas")
  )
end)





----------------------------------------------
----------------FOR EVERYONE------------------
----------------------------------------------

core.register_chatcommand("quit", {
  description = S("Quits a queue or an ongoing game"),

  func = function(name, param)
    if not arena_lib.is_player_in_arena(name) and not arena_lib.is_player_in_queue(name) then
      arena_lib.print_error(name, S("You must be in a game or in queue to perform this action!"))
      return end

    local arena = arena_lib.get_arena_by_player(name)

    -- se è in gioco...
    if arena.in_game then
      -- se l'arena è in celebrazione, annullo
      if arena.in_celebration then
        arena_lib.print_error(name, S("You can't perform this action during the celebration phase!"))
        return end

      local mod_ref = arena_lib.mods[arena_lib.get_mod_by_player(name)]

      -- se uso /quit e on_prequit ritorna false, annullo
      if mod_ref.on_prequit then
        if mod_ref.on_prequit(arena, name) == false then
        return end
      end

      arena_lib.remove_player_from_arena(name, 3)
      return true

    -- ..sennò è in coda
    else
      arena_lib.remove_player_from_queue(name)
      return true
    end
  end
})



core.register_chatcommand("all", {
  params = "<" .. S("message") .. ">",
  description = S("Writes a message in the arena global chat while in a game"),

  func = function(name, param)

    -- se non è in arena, annullo
    if not arena_lib.is_player_in_arena(name) then
      arena_lib.print_error(name, S("You must be in a game to perform this action!"))
      return false end

    -- se è spettatore, annullo
    if arena_lib.is_player_spectating(name) then
      arena_lib.print_error(name, S("You must be in a game to perform this action!"))
      return false end

    local msg = string.match(param, ".*")
    local chat_settings = arena_lib.mods[arena_lib.get_mod_by_player(name)].chat_settings
    local arena = arena_lib.get_arena_by_player(name)
    local recipient = chat_settings.can_interact_with_spectators and "both" or "players"

    arena_lib.send_message_in_arena(arena, recipient, core.colorize(chat_settings.color_all, chat_settings.prefix_all .. core.format_chat_message(name, msg)))
    return true
  end
})



core.register_chatcommand("t", {

  params = "<" .. S("message") .. ">",
  description = S("Writes a message in the arena team chat while in a game (if teams are enabled)"),

  func = function(name, param)

    -- se non è in arena, annullo
    if not arena_lib.is_player_in_arena(name) then
      arena_lib.print_error(name, S("You must be in a game to perform this action!"))
      return false end

    -- se è spettatore, annullo
    if arena_lib.is_player_spectating(name) then
      arena_lib.print_error(name, S("You must be in a game to perform this action!"))
      return false end

    local msg = string.match(param, ".*")
    local chat_settings = arena_lib.mods[arena_lib.get_mod_by_player(name)].chat_settings
    local arena = arena_lib.get_arena_by_player(name)
    local teamID = arena.players[name].teamID

    if not teamID then
      arena_lib.print_error(name, S("Teams are not enabled!"))
      return false end

    arena_lib.send_message_in_arena(arena, "players", core.colorize(chat_settings.color_team, chat_settings.prefix_team .. core.format_chat_message(name, msg)), teamID)
    return true
  end
})





----------------------------------------------
---------------FUNZIONI LOCALI----------------
----------------------------------------------

function get_minigames_by_arena(arena_name)
  local mgs = {}
  for mg, mg_data in pairs(arena_lib.mods) do
    for _, arena in pairs(mg_data.arenas) do
      if arena.name == arena_name then
        table.insert(mgs, mg)
        break
      end
    end
  end
  return mgs
end



function args(str)
  return core.colorize("#00abab", str) .. ": "
end