-- used for areas
local dummy = {
  initial_properties = {
    physical = false,
    visual = "sprite",
    visual_size = {x = 0, y = 0, z = 0},
    collisionbox = {0, 0, 0, 0, 0, 0},

    textures = { "blank.png" }
  },

  on_activate = function(self, staticdata)
    if not staticdata or staticdata == "" then self.object:remove() return end

    local staticdata_tbl = core.deserialize(staticdata)
    local _, arena = arena_lib.get_arena_by_name(staticdata_tbl.mod, staticdata_tbl.arena_name)

    if not arena or not arena.in_game then
      self.object:remove()
    end
  end
}

core.register_entity("arena_lib:spectate_dummy", dummy)
