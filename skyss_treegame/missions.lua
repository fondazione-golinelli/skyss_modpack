local S = core.get_translator("skyss_treegame")

local SAPLING = "mcl_trees:sapling_oak"
local TREE    = "mcl_trees:tree_oak"
local LEAVES  = "mcl_trees:leaves_oak"

-- ============================================================
-- CONFIGURATION
-- ============================================================

-- How many trees players must plant to win
local TREES_REQUIRED = 25


-- Celebration / exploration phase after all trees are planted (seconds)
local CELEBRATION_DURATION = 60

-- The node type used to mark valid planting spots.
-- You can freely change this to any block you want in-world.
-- Place these blocks manually in your arena to define valid spots.
local PLANTING_MARKER = "mcl_core:dirt_with_grass"   -- ← edit this freely

-- ============================================================
-- TREE GROWING HELPERS
-- ============================================================

-- Basic leaf pattern for a freshly placed sapling
local LEAF_OFFSETS_BASIC = {
    {x=0,  y=1,  z=0},  {x=0,  y=2,  z=0},  {x=0,  y=3,  z=0},
    {x=1,  y=2,  z=0},  {x=-1, y=2,  z=0},
    {x=0,  y=2,  z=1},  {x=0,  y=2,  z=-1},
    {x=1,  y=3,  z=0},  {x=-1, y=3,  z=0},
    {x=0,  y=3,  z=1},  {x=0,  y=3,  z=-1},
    {x=1,  y=1,  z=0},  {x=-1, y=1,  z=0},
    {x=0,  y=1,  z=1},  {x=0,  y=1,  z=-1},
}

-- Extended leaf pattern used during the celebration phase
local LEAF_OFFSETS_BIG = {
    -- trunk extension
    {x=0,  y=4,  z=0},  {x=0,  y=5,  z=0},
    -- wide canopy layer 1 (y+2)
    {x=2,  y=2,  z=0},  {x=-2, y=2,  z=0},
    {x=0,  y=2,  z=2},  {x=0,  y=2,  z=-2},
    {x=1,  y=2,  z=1},  {x=-1, y=2,  z=1},
    {x=1,  y=2,  z=-1}, {x=-1, y=2,  z=-1},
    -- wide canopy layer 2 (y+3)
    {x=2,  y=3,  z=0},  {x=-2, y=3,  z=0},
    {x=0,  y=3,  z=2},  {x=0,  y=3,  z=-2},
    {x=1,  y=3,  z=1},  {x=-1, y=3,  z=1},
    {x=1,  y=3,  z=-1}, {x=-1, y=3,  z=-1},
    {x=2,  y=3,  z=1},  {x=-2, y=3,  z=1},
    {x=2,  y=3,  z=-1}, {x=-2, y=3,  z=-1},
    {x=1,  y=3,  z=2},  {x=-1, y=3,  z=2},
    {x=1,  y=3,  z=-2}, {x=-1, y=3,  z=-2},
    -- top cap (y+4)
    {x=1,  y=4,  z=0},  {x=-1, y=4,  z=0},
    {x=0,  y=4,  z=1},  {x=0,  y=4,  z=-1},
    {x=1,  y=4,  z=1},  {x=-1, y=4,  z=1},
    {x=1,  y=4,  z=-1}, {x=-1, y=4,  z=-1},
    -- very top (y+5)
    {x=1,  y=5,  z=0},  {x=-1, y=5,  z=0},
    {x=0,  y=5,  z=1},  {x=0,  y=5,  z=-1},
}

-- Grow leaves around a position from an offset list
local function grow_leaves(pos, offsets)
    for _, offset in ipairs(offsets) do
        local leaf_pos = vector.add(pos, offset)
        if core.get_node(leaf_pos).name == "air" then
            core.set_node(leaf_pos, {name = LEAVES})
        end
    end
end

-- Expand every planted trunk into a bigger tree
local function grow_all_trees(state)
    for _, pos in ipairs(state.planted_trees) do
        grow_leaves(pos, LEAF_OFFSETS_BIG)
    end
end

-- ============================================================
-- GAME
-- ============================================================
-- `match` is the skyss_minigames match; the game keeps its counters in
-- match.data. The area (saplings, trees) is restored after the match.

local function chat(match, message)
    skyss_minigames.chat(match, message)
end

-- The time limit comes from skyss_minigames (3 minutes unless an admin or
-- a teacher changes it); without one there are no reminders.
local function reminder(match, seconds_left, message_fn)
    if match.time_limit <= seconds_left then return end
    core.after(match.time_limit - seconds_left, function()
        if match.state == "running" and not match.data.celebrating then
            chat(match, "\xE2\x8F\xB1 " .. message_fn())
        end
    end)
