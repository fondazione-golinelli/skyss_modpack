local S = core.get_translator("magic_compass")
local S_wrld = core.get_translator("magic_compass_data")
local on_cooldown = {}    -- KEY: player name; VALUE: {items, on, cooldown}

local function run_cooldown() end



function magic_compass.get_formspec(p_name)

  local SLOTS_PER_ROW = 5
  local y_offset = 0.3
  local rows = math.floor(table.maxn(magic_compass.items) / SLOTS_PER_ROW - 0.1) + 1
  local hidden_rows = 0
  local last_pointed_row = 0

  local formspec = {}

  -- aggiungo le varie caselle (matrice i*j)
  for i = 1, rows do
    local hidden_items = 0
    local is_row_empty = true

    for j = 1, SLOTS_PER_ROW do

      local x = 0.5 + (j-1)
      local y = 0.3 + y_offset + (i - hidden_rows -1)
      local idx = SLOTS_PER_ROW * (i - hidden_rows -1) + j
      local itemID = SLOTS_PER_ROW * (i-1) + j
      local item = magic_compass.items[itemID]

      if item then
        if item.privs then
          if not item.hide or (item.hide and core.check_player_privs(p_name, core.string_to_privs(item.privs, ", "))) then
            table.insert(formspec, idx, "item_image_button[" .. x .. "," .. y .. ";1,1;magic_compass:" .. itemID .. ";" .. itemID .. ";]")
            if is_row_empty then is_row_empty = false end
          else
            table.insert(formspec, idx, "image_button[" .. x .. "," .. y .. ";1,1;blank.png;EMPTY;]")
            hidden_items = hidden_items + 1
          end
        else
          table.insert(formspec, idx, "item_image_button[" .. x .. "," .. y .. ";1,1;magic_compass:" .. itemID .. ";" .. itemID .. ";]")
          if is_row_empty then is_row_empty = false end
        end
      else
        table.insert(formspec, idx, "image_button[" .. x .. "," .. y .. ";1,1;blank.png;EMPTY;]")
      end
    end

    if not is_row_empty then
      last_pointed_row = i
    end

    -- se una riga contiene solo oggetti non visibili al giocatore, non la mostro
    if hidden_items > 0 and is_row_empty then

      hidden_rows = hidden_rows + (i - last_pointed_row)

      for k = (SLOTS_PER_ROW * (i - hidden_rows)) + 1, SLOTS_PER_ROW * i do
        formspec[k] = nil
      end

      -- fa in modo che se ci sono più aree nascoste da NON mostrare, il conteggio non svuoti linee di troppo incrementando hidden_rows più del dovuto
      last_pointed_row = i
    end

  end

  local shown_rows = rows - hidden_rows

  -- assegno intestazioni formspec (dimensione, sfondo ecc)
  local fs_begin = {
    "size[6," .. 2 + (shown_rows-1) .. "]",
    "style_type[image_button;border=false;bgimg=magiccompass_gui_button_bg.png]",
    "style_type[item_image_button;border=false;bgimg=magiccompass_gui_button_bg.png]",
    "style[close;border=false;bgimg=]",
    "background[0,0;6," .. 1.5 + (shown_rows -1) .. ";magiccompass_gui_bg" .. shown_rows .. ".png;true]",
    "hypertext[0.5,-0.2;5.6,1;title;<global font=mono halign=center valign=middle>" .. S_wrld(magic_compass.menu_title) .. "</style>]",
    "image_button[5.6,-0.2;0.6,0.6;magiccompass_gui_close.png;close;]"
  }

  table.insert(formspec, 1, table.concat(fs_begin))

  return table.concat(formspec,"")
end





----------------------------------------------
---------------FUNZIONI LOCALI----------------
----------------------------------------------

function run_cooldown(p_name, ID)
  on_cooldown[p_name][ID] = on_cooldown[p_name][ID] -1
  if on_cooldown[p_name][ID] == 0 then
    on_cooldown[p_name][ID] = nil
  else
    core.after(1, function()
      run_cooldown(p_name, ID)
    end)
  end
end





----------------------------------------------
---------------GESTIONE CAMPI-----------------
----------------------------------------------

core.register_on_player_receive_fields(function(player, formname, fields)
  if formname ~= "magic_compass:GUI" then return end

  if fields.EMPTY or fields.quit or fields.key_up or fields.key_down then return end

  local p_name = player:get_player_name()

  if fields.close then
    core.close_formspec(p_name, "magic_compass:GUI")
    return
  end

  local ID = string.match(dump(fields), "%d+") or 1 -- sanity check pt.1
  local item = magic_compass.items[tonumber(ID)]

  -- sanity check pt.2
  if not item then
    for id, _ in pairs(magic_compass.items) do
      item = magic_compass.items[id]
      break
    end
  end

  -- se non ha i permessi, annullo
  if item.privs and not core.check_player_privs(p_name, core.string_to_privs(item.privs, ", ")) then
    core.chat_send_player(p_name, core.colorize("#e6482e", S("[!] You haven't got the requirements to teleport into this area!")))
    magic_compass.play_sound("magiccompass_teleport_deny", p_name)
    return
  end

  -- se è in cooldown, annullo
  if item.cooldown and on_cooldown[p_name] and on_cooldown[p_name][ID] then
    core.chat_send_player(p_name, core.colorize("#e6482e", S("[!] You can't reteleport to this location so quickly! (seconds remaining: @1)",  on_cooldown[p_name][ID])))
    magic_compass.play_sound("magiccompass_teleport_deny", p_name)
    return
  end

  -- se non è fermo, annullo
  if vector.length(player:get_velocity()) > 0.2 then
    core.chat_send_player(p_name, core.colorize("#e6482e", S("[!] Can't teleport whilst moving!")))
    magic_compass.play_sound("magiccompass_teleport_deny", p_name)
    return
  end

  -- se non passa gli eventuali richiami, annullo
  for _, callback in ipairs(magic_compass.registered_on_use) do
    if not callback(player, ID, item.desc, item.pos) then
      magic_compass.play_sound("magiccompass_teleport_deny", p_name)
      return
    end
  end

  -- teletrasporto, ruoto e chiudo
  player:add_velocity(vector.multiply(player:get_velocity(), -1))
  player:set_pos(core.string_to_pos(item.pos))

  if item.rotation then
    player:set_look_horizontal(math.rad(item.rotation))
    player:set_look_vertical(0)
  end

  magic_compass.play_sound("magiccompass_teleport", p_name)
  core.close_formspec(p_name, "magic_compass:GUI")

  -- eventuali richiami dopo l'uso
  for _, callback in ipairs(magic_compass.registered_on_after_use) do
    callback(player, ID, item.desc, item.pos)
  end

  -- eventuale cooldown
  if item.cooldown then

    if not on_cooldown[p_name] then
      on_cooldown[p_name] = {}
    end

    -- lo imposto
    on_cooldown[p_name][ID] = item.cooldown

    -- e lo avvio
    run_cooldown(p_name, ID)
  end
end)
