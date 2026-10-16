-- Celestial bodies. Gravity is a factor of Earth's (9.81 m/s²); sky values
-- go to player:set_sky/set_sun/set_moon/set_stars/set_clouds. Only built-in
-- client textures and Mineclonia nodes are used: these worlds share the
-- instance media pool, so the mod must not add media or definitions.

local bodies = {}

-- The Moon: 1.62 m/s², no air, so a black sky with stars by day too, a sun
-- without sunrise glow and the Earth (about 3.7 times the size of the Moon as
-- seen from the Earth) in place of the moon.
bodies.moon = {
    gravity = 1.62 / 9.81,
    sky = {
        type = "regular",
        clouds = false,
        sky_color = {
            day_sky = "#000000", day_horizon = "#000000",
            dawn_sky = "#000000", dawn_horizon = "#000000",
            night_sky = "#000000", night_horizon = "#000000",
            indoors = "#0c0c0c",
            fog_sun_tint = "#000000", fog_moon_tint = "#000000",
            fog_tint_type = "custom",
        },
        fog = { fog_start = 0.9 },
    },
    sun = { visible = true, sunrise_visible = false, scale = 1 },
    moon = { visible = true, texture = "moon.png^[colorize:#2f6fd8:170", scale = 3.7 },
    stars = { visible = true, day_opacity = 1, count = 2500, star_color = "#ffffffdd", scale = 1 },
    clouds = { density = 0 },
}

-- Mars: 3.71 m/s², a thin dusty air: butterscotch sky by day, blue sunsets
-- around a sun two thirds the size seen from the Earth, faint ice clouds,
-- haze, and the small moon Phobos.
bodies.mars = {
    gravity = 3.71 / 9.81,
    sky = {
        type = "regular",
        clouds = true,
        sky_color = {
            day_sky = "#b98a63", day_horizon = "#dcbc98",
            dawn_sky = "#34507c", dawn_horizon = "#7f9cc2",
            night_sky = "#05060b", night_horizon = "#0e0c12",
            indoors = "#3e2c22",
            fog_sun_tint = "#6c93c9", fog_moon_tint = "#2a2a33",
            fog_tint_type = "custom",
        },
        fog = { fog_start = 0.2 },
    },
    sun = { visible = true, sunrise_visible = true, scale = 0.66,
        sunrise = "sunrisebg.png^[colorize:#5b8bd6:200" },
    moon = { visible = true, texture = "moon.png^[colorize:#6b5a4a:160", scale = 0.35 },
    stars = { visible = true, day_opacity = 0, count = 1200, star_color = "#ffffffaa", scale = 1 },
    clouds = { density = 0.12, color = "#f0dcc8a0", height = 180, thickness = 4,
        speed = { x = 1.5, z = -0.5 } },
}

return bodies
