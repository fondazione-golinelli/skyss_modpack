-- refactored clone of arena_lib's tools_customise_sky.lua file
local al_S = core.get_translator("arena_lib")

local function fill_tempsky() end
local function get_celvault_formspec() end
local function get_sky_params() end
local function get_sun_params() end
local function get_moon_params() end
local function get_stars_params() end
local function get_clouds_params() end
local function get_clouds_col_alpha() end
local function calc_clouds_col() end
local function colstr() end
local function same_table() end

local temp_sky_settings = {}            -- KEY: p_name, VALUE: {all the sky settings}
local temp_util_values = {}             -- KEY: p_name, VALUE: {fog_distance, fog_start}
                                        -- ^ tengo traccia di valori che servono a me ma che non son da passare a set_celestial_vault
local palette_str, palette_id = arena_lib.get_palette_col_and_sorted_table()    -- palette id KEY = hex value; VALUE = id



function hub.edit_celvault(p_name)
  fill_tempsky(p_name)

  core.show_formspec(p_name, "hub:celestial_vault", get_celvault_formspec(p_name, "sky"))
end





----------------------------------------------
---------------FUNZIONI LOCALI----------------
----------------------------------------------

function fill_tempsky(p_name)
  temp_util_values[p_name] = {}
  temp_sky_settings[p_name] = not hub.celestial_vault and {} or table.copy(hub.celestial_vault)

  if not temp_sky_settings[p_name].sky then
    temp_sky_settings[p_name].sky = {fog = {}, sky_color = {}, textures = {}}
  end
  if not temp_sky_settings[p_name].sun then
    temp_sky_settings[p_name].sun = {}
  end
  if not temp_sky_settings[p_name].moon then
    temp_sky_settings[p_name].moon = {}
  end
  if not temp_sky_settings[p_name].stars then
    temp_sky_settings[p_name].stars = {}
  end
  if not temp_sky_settings[p_name].clouds then
    temp_sky_settings[p_name].clouds = {speed = {}}
  end
end



