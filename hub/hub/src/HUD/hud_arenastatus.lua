local S = core.get_translator("hub")

local function trim_name() end
local function sort_by_priority() end

local ignored_arenas = {}               -- KEY: mod@ar_name; VALUE = true
local arenas = {}                       -- KEY: sorting ID, VALUE: {mod = mod, mg = mg_name, name = a_name, icon = mg_icon, y_off, bg = txt.png, amount = txt}
local hidden_panels = {}                -- KEY: p_name, VALUE: true
local MAX_ARENAS_IN_STATUS = hub.settings.MAX_ARENAS_IN_STATUS
local SLOT_DISTANCE = 52
local TITLE_DISTANCE = 42

-- I pannelli si dividono nelle tabelle contenenti le informazioni da mostrare (`arenas`)
-- e nella loro resa grafica vera e propria (panel_lib). Ogni volta che un pannello
-- viene aggiornato, pesca i dati da `arenas`.
-- I pannelli sono gestiti in modo tale che le loro posizioni non si intersechino mai:
-- il pannello più in alto sarà sempre il n°1, quello seguente il n°2 ecc. Se l'arena
-- associata al primo pannello scompare, le informazioni del pannello n°2 passeranno
-- a quest'ultimo e via dicendo, nascondendo quello visibile più in fondo (a meno che
-- il numero di `arenas` non superi il numero di pannelli visibili: in quel caso
-- otterrà le informazioni dal primo non visibile)



