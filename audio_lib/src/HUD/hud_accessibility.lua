local function can_override_panel() end
local function override_panel() end
local function calc_pos() end
local function hide_after_s() end
local function hide() end
local function bgm_flash() end

local MAX_SLOTS = 10
local READING_DURATION = 1
local DIST_THRESHOLD = 1.5
local BG = "audiolib_hud_panel_bg.png"

-- contains data to then display onto panels. In case of duplicates, audio_name will be audio_name@1, audio_name@2 etc.
local curr_shown = {}           -- KEY: p_name; VALUE: {audio_name = {id = id, title = desc, icons = {left = "", right = ""}, pos = pos, object = obj,
                                --                      fading = false, fading_time = 0, after_func = func}}
local instances = {}            -- KEY: p_name; VALUE: {track_name = counter}
local panels_order = {}         -- KEY: p_name; VALUE: {n = audio_name}





core.register_globalstep(function(dtime)
  -- rimozione vecchi pannelli e aggiornamento valore indicatore posizione
  for pl_name, tracks in pairs(curr_shown) do
    for audio_name, data in pairs(tracks) do
      -- se non è BGM
      if data.id ~= -1 then
        -- rimozione vecchi pannelli
        if data.fading then
          data.fading_time = data.fading_time + dtime

          if data.fading_time >= 1 then
            hide(pl_name, audio_name)
          end
        end

        -- aggiornamento valore indicatore posizione
        if data.pos or data.object then
          local pos = data.pos or data.object:get_pos()

          -- la posizione potrebbe essere nil in caso di entità rimossa nel mentre
          if pos then
            local _, sub_img = calc_pos(pl_name, pos)
            data.icons = {left = sub_img.indicator_left.text, right = sub_img.indicator_right.text}
          end
        end
      end
    end
  end

  -- renderizzazione pannelli
  for pl_name, data in pairs(panels_order) do
    for i, audio_name in pairs(data) do
      local track_data = curr_shown[pl_name][audio_name]
      local panel = panel_lib.get_panel(pl_name, "audiolib_acc_" .. i)
      local col = "#FFFFFF"
      local title_col = 0xFFFFFF

      if track_data.fading then
        local fading_time = track_data.fading_time
        if fading_time <= 0.25 then
          title_col = 0xD0C9C7
          col = "#D0C9C7"
        elseif fading_time <= 0.5 then
          title_col = 0xB5ABA7
          col = "#B5ABA7"
        else
          title_col = 0xA0938E
          col = "#A0938E"
        end
      end

      local indicators

      -- per evitare di aggiornare i sottopannelli posizionali anche quando non necessario
      if track_data.pos or track_data.object then
        indicators = {indicator_left = {text = track_data.icons.left .. "^[multiply:" .. col}, indicator_right = {text = track_data.icons.right .. "^[multiply:" .. col}}
      end

      panel:update({title = track_data.title, title_color = title_col}, indicators)
    end
  end
end)



function audio_lib.HUD_accessibility_create(p_name)
  curr_shown[p_name] = {}
  instances[p_name] = {}
  panels_order[p_name] = {}

  local y_off   = 0

  -- bgm
  Panel:new("audiolib_acc_bgm", {
    player = p_name,
    position  = {x = 1, y = 0.8},
    alignment = {x = -1, y = 0},
    offset = {x = 0, y = y_off},
    bg = BG .. "^[opacity:220",
    bg_scale = {x = 200, y = 37},
    title = "",
    title_offset = {x = -100, y = 0},
    z_index = 1000,
    sub_img_elems = {
      indicator_left = {
        scale = {x=1.25, y=1.25},
        text = "",
        alignment = {x = 0},
        offset = {x = -185}
      },
      indicator_right = {
        scale = {x=1.25, y=1.25},
        text = "",
        alignment = {x = 0},
        offset = {x = -15}
      },
    },
    visible = false
  })

  y_off = -37

  -- sounds
  for i = 1, MAX_SLOTS - 1 do             -- MAX_SLOTS -1 due to bgm
    Panel:new("audiolib_acc_" .. i, {
      player = p_name,
      position  = {x = 1, y = 0.8},
      alignment = {x = -1, y = 0},
      offset = {x = 0, y = y_off},
      bg = "audiolib_hud_panel_bg.png^[opacity:220",
      bg_scale = {x = 200, y = 37},
      title = "Sound test plchldr",
      title_offset = {x = -100, y = 0},
      z_index = 1000,
      sub_img_elems = {
        indicator_left = {
          scale = {x=0.02, y=0.02},
          text = "",
          alignment = {x = 0},
          offset = {x = -185}
        },
        indicator_right = {
          scale = {x=0.02, y=0.02},
          text = "",
          alignment = {x = 0},
          offset = {x = -15}
        },
      },
      visible = false
    })

    y_off = y_off - 37
  end
