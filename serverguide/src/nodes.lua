local S = core.get_translator("serverguide")

local function remove_label_entities(pos, entity_name)
	for _, object in ipairs(core.get_objects_inside_radius(pos, 0.5)) do
		local entity = object:get_luaentity()
		if entity and entity.name == entity_name then
			object:remove()
		end
	end
end

local function add_label_entity(pos, entity_name)
	remove_label_entities(pos, entity_name)
	core.add_entity(pos, entity_name)
end

local function place_facing_player(itemstack, placer, pointed_thing)
	if not placer then
		return core.item_place(itemstack, placer, pointed_thing)
	end

	return core.item_place(itemstack, placer, pointed_thing, core.dir_to_facedir(placer:get_look_dir()))
end

local function remove_if_orphaned(self, expected_node)
	local pos = self.object:get_pos()
	if not pos then return end

	local node = core.get_node(vector.round(pos))
	if node.name ~= expected_node then
		self.object:remove()
	end
end

local label_nodes = {
	["serverguide:rules"] = "serverguide:pedestal_rules",
	["serverguide:values"] = "serverguide:pedestal_values",
}

local function cleanup_orphaned_labels_around(pos, radius)
	for _, object in ipairs(core.get_objects_inside_radius(pos, radius)) do
		local entity = object:get_luaentity()
		local expected_node = entity and label_nodes[entity.name]
		if expected_node then
			remove_if_orphaned(entity, expected_node)
		end
	end
end

local cleanup_timer = 0
core.register_globalstep(function(dtime)
	cleanup_timer = cleanup_timer + dtime
	if cleanup_timer < 10 then return end
	cleanup_timer = 0

	for _, player in ipairs(core.get_connected_players()) do
		cleanup_orphaned_labels_around(player:get_pos(), 64)
	end
end)



-- nodi
core.register_node("serverguide:pedestal_rules", {
	drawtype = "mesh",
	mesh = "fbrawl_book_pedestal.obj",
	tiles = {"aesguide_pedestal.png"},
	visual_scale = 1.4,
	selection_box = {
		type = "fixed",
		fixed  = {-0.3, -0.5, -0.3, 0.3, 0.12, 0.3}
	},
	use_texture_alpha = "clip",
	groups = {oddly_breakable_by_hand=1},
	paramtype = "light",
	paramtype2 = "facedir",
	description = S("Rules"),

	on_place = place_facing_player,

  on_construct = function(pos)
    add_label_entity(pos, "serverguide:rules")
  end,

	on_destruct = function(pos)
		remove_label_entities(pos, "serverguide:rules")
	end,

	on_punch = function (pos, node, puncher)
		serverguide.show_rules(puncher:get_player_name())
	end,

	on_rightclick = function (pos, node, clicker)
		serverguide.show_rules(clicker:get_player_name())
	end
})



core.register_node("serverguide:pedestal_values", {
	drawtype = "mesh",
	mesh = "fbrawl_book_pedestal.obj",
	tiles = {"aesguide_pedestal.png"},
	visual_scale = 1.4,
	selection_box = {
		type = "fixed",
		fixed  = {-0.3, -0.5, -0.3, 0.3, 0.12, 0.3}
	},
	use_texture_alpha = "clip",
	groups = {oddly_breakable_by_hand=1},
	paramtype = "light",
	paramtype2 = "facedir",
	description = S("Biophilia values"),

	on_place = place_facing_player,

  on_construct = function(pos)
    add_label_entity(pos, "serverguide:values")
  end,

	on_destruct = function(pos)
		remove_label_entities(pos, "serverguide:values")
	end,

	on_punch = function (pos, node, puncher)
		serverguide.get_values_formspec(puncher:get_player_name())
	end,

	on_rightclick = function (pos, node, clicker)
		serverguide.get_values_formspec(clicker:get_player_name())
	end
})




-- entità
local rules_txt = {
  initial_properties = {
    visual = "upright_sprite",
    textures = {"blank.png"},
    physical = false,
	pointable = false,
    static_save = true,
    nametag = S("Rules"),
	nametag_scale_z = true,
	nametag_fontsize = 50
  },

	on_activate = function(self)
		remove_if_orphaned(self, "serverguide:pedestal_rules")
	end,
}


local values_txt = {
	initial_properties = {
	  visual = "upright_sprite",
	  textures = {"blank.png"},
	  physical = false,
	  pointable = false,
	  static_save = true,
	  nametag = S("Biophilia values"),
	  nametag_scale_z = true,
	  nametag_fontsize = 50
	},

	on_activate = function(self)
		remove_if_orphaned(self, "serverguide:pedestal_values")
	end,
  }



core.register_entity("serverguide:rules", rules_txt)
core.register_entity("serverguide:values", values_txt)