----------------------------------------------
---------------------API----------------------
----------------------------------------------
function hub.HUD_arstatus_show(p_name)
  if not hidden_panels[p_name] then return end

  for i = 1, math.min(#arenas, MAX_ARENAS_IN_STATUS) do
    local panel = panel_lib.get_panel(p_name, "hubman_arenastatus_" .. i)
    panel:show()
  end

  if next(arenas) then
    panel_lib.get_panel(p_name, "hubman_arenastatus_title"):show()
  end

  hidden_panels[p_name] = nil
end



function hub.HUD_arstatus_hide(p_name)
  if hidden_panels[p_name] then return end

  for i = 1, MAX_ARENAS_IN_STATUS do
    local panel = panel_lib.get_panel(p_name, "hubman_arenastatus_" .. i)
    panel:hide()
  end

  panel_lib.get_panel(p_name, "hubman_arenastatus_title"):hide()
  hidden_panels[p_name] = true
end



function hub.HUD_ignore(mod, arena_name)
    ignored_arenas[mod .. "@" .. arena_name] = true
end



function hub.HUD_unignore(mod, arena_name)
  ignored_arenas[mod .. "@" .. arena_name] = nil
end





----------------------------------------------
----------------INTERNAL ONLY-----------------
----------------------------------------------
function hub.HUD_arstatus_create(p_name)
  for i = 1, MAX_ARENAS_IN_STATUS do
    local a_data  = arenas[i]
    local y_off   = a_data and a_data.y_off or 0
    local bg      = a_data and a_data.bg or "blank.png"
    local icon    = a_data and a_data.icon or "blank.png"
    local a_name  = a_data and trim_name(a_data.name) or ""
    local amount  = a_data and a_data.amount or ""

    Panel:new("hubman_arenastatus_" .. i, {
      player = p_name,
      position  = {x = 1, y = 0.5},
      alignment = {x = -1, y = 0},
      offset = {x = 0, y = y_off},
      bg = bg,
      bg_scale = {x = 3, y = 3},
      title = "",
      sub_img_elems = {
        icon = {
          text = icon,
          offset = {x = -180}
        }
      },
      sub_txt_elems = {
        arena_name = {
          text = a_name,
          alignment = {x = 1},
          offset = {x = -175}
        },
        p_amount = {
          text = amount,
          alignment = {x = -1},
          offset = {x = -5}
        }
      }
    })
  end

  local title_y_offset = next(arenas) and arenas[1].y_off - TITLE_DISTANCE or 0

  Panel:new("hubman_arenastatus_title", {
    player = p_name,
    position  = {x = 1, y = 0.5},
    alignment = {x = -1, y = 0},
    title_alignment = {x = -1},
    offset = {x = 0, y = title_y_offset},
    bg = "hub_arenastatus_title.png",
    bg_scale = {x = 3, y = 3},
    title = S("Current games") .. "    ",
    title_color = 0x000000,
    visible = next(arenas) or false
  })

  -- se si son sconnessi mentre avevano i pannelli nascosti e poi riconnessi,
  -- hidden_panels sarà ancora `true`. Reimposto per sicurezza
  hidden_panels[p_name] = nil
end



function hub.HUD_arstatus_add(mod, arena)
  local arenas_amnt = #arenas
  local y_off

  -- calcolo lo scostamento che avrà il pannello. Se sono già visualizzati i pannelli massimi,
  -- lo accoderò in basso di un'unità. Al contrario, se questo sarà visibile,
  -- sposterò tutti quelli visibili di mezza unità verso l'alto, accodando quello
  -- nuovo sempre di mezza unità
  if arenas_amnt == 0 then
    y_off = 0
  else
    if arenas_amnt >= MAX_ARENAS_IN_STATUS then
      y_off = arenas[arenas_amnt].y_off + SLOT_DISTANCE
    else
      y_off = arenas[arenas_amnt].y_off + SLOT_DISTANCE / 2

      for _, slot in ipairs(arenas) do
        slot.y_off = slot.y_off - SLOT_DISTANCE / 2
      end
    end
  end

  -- aggiungo l'arena nella tabella
  local bg_img = arena.players_amount < arena.max_players and "hub_arenastatus_join.png" or "hub_arenastatus_nojoin.png"
  local mg = arena_lib.mods[mod]
  local a_info = {
    mod     = mod,
    mg      = mg.name,
    name    = arena.name,
    icon    = mg.icon,
    y_off   = y_off,
    bg      = bg_img,
    amount  = arena.players_amount .. "/" .. arena.max_players * #arena.teams
  }

  table.insert(arenas, a_info)
  hub.HUD_arstatus_update(#arenas)  -- aggiungi l'arena e riordina eventualmente i pannelli

  -- se le arene superano il n° max di pannelli visibili, è inutile aggiornare l'altezza
  -- e aggiungere un nuovo pannello
  if #arenas > MAX_ARENAS_IN_STATUS then return end

  for i = 1, #arenas do
    hub.HUD_arstatus_update(i, true, false, true, true, true)
  end

  local title_pos = arenas[1].y_off - TITLE_DISTANCE

  -- aggiorno titolo
  for _, pl in pairs(core.get_connected_players()) do
    local pl_name = pl:get_player_name()
    local panel = panel_lib.get_panel(pl_name, "hubman_arenastatus_title")

    panel:update({offset = {y = title_pos}})

    if not arena_lib.is_player_in_arena(pl_name) and not panel:is_visible() and not hidden_panels[pl_name] then
      panel:show()
    end
  end
end



function hub.HUD_arstatus_remove(mod, arena_name)
  -- trovo l'ID dell'arena nell'HUD
  local HUD_ID = hub.get_arenastatus_slot(mod, arena_name)

  table.remove(arenas, HUD_ID)

  local arenas_amnt = #arenas

  -- scalo la posizione dei pannelli che venivano dopo quello rimosso. Li muovo
  -- di mezza unità verso l'alto se quelli visibili cambieranno di numero, o di
  -- una intera se erano già al completo (ovvero uguali o maggiori di MAX_ARENAS_IN_STATUS)
  local mov_divisor = arenas_amnt < MAX_ARENAS_IN_STATUS and 2 or 1
  for i = HUD_ID, arenas_amnt do
    arenas[i].y_off = arenas[i].y_off - SLOT_DISTANCE / mov_divisor
  end

  -- se ora ci sono meno slot di quelli massimi..
  if arenas_amnt < MAX_ARENAS_IN_STATUS then
    -- aggiorno la posizione degli slot che venivano prima
    for i = 1, HUD_ID -1 do
      arenas[i].y_off = arenas[i].y_off + SLOT_DISTANCE / 2
    end

    -- e faccio sparire l'ultimo
    for _, pl in pairs(core.get_connected_players()) do
      local pl_name = pl:get_player_name()
      local panel = panel_lib.get_panel(pl_name, "hubman_arenastatus_" .. arenas_amnt + 1)

      if panel.visible then
        panel:hide()
      end
    end
  end

  -- aggiorno tutti i pannelli visibili
  for i = 1, arenas_amnt do
    hub.HUD_arstatus_update(i, false, false, false, false, true)
  end

  local title_pos = next(arenas) and arenas[1].y_off - TITLE_DISTANCE

  -- aggiorno titolo
  for _, pl in pairs(core.get_connected_players()) do
    local pl_name = pl:get_player_name()
    local panel = panel_lib.get_panel(pl_name, "hubman_arenastatus_title")

    panel:update({offset = {y = title_pos}})

    if not next(arenas) then
      panel:hide()
    end
  end
end



function hub.HUD_arstatus_update(slot_ID, skip_mgarena, skip_pos, skip_status, skip_amount, skip_sorting)
  local IDs_to_update = {} -- solo slot_ID se non c'è da riordinare, sennò tutti quelli cambiati
  local has_order_changed

  -- se c'è da riordinare
  if not skip_sorting and #arenas > 1 then
    local old_slot_mg = arenas[slot_ID].mod
    local old_slot_name = arenas[slot_ID].name
    local old_arenas = table.copy(arenas)
    local lowest_y_off = arenas[1].y_off

    table.sort(arenas, function(a, b) return sort_by_priority(a, b) end)
    local slot_ID_new = hub.get_arenastatus_slot(old_slot_mg, old_slot_name)

    -- In teoria, se sia prima che dopo l'ID andava oltre i pannelli visibili, si
    -- potrebbe fermare. Tuttavia, table.sort usa il quicksort, che è instabile,
    -- quindi onde evitare brutte sorprese (come successo in passato) sticazzi e
    -- vado a verificare la posizione di ciò che è cambiato, sempre e comunque
    --if slot_ID > MAX_ARENAS_IN_STATUS and slot_ID_new > MAX_ARENAS_IN_STATUS then return end

    has_order_changed = slot_ID ~= slot_ID_new

    local curr_y_off = lowest_y_off

    -- trovo differenze e aggiorno y_off di pannelli che mutano
    for i = 1, math.min(#arenas, MAX_ARENAS_IN_STATUS) do
      if i == slot_ID_new or old_arenas[i].name ~= arenas[i].name or old_arenas[i].mod ~= arenas[i].mod then
        table.insert(IDs_to_update, i)
        arenas[i].y_off = curr_y_off
      end

      curr_y_off = curr_y_off + SLOT_DISTANCE
    end

  else
    if slot_ID > MAX_ARENAS_IN_STATUS  then return end

    IDs_to_update = {slot_ID}
  end

  for _, id in pairs(IDs_to_update) do
    local slot = arenas[id]
    local elem = {}
    local subtxt_elems = {}
    local icon = nil

    -- se è cambiato l'ordine, aggiorna qualsiasi cosa
    if has_order_changed then
      -- icon / name
      icon = { icon = { text = slot.icon }}
      subtxt_elems.arena_name = { text = trim_name(slot.name) }

      -- pos
      elem.offset = { x = 0, y = slot.y_off }

      -- status (bg)
      local _, arena = arena_lib.get_arena_by_name(slot.mod, slot.name)
      local mg = arena_lib.mods[slot.mod]
      local bg_img = ""

      if not arena.in_game and not arena.in_queue then
        bg_img = "hub_arenastatus_waiting.png"
      elseif not arena.in_loading and not arena.in_celebration and
        arena.players_amount < arena.max_players * #arena.teams and
        (arena.in_queue or (arena.in_game and mg.join_while_in_progress)) then
        bg_img = "hub_arenastatus_join.png"
      else
        bg_img = "hub_arenastatus_nojoin.png"
      end

      slot.bg = bg_img
      elem.bg = bg_img

      -- amount
      local amount = arena.players_amount .. "/" .. arena.max_players * #arena.teams

      slot.amount = amount
      subtxt_elems.p_amount = { text = amount }

    else
      if not skip_mgarena then
        icon = { icon = { text = slot.icon }}
        subtxt_elems.arena_name = { text = trim_name(slot.name) }
      end

      if not skip_pos then
        elem.offset = { x = 0, y = slot.y_off  }
      end

      local _, arena = arena_lib.get_arena_by_name(slot.mod, slot.name)
      local mg = arena_lib.mods[slot.mod]

      if not skip_status then
        local bg_img = ""

        if not arena.in_game and not arena.in_queue then
          bg_img = "hub_arenastatus_waiting.png"
        elseif not arena.in_loading and not arena.in_celebration and
          arena.players_amount < arena.max_players * #arena.teams and
          (arena.in_queue or (arena.in_game and mg.join_while_in_progress)) then
          bg_img = "hub_arenastatus_join.png"
        else
          bg_img = "hub_arenastatus_nojoin.png"
        end

        slot.bg = bg_img
        elem.bg = bg_img
      end

      if not skip_amount then
        local amount = arena.players_amount .. "/" .. arena.max_players * #arena.teams

        slot.amount = amount
        subtxt_elems.p_amount = { text = amount }
      end
    end

    -- se non c'è nessun elemento/sottoelemento da aggiornare, faccio sparire
    if not next(elem) then
      elem = nil
    end

    if not next(subtxt_elems) then
      subtxt_elems = nil
    end

    for _, pl in pairs(core.get_connected_players()) do
      local pl_name = pl:get_player_name()
      local panel = panel_lib.get_panel(pl_name, "hubman_arenastatus_" .. id)

      panel:update(elem, icon, subtxt_elems)

      if not arena_lib.is_player_in_arena(pl_name) and not panel:is_visible() and not hidden_panels[pl_name] then
        panel:show()
      end
    end
  end
end



function hub.HUD_is_ignored(mod, arena_name)
  return ignored_arenas[mod .. "@" .. arena_name]
end



function hub.get_arenastatus_slot(mod, arena_name)
  for i = 1, #arenas do
    if arenas[i].name == arena_name and arenas[i].mod == mod then
      return i
    end
  end
end





----------------------------------------------
---------------FUNZIONI LOCALI----------------
----------------------------------------------

function trim_name(name)
  if name:len() > 15 then
    return name:sub(1, 13) .. "..."
  else
    return name
  end
end



-- l'ordine di priorità è:
-- 1. in coda con spazio
-- 2. avviate accessibili in corso con spazio
-- 3. in attesa con spazio
-- 4. in coda piene
-- 5. avviate accessibili in corso piene
-- 6. avviate non accessibili in corso (piene o con spazio)
-- Per doppioni, ordinare per n° giocanti
function sort_by_priority(a, b)
  local _, arena_a = arena_lib.get_arena_by_name(a.mod, a.name)
  local _, arena_b = arena_lib.get_arena_by_name(b.mod, b.name)
  local mod_ref_a = arena_lib.mods[a.mod]
  local mod_ref_b = arena_lib.mods[b.mod]

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