end



function audio_lib.HUD_accessibility_remove(p_name)
  curr_shown[p_name] = nil
  instances[p_name] = nil
  panels_order[p_name] = nil
end



function audio_lib.HUD_accessibility_play(p_name, s_type, audio)
  if not curr_shown[p_name] then return end

  -- non incolonnare in caso di suoni simili, ricomincia soltanto durata
  if s_type ~= "bgm" then
    local p_shown = curr_shown[p_name]
    local p_instances = instances[p_name]
    local p_data = p_shown[audio.name]
    local audio_name = audio.name
    local duration = audio.duration * (audio.pitch or 1)

    -- potrebbe non esserci più l'originale ma solo le copie: prendi la prima
    if not p_data and p_instances[audio.name] then
      for i = 1, 99999 do
        if p_shown[audio.name .. "@" .. i] then
          audio_name = audio.name .. "@" .. i
          p_data = p_shown[audio_name]
          break
        end
      end
    end

    if p_data then
      local params = audio.params

      -- se ce n'è più di uno..
      if p_instances[audio.name] > 1 then
        -- controllo pannello con nome originale, se esiste
        if p_shown[audio.name] and can_override_panel(p_data, params) then
          override_panel(p_name, p_data, audio.name, duration)
          return

        -- controllo gli altri (@N)
        else
          local name_to_update
          local remaining_duplicates = p_instances[audio.name]

          for i = 1, 99999 do
            local name = audio.name .. "@" .. i
            local p_data_i = p_shown[name]

            if p_data_i then
              remaining_duplicates = remaining_duplicates - 1

              if can_override_panel(p_data_i, params) then
                name_to_update = name
                p_data = p_data_i
                break
              end
            end

            if remaining_duplicates == 0 then
              break
            end
          end

          if name_to_update then
            override_panel(p_name, p_data, name_to_update, duration)
            return
          end
        end

      -- .. sennò ce n'è solo uno
      else
        if can_override_panel(p_data, params) then
          override_panel(p_name, p_data, audio_name, duration)
          return
        end
      end

      -- se arrivo qua, c'è da aumentare le istanze perché verrà creato un nuovo pannello
      p_instances[audio.name] = (p_instances[audio.name] or 0) + 1
    else
      p_instances[audio.name] = 1
    end
  end

  local panel
  local slot_id

  -- trovo pannello
  if s_type ~= "bgm" then
    for i = 1, MAX_SLOTS -1 do
      local ppanel = panel_lib.get_panel(p_name, "audiolib_acc_" .. i)

      if not ppanel:is_visible() then
        panel = ppanel
        slot_id = i
        break
      end
    end

    -- se tutti i pannelli sono già visibili, nascondi il primo apparso e sovrascrivi
    -- quello in cima alla pila
    if not slot_id then
      hide(p_name, panels_order[p_name][1])
      slot_id = MAX_SLOTS - 1
      panel = panel_lib.get_panel(p_name, "audiolib_acc_" .. slot_id)
    end

  else
    panel = panel_lib.get_panel(p_name, "audiolib_acc_bgm")
    slot_id = -1 -- non ho bisogno di un id per bgm ,che ha casella a parte
  end

  local p_shown = curr_shown[p_name]
  local audio_name = audio.name

  -- se ha duplicati, trasforma nome in nome@N
  if p_shown[audio_name] then
    for i = 1, 99999 do
      if not p_shown[audio_name .. "@" .. i] then
        audio_name = audio_name .. "@" .. i
        break
      end
    end
  end

  p_shown[audio_name] = {id = slot_id, title = audio.description, icons = {left = "", right = ""}, fading = false, fading_time = 0}

  if s_type ~= "bgm" then
    table.insert(panels_order[p_name], audio_name)
  end

  local main_panel = {title = audio.description, title_color = 0xffffff, bg = BG .. "^[opacity:220"} -- essendo una metatabella, bg non me lo vede sennò con get_info in stop(..)
  local sub_img = {}

  -- icona da mettere
  if s_type == "bgm" then
    sub_img = {indicator_left = {text = "audiolib_test_sfx1.png"}, indicator_right = {text = "audiolib_test_sfx1.png"}}
  else
    local params = audio.params

    if params.pos or params.object then
      local sound_pos = params.pos or params.object:get_pos()
      local main_bg = {}

      main_bg, sub_img = calc_pos(p_name, sound_pos)

      if params.pos then
        p_shown[audio_name].pos = params.pos
      else
        p_shown[audio_name].object = params.object
      end

      p_shown[audio_name].icons = {
        left = sub_img.indicator_left.text,
        right = sub_img.indicator_right.text
      }

      if next(main_bg) then
        main_panel.bg = main_bg.bg
      end
    else
      sub_img = {indicator_left = {text = ""}, indicator_right = {text = ""}}
    end
  end

  panel:update(main_panel, sub_img)
  panel:show()

  if s_type ~= "bgm" then
    p_shown[audio_name].after_func = hide_after_s(p_name, audio_name, audio.duration * (audio.pitch or 1))
  else
    bgm_flash(p_name, panel, audio.description)
  end