function get_celvault_formspec(p_name, section)
  local formspec = {
    "formspec_version[4]",
    "size[9.72,10]",
    "bgcolor[;neither]",
    "no_prepend[]",
    "style_type[image_button;border=false]",
    "scrollbaroptions[min=0;max=100;arrows=hide]",
    -- bottoni
    "container[1,1]",
    "tooltip[sky_btn;" .. al_S("Sky") .."]",
    "tooltip[sun_btn;" .. al_S("Sun") .."]",
    "tooltip[moon_btn;" .. al_S("Moon") .."]",
    "tooltip[stars_btn;" .. al_S("Stars") .. "]",
    "tooltip[clouds_btn;" .. al_S("Clouds") .. "]",
    "image_button[0,0;1,1;arenalib_sky_sky.png" .. (section == "sky" and "^[multiply:#777777" or "") .. ";sky_btn;]",
    "image_button[1.68,0;1,1;arenalib_sky_sun.png" .. (section == "sun" and "^[multiply:#777777" or "") .. ";sun_btn;]",
    "image_button[3.36,0;1,1;arenalib_sky_moon.png" .. (section == "moon" and "^[multiply:#777777" or "") .. ";moon_btn;]",
    "image_button[5.04,0;1,1;arenalib_sky_stars.png" .. (section == "stars" and "^[multiply:#777777" or "") .. ";stars_btn;]",
    "image_button[6.72,0;1,1;arenalib_sky_cloud.png" .. (section == "clouds" and "^[multiply:#777777" or "") .. ";clouds_btn;]",
    "container_end[]",
    "container[1,2.2]",
    -- <dove saranno i vari campi a seconda del tipo>
    "button[2,6.7;1.9,0.7;reset;" .. al_S("Reset") .."]",
    "button[4,6.7;1.9,0.7;apply;" .. al_S("Apply") .."]",
    "container_end[]",
  }

  local fields = {}
  if section == "sky" then
    fields = get_sky_params(p_name)
  elseif section == "sun" then
    fields = get_sun_params(p_name)
  elseif section == "moon" then
    fields = get_moon_params(p_name)
  elseif section == "stars" then
    fields = get_stars_params(p_name)
  else
    fields = get_clouds_params(p_name)
  end

  for k, v in pairs(fields) do
    table.insert(formspec, #formspec-2, v)
  end

  return table.concat(formspec, "")
end



function get_sky_params(p_name)
  local temp_sky = temp_sky_settings[p_name].sky
  local clouds = true
  local sky_type = 1

  if temp_sky.clouds ~= nil and temp_sky.clouds == false then
    clouds = false
  end

  if temp_sky.type == "skybox" then
    sky_type = 2
  elseif temp_sky.type == "plain" then
    sky_type = 3
  end

  local temp_sky_col = temp_sky.sky_color
  local temp_sky_fog = temp_sky.fog
  local sky_params = {}
  local sky = {
    "label[0,0.25;" .. al_S("Type") .. "]",
    "dropdown[0,0.5;3.75,0.6;sky_type;regular,skybox,plain;" .. sky_type .. ";]",
    "checkbox[4.2,0.78;sky_clouds;" .. al_S("Clouds") .. ";" .. tostring(clouds) .. "]"
  }

  if sky_type == 1 then

    sky_params = {
      "container[0,1.6]",
      "label[0,0;" .. al_S("Day sky") .. "]",
      "dropdown[0,0.2;2.5,0.6;day_sky;" .. palette_str .. ";" .. (palette_id[colstr(temp_sky_col.day_sky)] or 1) .. "]",
      "label[2.6,0;" .. al_S("Dawn sky") .. "]",
      "dropdown[2.6,0.2;2.5,0.6;dawn_sky;" .. palette_str .. ";" .. (palette_id[colstr(temp_sky_col.dawn_sky)] or 1) .. "]",
      "label[5.2,0;" .. al_S("Night sky") .. "]",
      "dropdown[5.2,0.2;2.5,0.6;night_sky;" .. palette_str .. ";" .. (palette_id[colstr(temp_sky_col.night_sky)] or 1) .. "]",
      "label[0,1.05;" .. al_S("Day horizon") .. "]",
      "dropdown[0,1.25;2.5,0.6;day_horizon;" .. palette_str .. ";" .. (palette_id[colstr(temp_sky_col.day_horizon)] or 1) .. "]",
      "label[2.6,1.05;" .. al_S("Dawn horizon") .. "]",
      "dropdown[2.6,1.25;2.5,0.6;dawn_horizon;" .. palette_str .. ";" .. (palette_id[colstr(temp_sky_col.dawn_horizon)] or 1) .. "]",
      "label[5.2,1.05;" .. al_S("Night horizon") .. "]",
      "dropdown[5.2,1.25;2.5,0.6;night_horizon;" .. palette_str .. ";" .. (palette_id[colstr(temp_sky_col.night_horizon)] or 1) .. "]",
      "label[0,2.1;" .. al_S("Indoors") .. "]",
      "dropdown[0,2.3;2.5,0.6;indoors;" .. palette_str .. ";" .. (palette_id[colstr(temp_sky_col.indoors)] or 1) .. "]",
      "container_end[]",
      "checkbox[0,4.9;custom_fog_tint;" .. al_S("Custom fog tint") .. ";" .. (temp_sky_col.fog_tint_type == "custom" and "true" or "false") .. "]",
    }

    if temp_sky_col.fog_tint_type == "custom" then
      local fog_tint_params =  {
        "label[2.6,2.1;" .. al_S("Fog sun tint") .. "]",
        "dropdown[2.6,2.3;2.5,0.6;fog_sun_tint;" .. palette_str .. ";" .. (palette_id[colstr(temp_sky_col.fog_sun_tint)] or 1) .. "]",
        "label[5.2,2.1;" .. al_S("Fog moon tint") .. "]",
        "dropdown[5.2,2.3;2.5,0.6;fog_moon_tint;" .. palette_str .. ";" .. (palette_id[colstr(temp_sky_col.fog_moon_tint)] or 1) .. "]"
        }

        for k, v in pairs(fog_tint_params) do
          table.insert(sky_params, #sky_params - 3, v)
        end
    end

  else
    sky_params = {
      "container[0,4.5]",
      "label[0,-0.1;" .. al_S("Base colour") .. "]",
      "dropdown[0,0.14;3.75,0.6;base_color;" .. palette_str .. ";" .. (palette_id[temp_sky.base_color] or 1) .. "]",
      "container_end[]"
    }

    if sky_type == 2 then
      local skybox = {
        "container[0,1.6]",
        "field[0,0;3.75,0.6;top;" .. al_S("Top") .. ";" .. (temp_sky.textures[1] or "" ) .. "]",
        "field[4.15,0;3.75,0.6;bottom;" .. al_S("Bottom") .. ";" .. (temp_sky.textures[2] or "") .. "]",
        "field[0,1;3.75,0.6;west;" .. al_S("West") .. ";" .. (temp_sky.textures[3] or "") .. "]",
        "field[4.15,1;3.75,0.6;east;" .. al_S("East") .. ";" .. (temp_sky.textures[4] or "") .. "]",
        "field[0,2;3.75,0.6;north;" .. al_S("North") .. ";" .. (temp_sky.textures[5] or "") .. "]",
        "field[4.15,2;3.75,0.6;south;" .. al_S("South") .. ";" .. (temp_sky.textures[6] or "") .. "]",
        "container_end[]",
      }

      for k, v in pairs(skybox) do
        table.insert(sky_params, #sky_params-3, v)
      end
    end
  end

  local fog = "checkbox[5.2,4.9;enable_fog;" .. al_S("Fog") .. ";" .. (temp_sky_fog.fog_distance and "true" or "false") .. "]"

  table.insert(sky_params, fog)

  if temp_sky_fog.fog_distance then
    local fog_params = {
      "field[0,5.8;3.75,0.6;fog_distance;" .. al_S("Fog distance") .. ";" .. temp_sky_fog.fog_distance .. "]",
      "label[3.85,5.62;" .. al_S("Fog start") .. "]",
      "label[3.85,6.09;0]",
      "label[7.6,6.09;1]",
      "scrollbar[4.2,5.93;3.15,0.3;horizontal;fog_start;" .. temp_sky_fog.fog_start * 100 .. "]",
    }

    for k, v in pairs(fog_params) do
      table.insert(sky_params, v)
    end
  end

  for k, v in pairs(sky_params) do
    table.insert(sky, #sky, v)
  end

  return sky
end



function get_sun_params(p_name)
  local temp_sun = temp_sky_settings[p_name].sun
  local is_sun_visible = temp_sun.visible ~= false
  local is_sunrise_visible = temp_sun.sunrise_visible ~= false

  local sun = {
    "checkbox[0,0.78;sun_visible;" .. al_S("Visible sun") .. ";" .. tostring(is_sun_visible) .. "]",
    "checkbox[4,0.78;sunrise_visible;" .. al_S("Visible sunrise") .. ";" .. tostring(is_sunrise_visible) .. "]",
    "container[0,1.6]",
    "container_end[]"
  }

  if is_sun_visible then
    local sun_params = {
      "field[0,0;3.75,0.6;sun_texture;" .. al_S("Texture") .. ";" .. (temp_sun.texture or "sun.png") .. "]",
      "field[0,1;3.75,0.6;sun_tonemap;" .. al_S("Tonemap") .. ";" .. (temp_sun.tonemap or "sun_tonemap.png") .. "]",
      "field[0,2;1,0.6;sun_size;" .. al_S("Size") .. ";" .. (temp_sun.scale or 1) .. "]"
    }

    for k, v in pairs(sun_params) do
      table.insert(sun, #sun, v)
    end
  end

  if is_sunrise_visible then
    local sunrise_params = {
      "field[4.15,0;3.75,0.6;sunrise_texture;" .. al_S("Sunrise texture") .. ";" .. (temp_sun.sunrise or "sunrisebg.png") .. "]",
    }

    for k, v in pairs(sunrise_params) do
      table.insert(sun, #sun, v)
    end
  end

  return sun
end



function get_moon_params(p_name)
  local temp_moon = temp_sky_settings[p_name].moon
  local is_moon_visible = temp_moon.visible ~= false

  local moon = {
    "checkbox[0,0.78;moon_visible;" .. al_S("Visible moon") .. ";" .. tostring(is_moon_visible) .. "]",
  }

  if is_moon_visible then
    local moon_params = {
      "container[0,1.6]",
      "field[0,0;3.75,0.6;moon_texture;" .. al_S("Texture") ..";" .. (temp_moon.texture or "moon.png") .. "]",
      "field[0,1;3.75,0.6;moon_tonemap;" .. al_S("Tonemap") .. ";" .. (temp_moon.tonemap or "moon_tonemap.png") .. "]",
      "field[0,2;1,0.6;moon_size;" .. al_S("Size") .. ";" .. (temp_moon.scale or 1 ) .. "]",
      "container_end[]"
    }

    for k, v in pairs(moon_params) do
      table.insert(moon, #moon, v)
    end
  end

  return moon
end



function get_stars_params(p_name)
  local temp_stars = temp_sky_settings[p_name].stars
  local are_stars_visible = temp_stars.visible ~= false

  local stars = {
    "checkbox[0,0.78;stars_visible;" .. al_S("Visible stars") .. ";" .. tostring(are_stars_visible) .. "]",
  }

  if are_stars_visible then
    local stars_params = {
      "field[6.9,0.7;1,0.6;stars_size;" .. al_S("Size") .. ";" .. (temp_stars.scale or 1) .. "]",
      "container[0,1.6]",
      "label[0,-0.2;" .. al_S("Colour") .. "]",
      "dropdown[0,0;3.75,0.6;stars_color;" .. palette_str .. ";" .. (palette_id[temp_stars.star_color] or 1) .. "]",
      "field[4.15,0;3.75,0.6;stars_count;" .. al_S("Count") .. ";" .. (temp_stars.count or 1000) .. "]",
      "label[0,1;" .. al_S("Opacity") .. "]",
      "label[0,1.5;0]",
      "label[7.6,1.5;1]",
      "scrollbar[0.3,1.35;7.15,0.3;horizontal;stars_opacity;" .. (temp_stars.day_opacity or 0) * 100 .. "]",
      "container_end[]"
    }

    for k, v in pairs(stars_params) do
      table.insert(stars, #stars, v)
    end
  end

  return stars
end



function get_clouds_params(p_name)
  local temp_clouds = temp_sky_settings[p_name].clouds
  local are_clouds_visible = temp_sky_settings[p_name].sky.clouds ~= false
  local clouds = {}

  if not are_clouds_visible then
    clouds = {
      "hypertext[0,0.85;7,1;name; <global size=18 font=mono halign=center color=#e6482e><b>" .. al_S("Clouds must be enabled first to change their parameters") .. "</b>]",
    }

  else
    local col, alpha = get_clouds_col_alpha(temp_clouds.color)
    clouds = {
      "container[0,0.5]",
      -- colour
      "container[0,0]",
      "label[0,0;" .. al_S("Colour") .. "]",
      "dropdown[0,0.2;3.75,0.6;clouds_color;" .. palette_str .. ";" .. (palette_id[col] or 1) .. "]",
      "label[4.15,0;" .. al_S("Ambient") .. "]",
      "dropdown[4.15,0.2;3.75,0.6;clouds_ambient;" .. palette_str .. ";" .. (palette_id[temp_clouds.ambient] or 1) .. "]",
      "label[0,1.2;" .. al_S("Opacity") .. "]",
      "label[0,1.7;0]",
      "label[7.6,1.7;1]",
      "scrollbar[0.3,1.55;7.15,0.3;horizontal;clouds_opacity;" .. alpha * 100 .. "]",
      "container_end[]",
      -- density etc
      "container[0,2.3]",
      "label[0,0;" .. al_S("Density") .. "]",
      "label[0,0.5;0]",
      "label[7.6,0.5;1]",
      "scrollbar[0.3,0.35;7.15,0.3;horizontal;clouds_density;" .. ((temp_clouds.density or 0.4) * 100) .. "]",
      "label[0,1.05;" .. al_S("Thickness") .. "]",
      "field[0,1.25;1,0.6;clouds_thickness;;" .. (temp_clouds.thickness or 16) .. "]",
      "label[1.7,1.05;" .. al_S("Height") .. "]",
      "field[1.7,1.25;1,0.6;clouds_height;;" .. (temp_clouds.height or 120) .. "]",
      "label[4.15,1.05;" .. al_S("Speed") .. "]",
      "label[4.15,1.55;X]",
      "field[4.45,1.25;1,0.6;clouds_speed_x;;" .. (temp_clouds.speed.x or 0) .. "]",
      "label[5.8,1.55;Z]",
      "field[6.1,1.25;1,0.6;clouds_speed_z;;" .. (temp_clouds.speed.z or -2) .. "]",
      "container_end[]",
      "container_end[]"
    }
  end

  return clouds
end



function get_clouds_col_alpha(colour)
  if not colour then return "", 0.9 end

  local col = string.sub(colour, 1, 7)
  local alpha_hex = string.sub(colour, -2)
  local alpha = tonumber(alpha_hex, 16) / 255

  return col, alpha
end



function calc_clouds_col(colour, alpha_val)
  colour = colour == "" and "#FFF0F0" or colour
  local alpha_hex = string.format("%x", alpha_val * 255)
  return colour .. alpha_hex
end



function colstr(col)
  if type(col) == "table" then
    return core.rgba(col.r, col.g, col.b)
  else
    return col
  end
end



function same_table(t1,t2)
  return core.serialize(t1) == core.serialize(t2)
end





----------------------------------------------
---------------GESTIONE CAMPI-----------------
----------------------------------------------

core.register_on_player_receive_fields(function(player, formname, fields)
  if formname ~= "hub:celestial_vault" then return end

  local p_name = player:get_player_name()
  local temp_sky = temp_sky_settings[p_name].sky
  local temp_sky_col = temp_sky.sky_color
  local temp_sky_fog = temp_sky.fog
  local temp_sun = temp_sky_settings[p_name].sun
  local temp_moon = temp_sky_settings[p_name].moon
  local temp_stars = temp_sky_settings[p_name].stars
  local temp_clouds = temp_sky_settings[p_name].clouds

  local celvault    = hub.celestial_vault

  -- se abbandona...
  if fields.quit then
    if celvault then
      if celvault.sky    then player:set_sky(celvault.sky)       end
      if celvault.sun    then player:set_sun(celvault.sun)       end
      if celvault.moon   then player:set_moon(celvault.moon)     end
      if celvault.stars  then player:set_stars(celvault.stars)   end
      if celvault.clouds then player:set_clouds(celvault.clouds) end
    else
      -- TODO: this should be considered to make it shorter: https://github.com/minetest/minetest/issues/11917
      player:set_sky()
      player:set_sun()
      player:set_moon()
      player:set_stars()
      player:set_clouds()
    end

    temp_sky_settings[p_name] = nil
    temp_util_values[p_name] = nil
    return

  -- ...o se ripristina, non c'è bisogno di andare oltre
  elseif fields.reset then
    hub.set_celestial_vault()
    player:set_sky()
    player:set_sun()
    player:set_moon()
    player:set_stars()
    player:set_clouds()
    fill_tempsky(p_name)

    -- riapro il formspec sul quale mi trovavo
    if fields.day_sky then
      core.show_formspec(p_name, "hub:celestial_vault", get_celvault_formspec(p_name, "sky"))
    elseif fields.sun_size then
      core.show_formspec(p_name, "hub:celestial_vault", get_celvault_formspec(p_name, "sun"))
    elseif fields.moon_size then
      core.show_formspec(p_name, "hub:celestial_vault", get_celvault_formspec(p_name, "moon"))
    elseif fields.stars_count then
      core.show_formspec(p_name, "hub:celestial_vault", get_celvault_formspec(p_name, "stars"))
    else
      core.show_formspec(p_name, "hub:celestial_vault", get_celvault_formspec(p_name, "clouds"))
    end

    return
  end

  -- se cambia sezione, non c'è bisogno di controllare il resto (dato che viene automatico cambiare
  -- e poi premere "Applica")
  if fields.sky_btn then
    core.show_formspec(p_name, "hub:celestial_vault", get_celvault_formspec(p_name, "sky"))
    return
  elseif fields.sun_btn then
    core.show_formspec(p_name, "hub:celestial_vault", get_celvault_formspec(p_name, "sun"))
    return
  elseif fields.moon_btn then
    core.show_formspec(p_name, "hub:celestial_vault", get_celvault_formspec(p_name, "moon"))
    return
  elseif fields.stars_btn then
    core.show_formspec(p_name, "hub:celestial_vault", get_celvault_formspec(p_name, "stars"))
    return
  elseif fields.clouds_btn then
    core.show_formspec(p_name, "hub:celestial_vault", get_celvault_formspec(p_name, "clouds"))
    return
  end


  local palette = arena_lib.PALETTE

  --
  -- aggiorna i vari parametri
  --

  -- cielo
  if fields.base_color then
    temp_sky.base_color = palette[fields.base_color]
  end

  if fields.day_sky then
    temp_sky_col.day_sky = palette[fields.day_sky]
  end

  if fields.day_horizon then
    temp_sky_col.day_horizon = palette[fields.day_horizon]
  end

  if fields.dawn_sky then
    temp_sky_col.dawn_sky = palette[fields.dawn_sky]
  end

  if fields.dawn_horizon then
    temp_sky_col.dawn_horizon = palette[fields.dawn_horizon]
  end

  if fields.night_sky then
    temp_sky_col.night_sky = palette[fields.night_sky]
  end

  if fields.night_horizon then
    temp_sky_col.night_horizon = palette[fields.night_horizon]
  end

  if fields.indoors then
    temp_sky_col.indoors = palette[fields.indoors]
  end

  if fields.fog_sun_tint then
    temp_sky_col.fog_sun_tint = palette[fields.fog_sun_tint]
  end

  if fields.fog_moon_tint then
    temp_sky_col.fog_moon_tint = palette[fields.fog_moon_tint]
  end

  if fields.fog_distance then
    temp_sky_fog.fog_distance = tonumber(fields.fog_distance)
  end

  if fields.fog_start then
    temp_sky_fog.fog_start = core.explode_scrollbar_event(fields.fog_start).value / 100
  end

  if fields.sky_type == "skybox" and fields.top then
    temp_sky.textures[1] = fields.top
    temp_sky.textures[2] = fields.bottom
    temp_sky.textures[3] = fields.west
    temp_sky.textures[4] = fields.east
    temp_sky.textures[5] = fields.north
    temp_sky.textures[6] = fields.south
  end

  -- sole
  if fields.sun_texture then
    temp_sun.texture = fields.sun_texture
  end

  if fields.sun_tonemap then
    temp_sun.tonemap = fields.sun_tonemap
  end

  if fields.sunrise_texture then
    temp_sun.sunrise = fields.sunrise_texture
  end

  if fields.sun_size then
    temp_sun.scale = tonumber(fields.sun_size) or temp_sun.scale
  end

  -- luna
  if fields.moon_texture then
    temp_moon.texture = fields.moon_texture
  end

  if fields.moon_tonemap then
    temp_moon.tonemap = fields.moon_tonemap
  end

  if fields.moon_size then
    temp_moon.scale = tonumber(fields.moon_size) or temp_moon.scale
  end

  -- stelle
  if fields.stars_color then
    temp_stars.star_color = palette[fields.stars_color]
  end

  if fields.stars_count then
    temp_stars.count = tonumber(fields.stars_count) or temp_stars.count
  end

  if fields.stars_size then
    temp_stars.scale = tonumber(fields.stars_size) or temp_stars.scale
  end

  if fields.stars_opacity then
    temp_stars.day_opacity = core.explode_scrollbar_event(fields.stars_opacity).value / 100
  end

  -- nuvole
  -- Minetest è stupido perché alcuni campi li aggiorna sempre e altri no, quindi
  -- per farla breve, non controllo anche clouds_opacity per evitare un crash con
  -- clouds_ambient che non rileverebbe clouds_color, esplodendo su calc_clouds_col
  if fields.clouds_color then
    local alpha_value = core.explode_scrollbar_event(fields.clouds_opacity).value / 100
    temp_clouds.color = calc_clouds_col(palette[fields.clouds_color], alpha_value)
  end

  if fields.clouds_ambient then
    temp_clouds.ambient = palette[fields.clouds_ambient]
  end

  if fields.clouds_density then
    temp_clouds.density = core.explode_scrollbar_event(fields.clouds_density).value / 100
  end

  if fields.clouds_thickness then
    temp_clouds.thickness = tonumber(fields.clouds_thickness) or temp_clouds.thickness
  end

  if fields.clouds_height then
    temp_clouds.height = tonumber(fields.clouds_height) or temp_clouds.height
  end

  if fields.clouds_speed_x then
    temp_clouds.speed.x = tonumber(fields.clouds_speed_x) or temp_clouds.speed.x
  end

  if fields.clouds_speed_z then
    temp_clouds.speed.z = tonumber(fields.clouds_speed_z) or temp_clouds.speed.z
  end


  -- controlla i vari campi che necessitano di ricaricare il formspec (le spunte)
  if fields.sky_clouds then
    temp_sky.clouds = fields.sky_clouds == "true" and true or false

  elseif fields.custom_fog_tint then
    temp_sky_col.fog_tint_type = fields.custom_fog_tint == "true" and "custom" or "default"
    core.show_formspec(p_name, "hub:celestial_vault", get_celvault_formspec(p_name, "sky"))

  elseif fields.enable_fog then
    if fields.enable_fog == "true" then
      temp_sky_fog.fog_distance = temp_util_values[p_name].fog_distance or 50
      temp_sky_fog.fog_start = temp_util_values[p_name].fog_start or 0.5
    else
      temp_util_values[p_name].fog_distance = temp_sky_fog.fog_distance
      temp_util_values[p_name].fog_start = temp_sky_fog.fog_start
      temp_sky_fog.fog_distance = nil
    end

    core.show_formspec(p_name, "hub:celestial_vault", get_celvault_formspec(p_name, "sky"))

  elseif fields.sky_type and temp_sky.type ~= fields.sky_type then
    temp_sky.type = fields.sky_type
    core.show_formspec(p_name, "hub:celestial_vault", get_celvault_formspec(p_name, "sky"))

  elseif fields.sun_visible then
    temp_sun.visible = fields.sun_visible == "true" and true or false
    core.show_formspec(p_name, "hub:celestial_vault", get_celvault_formspec(p_name, "sun"))

  elseif fields.sunrise_visible then
    temp_sun.sunrise_visible = fields.sunrise_visible == "true" and true or false
    core.show_formspec(p_name, "hub:celestial_vault", get_celvault_formspec(p_name, "sun"))

  elseif fields.moon_visible then
    temp_moon.visible = fields.moon_visible == "true" and true or false
    core.show_formspec(p_name, "hub:celestial_vault", get_celvault_formspec(p_name, "moon"))

  elseif fields.stars_visible then
    temp_stars.visible = fields.stars_visible == "true" and true or false
    core.show_formspec(p_name, "hub:celestial_vault", get_celvault_formspec(p_name, "stars"))
  end


  -- applica
  if fields.apply then
    -- faccio una copia o va a condividere la tabella temporanea con quella dell'arena
    -- finché non si chiude l'editor (non salvando le modifiche nel mezzo). La faccio qui
    -- (e non sul set) perché sennò cambia non so come l'ordine degli elementi della tabella,
    -- ritornando quindi same_table(...) sempre falso
    local temp_copy = table.copy(temp_sky_settings[p_name])
    local overwrite = not celvault or not same_table(celvault, temp_copy)

    if overwrite then
      hub.set_celestial_vault(temp_copy)
    end
  end

  local reset_fog = false

  -- se è appena stata tolta la spunta dalla casella "fog", faccio sparire in tempo
  -- reale l'eventuale nebbia rimasta allə giocatorə nell'editor, in quanto MT
  -- richiede che la nebbia sia -1 per rimuoverla
  if not temp_sky_fog.fog_distance then
    temp_sky_fog.fog_distance = -1
    temp_sky_fog.fog_start = -1
    reset_fog = true
  end

  player:set_sky(temp_sky)
  player:set_sun(temp_sun)
  player:set_moon(temp_moon)
  player:set_stars(temp_stars)
  player:set_clouds(temp_clouds)

  -- e qui rimuovo quello che ho fatto su
  if reset_fog then
    temp_sky_fog.fog_distance = nil
    temp_sky_fog.fog_start = nil
  end
end)
