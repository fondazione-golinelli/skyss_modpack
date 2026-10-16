-- Built-in places of the HUB map, in list order. Positions match the map made
-- by luanti-tools/hubgen (feet position, yaw in degrees as Luanti counts it:
-- 0 = north, 90 = west). hubgen also writes them to
-- <world>/skyss_hubmap/places.json, which wins over these values, and admins
-- can move a place in game (kept in mod storage).
--
-- spawn follows the hub mod's spawn point; a minigame place follows the
-- return point of the game's launcher in skyss_minigames, when there is one.
local S = ...

local tags = {
    { id = "spawn", title = S("Spawn point") },
    { id = "portal", title = S("Worlds portal") },
    { id = "minigames", title = S("Minigames") },
    { id = "countries", title = S("Countries") },
}

local places = {
    { id = "spawn", tag = "spawn", title = S("Spawn point"),
        info = S("Where players arrive in the HUB."), pos = { 0, 7, 13 }, yaw = 0 },
    { id = "portal", tag = "portal", title = S("Worlds portal"),
        info = S("Step through the portal to visit the worlds."), pos = { 0, 9, 58 }, yaw = 0 },

    { id = "skyss_animalgame", tag = "minigames", game = "skyss_animalgame", title = S("Animal Sounds"),
        pos = { 46, 7, 15 }, yaw = 288 },
    { id = "skyss_cleanup", tag = "minigames", game = "skyss_cleanup", title = S("Eco-CleanUp"),
        pos = { 28, 7, -39 }, yaw = 216 },
    { id = "skyss_treegame", tag = "minigames", game = "skyss_treegame", title = S("Restore the Forest"),
        pos = { -28, 7, -39 }, yaw = 144 },
    { id = "skyss_firegame", tag = "minigames", game = "skyss_firegame", title = S("Wildfire Crew"),
        pos = { -46, 7, 15 }, yaw = 72 },

    { id = "germany", tag = "countries", flag = "de", title = S("Germany"), pos = { 46, 7, 63 }, yaw = 324 },
    { id = "hungary", tag = "countries", flag = "hu", title = S("Hungary"), pos = { 74, 7, -24 }, yaw = 252 },
    { id = "italy", tag = "countries", flag = "it", title = S("Italy"), pos = { 0, 7, -78 }, yaw = 180 },
    { id = "poland", tag = "countries", flag = "pl", title = S("Poland"), pos = { -74, 7, -24 }, yaw = 108 },
    { id = "spain", tag = "countries", flag = "es", title = S("Spain"), pos = { -46, 7, 63 }, yaw = 36 },
}

return tags, places