end



function audio_lib.HUD_accessibility_stop(p_name, s_type, track_name, is_overlapping)
  if not core.get_player_by_name(p_name) then return end

  local p_data = curr_shown[p_name][track_name]

  if not p_data then return end

  if s_type == "bgm" then
    panel_lib.get_panel(p_name, "audiolib_acc_bgm"):hide()
    curr_shown[p_name][track_name] = nil

  else
    local panel = panel_lib.get_panel(p_name, "audiolib_acc_" .. p_data.id)
    local col = is_overlapping and "#1399ff" or "#ff0000"
    local bg = panel:get_info().bg.text
    local opacity = string.sub(bg, bg:find("%^%[opacity"), -1)

    panel:update({bg = BG .. "^[fill:1000x1000:0,0:" .. col .. opacity, title_color = 0x000000})

    core.after(0.3, function()
      if not core.get_player_by_name(p_name) then return end

      panel:update({bg = BG .. opacity, title_color = 0xffffff})

      if not panel:is_visible() or is_overlapping then return end

      hide(p_name, track_name)
    end)
  end
end





----------------------------------------------
---------------FUNZIONI LOCALI----------------
----------------------------------------------

function can_override_panel(p_data, params)
  if (params.pos and not p_data.pos) or (params.object and not p_data.object) or (p_data.pos and not params.pos) or (p_data.object and not params.object) then
    return false
  end

  -- TEMP: p_data.object:get_pos() needed due to https://github.com/minetest/minetest/issues/13297
  if (not params.pos or vector.distance(p_data.pos, params.pos) < DIST_THRESHOLD)
     and (not params.object or not p_data.object:get_pos() or vector.distance(p_data.object:get_pos(), params.object:get_pos()) < DIST_THRESHOLD) then
    return true
  end
end



function override_panel(p_name, p_data, audio_name, duration)
  local panel = panel_lib.get_panel(p_name, "audiolib_acc_" .. p_data.id)
  local icons = p_data.icons

  p_data.fading = false
  p_data.fading_time = 0
  p_data.after_func:cancel()
  p_data.after_func = hide_after_s(p_name, audio_name, duration)

  panel:update({title_color = 0xffffff}, {indicator_left = {text = icons.indicator_left}, indicator_right = {text = icons.indicator_right}})
end



