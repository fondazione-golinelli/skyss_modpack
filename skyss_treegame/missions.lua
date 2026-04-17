local SAPLING = "mcl_trees:sapling_oak"
local TREE    = "mcl_trees:tree_oak"
local LEAVES  = "mcl_trees:leaves_oak"

-- ============================================================
-- CONFIGURATION
-- ============================================================

-- How many trees players must plant to win
local TREES_REQUIRED = 25

-- Match time limit in seconds (5 minutes). If players don't finish
-- in time, the game ends in failure.
local MATCH_TIMEOUT = 300

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

-- Scan the arena region and expand every oak trunk into a bigger tree
local function grow_all_trees(arena)
    if not arena.planted_trees then return end

    for _, pos in ipairs(arena.planted_trees) do
        grow_leaves(pos, LEAF_OFFSETS_BIG)
    end
end

-- ============================================================
-- TIMER STATE  (keyed by arena id)
-- ============================================================
local arena_timers = {}   -- arena.id -> handle

local function cancel_timer(arena)
    if arena_timers[arena] then
        -- core.after handles can't be cancelled directly in older LT builds;
        -- we use a "cancelled" flag stored on the table instead.
        arena_timers[arena].cancelled = true
        arena_timers[arena] = nil
    end
end

-- ============================================================
-- GAME REGISTRATION
-- ============================================================

arena_lib.register_minigame("skyss_treegame", {
    name          = "Plant the Forest!",
    min_players   = 1,
    max_players   = 25,
    keep_inventory = false,
    can_build      = true,
    regenerate_map = true,
    eliminate_on_death = false,
})

-- -------------------------------------------------------
-- on_start: give saplings, init counters, start timeout
-- -------------------------------------------------------
arena_lib.on_start("skyss_treegame", function(arena)
    -- Initialise shared tree counter on the arena table
    arena.total_trees_grown = 0
    arena.celebration_active = false

    -- Give each player saplings and reset their personal counter
    for p_name, _ in pairs(arena.players) do
        local player = core.get_player_by_name(p_name)
        if player then
            local inv = player:get_inventory()
            if inv then
                -- Give enough saplings for the whole team's share plus spare
                local per_player = math.ceil(TREES_REQUIRED / math.max(1,
                    (function()
                        local n = 0
                        for _ in pairs(arena.players) do n = n + 1 end
                        return n
                    end)()
                )) + 2
                inv:set_stack("main", 1, ItemStack(SAPLING .. " " .. per_player))
            end
            arena.players[p_name].trees_grown = 0
        end
        core.chat_send_player(p_name,
            "[TreeGame] Plant trees on the marked spots! Goal: " ..
            TREES_REQUIRED .. " trees. You have " .. MATCH_TIMEOUT .. "s!")
    end

    -- ---- 5-minute timeout ----
    local timeout_handle = {}
    arena_timers[arena] = timeout_handle

    core.after(MATCH_TIMEOUT, function()
        if timeout_handle.cancelled then return end
        if arena.celebration_active then return end

        -- Time's up — failure
        core.chat_send_all(
            "[TreeGame] Time's up! The forest was not planted in time. " ..
            arena.total_trees_grown .. "/" .. TREES_REQUIRED .. " trees grown.")
        cancel_timer(arena)
        arena_lib.load_celebration("skyss_treegame", arena, nil)   -- nil = no winner
    end)

    -- Broadcast countdown reminders at 2 min and 1 min remaining
    local remind_handle_2 = {}
    local remind_handle_1 = {}

    core.after(MATCH_TIMEOUT - 120, function()
        if remind_handle_2.cancelled then return end
        if arena.celebration_active then return end
        core.chat_send_all("[TreeGame] \xE2\x8F\xB1 2 minutes left! Trees: " ..
            arena.total_trees_grown .. "/" .. TREES_REQUIRED)
    end)
    core.after(MATCH_TIMEOUT - 60, function()
        if remind_handle_1.cancelled then return end
        if arena.celebration_active then return end
        core.chat_send_all("[TreeGame] \xE2\x8F\xB1 1 minute left! Trees: " ..
            arena.total_trees_grown .. "/" .. TREES_REQUIRED)
    end)
end)

