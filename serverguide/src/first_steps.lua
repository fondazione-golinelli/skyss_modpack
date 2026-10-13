local S = minetest.get_translator("serverguide")

local FS = function(...) return core.formspec_escape(S(...)) end

local function get_formspec() end



function serverguide.get_firststeps_formspec(p_name)
  minetest.show_formspec(p_name, "serverguide:steps", get_formspec(p_name))
end




----------------------------------------------
---------------FUNZIONI LOCALI----------------
----------------------------------------------

function get_formspec(p_name)
  return serverguide.get_board_formspec(p_name, {
    title = FS("FIRST STEPS"),
    items = {
      FS("Use your free hand to hit an arena sign and enter a minigame (/quit to leave)"),
      FS("Use the compass to teleport and reach places more quickly"),
      FS("Complete many challenges and unlock content to make your adventure more magical!")
    },
    hint = "/tutorial",
    button = FS("LET'S GO!"),
    allow_close = false
  })
end






----------------------------------------------
---------------GESTIONE CAMPI-----------------
----------------------------------------------


core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "serverguide:steps" then return end

	if fields.quit and not fields.confirm then
    local p_name = player:get_player_name()
    core.show_formspec(p_name, "serverguide:steps", get_formspec(p_name))
    return
  end
end)