function calc_pos(p_name, sound_pos)
  local player = core.get_player_by_name(p_name)
  local p_pos = player:get_pos()
  local distance = vector.distance(sound_pos, p_pos)
  local ret1, ret2

  if distance < DIST_THRESHOLD then
    ret1, ret2 = {bg = BG .. "^[opacity:220"}, {indicator_left = {text = "audiolib_arrow-center.png"}, indicator_right = {text = "audiolib_arrow-center.png"}}

  else
    if distance < 5 then
      ret1 = {bg = BG .. "^[opacity:220"}
    elseif distance < 10 then
      ret1 = {bg = BG .. "^[opacity:190"}
    elseif distance < 15 then
      ret1 = {bg = BG .. "^[opacity:160"}
    elseif distance < 20 then
      ret1 = {bg = BG .. "^[opacity:130"}
    else
      ret1 = {bg = BG .. "^[opacity:100"}
    end

    local p_dir = player:get_look_dir()
    local to_target_dir = vector.direction(p_pos, sound_pos)
    local deg = math.deg(math.atan2(p_dir.z, p_dir.x) - math.atan2(to_target_dir.z, to_target_dir.x))

    -- in some situations, angles are subtracted in the wrong order, having `deg`
    -- overflowing the ±180 value, until a max of ±360. This fixes it
    if deg > 180 then deg = deg - 360 elseif deg <= -180 then deg = deg + 360 end

    -- blank.png perché ^[multiply con niente tira errore (nel globalstep, quando c'è solo una freccia)
    if math.abs(deg) < 10 then
      ret2 = {indicator_left = {text = "audiolib_arrow-up.png"}, indicator_right = {text = "audiolib_arrow-up.png"}}
    elseif math.abs(deg) > 170 then
      ret2 = {indicator_left = {text = "audiolib_arrow-down.png"}, indicator_right = {text = "audiolib_arrow-down.png"}}
    elseif deg > 10 and deg < 45 then
      ret2 = {indicator_left = {text = "blank.png"}, indicator_right = {text = "audiolib_arrow-upright.png"}}
    elseif deg > -45 and deg < -10 then
      ret2 = {indicator_left = {text = "audiolib_arrow-upleft.png"}, indicator_right = {text = "blank.png"}}
    elseif deg > 135 and deg < 170 then
      ret2 = {indicator_left = {text = "blank.png"}, indicator_right = {text = "audiolib_arrow-downright.png"}}
    elseif deg > -170 and deg < -135 then
      ret2 = {indicator_left = {text = "audiolib_arrow-downleft.png"}, indicator_right = {text = "blank.png"}}
    elseif deg < 0 then
      ret2 = {indicator_left = {text = "audiolib_arrow-left.png"}, indicator_right = {text = "blank.png"}}
    else
      ret2 = {indicator_left = {text = "blank.png"}, indicator_right = {text = "audiolib_arrow-right.png"}}
    end
  end

  return ret1, ret2
end



function hide_after_s(p_name, audio_name, duration)
  return core.after(math.max(duration, READING_DURATION), function()
    if not core.get_player_by_name(p_name) or not curr_shown[p_name][audio_name] then return end
    curr_shown[p_name][audio_name].fading = true
  end)
end



function hide(p_name, audio_name)
  local p_instances = instances[p_name]
  local stripped_name = string.gsub(audio_name, "@%d", "")

  -- Non so come, ma di rado hide(..) da stop(..) viene chiamato due volte. È il
  -- caso delle armi di weapons_lib che interrompono la ricarica quando si seleziona
  -- un'altra casella: tenendo premuto Q e scorrendo rapidamente la rotella, prima
  -- o poi crasha. Più armi si hanno in quella condizione, più rapidamente crasherà.
  -- Penso possa essere dovuto a qualche problema di coroutine (che in teoria
  -- prevengo con if not panel:is_visible()) misto all'interazione con gli oggetti
  -- di Luanti (ergo il problema potrebbe essere di Luanti). Mettendo questo controllo,
  -- si previene il crash e non sembrano esserci spiacevoli sorprese (anche perché
  -- se p_instances[stripped_name] non esiste, vuol dire che son già stati fatti
  -- tutti i calcoli della situazione)
  if not p_instances[stripped_name] then return end

  -- diminuisco contatore istanze
  p_instances[stripped_name] = p_instances[stripped_name] - 1

  if p_instances[stripped_name] == 0 then
    p_instances[stripped_name] = nil
  end

  local id = curr_shown[p_name][audio_name].id

  -- scalo id
  for _, val in pairs(curr_shown[p_name]) do
    if val.id > id then
      val.id = val.id - 1
    end
  end

  local panels_amount = #panels_order[p_name]
  local panel = panel_lib.get_panel(p_name, "audiolib_acc_" .. panels_amount)

  curr_shown[p_name][audio_name] = nil
  table.remove(panels_order[p_name], id)
  panel:hide()
end



function bgm_flash(p_name, panel, txt)
  local white = "^[fill:1000x1000:0,0:#ffffff^[opacity:220"
  local black = "^[opacity:220"

  panel:update({bg = BG .. white, title_color = 0x000000})

  core.after(0.1, function()
    if not core.get_player_by_name(p_name) or not panel:is_visible() or txt ~= panel:get_info().title.text then return end
    panel:update({bg = BG .. black, title_color = 0xffffff})

    core.after(0.1, function()
      if not core.get_player_by_name(p_name) or not panel:is_visible() or txt ~= panel:get_info().title.text then return end
      panel:update({bg = BG .. white, title_color = 0x000000})

      core.after(0.1, function()
        if not core.get_player_by_name(p_name) or not panel:is_visible() or txt ~= panel:get_info().title.text then return end
        panel:update({bg = BG .. black, title_color = 0xffffff})
      end)
    end)
  end)
end