end

local game_def = {
    title         = S("Plant the Forest!"),
    description   = S("Plant trees on the marked spots and grow a forest together."),
    mode          = "coop",
    ranking       = "time",
    min_players   = 1,
    max_players   = 25,
    icon          = "default_sapling.png",
    color         = "#3f8f4f",
    can_place     = true,
    exclusive     = false,
    celebration_time = CELEBRATION_DURATION,
}

function game_def.on_start(match)
    local state = { total = 0, per_player = {}, planted_trees = {} }
    match.data = state

    local count = skyss_minigames.player_count(match)
    -- Enough saplings for each player's share of the goal, plus spare
    local per_player = math.ceil(TREES_REQUIRED / math.max(1, count)) + 2
    for p_name, player in skyss_minigames.players(match) do
        player:get_inventory():set_stack("main", 1, ItemStack(SAPLING .. " " .. per_player))
        state.per_player[p_name] = 0
    end
    chat(match, S("Plant trees on the marked spots! Goal: @1 trees. You have @2 seconds!",
        TREES_REQUIRED, match.time_limit))

    reminder(match, 120, function()
        return S("2 minutes left! Trees: @1/@2", state.total, TREES_REQUIRED)
    end)
    reminder(match, 60, function()
        return S("1 minute left! Trees: @1/@2", state.total, TREES_REQUIRED)
    end)
end

function game_def.on_timeout(match)
    chat(match, S("Time's up! The forest was not planted in time. @1/@2 trees grown.",
        match.data.total or 0, TREES_REQUIRED))
    return { success = false, celebration_time = 5 }
end

function game_def.on_respawn(match, p_name)
    core.chat_send_player(p_name, S("You died! Keep planting..."))
end

function game_def.on_finish(match, result)
    if not result.success then return end
    core.after(CELEBRATION_DURATION - 30, function()
        if match.state == "ending" then
            chat(match, "\xE2\x8F\xB1 " .. S("30 seconds of exploration left!"))
        end
    end)
end

function game_def.on_end(match, result)
    if result.success then
        chat(match, S("Exploration time is over. Thanks for planting!"))
    end
end

skyss_minigames.register_game("skyss_treegame", game_def)

-- ============================================================
-- NODE PLACEMENT HANDLER
-- ============================================================

core.register_on_placenode(function(pos, newnode, placer)
    if newnode.name ~= SAPLING then return end
    if not placer or not placer:is_player() then return end

    local p_name = placer:get_player_name()
    local match = skyss_minigames.get_match_by_player(p_name)
    if not match or match.game.name ~= "skyss_treegame" or match.state ~= "running" then return end
    local state = match.data

    -- ---- Check the block directly below is a valid planting marker ----
    local below = {x=pos.x, y=pos.y - 1, z=pos.z}
    if core.get_node(below).name ~= PLANTING_MARKER then
        -- Remove the misplaced sapling and refund it
        core.remove_node(pos)
        local inv = placer:get_inventory()
        if inv then
            inv:add_item("main", ItemStack(SAPLING .. " 1"))
        end
        core.chat_send_player(p_name, S("Plant only on the marked spots! (Sapling refunded)"))
        return
    end

    -- ---- Grow the tree ----
    core.set_node(pos, {name = TREE})
    table.insert(state.planted_trees, vector.new(pos))
    grow_leaves(pos, LEAF_OFFSETS_BASIC)

    -- ---- Update counters ----
    state.per_player[p_name] = (state.per_player[p_name] or 0) + 1
    state.total = state.total + 1

    core.chat_send_player(p_name,
        S("Tree planted! Your contribution: @1  |  Team total: @2/@3",
            state.per_player[p_name], state.total, TREES_REQUIRED))

    -- Broadcast milestones every 5 trees
    if state.total % 5 == 0 and state.total < TREES_REQUIRED then
        chat(match, "\xF0\x9F\x8C\xB3 " .. S("@1/@2 trees planted! Keep going!", state.total, TREES_REQUIRED))
    end

    -- ---- Victory: the forest grows, then players explore it ----
    if state.total >= TREES_REQUIRED then
        state.celebrating = true
        chat(match, "\xF0\x9F\x8E\x89 " ..
            S("All @1 trees planted! The forest is growing — explore for @2 seconds!",
                TREES_REQUIRED, CELEBRATION_DURATION))
        grow_all_trees(state)
        skyss_minigames.finish(match, { success = true })
    end
end)
