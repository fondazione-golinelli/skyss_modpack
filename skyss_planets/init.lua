-- Moon and Mars worlds: the `skyss_planet` setting (moon or mars) picks the
-- celestial body. Players get its gravity, the sky replaces Mineclonia's
-- weather sky, the weather stays clear, no mobs spawn by themselves and new
-- map chunks get its terrain.
-- Enable this mod only in Moon and Mars worlds created on the singlenode
-- mapgen; it adds no nodes, items or media.

local PLANET = core.settings:get("skyss_planet") or "none"
local modpath = core.get_modpath(core.get_current_modname())
local bodies = dofile(modpath .. "/bodies.lua")
local BODY = bodies[PLANET]

skyss_planets = { planet = BODY and PLANET or nil, body = BODY }

if not BODY then
    core.log("warning", "[skyss_planets] skyss_planet is \"" .. PLANET .. "\": mod inactive")
    return
end

local GRAVITY_ID = "skyss_planets:gravity"
local CHECK_EVERY = 5

-- ── Gravity ──────────────────────────────────────────────────────────────────

-- Through playerphysics the factor multiplies with Mineclonia's own effects.
-- Falling damage is computed by the engine from the landing speed, so it
-- shrinks with the gravity by itself.
core.register_on_joinplayer(function(player)
    playerphysics.add_physics_factor(player, "gravity", GRAVITY_ID, BODY.gravity)
end)

core.register_on_leaveplayer(function(player)
    playerphysics.remove_physics_factor(player, "gravity", GRAVITY_ID)
end)

-- ── Sky ──────────────────────────────────────────────────────────────────────

function skyss_planets.apply_sky(player)
    player:set_sky(BODY.sky)
    player:set_sun(BODY.sun)
    player:set_moon(BODY.moon)
    player:set_stars(BODY.stars)
end

local function apply_all(player)
    skyss_planets.apply_sky(player)
    player:set_clouds(BODY.clouds)
end

-- Mineclonia repaints the sky every few seconds from the weather and the
-- biome; in the overworld ours takes its place, other dimensions keep theirs.
local update_sky_color = mcl_weather.skycolor.update_sky_color
mcl_weather.skycolor.update_sky_color = function(players)
    local others = {}
    for _, player in ipairs(mcl_weather.skycolor.utils.get_players(players)) do
        if mcl_worlds.pos_to_dimension(player:get_pos()) == "overworld" then
            skyss_planets.apply_sky(player)
            mcl_weather.skycolor.override_day_night_ratio(player, nil)
        else
            others[#others + 1] = player
        end
    end
    if #others > 0 then
        update_sky_color(others)
    end
end

-- Mineclonia sets its clouds on join and respawn; ours are set after it.
core.register_on_joinplayer(function(player)
    core.after(0, function()
        if player:is_valid() then apply_all(player) end
    end)
end)
core.register_on_respawnplayer(function(player)
    core.after(0, function()
        if player:is_valid() then apply_all(player) end
    end)
end)

-- ── Weather ──────────────────────────────────────────────────────────────────

local function keep_weather()
    if mcl_weather.state ~= "none" then
        mcl_weather.change_weather("none", nil, "skyss_planets")
    end
end

core.register_on_mods_loaded(function()
    core.after(1, keep_weather)
end)

local timer = 0
core.register_globalstep(function(dtime)
    timer = timer + dtime
    if timer < CHECK_EVERY then return end
    timer = 0
    keep_weather()
end)

-- ── Mobs ──────────────────────────────────────────────────────────────────────

-- No natural spawning, whatever the classroom setting: new instances start
-- with mobs_spawn on (peaceful only). Spawn eggs still work.
local spawn_cycle = mcl_mobs.spawn_cycle
mcl_mobs.spawn_cycle = function(level, ...)
    if level == "overworld" then return end
    return spawn_cycle(level, ...)
end

-- ── Terrain ──────────────────────────────────────────────────────────────────

if core.get_mapgen_setting("mg_name") == "singlenode" then
    loadfile(modpath .. "/mapgen.lua")(PLANET)
else
    core.log("warning", "[skyss_planets] mapgen is not singlenode: no planet terrain")
end

core.log("action", ("[skyss_planets] %s, gravity x%.3f"):format(PLANET, BODY.gravity))
