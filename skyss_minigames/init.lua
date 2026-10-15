-- skyss_minigames: minigame manager for the Skyss hub.
--
-- Arenas are data (<world>/skyss_minigames/arenas.json, written by hubgen),
-- so regenerating the hub map regenerates the arenas with it. Games register
-- with skyss_minigames.register_game() and get a match table; see README.md.

skyss_minigames = {}

-- Private namespace shared by the src/ files.
local P = {
    S = core.get_translator("skyss_minigames"),
    storage = core.get_mod_storage(),
    games = {},
}

local SRC = core.get_modpath("skyss_minigames") .. "/src/"
for _, file in ipairs({
    "util", "arenas", "snapshot", "leaderboard", "hud",
    "match", "queue", "ui_layout", "ui", "forms", "editor", "tools", "commands",
}) do
    assert(loadfile(SRC .. file .. ".lua"))(P)
end

-- For tests and debugging only; not an API.
skyss_minigames._internal = P

core.log("action", "[skyss_minigames] Loaded")
