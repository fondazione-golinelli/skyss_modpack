-- Sky textures drawn at load time and sent inline as "[png:<base64>".
--
-- Built-in client names do not work here: the proxy prefixes every texture
-- name with the media pool ("instance_moon.png") and only leaves the plain
-- names "sun.png" and "moon.png" alone, so "moon.png^[colorize:..." or
-- "sunrisebg.png^..." become missing images. Inline PNGs have no file name
-- to prefix and need no media.

local textures = {}

-- size x size image from fn(x, y) -> r, g, b, a (0..255), x and y from 0.
local function png(w, h, fn)
    local px = {}
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local r, g, b, a = fn(x, y)
            px[#px + 1] = string.char(
                math.max(0, math.min(255, math.floor(r))),
                math.max(0, math.min(255, math.floor(g))),
                math.max(0, math.min(255, math.floor(b))),
                math.max(0, math.min(255, math.floor(a))))
        end
    end
    return "[png:" .. core.encode_base64(core.encode_png(w, h, table.concat(px)))
end

local function in_ellipse(u, v, cx, cy, rx, ry)
    return ((u - cx) / rx) ^ 2 + ((v - cy) / ry) ^ 2 <= 1
end

-- Disc of radius 1 in u, v (-1..1) with an outline and limb darkening;
-- fn(u, v) gives the surface colour.
local function body(size, fn)
    local c = (size - 1) / 2
    local r = size / 2 - 0.5
    return png(size, size, function(x, y)
        local u, v = (x - c) / r, (y - c) / r
        local d = math.sqrt(u * u + v * v)
        if d > 1 then return 0, 0, 0, 0 end
        local cr, cg, cb = fn(u, v)
        local k = 1 - 0.35 * d ^ 3
        if d > 1 - 1.5 / r then k = k * 0.7 end
        return cr * k, cg * k, cb * k, 255
    end)
end

-- The Earth: Africa and Europe facing the Moon, a bit of South America,
-- polar ice and cloud bands.
textures.earth = body(32, function(u, v)
    local ocean = { 36, 84, 196 }
    local land = { 76, 140, 62 }
    local desert = { 196, 164, 96 }
    local col = ocean
    if in_ellipse(u, v, 0.08, 0.28, 0.3, 0.42) or in_ellipse(u, v, 0.18, -0.02, 0.38, 0.18) then
        col = (v < 0.12 and v > -0.12) and desert or land                  -- Africa, Sahara
    end
    if in_ellipse(u, v, -0.05, -0.42, 0.3, 0.12) or in_ellipse(u, v, 0.3, -0.48, 0.25, 0.12) then
        col = land                                                          -- Europe
    end
    if in_ellipse(u, v, 0.55, -0.2, 0.18, 0.12) then col = desert end   -- Arabia
    if in_ellipse(u, v, -0.82, 0.3, 0.22, 0.38) then col = land end     -- South America
    if v < -0.84 or v > 0.86 then col = { 236, 242, 248 } end            -- ice
    -- clouds: wavy white bands
    local band = math.sin(v * 8 + math.sin(u * 4 + v * 3) * 1.8) * math.sin(u * 3 + 1.3)
    if band > 0.62 or in_ellipse(u, v, -0.35, -0.62, 0.22, 0.06) then col = { 244, 246, 250 } end
    return col[1], col[2], col[3]
end)

-- Phobos: a small, lumpy, dark grey-brown moon with the Stickney crater.
textures.phobos = png(16, 16, function(x, y)
    local u, v = (x - 7.5) / 7, (y - 7.5) / 5.6
    local a = math.atan2(v, u)
    local edge = 1 + 0.12 * math.sin(a * 3 + 0.5) + 0.06 * math.sin(a * 5)
    local d = math.sqrt(u * u + v * v)
    if d > edge then return 0, 0, 0, 0 end
    local g = 112 - 40 * d
    if in_ellipse(u, v, -0.35, -0.1, 0.32, 0.4) then g = g * 0.7 end
    if d > edge - 0.18 then g = g * 0.7 end
    return g * 1.05, g * 0.92, g * 0.8, 255
end)

-- Martian sunset glow, shaped like the client's sunrisebg.png (240x40, glow
-- at the bottom centre narrowing upwards) but blue.
textures.mars_sunrise = png(120, 20, function(x, y)
    local u, v = (x - 59.5) / 60, (19 - y) / 19
    local width = 0.18 + 0.7 * (1 - v)
    local a = (1 - v) ^ 1.3 * math.exp(-(u / width) ^ 2) * 230
    return 91 + 60 * (1 - v), 139 + 40 * (1 - v), 214 + 20 * (1 - v), a
end)

return textures
