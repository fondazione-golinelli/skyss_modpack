local S = core.get_translator("arena_lib")

local function follow_executioner_or_random() end
local function calc_p_amount_teams() end
local function calc_spec_id() end
local function override_hotbar() end
local function set_spectator() end

local players_in_spectate_mode = {}         -- KEY: player name, VALUE: {(string) minigame, (int) arenaID, (string) type, (string) spectating}
local spectate_temp_storage = {}            -- KEY: player_name, VALUE: {(string) camera_mode, (table) camera_offset, (string) inventory_fs, (ItemStack) hand}
local players_spectated = {}                -- KEY: player name, VALUE: {(string) spectator(s) = true}
local entities_spectated = {}               -- KEY: [mod][arena_name][entity name], VALUE: {(string) spectator(s) = true}
local areas_spectated = {}                  -- KEY: [mod][arena_name][area_name], VALUE: {(string) spectator(s) = true}
local entities_storage = {}                 -- KEY: [mod][arena_name][entity_name], VALUE: entity
local areas_storage = {}                    -- KEY: [mod][arena_name][area_name], VALUE: dummy entity
local is_parties_enabled = core.get_modpath("parties")



----------------------------------------------
--------------INTERNAL USE ONLY---------------
----------------------------------------------

-- init e unload servono esclusivamente per le eventuali entità e aree, e vengon
-- chiamate rispettivamente quando l'arena si avvia e termina. I contenitori dei
-- giocatori invece vengono creati/distrutti singolarmente ogni volta che un giocatore
-- entra/esce, venendo lanciati in operations_before_playing/leaving_arena

function arena_lib.init_spectate_containers(mod, arena_name)
  if not entities_spectated[mod] then
    entities_spectated[mod] = {}
  end
  if not areas_spectated[mod] then
    areas_spectated[mod] = {}
  end
  if not entities_storage[mod] then
    entities_storage[mod] = {}
  end
  if not areas_storage[mod] then
    areas_storage[mod] = {}
  end

  entities_spectated[mod][arena_name] = {}
  areas_spectated[mod][arena_name] = {}
  entities_storage[mod][arena_name] = {}
  areas_storage[mod][arena_name] = {}
end



function arena_lib.unload_spectate_containers(mod, arena_name)
  -- rimuovo tutte le entità fantoccio delle aree
  for _, dummy_entity in pairs(arena_lib.get_spectatable_areas(mod, arena_name)) do
    dummy_entity:remove()
  end

  -- non c'è bisogno di cancellare X[mod], al massimo rimangono vuote
  entities_spectated[mod][arena_name] = nil
  areas_spectated[mod][arena_name] = nil
  entities_storage[mod][arena_name] = nil
  areas_storage[mod][arena_name] = nil
end



function arena_lib.add_spectate_p_container(p_name)
  players_spectated[p_name] = {}
end



function arena_lib.remove_spectate_p_container(p_name)
  players_spectated[p_name] = {}
end


----------------------------
-- entering / leaving
----------------------------

