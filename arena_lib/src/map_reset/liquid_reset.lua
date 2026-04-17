local get_node = core.get_node
local hash_node_position = core.hash_node_position
local get_position_from_hash = core.get_position_from_hash
local remove_node = core.remove_node



function arena_lib.drain_source(pos, iteration)
    iteration = iteration or 1
    if iteration > 4 then
        return
    end

    local visited = {}
    local queue = {pos}
    local drained_count = 0
    local max_iterations = 100000         -- sicurezza contro loop infiniti
    local liquid_boundary_positions = {} -- posizioni dei liquidi ai margini per trovare i loro vicini d'aria

    while #queue > 0 and drained_count < max_iterations do
        local current_pos = table.remove(queue, 1)
        local hash_pos = hash_node_position(current_pos)

        -- evita di visitare la stessa posizione due volte
        if not visited[hash_pos] then
            visited[hash_pos] = true

            local node = get_node(current_pos)
            local nodedef = core.registered_nodes[node.name]

            -- se è un liquido, procedi con l'elaborazione
            if nodedef and nodedef.liquidtype and nodedef.liquidtype ~= "none" then
                -- rimuovi immediatamente il nodo liquido SENZA tracking
                remove_node(current_pos, false)
                drained_count = drained_count + 1

                -- controlla se questo liquido è al margine (ha almeno un vicino non-liquido)
                local neighbors = {
                    {x = current_pos.x + 1, y = current_pos.y,     z = current_pos.z},     -- east
                    {x = current_pos.x - 1, y = current_pos.y,     z = current_pos.z},     -- west
                    {x = current_pos.x,     y = current_pos.y,     z = current_pos.z + 1}, -- north
                    {x = current_pos.x,     y = current_pos.y,     z = current_pos.z - 1}, -- south
                    {x = current_pos.x,     y = current_pos.y - 1, z = current_pos.z},     -- sopra
                    {x = current_pos.x,     y = current_pos.y + 1, z = current_pos.z}      -- sotto
                }

                local is_boundary = false
                for _, neighbor_pos in ipairs(neighbors) do
                    local neighbor_hash = hash_node_position(neighbor_pos)
                    if not visited[neighbor_hash] then
                        table.insert(queue, neighbor_pos)

                        -- controlla se il vicino non è un liquido (rende questo nodo un bordo)
                        local neighbor_node = get_node(neighbor_pos)
                        local neighbor_nodedef = core.registered_nodes[neighbor_node.name]
                        if not neighbor_nodedef or not neighbor_nodedef.liquidtype or neighbor_nodedef.liquidtype == "none" then
                            is_boundary = true
                        end
                    end
                end

                -- memorizza solo i liquidi ai margini per controllare i loro vicini d'aria
                if is_boundary then
                    table.insert(liquid_boundary_positions, current_pos)
                end
            end
        end
    end

    -- controlla i vicini d'aria delle posizioni dei liquidi rimossi
    if #liquid_boundary_positions > 0 then
        local air_positions = {}

        -- per ogni liquido rimosso, controlla i suoi vicini d'aria
        for _, liquid_pos in ipairs(liquid_boundary_positions) do
            local neighbors = {
                {x = liquid_pos.x + 1, y = liquid_pos.y,     z = liquid_pos.z},
                {x = liquid_pos.x - 1, y = liquid_pos.y,     z = liquid_pos.z},
                {x = liquid_pos.x,     y = liquid_pos.y,     z = liquid_pos.z + 1},
                {x = liquid_pos.x,     y = liquid_pos.y,     z = liquid_pos.z - 1},
                {x = liquid_pos.x,     y = liquid_pos.y - 1, z = liquid_pos.z}
            }

            for _, neighbor_pos in ipairs(neighbors) do
                local neighbor_hash = hash_node_position(neighbor_pos)
                if not visited[neighbor_hash] then
                    local neighbor_node = get_node(neighbor_pos)
                    if neighbor_node.name == "air" then
                        table.insert(air_positions, neighbor_pos)
                    end
                end
            end
        end

        -- ricontrolla solo le posizioni d'aria dove potrebbero essere scorsi liquidi
        if #air_positions > 0 then
            core.after(1, function()
                for _, air_pos in ipairs(air_positions) do
                    arena_lib.drain_source(air_pos, iteration + 1)
                end
            end)
        end
    end
end
