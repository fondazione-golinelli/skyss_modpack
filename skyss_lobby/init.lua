-- Hub-wide settings for the Skyss lobby world: the clock stands still at a
-- fixed time of day, the sky stays clear and players move a little faster.
-- Enable this mod in the lobby world only.

local settings = core.settings
local TIME = tonumber(settings:get("skyss_lobby_time_of_day") or "") or 0.5
local CLEAR = settings:get_bool("skyss_lobby_clear_weather", true)
local SPEED = tonumber(settings:get("skyss_lobby_speed") or "") or 1.3
local FACTOR_ID = "skyss_lobby:speed"
local CHECK_EVERY = 5

skyss_lobby = {}

local function keep_time()
    if TIME < 0 then return end
    if math.abs(core.get_timeofday() - TIME) > 0.001 then
        core.set_timeofday(TIME)
    end
end

local function keep_weather()
    if not CLEAR or not (mcl_weather and mcl_weather.change_weather) then return end
    if mcl_weather.state ~= "none" then
        mcl_weather.change_weather("none", nil, "skyss_lobby")
    end
end

-- Through Mineclonia's playerphysics the factor multiplies with sprinting
-- and the other speed effects instead of replacing them.
function skyss_lobby.apply_speed(player)
    if SPEED == 1 then return end
    if playerphysics and playerphysics.add_physics_factor then
        playerphysics.add_physics_factor(player, "speed", FACTOR_ID, SPEED)
    else
        player:set_physics_override({ speed = SPEED })
    end
end

function skyss_lobby.remove_speed(player)
    if playerphysics and playerphysics.remove_physics_factor then
        playerphysics.remove_physics_factor(player, "speed", FACTOR_ID)
    end
end

core.register_on_joinplayer(function(player)
    skyss_lobby.apply_speed(player)
end)

-- Taken off again on leaving, so it is not kept in the player data if the
-- mod is ever switched off.
core.register_on_leaveplayer(function(player)
    skyss_lobby.remove_speed(player)
end)

core.register_on_mods_loaded(function()
    if TIME >= 0 and tonumber(settings:get("time_speed") or "72") ~= 0 then
        core.log("warning", "[skyss_lobby] time_speed is not 0: the clock is reset to the fixed time every "
            .. CHECK_EVERY .. " s")
    end
    core.after(0, keep_time)
    core.after(1, keep_weather)
end)

local timer = 0
core.register_globalstep(function(dtime)
    timer = timer + dtime
    if timer < CHECK_EVERY then return end
    timer = 0
    keep_time()
    keep_weather()
end)

core.log("action", ("[skyss_lobby] time of day %s, clear weather %s, speed %s"):format(
    TIME >= 0 and tostring(TIME) or "free", tostring(CLEAR), tostring(SPEED)))
