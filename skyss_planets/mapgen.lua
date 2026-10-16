-- Terrain of the Moon and Mars, generated in Lua on the singlenode mapgen
-- (mcl_levelgen.conf keeps Mineclonia's own singlenode generator off).
--
-- Both are height maps: noise for the ground, plus craters placed per grid
-- cell from the world seed, so every chunk computes the same craters.
-- A flat landing site of LANDING nodes around 0,0 is kept free of craters
-- (the template sets the spawn point there).
--   Moon: light highlands, dark basalt "seas" (maria), many craters, bright
--         fresh ones, scattered boulders.
--   Mars: red dust over sandstone and coloured layers seen in a canyon and
--         on mesas, a shield volcano, dark dunes, eroded craters, some with
--         water ice under the floor, dark basalt rocks.

local planet = ...

local LANDING = 24
local BASE = 16

local seed = tonumber((core.get_mapgen_setting("seed") or "0"):sub(-9)) or 0
local BEDROCK_MIN = mcl_vars.mg_bedrock_overworld_min
local BEDROCK_MAX = BEDROCK_MIN + 3

local function smoothstep(a, b, v)
    local t = math.min(1, math.max(0, (v - a) / (b - a)))
    return t * t * (3 - 2 * t)
end

local function id(name)
    return core.get_content_id(name)
end

-- ── Craters ──────────────────────────────────────────────────────────────────

-- Each layer puts at most one crater per cell; radius biased to small ones.
local CRATER_LAYERS = {
    moon = {
        { cell = 40,  chance = 0.75, rmin = 3,  rmax = 9,  depth = 0.22, rim = 0.06, young = 0.3 },
        { cell = 140, chance = 0.7,  rmin = 10, rmax = 28, depth = 0.2,  rim = 0.05, young = 0.25 },
        { cell = 420, chance = 0.7,  rmin = 32, rmax = 70, depth = 0.14, rim = 0.04, young = 0.15 },
    },
    mars = {
        { cell = 80,  chance = 0.5,  rmin = 3,  rmax = 10, depth = 0.18, rim = 0.05, icy = 0.15 },
        { cell = 260, chance = 0.75, rmin = 12, rmax = 45, depth = 0.15, rim = 0.04, icy = 0.4 },
    },
}

local function cell_rng(layer, cx, cz)
    return PcgRandom((seed + cx * 73856093 + cz * 19349663 + layer * 83492791) % 2147483647)
end

local function crater_in_cell(planet_layers, li, cx, cz)
    local L = planet_layers[li]
    local rng = cell_rng(li, cx, cz)
    if rng:next(0, 999) >= L.chance * 1000 then return end
    local x = cx * L.cell + rng:next(0, L.cell - 1)
    local z = cz * L.cell + rng:next(0, L.cell - 1)
    local u = rng:next(0, 1000) / 1000
    local r = L.rmin + (L.rmax - L.rmin) * u * u
    if math.sqrt(x * x + z * z) < r * 2.6 + LANDING + 24 then return end
    return {
        x = x, z = z, r = r, reach = r * 2.5,
        depth = r * L.depth, rim = r * L.rim, complex = r >= 30,
        young = L.young and rng:next(0, 999) < L.young * 1000,
        icy = L.icy and rng:next(0, 999) < L.icy * 1000,
    }
end

local function craters_for(minx, maxx, minz, maxz)
    local layers = CRATER_LAYERS[planet]
    local list = {}
    for li, L in ipairs(layers) do
        local m = L.rmax * 2.5
        for cx = math.floor((minx - m) / L.cell), math.floor((maxx + m) / L.cell) do
            for cz = math.floor((minz - m) / L.cell), math.floor((maxz + m) / L.cell) do
                local c = crater_in_cell(layers, li, cx, cz)
                if c and c.x + c.reach >= minx and c.x - c.reach <= maxx
                        and c.z + c.reach >= minz and c.z - c.reach <= maxz then
                    list[#list + 1] = c
                end
            end
        end
    end
    return list
end

local TAIL = 2.5 ^ -3

-- Height change at a column, and the crater whose bowl or ejecta covers it.
local function crater_offset(list, x, z)
    local dh, inside, ejecta = 0, nil, nil
    for i = 1, #list do
        local c = list[i]
        local dx, dz = x - c.x, z - c.z
        if dx > -c.reach and dx < c.reach and dz > -c.reach and dz < c.reach then
            local t = math.sqrt(dx * dx + dz * dz) / c.r
            if t < 1 then
                local bowl
                if c.complex then -- flat floor and a central peak
                    bowl = -c.depth + (c.depth + c.rim) * smoothstep(0.45, 1, t)
                    if t < 0.15 then
                        bowl = bowl + c.depth * 0.45 * (1 - t / 0.15)
                    end
                else
                    bowl = -c.depth + (c.depth + c.rim) * t * t
                end
                dh = dh + bowl
                inside = c
            elseif t < 2.5 then
                dh = dh + c.rim * (t ^ -3 - TAIL) / (1 - TAIL)
                if t < 1.6 then ejecta = ejecta or c end
            end
        end
    end
    return dh, inside, ejecta
end

-- ── Noise ────────────────────────────────────────────────────────────────────

local NOISE = {
    moon = {
        base = { offset = 0, scale = 9, spread = { x = 420, y = 420, z = 420 }, seed = 7301, octaves = 4, persistence = 0.5, lacunarity = 2 },
        mare = { offset = 0, scale = 1, spread = { x = 650, y = 650, z = 650 }, seed = 7302, octaves = 3, persistence = 0.5, lacunarity = 2 },
        detail = { offset = 0, scale = 1, spread = { x = 12, y = 12, z = 12 }, seed = 7303, octaves = 2, persistence = 0.5, lacunarity = 2 },
    },
    mars = {
        base = { offset = 0, scale = 8, spread = { x = 500, y = 500, z = 500 }, seed = 8301, octaves = 5, persistence = 0.5, lacunarity = 2 },
        mesa = { offset = 0, scale = 1, spread = { x = 220, y = 220, z = 220 }, seed = 8302, octaves = 3, persistence = 0.55, lacunarity = 2 },
        canyon = { offset = 0, scale = 1, spread = { x = 260, y = 260, z = 260 }, seed = 8303, octaves = 3, persistence = 0.5, lacunarity = 2 },
        dunes = { offset = 0, scale = 1, spread = { x = 160, y = 160, z = 160 }, seed = 8304, octaves = 2, persistence = 0.5, lacunarity = 2 },
        detail = { offset = 0, scale = 1, spread = { x = 12, y = 12, z = 12 }, seed = 8305, octaves = 2, persistence = 0.5, lacunarity = 2 },
    },
}

-- The landing site takes the plain ground height at 0,0, without craters or
-- other features, and blends into the terrain around it.
local landing_h
local function landing_blend(h, r)
    if not landing_h then
        local origin = { x = 0, y = 0 }
        local nb = core.get_perlin(NOISE[planet].base):get_2d(origin)
        if planet == "moon" then
            local mare = smoothstep(0.25, 0.55, core.get_perlin(NOISE.moon.mare):get_2d(origin))
            landing_h = BASE + nb * (1 - 0.7 * mare) - 7 * mare
        else
            landing_h = BASE + nb
        end
    end
    return landing_h + (h - landing_h) * smoothstep(LANDING, LANDING + 40, r)
end

local SIDE -- columns per side of a chunk plus a border of one
local maps, bufs = {}, {}

local function noise_maps(minp)
    for name, params in pairs(NOISE[planet]) do
        maps[name] = maps[name] or core.get_perlin_map(params, { x = SIDE, y = SIDE, z = 1 })
        bufs[name] = maps[name]:get_2d_map_flat({ x = minp.x - 1, y = minp.z - 1 }, bufs[name])
    end
    return bufs
end

-- ── Moon ─────────────────────────────────────────────────────────────────────

local moon_c

local function moon_columns(minp, n, list)
    moon_c = moon_c or {
        high_top = id("mcl_colorblocks:concrete_powder_silver"),
        mare_top = id("mcl_colorblocks:concrete_powder_grey"),
        fresh_top = id("mcl_colorblocks:concrete_powder_white"),
        high_sub = id("mcl_core:andesite"),
        mare_sub = id("mcl_blackstone:basalt_smooth"),
        stone = id("mcl_core:stone"),
        ore = id("mcl_core:stone_with_iron"),
        boulder = id("mcl_core:andesite"),
    }
    local c = moon_c
    local cols = {}
    local i = 0
    for z = minp.z - 1, minp.z + SIDE - 2 do
        for x = minp.x - 1, minp.x + SIDE - 2 do
            i = i + 1
            local mare = smoothstep(0.25, 0.55, n.mare[i])
            local h = BASE + n.base[i] * (1 - 0.7 * mare) - 7 * mare
            local dh, inside, ejecta = crater_offset(list, x, z)
            h = h + dh
            local r = math.sqrt(x * x + z * z)
            h = landing_blend(h, r)
            local young = (inside and inside.young) or (ejecta and ejecta.young)
            local top
            if young and n.detail[i] > -0.2 then
                top = c.fresh_top
            elseif mare > 0.5 then
                top = c.mare_top
            else
                top = c.high_top
            end
            cols[i] = {
                h = math.floor(h + 0.5), top = top, top_depth = 2,
                sub = mare > 0.5 and c.mare_sub or c.high_sub, sub_depth = 4,
                rock = (r > LANDING and (young or n.detail[i] > 0.9)) and c.boulder or nil,
            }
        end
    end
    return cols, c.stone, c.ore
end

-- ── Mars ─────────────────────────────────────────────────────────────────────

local mars_c

-- The shield volcano and the canyon are fixed features near the spawn.
local VOLCANO = { x = -300, z = -260, r = 170, h = 64, caldera = 22, caldera_depth = 14 }
local CANYON_Z, CANYON_DEPTH = 150, 34

local function mars_columns(minp, n, list)
    mars_c = mars_c or {
        dust = id("mcl_core:redsand"),
        sandstone = id("mcl_core:redsandstone"),
        dark_dust = id("mcl_colorblocks:concrete_powder_brown"),
        basalt_top = id("mcl_blackstone:basalt"),
        basalt = id("mcl_blackstone:basalt_smooth"),
        ice = id("mcl_core:packed_ice"),
        rock = id("mcl_blackstone:basalt_polished"),
        ore = id("mcl_core:stone_with_iron"),
        strata = {
            id("mcl_colorblocks:hardened_clay_orange"),
            id("mcl_colorblocks:hardened_clay"),
            id("mcl_colorblocks:hardened_clay_red"),
            id("mcl_colorblocks:hardened_clay_orange"),
            id("mcl_colorblocks:hardened_clay_brown"),
            id("mcl_colorblocks:hardened_clay_yellow"),
            id("mcl_colorblocks:hardened_clay_red"),
        },
    }
    local c = mars_c
    local cols = {}
    local i = 0
    for z = minp.z - 1, minp.z + SIDE - 2 do
        for x = minp.x - 1, minp.x + SIDE - 2 do
            i = i + 1
            local h = BASE + n.base[i]
            -- Mesas: terraced plateaus.
            local mesa = smoothstep(0.32, 0.42, n.mesa[i])
            if mesa > 0 then
                h = h + math.floor(mesa * 22 / 4) * 4
            end
            -- Shield volcano with a caldera.
            local vx, vz = x - VOLCANO.x, z - VOLCANO.z
            local vr = math.sqrt(vx * vx + vz * vz)
            local volcanic = false
            if vr < VOLCANO.r then
                local rise = VOLCANO.h * (1 - vr / VOLCANO.r) ^ 1.6
                h = math.max(h, BASE + rise)
                if vr < VOLCANO.caldera then
                    h = h - VOLCANO.caldera_depth * smoothstep(VOLCANO.caldera, VOLCANO.caldera - 4, vr)
                end
                volcanic = vr < VOLCANO.r * 0.6
            end
            -- Canyon with stepped walls, crossing the map from west to east.
            local cz = CANYON_Z + 60 * math.sin(x / 230) + 30 * n.canyon[i]
            local width = 38 + 10 * n.canyon[i]
            local d = math.abs(z - cz) / width
            local floor_dunes = 0
            if d < 1 then
                local cut = CANYON_DEPTH * smoothstep(1, 0.35, d)
                h = math.min(h, BASE - math.floor(cut / 4) * 4 + 4 * (1 - smoothstep(1, 0.35, d)))
                if d < 0.35 and n.dunes[i] > -0.2 then
                    floor_dunes = 1
                end
            end
            local dh, inside = crater_offset(list, x, z)
            h = h + dh
            local r = math.sqrt(x * x + z * z)
            h = landing_blend(h, r)
            -- Dark dune fields in low places and on the canyon floor.
            local dune = floor_dunes == 1 or (n.dunes[i] > 0.85 and r > LANDING + 40)
            local top, top_depth = c.dust, 1
            if dune then
                h = h + 1.5 * (math.sin((x * 0.8 + z * 0.35) * 0.22 + n.dunes[i] * 6) + 1)
                top, top_depth = c.dark_dust, 2
            elseif volcanic and n.detail[i] + n.dunes[i] * 0.8 < -0.6 then
                top = c.basalt_top
            end
            cols[i] = {
                h = math.floor(h + 0.5), top = top, top_depth = top_depth,
                sub = c.sandstone, sub_depth = 3,
                ice = inside and inside.icy and math.sqrt((x - inside.x) ^ 2 + (z - inside.z) ^ 2) < inside.r * 0.6,
                rock = (r > LANDING and not dune and n.detail[i] > 0.85) and c.rock or nil,
            }
        end
    end
    return cols, c.basalt, c.ore
end

-- ── Generator ────────────────────────────────────────────────────────────────

local data = {}

core.register_on_generated(function(minp, maxp, blockseed)
    local vm = core.get_mapgen_object("voxelmanip")
    SIDE = maxp.x - minp.x + 3
    local n = noise_maps(minp)
    local list = craters_for(minp.x - 1, maxp.x + 1, minp.z - 1, maxp.z + 1)
    local cols, deep, ore
    if planet == "moon" then
        cols, deep, ore = moon_columns(minp, n, list)
    else
        cols, deep, ore = mars_columns(minp, n, list)
    end

    local emin, emax = vm:get_emerged_area()
    local area = VoxelArea(emin, emax)
    vm:get_data(data)
    local rng = PcgRandom(blockseed)
    local bedrock = id("mcl_core:bedrock")
    local strata = mars_c and mars_c.strata
    local c_ice = mars_c and mars_c.ice

    for z = minp.z, maxp.z do
        for x = minp.x, maxp.x do
            local ci = (z - minp.z + 1) * SIDE + (x - minp.x + 1) + 1
            local col = cols[ci]
            local h = col.h
            -- Steep slopes show the rock under the dust.
            local steep = math.max(
                math.abs(h - cols[ci - 1].h), math.abs(h - cols[ci + 1].h),
                math.abs(h - cols[ci - SIDE].h), math.abs(h - cols[ci + SIDE].h)) >= 3
            local top_to = math.min(maxp.y, h + ((col.rock and rng:next(0, 99) < 30) and 1 or 0))
            for y = math.max(minp.y, BEDROCK_MIN), top_to do
                local vi = area:index(x, y, z)
                local depth = h - y
                local node
                if y <= BEDROCK_MAX and (y == BEDROCK_MIN or rng:next(0, BEDROCK_MAX - BEDROCK_MIN) >= y - BEDROCK_MIN) then
                    node = bedrock
                elseif depth < 0 then
                    node = col.rock
                elseif col.ice and depth >= 2 and depth <= 4 then
                    node = c_ice
                elseif depth < col.top_depth and not steep then
                    node = col.top
                elseif depth < col.top_depth + col.sub_depth and not (steep and strata) then
                    node = col.sub
                elseif strata and y > BASE - 48 then
                    node = strata[(math.floor(y / 3) % #strata) + 1]
                elseif rng:next(0, 999) < 4 then
                    node = ore
                else
                    node = deep
                end
                data[vi] = node
            end
        end
    end

    vm:set_data(data)
    vm:calc_lighting()
    vm:write_to_map()
end)

core.log("action", "[skyss_planets] terrain generator: " .. planet)
