local ping = {}
local MAX_SLOTS = hub.settings.plist_max_slots



local function update_ping()
  local players = core.get_connected_players()
  for i = 1, math.min(#players, MAX_SLOTS) do
    local pl_name = players[i]:get_player_name()
    local rtt_ms = (core.get_player_information(pl_name).avg_rtt or 0) * 1000

    if rtt_ms <= 80 then
      ping[pl_name] = 4
    elseif rtt_ms <= 160 then
      ping[pl_name] = 3
    elseif rtt_ms <= 250 then
      ping[pl_name] = 2
    else
      ping[pl_name] = 1
    end
  end
  playerlist.HUD_update("ping")

  core.after(10, function() update_ping() end)
end

core.after(0.1, function()
  update_ping()
end)

function playerlist.get_ping(p_name)
  return ping[p_name]
end
