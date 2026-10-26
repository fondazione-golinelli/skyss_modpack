-- "Painting exhibition": special mission of classrooms_bridge.
--
-- Every participant gets a painting frame (the mission one, handed out in
-- the zone and taken back outside it) and must hang at least N paintings of
-- their own inside the zone. A student's HUD counts their own paintings (the
-- mission is done for them at N); the mission as a whole counts the student
-- who hung the fewest, so it completes when every participant has hung N.
-- Paintings stay on the walls when the mission is deleted.

local S = minetest.get_translator("skyss_paintings")
local paintings = skyss_paintings
local storage = minetest.get_mod_storage()
local KIND = "paintings"
local GOAL = "paintings_each"

local function start_key(id) return "mission_start_" .. tostring(id) end

local active = {} -- [mission id] = { site, mission }, refreshed by count

local function inside(site, pos)
    return site.min_x and pos.x >= site.min_x and pos.x <= site.max_x
        and pos.z >= site.min_z and pos.z <= site.max_z
end

-- { [player] = paintings of their own they hung in the zone since the start }
local function hung_by(site, mission)
    local since = storage:get_int(start_key(mission.id))
    local counts = {}
    for _, p in ipairs(mission.participants or {}) do counts[p] = 0 end
    for key, entry in pairs(paintings.registry()) do
        local pos = minetest.string_to_pos(key)
        if pos and counts[entry.placer] and entry.placer == entry.owner
                and (tonumber(entry.placed) or 0) >= since and inside(site, pos) then
            counts[entry.placer] = counts[entry.placer] + 1
        end
    end
    return counts
end

local function wanted(mission)
    return math.max(1, tonumber((mission.settings or {}).per_student) or 1)
end

local function mission_here(player)
    local pos = vector.round(player:get_pos())
    for _, a in pairs(active) do
        if inside(a.site, pos) then return a end
    end
end

-- Mission lines in the frame panel: the student's own progress, or every
-- participant for the staff.
paintings.panel_extra = function(player)
    local a = mission_here(player)
    if not a then return nil end
    local name = player:get_player_name()
    local need = wanted(a.mission)
    local counts = hung_by(a.site, a.mission)
    local lines = {}
    local esc = minetest.formspec_escape
    if paintings.is_staff(name) then
        local names = {}
        for p in pairs(counts) do table.insert(names, p) end
        table.sort(names, function(x, y)
            if (counts[x] >= need) ~= (counts[y] >= need) then return counts[x] < need end
            return x:lower() < y:lower()
        end)
        for _, p in ipairs(names) do
            local done = counts[p] >= need
            table.insert(lines, esc((done and "#7fd67f" or "#ffb347") .. p .. "  " ..
                S("@1 / @2", counts[p], need)))
        end
        if #lines == 0 then table.insert(lines, esc(S("No students in this mission."))) end
        return { title = S("Mission: paintings hung by each student"), lines = lines }
    end
    if counts[name] == nil then return nil end
    local done, total = 0, 0
    for _, n in pairs(counts) do
        total = total + 1
        if n >= need then done = done + 1 end
    end
    table.insert(lines, esc((counts[name] >= need and "#7fd67f" or "#ffb347")
        .. S("You have hung @1 of @2 paintings in this zone.", counts[name], need)))
    table.insert(lines, esc(S("Students who have finished: @1 of @2", done, total)))
    return { title = S("Mission: @1", tostring(a.mission.title or "")), lines = lines }
end

-- Tells the student where they stand after hanging a painting in the zone:
-- the goal waits for every participant, which the HUD alone doesn't say.
-- How many participants have hung all their paintings, and how many there are.
local function finished(counts, need)
    local done, total = 0, 0
    for _, n in pairs(counts) do
        total = total + 1
        if n >= need then done = done + 1 end
    end
    return done, total
end

-- Tells the student where they stand after hanging a painting in the zone.
table.insert(paintings.on_hang, function(pos, placer, data)
    local name = placer:get_player_name()
    for _, a in pairs(active) do
        if inside(a.site, pos) then
            local counts = hung_by(a.site, a.mission)
            if counts[name] and data.owner == name then
                local need = wanted(a.mission)
                local done, total = finished(counts, need)
                local text
                if counts[name] < need then
                    text = S("Painting hung: @1 of @2.", counts[name], need)
                elseif done < total then
                    text = S("Mission complete for you! Classmates who have finished: @1 of @2.", done, total)
                else
                    text = S("Every student has hung their paintings!")
                end
                minetest.chat_send_player(name, minetest.colorize("#7fd67f", S("[Paintings]") .. " " .. text))
            end
            return
        end
    end
end)

classrooms_bridge.register_special_mission(KIND, {
    label = S("Painting exhibition"),
    description = S("Every student gets a painting frame and hangs their own pixel-art paintings in the zone"),
    icon = paintings.FRAME,
    zone_only = true,
    dig = true, -- hanging a painting is building: students must be able to build in the zone
    settings = {
        { key = "per_student", label = S("Paintings for each student"), type = "number", default = 1, min = 1, max = 5 },
    },
    goals = {
        { key = GOAL, label = S("Paintings hung"), icon = paintings.FRAME, count_from = "per_student" },
    },
    tools = { paintings.MISSION_FRAME },
    on_start = function(_, mission)
        storage:set_int(start_key(mission.id), os.time())
    end,
    on_stop = function(mission_id)
        storage:set_string(start_key(mission_id), "")
        active[mission_id] = nil
    end,
    -- The whole mission: the participant who has hung the fewest, so it is
    -- complete when every student has hung theirs.
    count = function(site, goal, mission, previous)
        active[mission.id] = { site = site, mission = mission }
        if goal.key ~= GOAL then return previous or 0 end
        if #(mission.participants or {}) == 0 then return 0 end
        local least = wanted(mission)
        for _, n in pairs(hung_by(site, mission)) do least = math.min(least, n) end
        return least
    end,
    -- Each student sees their own paintings: done once they have hung theirs.
    count_player = function(name, site, goal, mission)
        if goal.key ~= GOAL then return nil end
        return hung_by(site, mission)[name]
    end,
    player_note = function(_, site, mission)
        local done, total = finished(hung_by(site, mission), wanted(mission))
        if total == 0 then return nil end
        return S("Students who have finished: @1 of @2", done, total)
    end,
})
