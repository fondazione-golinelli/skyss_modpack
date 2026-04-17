local S = core.get_translator("playerlist")
local MAX_PLAYERS = tonumber(core.settings:get("max_users"))
local P_PER_COLUMN = hub.settings.plist_p_per_column
local MAX_SLOTS = hub.settings.plist_max_slots
local NAMES_COL = hub.settings.plist_name_colours
local NAMES_COL_DEFAULT = NAMES_COL[#NAMES_COL].__default
local X_DIST = 402
local Y_DIST = 29
local Y_OFF = 60
local curr_col_amount = 1   -- usato per sapere se devo spostare tutte le caselle dei giocatori connessi (in caso sia cambiato il n° di colonne)

local function calc_name_col() end
local function calc_avatar() end
local function calc_minigame() end
local function calc_panel_data() end
local function add_slot() end
local function shift_columns() end
local function get_player_id() end



function playerlist.HUD_create(p_name)
  local players, p_amount, col_amount, x_off, last_row, next_col = calc_panel_data()

  -- inizio contando da zero per semplificarmi la vita
  local row = 0
  local col = 0

  -- aggiungo indicatore giocatori connessi
  Panel:new("playerlist_data", {
    player = p_name,
    position  = {x = 0.5, y = 0},
    offset = {x = 0, y = Y_OFF / 2 + (row * Y_DIST) },
    bg = "",
    visible = false,
    title = p_amount .. "/" .. MAX_PLAYERS
  })

  -- aggiorna la posizione delle caselle dei vari giocatori in caso sia cambiato il numero di colonne
  if curr_col_amount ~= col_amount then
    shift_columns(players, p_amount -1, x_off, col_amount, p_name)
  end

  -- ottengo e aggiungo le singole caselle ciclando i vari giocatori connessi
  for i, pl in ipairs(players) do
    local pl_name = pl:get_player_name()
    local offset = {x = x_off + (col * X_DIST), y = Y_OFF + (row * Y_DIST) }

    -- se è arrivato all'ultima casella, renderizzalo e interrompi la funzione
    if i == MAX_SLOTS then
      -- se seguono altri giocatori, mostrerà "...and much more!"
      if p_amount > MAX_SLOTS then
        Panel:new("playerlist_" .. i, {
          player = p_name,
          position  = {x = 0.5, y = 0},
          offset = offset,
          bg_scale = {x = 25, y = 1.8},
          visible = false,
          title = S("...and much more!"),
          sub_img_elems = {
            ping = {
              text = "",
              offset = {x = -180},
              scale = {x = 1.5, y = 1.5}
            },
            avatar = {
              text = "",
              offset = {x = -150},
              scale = {x = 2.5, y = 2.5}
            },
            minigame = {
              text = "",
              offset = {x = 180},
              scale = {x = 1.6, y = 1.6}
            }
          }
        })
        -- idem a tutti gli altri giocatori connessi (se già non era mostrato, ovvero se non c'erano già più di MAX_SLOTS giocatori)
        if p_amount -1 == MAX_SLOTS then
          for j = 1, p_amount -1 do
            panel_lib.get_panel(players[j]:get_player_name(), "playerlist_" .. i):update(
              {title = S("...and much more!"), title_color = 0xFFFFFF}, nil,
              {ping = {text = ""}, avatar = { text = ""}, minigame = { text = ""}}
            )
          end
        end

      -- sennò il giocatore normale
      else
        add_slot(i, p_name, p_name, offset)
        for j = 1, p_amount -1 do
          local pla_name = players[j]:get_player_name()
          local panel = panel_lib.get_panel(pla_name, "playerlist_" .. i)
          -- aggiorno se già esiste (più colonne, quindi casella vuota) o creo se non (colonna singola)
          if panel_lib.has_panel(pl_name, panel) then
            panel_lib.get_panel(pla_name, "playerlist_" .. i):update(
              {title = p_name}, nil,
              {ping = {text = "server_ping_2.png"}, avatar = {text = calc_avatar(p_name)}, minigame = {text = calc_minigame(p_name)}}
            )
          else
            local is_visible = panel_lib.get_panel(pla_name, "playerlist_" .. p_amount - 1):is_visible()
            add_slot(i, pla_name, p_name, offset, is_visible)
          end
        end
      end

      break


    -- se non è l'ultima casella, aggiungi normalmente
    else

      add_slot(i, p_name, pl_name, offset)

      -- aggiungo a tutti i giocatori la nuova eventuale casella
      if p_amount < MAX_SLOTS and pl_name ~= p_name then
        local is_visible = panel_lib.get_panel(pl_name, "playerlist_" .. p_amount - 1):is_visible()
        local off = {x = x_off + (next_col * X_DIST), y = Y_OFF + (last_row * Y_DIST) }

        add_slot(p_amount, pl_name, p_name, off, is_visible)
      end

      if i / col_amount == math.round(i / col_amount) then
        row = row + 1
        col = 0
      else
        col = col + 1
      end
    end
  end

  playerlist.HUD_update("p_amount")
  curr_col_amount = col_amount

  if p_amount >= MAX_SLOTS then return end

  -- aggiungo eventuali caselle vuote aggiuntive
  for i = p_amount, 999 do
    if i / col_amount == math.round(i / col_amount) then break end

    for _, pl in pairs(players) do
      local pl_name = pl:get_player_name()
      local panel_name = "playerlist_" .. i+1
      local is_visible = panel_lib.get_panel(pl_name, "playerlist_" .. i):is_visible()

      if not panel_lib.has_panel(pl_name, panel_name) then
        Panel:new("playerlist_" .. i+1, {
          player = pl:get_player_name(),
          position  = {x = 0.5, y = 0},
          offset = {x = x_off + (col * X_DIST), y = Y_OFF + (row * Y_DIST) },
          bg_scale = {x = 25, y = 1.8},
          visible = is_visible,
          title = "",
          sub_img_elems = {
            ping = {
              text = "",
              offset = {x = -180},
              scale = {x = 1.5, y = 1.5}
            },
            avatar = {
              text = "",
              offset = {x = -150},
              scale = {x = 2.5, y = 2.5}
            },
            minigame = {
              text = "",
              offset = {x = 180},
              scale = {x = 1.6, y = 1.6}
            }
          }
        })
      end
    end

    col = col + 1
  end
end



function playerlist.HUD_remove_player(p_name)
  local players, p_amount, _, _, _, curr_col = calc_panel_data()
  local p_id = get_player_id(p_name)

  if p_id > MAX_SLOTS and p_amount -1 > MAX_SLOTS then return end

  local col_amount = math.ceil(math.min(p_amount -1, MAX_SLOTS) / P_PER_COLUMN)
  local x_off = -201 * (col_amount - 1)
  local has_col_amount_changed = false

  if curr_col_amount ~= col_amount then
    shift_columns(players, p_amount, x_off, col_amount, p_name)
    has_col_amount_changed = true

    local p_amount_minus_one = p_amount -1
    local last_row = math.ceil(p_amount_minus_one / col_amount) -1
    curr_col = p_amount_minus_one - (last_row * col_amount) -1
  end

  for _, pl in pairs(players) do
    local pl_name = pl:get_player_name()

    for i = math.min(p_id, MAX_SLOTS), math.min(p_amount, MAX_SLOTS) do -- math.min sul primo in caso di "much more"
      local panel = panel_lib.get_panel(pl_name, "playerlist_" .. i)
      local next_player = players[i+1]

      -- se non ci son altri pannelli contenenti giocatori..
      if not next_player then
        -- ..ed era il primo della colonna (salvo "much more" a colonna singola)
        -- o se le colonne son cambiate (rischiando di aver generato righe vuote sotto), elimino tutte le caselle vuote che seguono
        if (curr_col == 0 and p_amount -1 ~= MAX_SLOTS) or has_col_amount_changed then
          for j = 0, curr_col_amount do
            panel = panel_lib.get_panel(pl_name, "playerlist_" .. i + j)
            if not panel then break end
            panel:remove()
          end

        else
          -- sennò o siam davanti al limite di caselle visibili (e se c'era solo un altro giocatore in più, la tramuto in casella giocatore)
          if i == MAX_SLOTS then
            if p_amount -1 == MAX_SLOTS then
              local next_name = players[i+1]:get_player_name() or players[i-1]:get_player_name()
              panel:update({
                  title = next_name,
                  title_color = calc_name_col(next_name)
                  },
                  nil, {avatar = { text = calc_avatar(next_name)}, minigame = { text = calc_minigame(next_name)}}
                )
              elseif p_amount -1 < MAX_SLOTS then
                panel:remove()
              end
          -- oppure a una casella che diventerà vuota
          else
            panel:update({title = ""}, nil, {ping = {text = ""}, avatar = {text = ""}, minigame = {text = ""}})
          end
        end

      -- se invece ci son altri pannelli, scalo di 1
      else
        local next_name = next_player:get_player_name()
        panel:update({
            title = next_name,
            title_color = calc_name_col(next_name)
            },
            nil, {avatar = { text = calc_avatar(next_name)}, minigame = { text = calc_minigame(next_name)}}
          )
      end
    end
  end

  curr_col_amount = col_amount

  -- ritardo sennò vede quello che esce ancora connesso
  core.after(0.1, function()
    playerlist.HUD_update("p_amount")
  end)
end



-- field = "ping", "avatar", "name", "minigame", "p_amount".
-- params al momento usato da:
-- * `name`: tabella contenente nome e colore.
-- * `minigame`: se entra come spettante
function playerlist.HUD_update(field, p_name, params)
  local players = core.get_connected_players()
  local p_amount = #players

  if field == "ping" then
    local max = p_amount > MAX_SLOTS and MAX_SLOTS -1 or MAX_SLOTS  -- non voglio mostrare ping nell'ultima casella se è "and much more"
    for i = 1, math.min(p_amount, max) do
      for _, pl_name in pairs(hub.get_players_in_hub()) do
        local panel = panel_lib.get_panel(pl_name, "playerlist_" .. i)
  			panel:update(nil, nil, {ping = {text = "server_ping_" .. (playerlist.get_ping(players[i]:get_player_name()) or 2) .. ".png"}})
      end
    end

  elseif field == "avatar" then
    local p_id = get_player_id(p_name)
    if p_id > MAX_SLOTS or (p_id == MAX_SLOTS and p_amount > MAX_SLOTS) then return end

    local avatar = calc_avatar(p_name)

    for _, pl in ipairs(players) do
      local panel = panel_lib.get_panel(pl:get_player_name(), "playerlist_" .. p_id)
      panel:update(nil, nil, {avatar = {text = avatar}})
    end

  elseif field == "name" then -- al momento non ci son chiamate con "name"
    local p_id = get_player_id(p_name)
    if p_id > MAX_SLOTS or (p_id == MAX_SLOTS and p_amount > MAX_SLOTS) then return end

    local name = params.text or p_name
    local col = params.color or calc_name_col(p_name)

    for _, pl in ipairs(players) do
      local panel = panel_lib.get_panel(pl:get_player_name(), "playerlist_" .. p_id)
      panel:update({title = name, title_color = col})
    end

  elseif field == "minigame" then
    local p_id = get_player_id(p_name)
    if p_id > MAX_SLOTS or (p_id == MAX_SLOTS and p_amount > MAX_SLOTS) then return end

    local mg_icon = calc_minigame(p_name)

    -- se chiamato su on_join, non c'è modo di sapere se sta entrando come spettante;
    -- perché prima si entra e poi si passa in modalità spettatore. L'unica è usare
    -- il parametro `as_spectator` di on_join, che viene passato qui tramite `params`
    if params and params.spectator then
      mg_icon = mg_icon .. "^[hsl:0:-100"
    end

    for _, pl in ipairs(players) do
      local panel = panel_lib.get_panel(pl:get_player_name(), "playerlist_" .. p_id)
      panel:update(nil, nil, {minigame = {text = mg_icon}})
    end

  elseif field == "p_amount" then
    local amnt_txt = p_amount .. "/" .. MAX_PLAYERS

    for _, pl in ipairs(players) do
      local panel = panel_lib.get_panel(pl:get_player_name(), "playerlist_data")
      panel:update({title = amnt_txt})
    end
  end
end



function playerlist.HUD_show(p_name)
  panel_lib.get_panel(p_name, "playerlist_data"):show()

  for i = 1, 999 do -- così da renderizzare anche le caselle vuote
    local panel = panel_lib.get_panel(p_name, "playerlist_" .. i)
    if not panel then break end

    panel:show()
  end
end



function playerlist.HUD_hide(p_name)
  panel_lib.get_panel(p_name, "playerlist_data"):hide()

  for i = 1, 999 do -- così da renderizzare anche le caselle vuote
    local panel = panel_lib.get_panel(p_name, "playerlist_" .. i)
    if not panel then break end

    panel:hide()
  end
end





----------------------------------------------
---------------FUNZIONI LOCALI----------------
----------------------------------------------

function calc_name_col(p_name)
  local p_privs = core.get_player_privs(p_name)
  local col

  for _, col_data in ipairs(NAMES_COL) do
    for priv, priv_col in pairs(col_data) do
      if p_privs[priv] then
        col = priv_col
      end
    end
    if col then break end
  end

  return col or NAMES_COL_DEFAULT
end



function calc_avatar(p_name)
  local skin = core.get_player_by_name(p_name):get_properties().textures[1]
  local skin_clean = string.match(skin, "(.*)^%[")
  return "([combine:24x24:0,0=" .. (skin_clean or skin) .. "^[mask:playerlist_avatarmask.png)"
end



function calc_minigame(p_name)
  local mod = arena_lib.get_mod_by_player(p_name)
  if not mod then return "" end

  local icon = arena_lib.mods[mod].icon

  if arena_lib.is_player_in_queue(p_name) then
    icon = icon .. "^[opacity:128"
  elseif arena_lib.is_player_spectating(p_name) then
    icon = icon .. "^[hsl:0:-100"
  end

  return icon
end



function calc_panel_data(sub_one)
  local players = core.get_connected_players()
  local p_amount = sub_one and #players -1 or #players
  local col_amount = math.ceil(math.min(p_amount, MAX_SLOTS) / P_PER_COLUMN)
  local x_off = -201 * (col_amount - 1)
  local last_row = math.ceil(p_amount / col_amount) -1
  local next_col = p_amount - (last_row * col_amount) -1                        -- chiamata 'next_col' nella creazione perché indica la colonna che verrà riempita,
                                                                                -- e 'curr_col' durante la rimozione perché indica quella che verrà rimossa
  return players, p_amount, col_amount, x_off, last_row, next_col
end



function add_slot(i, t_name, p_name, offset, is_visible)
  local panel_name = "playerlist_" .. i
  local color = calc_name_col(p_name)
  local ping_img = "server_ping_" .. (playerlist.get_ping(p_name) or 2) .. ".png"

  -- se già ce l'aveva era una casella grigia, che sovrascrivo
  if panel_lib.has_panel(t_name, panel_name) then
    panel_lib.get_panel(t_name, panel_name):update(
      {title = p_name, title_color = color}, nil,
      {ping = {text = ping_img}, avatar = {text = calc_avatar(p_name)}, minigame = {text = calc_minigame(p_name)}}
    )

  -- sennò aggiungo normalmente
  else
    Panel:new("playerlist_" .. i, {
      player = t_name,
      position  = {x = 0.5, y = 0},
      offset = offset,
      bg_scale = {x = 25, y = 1.8},
      visible = is_visible or false,
      title = p_name,
      title_color = color,
      sub_img_elems = {
        ping = {
          text = ping_img,
          offset = {x = -180},
          scale = {x = 1.5, y = 1.5}
        },
        avatar = {
          text = calc_avatar(p_name),
          offset = {x = -150},
          scale = {x = 2.5, y = 2.5}
        },
        minigame = {
          text = calc_minigame(p_name),
          offset = {x = 180},
          scale = {x = 1.6, y = 1.6}
        }
      }
    })
  end
end



function shift_columns(players, p_amount, x_off, col_amount, except_for)
  local row = 0
  local col = 0
  for i, pl in ipairs(players) do
    local pl_name = pl:get_player_name()

    if pl_name ~= except_for then
      for j = 1, math.min(p_amount, MAX_SLOTS) do
        local offset = {x = x_off + (col * X_DIST), y = Y_OFF + (row * Y_DIST) }
        panel_lib.get_panel(pl_name, "playerlist_" .. j):update({offset = offset})

        if j / col_amount == math.round(j / col_amount) then
          row = row + 1
          col = 0
        else
          col = col + 1
        end
      end
      row = 0
      col = 0
    end
  end
end



function get_player_id(p_name)
  for i, pl in ipairs(core.get_connected_players()) do
    if pl:get_player_name() == p_name then
      return i
    end
  end
end
