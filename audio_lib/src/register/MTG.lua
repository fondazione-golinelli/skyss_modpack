local S = core.get_translator("audio_lib")
local old_mt_play = core.sound_play

function core.sound_play(spec, parameters, ephemeral, force_mt)
  if not force_mt and audio_lib.is_sound_registered(spec) then
    audio_lib.play_sound(spec, parameters) -- yes, I'm not returning a possible handle, but AFAIK MTG sounds don't use handles so there shouldn't be any issue
  else
    return old_mt_play(spec, parameters, ephemeral)
  end
end



if core.get_modpath("carts") then
  audio_lib.register_sound("sfx", "carts_cart_moving", S("Cart moves"))
end

if core.get_modpath("default") then
  audio_lib.register_sound("sfx", "default_break_glass", S("Grass breaks"))
  audio_lib.register_sound("sfx", "default_chest_close", S("Chest closes"))
  audio_lib.register_sound("sfx", "default_chest_open", S("Chest opens"))
  audio_lib.register_sound("sfx", "default_cool_lava", S("Lapilli burst out"))
  -- TEMP: dig sounds aren't played through Lua, so they can't be spotted
  --audio_lib.register_sound("sfx", "default_dig_choppy", S("Chop chop"))
  --etc
  -- TEMP: footsteps can't be tracked, see https://github.com/minetest/minetest/issues/14650
  --audio_lib.register_sound("sfx", "default_gravel_footstep", S("Footsteps (gravel)"))
  --audio_lib.register_sound("sfx", "default_grass_footstep", S("Footsteps (grass)"))
  --audio_lib.register_sound("sfx", "default_dirt_footstep", S("Footsteps (dirt)"))
  -- etc.
  audio_lib.register_sound("sfx", "default_dug_metal", S("Metal breaks"))
  audio_lib.register_sound("sfx", "default_dug_node", S("Node breaks"))
  audio_lib.register_sound("sfx", "default_furnace_active", S("Furnace crackles"), nil, 10)
  audio_lib.register_sound("sfx", "default_gravel_dug", S("Gravel breaks"))
  audio_lib.register_sound("sfx", "default_ice_dug", S("Ice breaks"))
  audio_lib.register_sound("sfx", "default_item_smoke", S("Item evaporates"))
  audio_lib.register_sound("sfx", "default_place_node", S("Node placed"))
  audio_lib.register_sound("sfx", "default_place_node_hard", S("Hard node placed"))
  audio_lib.register_sound("sfx", "default_place_node_metal", S("Metal node placed"))
  audio_lib.register_sound("sfx", "default_tool_breaks", S("Item breaks"))
  audio_lib.register_sound("sfx", "player_damage", S("Hit"))
end

if core.get_modpath("doors") then
  audio_lib.register_sound("sfx", "doors_door_close", S("Door closes"))
  audio_lib.register_sound("sfx", "doors_door_open", S("Door opens"))
  audio_lib.register_sound("sfx", "doors_fencegate_close", S("Fence gate closes"))
  audio_lib.register_sound("sfx", "doors_fencegate_open", S("Fence gate opens"))
  audio_lib.register_sound("sfx", "doors_glass_door_close", S("Glass door closes"))
  audio_lib.register_sound("sfx", "doors_glass_door_open", S("Glass door opens"))
  audio_lib.register_sound("sfx", "doors_steel_door_close", S("Steel door closes"))
  audio_lib.register_sound("sfx", "doors_steel_door_open", S("Steel door opens"))
end

if core.get_modpath("env_sounds") then
  audio_lib.register_sound("sfx", "env_sounds_lava", S("Lava boils"))
  audio_lib.register_sound("sfx", "env_sounds_water", S("Water flows"))
end

if core.get_modpath("fire") then
  audio_lib.register_sound("sfx", "fire_extinguish_flame", S("Fire exstinguishes"))
  audio_lib.register_sound("sfx", "fire_fire", S("Fire burns"))
  audio_lib.register_sound("sfx", "fire_flint_and_steel", S("Flint scratches"))
  audio_lib.register_sound("sfx", "fire_large", S("Fire roars"))
  audio_lib.register_sound("sfx", "fire_small", S("Fire crackles"))
end

if core.get_modpath("tnt") then
  audio_lib.register_sound("sfx", "tnt_explode", S("Explosion"))
  audio_lib.register_sound("sfx", "tnt_gunpowder_burning", S("Fuse burns"))
  audio_lib.register_sound("sfx", "tnt_ignite", S("Fuse ignites"))
end

if core.get_modpath("xpanes") then
  audio_lib.register_sound("sfx", "xpanes_steel_bar_door_close", S("Steel bar door slams"))
  audio_lib.register_sound("sfx", "xpanes_steel_bar_door_open", S("Steel bar door creaks"))
end