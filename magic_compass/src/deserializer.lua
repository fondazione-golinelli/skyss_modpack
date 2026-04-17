magic_compass.items = {}

local yaml = dofile(core.get_modpath("magic_compass") .. "/libs/tinyyaml.lua")
local S_wrld = core.get_translator("magic_compass_data")



local function load_locations()
  local wrld_dir = core.get_worldpath() .. "/magic_compass"
  local content = core.get_dir_list(wrld_dir)

  for _, f_name in pairs(content) do
    -- carica le posizioni
    if f_name:sub(-4) == ".yml" or f_name:sub(-5) == ".yaml" then
      local file = io.open(wrld_dir .. "/" .. f_name, "r")
      local locs = yaml.parse(file:read("*all"))

      for ID, loc in pairs(locs) do

        assert(type(ID) == "number",  "[MAGIC_COMPASS] Invalid location ID '" .. ID .. "': numbers only!")
        assert(loc.description,       "[MAGIC_COMPASS] Location #" .. ID .. " has no description!")
        assert(loc.icon,              "[MAGIC_COMPASS] Location #" .. ID .. " has no icon!")
        assert(loc.teleport_to,       "[MAGIC_COMPASS] Location #" .. ID .. " has no teleport coordinates!")

        core.register_tool("magic_compass:" .. ID, {
          description = S_wrld(loc.description),
          inventory_image = loc.icon,
          groups = {not_in_creative_inventory = 1, oddly_breakable_by_hand = 2}
        })

        magic_compass.items[ID] = {
          desc = loc.description,
          pos = loc.teleport_to,
          rotation = loc.rotation,
          cooldown = loc.cooldown,
          privs = loc.requires,
          hide = loc.hidden_by_default
        }
      end

      file:close()
    end
  end
end

load_locations()