function arena_lib.enter_spectate_mode(p_name, arena, p_team_ID, xc_name)
  local mod      = arena_lib.get_mod_by_player(p_name)
  local arena_ID = arena_lib.get_arenaID_by_player(p_name)
  local player   = core.get_player_by_name(p_name)
  local hand     = p_name:find(" ") and "" or player:get_inventory():get_list("hand")
  p_team_ID      = p_team_ID or (arena.teams_enabled and 1)

  players_in_spectate_mode[p_name] = { minigame = mod, arenaID = arena_ID, teamID = p_team_ID, hand = hand}
  arena.spectators[p_name] = {}
  arena.players_and_spectators[p_name] = true
  arena.spectators_amount = arena.spectators_amount + 1

  local mod_ref = arena_lib.mods[mod]

  -- eventuali proprietà aggiuntive
  for k, v in pairs(mod_ref.spectator_properties) do
    if type(v) == "table" then
      arena.spectators[p_name][k] = table.copy(v)
    else
      arena.spectators[p_name][k] = v
    end
  end

  -- se fantoccio, fermati qui
  if p_name:find(" ") then return end

  local p_inv = player:get_inventory()

  -- che siano entrati anche come giocanti o meno, non importa, in quanto operations_before_entering_arena
  -- viene eseguita prima dell'entrata nella spettatore, e quindi questi parametri
  -- sono già stati eventualmente salvati nell'archiviazione di arena_lib
  spectate_temp_storage[p_name] = {}
  spectate_temp_storage[p_name].camera_mode = player:get_camera()
  spectate_temp_storage[p_name].camera_offset = {player:get_eye_offset()}
  spectate_temp_storage[p_name].inventory_fs = player:get_inventory_formspec()
  spectate_temp_storage[p_name].hand = p_inv:get_stack("hand", 1)

  -- applico mano finta
  p_inv:set_size("hand", 1)
  p_inv:set_stack("hand", 1, "arena_lib:spectate_hand")

  -- applicazione parametri vari
  local current_properties = table.copy(player:get_properties())
  players_in_spectate_mode[p_name].properties = current_properties

  player:set_properties({
    visual_size = {x = 0, y = 0},
    makes_footstep_sound = false,
    collisionbox = {0},
    pointable = false
  })

  player:set_camera({mode = "third"})
  player:set_eye_offset({x = 0, y = -2, z = -25}, {x=0, y=0, z=0})
  player:set_nametag_attributes({color = {a = 0}})
  player:set_inventory_formspec("")

  -- assegno un ID al giocatore per ruotare chi/cosa sta seguendo, in quanto gli
  -- elementi seguibili non dispongono di un ID per orientarsi nella loro navigazione
  -- (cosa viene dopo l'elemento X? È il capolinea?). Lo uso essenzialmente come
  -- un i = 1 nei cicli for, per capire dove mi trovo e cosa verrebbe dopo
  -- (assegnarlo a 0 equivale ad azzerarlo, ma l'ho specificato per chiarezza nel codice)
  player:get_meta():set_int("arenalib_watchID", 0)

  local can_read_msg = mod_ref.chat_settings.can_interact_with_spectators and
      S("In @1, spectate chat @2is shared@3 with players", mod_ref.name, core.get_color_escape_sequence("#88ff88"), core.get_color_escape_sequence("#cfc6b8")) or
      S("In @1, spectate chat @2is not shared@3 with players", mod_ref.name, core.get_color_escape_sequence("#ff8888"), core.get_color_escape_sequence("#cfc6b8"))
  local curr_spectators = ""

  -- dì chi sta già seguendo
  for sp_name, _ in pairs(arena.spectators) do
    curr_spectators = curr_spectators .. sp_name .. ", "
  end

  curr_spectators = curr_spectators:sub(1, -3)

  core.chat_send_player(p_name, core.colorize("#cfc6b8", can_read_msg))
  core.chat_send_player(p_name, core.colorize("#cfc6b8", S("Spectators inside: @1", curr_spectators)))

  -- inizia a seguire
  if mod_ref.spectate_mode == "blind" then
    local found = false
    if p_team_ID and arena.players_amount_per_team[p_team_ID] > 0 then
      for _, pl_name in pairs(arena_lib.get_players_in_team(arena, p_team_ID)) do
        arena_lib.spectate_target(mod, arena, p_name, "player", pl_name)
        found = true
        break
      end

    elseif is_parties_enabled and parties.is_player_in_party(p_name) then
      local pt_members = arena_lib.get_party_members_playing(p_name, arena)

      if #pt_members > 0 then
        arena_lib.spectate_target(mod, arena, p_name, "player", pt_members[1])
        found = true
      end
    end

    if not found then
      follow_executioner_or_random(mod, arena, p_name, xc_name)
    end

  else
    follow_executioner_or_random(mod, arena, p_name, xc_name)
  end

  override_hotbar(player, mod, arena)

  -- il 1° secondo non permettere di uscire (evita clic per sbaglio)
  p_inv:set_stack("main", player:hud_get_hotbar_itemcount(), "arena_lib:spectate_quit_wait")

  core.after(1, function()
    if not arena_lib.is_player_spectating(p_name) then return end
    p_inv:set_stack("main", player:hud_get_hotbar_itemcount(), "arena_lib:spectate_quit")
  end)

  return true
end



function arena_lib.leave_spectate_mode(p_name)
  local arena = arena_lib.get_arena_by_player(p_name)

  arena.spectators[p_name] = nil
  arena.spectators_amount = arena.spectators_amount -1

  -- se fantoccio, fermati qui
  if p_name:find(" ") then players_in_spectate_mode[p_name] = nil return end

  local player = core.get_player_by_name(p_name)
  local p_inv = player:get_inventory()
  local prev_hand = players_in_spectate_mode[p_name].hand

  -- rimuovo mano finta e reimposto eventuale mano precedente
  if prev_hand then
    p_inv:set_list("hand", prev_hand)
  else
    p_inv:set_size("hand", 0)
  end

  local p_storage = spectate_temp_storage[p_name]
  local prev_camera = p_storage.camera_mode

  -- che siano entrati anche come giocanti o meno, non importa, in quanto operations_before_leaving_arena
  -- viene eseguita dopo l'uscita dalla spettatore, e quindi questi parametri
  -- verranno eventualmente poi sovrascritti da quelli nell'archiviazione di arena_lib

  -- se `"any"`, forzo la prima persona prima, in quanto è la più usata
  if prev_camera.mode == "any" then
    player:set_camera({mode = "first"})
    -- TEMP: senza after di 0.1 non va, https://github.com/luanti-org/luanti/issues/16211
    core.after(0.1, function()
        if not core.get_player_by_name(p_name) then return end
        player:set_camera({mode = "any"})
    end)

  else
    player:set_camera(prev_camera)
  end

  player:set_eye_offset(p_storage.camera_offset[1], p_storage.camera_offset[2])
  player:set_inventory_formspec(p_storage.inventory_fs)
  player:get_inventory():set_stack("hand", 1, p_storage.hand)
  spectate_temp_storage[p_name] = nil

  player:set_detach()
  player:set_properties(players_in_spectate_mode[p_name].properties)
  player:get_meta():set_int("arenalib_watchID", 0)

  arena_lib.HUD_hide("hotbar", p_name)

  local target = players_in_spectate_mode[p_name].spectating
  local type = players_in_spectate_mode[p_name].type

  -- rimuovo dal database locale
  if type == "player" then
    players_spectated[target][p_name] = nil
  else

    local mod = arena_lib.get_mod_by_player(p_name)
    local arena_name = arena.name

    if type == "entity" then
      entities_spectated[mod][arena_name][target][p_name] = nil
    elseif type == "area" then
      areas_spectated[mod][arena_name][target][p_name] = nil
    end
  end

  players_in_spectate_mode[p_name] = nil
end



----------------------------
-- find next spectatable target
----------------------------

function arena_lib.find_and_spectate_player(sp_name, change_team, go_counterwise, rotate_in_party)
  local arena = arena_lib.get_arena_by_player(sp_name)

  -- se l'ultimə rimastə ha abbandonato (es. alt+f4), rispedisco subito fuori senza che cada all'infinito con rischio di crash
  if arena.players_amount == 0 then
    arena_lib.remove_player_from_arena(sp_name, 3)
    return end

  local prev_spectated = players_in_spectate_mode[sp_name].spectating

  -- se c'è rimastə solo unə giocante e già lə si seguiva, annullo
  if arena.players_amount == 1 and prev_spectated and arena.players[prev_spectated] then return end

  local mod = arena_lib.get_mod_by_player(sp_name)
  local spectator = core.get_player_by_name(sp_name)

  -- aggiornamenti vari della barra delle azioni
  -- TODO: aggiornare icona persona singola quando squadre e 1vN
  if is_parties_enabled and parties.is_player_in_party(sp_name) then
    arena_lib.update_spec_hotbar_party(mod, arena, sp_name)
  end

  if players_in_spectate_mode[sp_name].type ~= "player" then
    spectator:get_meta():set_int("arenalib_watchID", 0)
  end

  local team_ID = players_in_spectate_mode[sp_name].teamID
  local players_amount

  -- calcolo giocanti massimɜ tra cui ruotare
  -- squadre:
  if arena.teams_enabled and not rotate_in_party then
    -- se è l'unicə rimastə nella squadra e già lə si seguiva, annullo
    if arena.players_amount_per_team[team_ID] == 1 and not change_team and prev_spectated and arena.players[prev_spectated] then return end
    players_amount, team_ID = calc_p_amount_teams(arena, sp_name, team_ID, change_team, prev_spectated)
  elseif rotate_in_party then
    players_amount = #arena_lib.get_party_members_playing(sp_name, arena)
  -- no squadre:
  else
    players_amount = arena.players_amount
  end

  local curr_ID = spectator:get_meta():get_int("arenalib_watchID")
  local new_ID = calc_spec_id(curr_ID, players_amount, go_counterwise)

  -- trovo giocante da seguire
  -- squadre:
  if arena.teams_enabled then
    local players_team = arena_lib.get_players_in_team(arena, team_ID)
    for i = 1, #players_team do

      if i == new_ID then
        set_spectator(mod, arena.name, spectator, "player", players_team[i], i)
        return true
      end
    end

  -- gruppo:
  elseif rotate_in_party then
    local pt_members = arena_lib.get_party_members_playing(sp_name, arena)
    for i, pl_name in ipairs(pt_members) do
      if i == new_ID then
        -- evita che alternando tra singolo e gruppo riselezioni la stessa persona
        if prev_spectated and prev_spectated == pl_name then
          i = calc_spec_id(new_ID, players_amount, go_counterwise)
          pl_name = pt_members[i]
        end
        set_spectator(mod, arena.name, spectator, "player", pl_name, i)
        return true
      end
    end

  -- singolo:
  else
    local i = 1
    for pl_name, _ in pairs(arena.players) do
      if i == new_ID then
        -- evita che alternando tra singolo e gruppo riselezioni la stessa persona
        if prev_spectated and prev_spectated == pl_name then
          new_ID = calc_spec_id(new_ID, players_amount, go_counterwise)
          i = 1
          for pla_name, _ in pairs(arena.players) do
            if i == new_ID then
              set_spectator(mod, arena.name, spectator, "player", pla_name, i)
              return true
            end
            i = i +1
          end
        end

        set_spectator(mod, arena.name, spectator, "player", pl_name, i)
        return true
      end

      i = i + 1
    end
  end
end



function arena_lib.find_and_spectate_entity(mod, arena, sp_name, go_counterwise)
  local e_amount = arena.spectate_entities_amount

  -- se non ci sono entità da seguire, segui un giocatore
  if e_amount == 0 then
    arena_lib.find_and_spectate_player(sp_name)
    return end

  local arena_name = arena.name
  local prev_spectated = players_in_spectate_mode[sp_name].spectating

  -- se è l'unica entità rimasta e la si stava già seguendo
  if e_amount == 1 and prev_spectated and next(entities_spectated[mod][arena_name])[sp_name] then
    return end

  local spectator = core.get_player_by_name(sp_name)

  if players_in_spectate_mode[sp_name].type ~= "entity" then
    spectator:get_meta():set_int("arenalib_watchID", 0)
  end

  local current_ID = spectator:get_meta():get_int("arenalib_watchID")
  local new_ID

  if go_counterwise then
    new_ID = current_ID == 1 and e_amount or current_ID - 1
  else
    new_ID = e_amount <= current_ID and 1 or current_ID + 1
  end

  local i = 1
  for en_name, _ in pairs(entities_storage[mod][arena_name]) do
    if i == new_ID then
      set_spectator(mod, arena_name, spectator, "entity", en_name, i)
      return true
    end

    i = i +1
  end
end



function arena_lib.find_and_spectate_area(mod, arena, sp_name, go_counterwise)
  local ar_amount = arena.spectate_areas_amount

  -- se non ci sono aree da seguire, segui un giocatore
  if ar_amount == 0 then
    arena_lib.find_and_spectate_player(sp_name)
    return end

  local arena_name = arena.name
  local prev_spectated = players_in_spectate_mode[sp_name].spectating

  -- se è l'unica area rimasta e la si stava già seguendo
  if ar_amount == 1 and prev_spectated and next(areas_spectated[mod][arena_name])[sp_name] then
    return end

  local spectator = core.get_player_by_name(sp_name)

  if players_in_spectate_mode[sp_name].type ~= "area" then
    spectator:get_meta():set_int("arenalib_watchID", 0)
  end

  local current_ID = spectator:get_meta():get_int("arenalib_watchID")
  local new_ID

  if go_counterwise then
    new_ID = current_ID == 1 and ar_amount or current_ID - 1
  else
    new_ID = ar_amount <= current_ID and 1 or current_ID + 1
  end

  local i = 1
  for ar_name, _ in pairs(areas_storage[mod][arena_name]) do
    if i == new_ID then
      set_spectator(mod, arena_name, spectator, "area", ar_name, i)
      return true
    end

    i = i +1
  end
end





----------------------------------------------
---------------------CORE---------------------
----------------------------------------------

function arena_lib.add_spectate_entity(mod, arena, e_name, entity)
  if not arena.in_game then return end

  local arena_name = arena.name
  local old_deact = entity.on_deactivate

  -- aggiungo sull'on_deactivate la funzione per rimuoverla dalla spettatore
  entity.on_deactivate = function(...)
    local ret = old_deact and old_deact(...)

    arena_lib.remove_spectate_entity(mod, arena, e_name)
    return ret
  end

  -- la aggiungo
  entities_spectated[mod][arena_name][e_name] = {}
  entities_storage[mod][arena_name][e_name] = entity
  arena.spectate_entities_amount = arena.spectate_entities_amount + 1

  -- se è l'unica entità registrata, aggiungo lo slot per seguire le entità
  if arena.spectate_entities_amount == 1 then
    for sp_name, _ in pairs(arena.spectators) do
      override_hotbar(core.get_player_by_name(sp_name), mod, arena)
    end
  end
end



function arena_lib.add_spectate_area(mod, arena, pos_name, pos)
  if not arena.in_game then return end

  core.forceload_block(pos, true)

  local dummy_entity = core.add_entity(pos, "arena_lib:spectate_dummy", core.serialize({mod = mod, arena_name = arena.name}))
  local arena_name = arena.name

  areas_spectated[mod][arena_name][pos_name] = {}
  areas_storage[mod][arena_name][pos_name] = dummy_entity
  arena.spectate_areas_amount = arena.spectate_areas_amount + 1

  -- se è l'unica area registrata, aggiungo lo slot per seguire le aree
  if arena.spectate_areas_amount == 1 then
    for sp_name, _ in pairs(arena.spectators) do
      override_hotbar(core.get_player_by_name(sp_name), mod, arena)
    end
  end

end



function arena_lib.remove_spectate_entity(mod, arena, e_name)
  if not arena.in_game then return end          -- nel caso il minigioco si sia scordata di cancellarla, all'ucciderla fuori dalla partita non crasha

  local arena_name = arena.name

  entities_storage[mod][arena_name][e_name] = nil
  arena.spectate_entities_amount = arena.spectate_entities_amount - 1

  -- se non ci sono più entità, fai sparire l'icona
  if arena.spectate_entities_amount == 0 then
    for sp_name, _ in pairs(arena.spectators) do
      local spectator = core.get_player_by_name(sp_name)
      override_hotbar(spectator, mod, arena)
    end
  end

  for sp_name, _ in pairs(entities_spectated[mod][arena_name][e_name]) do
    arena_lib.find_and_spectate_entity(mod, arena, sp_name)
  end
end



function arena_lib.remove_spectate_area(mod, arena, pos_name)
  local arena_name = arena.name

  areas_storage[mod][arena_name][pos_name]:remove()
  areas_storage[mod][arena_name][pos_name] = nil
  arena.spectate_areas_amount = arena.spectate_areas_amount - 1

  -- se non ci sono più aree, fai sparire l'icona
  if arena.spectate_areas_amount == 0 then
    for sp_name, _ in pairs(arena.spectators) do
      local spectator = core.get_player_by_name(sp_name)
      override_hotbar(spectator, mod, arena)
    end
  end

  for sp_name, _ in pairs(areas_spectated[mod][arena_name][pos_name]) do
    arena_lib.find_and_spectate_area(mod, arena, sp_name)
  end
end



function arena_lib.spectate_target(mod, arena, sp_name, type, t_name)
  if type == "player" then
    if arena.players_amount == 0 or not players_spectated[t_name] then return end

    -- se ci son le squadre, assegna l'ID della squadra
    if arena.teams_enabled then
      players_in_spectate_mode[sp_name].teamID = arena.players[t_name].teamID
    end
  elseif type == "entity" then
    if arena.spectate_entities_amount == 0 or not entities_spectated[mod][arena.name][t_name] then return end
  elseif type == "area" then
    if arena.spectate_areas_amount == 0 or not areas_spectated[mod][arena.name][t_name] then return end
  else
    return
  end

  -- sì, potrei richiedere direttamente 'spectator', ma per coesione con il resto dell'API e con il fatto che
  -- arena_lib salva lɜ spettanti indicizzandolɜ per nome, tanto vale una conversione in più qui
  local spectator = core.get_player_by_name(sp_name)
  local i = spectator:get_meta():get_int("arenalib_watchID")     -- non c'è bisogno di calcolare l'ID, riapplico quello che già ha
  set_spectator(mod, arena.name, spectator, type, t_name, i, true)
end



function arena_lib.update_spec_hotbar_party(mod, arena, sp_name)
  local pt_members_amnt = #arena_lib.get_party_members_playing(sp_name, arena)
  local spectator = core.get_player_by_name(sp_name)
  local spectate_mode = arena_lib.mods[mod].spectate_mode

  if ((spectate_mode == "blind" and pt_members_amnt <= 1) or
     (spectate_mode ~= "blind" and pt_members_amnt == 0)) and
     spectator:get_inventory():contains_item("main", "arena_lib:spectate_changeplayerparty") then
    override_hotbar(spectator, mod, arena)
  end
end





----------------------------------------------
--------------------UTILS---------------------
----------------------------------------------

function arena_lib.is_player_spectating(sp_name)
  return players_in_spectate_mode[sp_name] ~= nil
end



function arena_lib.is_player_spectated(p_name)
  return players_spectated[p_name] and next(players_spectated[p_name])
end



function arena_lib.is_entity_spectated(mod, arena_name, e_name)
  return entities_spectated[mod][arena_name][e_name] and next(entities_spectated[mod][arena_name][e_name])
end



function arena_lib.is_area_spectated(mod, arena_name, pos_name)
  return areas_spectated[mod][arena_name][pos_name] and next(areas_spectated[mod][arena_name][pos_name])
end





----------------------------------------------
-----------------GETTERS----------------------
----------------------------------------------

function arena_lib.get_player_spectators(p_name)
  return players_spectated[p_name]
end



function arena_lib.get_target_spectators(mod, arena_name, type, t_name)
  if type == "player" then
    return players_spectated[t_name]
  elseif type == "entity" then
    return entities_spectated[mod][arena_name][t_name]
  elseif type == "area" then
    return areas_spectated[mod][arena_name][t_name]
  end
end



function arena_lib.get_spectated_target(sp_name)
  if arena_lib.is_player_spectating(sp_name) then
    local p_data = players_in_spectate_mode[sp_name]
    return {type = p_data.type, name = p_data.spectating}
  end
end



function arena_lib.get_spectatable_entities(mod, arena_name)
  return entities_storage[mod][arena_name]
end



function arena_lib.get_spectatable_areas(mod, arena_name)
  return areas_storage[mod][arena_name]
end



----------------------------------------------
---------------FUNZIONI LOCALI----------------
----------------------------------------------

function follow_executioner_or_random(mod, arena, p_name, xc_name)
  if xc_name and arena.players[xc_name] then
    arena_lib.spectate_target(mod, arena, p_name, "player", xc_name)
  else
    arena_lib.find_and_spectate_player(p_name)
  end
end



-- viene chiamata solo una volta ma a tenerla nella funzione principale rendeva il
-- codice pressoché illeggibile. Da qui la funzione locale a parte
function calc_p_amount_teams(arena, sp_name, team_ID, change_team, prev_spectated)
  -- se il giocatore seguito era l'ultimo membro della sua squadra, la imposto da cambiare
  if arena.players_amount_per_team[team_ID] == 0 then
    change_team = true
  end

  -- eventuale cambio squadra sul quale eseguire il calcolo
  if change_team then
    arena.spectators_amount_per_team[team_ID] = arena.spectators_amount_per_team[team_ID] - 1

    local active_teams = arena_lib.get_active_teams(arena)

    if team_ID >= active_teams[#active_teams] then
      team_ID = active_teams[1]
    else
      for i = team_ID + 1, #arena.teams do
        if arena.players_amount_per_team[i] ~= 0 then
          team_ID = i
          break
        end
      end
    end
    players_in_spectate_mode[sp_name].teamID = team_ID
    arena.spectators_amount_per_team[team_ID] = arena.spectators_amount_per_team[team_ID] + 1
  end

  return arena.players_amount_per_team[team_ID], team_ID
end



function calc_spec_id(curr_ID, players_amount, go_counterwise)
  if go_counterwise then
    return curr_ID == 1 and players_amount or curr_ID - 1
  else
    return players_amount <= curr_ID and 1 or curr_ID + 1
  end
end



function set_spectator(mod, arena_name, spectator, type, name, i, is_forced)
  local sp_name = spectator:get_player_name()
  local prev_spectated = players_in_spectate_mode[sp_name].spectating
  local prev_type = players_in_spectate_mode[sp_name].type

  -- se stava già seguendo qualcuno, lo rimuovo da questo
  if prev_spectated then
    if prev_type == "player" then
      players_spectated[prev_spectated][sp_name] = nil
    elseif prev_type == "entity" then
      entities_spectated[mod][arena_name][prev_spectated][sp_name] = nil
    else
      areas_spectated[mod][arena_name][prev_spectated][sp_name] = nil
    end
  end

  local target = ""

  if type == "player" then
    players_spectated[name][sp_name] = true
    target = core.get_player_by_name(name)
    spectator:set_properties({hp_max = target:get_properties().hp_max})
    spectator:set_hp(target:get_hp() > 0 and target:get_hp() or 1)

  elseif type == "entity" then
    entities_spectated[mod][arena_name][name][sp_name] = true
    target = entities_storage[mod][arena_name][name].object
    spectator:set_properties({hp_max = target:get_properties().hp_max})
    spectator:set_hp(target:get_hp() > 0 and target:get_hp() or 1)

  elseif type == "area" then
    areas_spectated[mod][arena_name][name][sp_name] = true
    target = areas_storage[mod][arena_name][name]
    spectator:set_hp(99999)
  end

  spectator:set_attach(target, "", {x=0, y=-5, z=-20}, {x=0, y=0, z=0})

  players_in_spectate_mode[sp_name].spectating = name
  players_in_spectate_mode[sp_name].type = type

  spectator:get_meta():set_int("arenalib_watchID", i)
  arena_lib.HUD_send_msg("hotbar", sp_name, S("Currently spectating: @1", name))

  local mod_ref = arena_lib.mods[players_in_spectate_mode[sp_name].minigame]

  -- eventuale codice aggiuntivo
  if mod_ref.on_change_spectated_target then
    local arena = arena_lib.get_arena_by_player(sp_name)
    mod_ref.on_change_spectated_target(arena, sp_name, type, name, prev_type, prev_spectated, is_forced)
  end
end



function override_hotbar(player, mod, arena)
  local p_inv = player:get_inventory()

  p_inv:set_list("main", {})
  p_inv:set_list("craft",{})

  local sp_name = player:get_player_name()
  local mod_ref = arena_lib.mods[mod]
  local spectate_mode = mod_ref.spectate_mode
  local tools = {}
  local pt_members_playing_amnt = 0

  if is_parties_enabled and parties.is_player_in_party(sp_name) then
    pt_members_playing_amnt = #arena_lib.get_party_members_playing(sp_name, arena)
  end

  if spectate_mode ~= "blind" or arena.teams_enabled then
    -- TODO: se è a squadre e c'è solo una persona nella tal squadra, non metterlo
    -- Poi ridallo però se nell'altra ce n'è più di una
    tools[1] = "arena_lib:spectate_changeplayer"     -- TODO: with endless arenas I could have a situation where I have entities/areas to spectate but no players. Dehardcode it?
  end

  if (spectate_mode == "blind" and pt_members_playing_amnt > 1) or
     (spectate_mode ~= "blind" and pt_members_playing_amnt > 0) then
    tools[#tools +1] = "arena_lib:spectate_changeplayerparty"
  end

  if spectate_mode == "all" then
    if #arena.teams > 1 then
      tools[#tools +1] = "arena_lib:spectate_changeteam"
    end

    if arena.spectate_entities_amount > 0 then
      tools[#tools +1] = "arena_lib:spectate_changeentity"
    end

    if arena.spectate_areas_amount > 0 then
      tools[#tools +1] = "arena_lib:spectate_changearea"
    end

    if mod_ref.join_while_in_progress then
      tools[#tools +1] = "arena_lib:spectate_join"
    end
  end

  tools[#tools +1] = "arena_lib:spectate_quit"

  player:hud_set_hotbar_image("arenalib_gui_hotbar" .. #tools .. ".png")
  player:hud_set_hotbar_itemcount(#tools)
  p_inv:set_list("main", tools)
end