-- -------------------------------------------------------
-- on_respawn: send player back to spawn
-- -------------------------------------------------------
arena_lib.on_respawn("skyss_treegame", function(arena, p_name)
    local player = core.get_player_by_name(p_name)
    if not player then return end

    core.after(0.2, function()
        if arena.spawners and #arena.spawners > 0 then
            player:set_pos(arena.spawners[1])
        end
        core.chat_send_player(p_name, "[TreeGame] You died! Keep planting...")
    end)
end)

-- -------------------------------------------------------
-- on_end: clean up barriers and timers
-- -------------------------------------------------------
arena_lib.on_end("skyss_treegame", function(arena, winners, is_forced)
    cancel_timer(arena)
    arena.celebration_active = false
end)

-- ============================================================
-- NODE PLACEMENT HANDLER
-- ============================================================

core.register_on_placenode(function(pos, newnode, placer)
    if newnode.name ~= SAPLING then return end
    if not placer or not placer:is_player() then return end

    local p_name = placer:get_player_name()
    local arena, _ = arena_lib.get_arena_by_player(p_name)
    if not arena or not arena.players[p_name] then return end
    if arena.celebration_active then return end   -- no planting during celebration

    -- ---- Check the block directly below is a valid planting marker ----
    local below = {x=pos.x, y=pos.y - 1, z=pos.z}
    if core.get_node(below).name ~= PLANTING_MARKER then
        -- Remove the misplaced sapling and refund it
        core.remove_node(pos)
        local inv = placer:get_inventory()
        if inv then
            inv:add_item("main", ItemStack(SAPLING .. " 1"))
        end
        core.chat_send_player(p_name,
            "[TreeGame] Plant only on the marked spots! (Sapling refunded)")
        return
    end

    -- ---- Grow the tree ----
    core.set_node(pos, {name = TREE})
    arena.planted_trees = arena.planted_trees or {}
    table.insert(arena.planted_trees, vector.new(pos))
    grow_leaves(pos, LEAF_OFFSETS_BASIC)

    -- ---- Update counters ----
    arena.players[p_name].trees_grown =
        (arena.players[p_name].trees_grown or 0) + 1
    arena.total_trees_grown = (arena.total_trees_grown or 0) + 1

    local personal = arena.players[p_name].trees_grown
    local total    = arena.total_trees_grown

    core.chat_send_player(p_name,
        "[TreeGame] Tree planted! Your contribution: " .. personal ..
        "  |  Team total: " .. total .. "/" .. TREES_REQUIRED)

    -- Broadcast milestones every 5 trees
    if total % 5 == 0 then
        core.chat_send_all("[TreeGame] \xF0\x9F\x8C\xB3 " .. total .. "/" ..
            TREES_REQUIRED .. " trees planted! Keep going!")
    end

    -- ---- Victory check ----
    if total >= TREES_REQUIRED then
        arena.celebration_active = true
        cancel_timer(arena)

        core.chat_send_all(
            "[TreeGame] \xF0\x9F\x8E\x89 All " .. TREES_REQUIRED ..
            " trees planted! The forest is growing — explore for " ..
            CELEBRATION_DURATION .. " seconds!")

        -- Grow all trees into their bigger form
        grow_all_trees(arena)

        -- Start celebration timer — end arena after exploration window
        local cel_handle = {}
        arena_timers[arena] = cel_handle

        core.after(CELEBRATION_DURATION, function()
            if cel_handle.cancelled then return end
            core.chat_send_all("[TreeGame] Exploration time is over. Thanks for planting!")
            cancel_timer(arena)
            arena_lib.load_celebration("skyss_treegame", arena, p_name)
        end)

        -- Countdown reminders during celebration
        core.after(CELEBRATION_DURATION - 30, function()
            if cel_handle.cancelled then return end
            core.chat_send_all("[TreeGame] \xE2\x8F\xB1 30 seconds of exploration left!")
        end)
    end
end)
