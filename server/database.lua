local Database = {}

local function GenerateUUID()
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function(c)
        local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format('%x', v)
    end)
end

local function NormalizeCoords(coords)
    return {
        x = tonumber(string.format("%.2f", coords.x)),
        y = tonumber(string.format("%.2f", coords.y)),
        z = tonumber(string.format("%.2f", coords.z))
    }
end

function Database.CreateChest(ownerCitizenId, coords, heading, model)
    local chestUUID = GenerateUUID()
    local normCoords = NormalizeCoords(coords)
    local result = MySQL.insert.await('INSERT INTO player_chests (chest_uuid, owner, coords, heading, model, shared_with) VALUES (?, ?, ?, ?, ?, ?)', { chestUUID, ownerCitizenId, json.encode(normCoords), heading or 0.0, model or Config.ChestProp, json.encode({}) })
    return result and chestUUID or nil
end

function Database.GetAllChests()
    local results = MySQL.query.await('SELECT * FROM player_chests')
    if not results then return {} end
    for i = 1, #results do
        results[i].coords = json.decode(results[i].coords)
        results[i].shared_with = (results[i].shared_with and json.decode(results[i].shared_with)) or {}
    end
    return results
end

function Database.ShareChest(chestUUID, sharedWithList)
    return MySQL.update.await('UPDATE player_chests SET shared_with = ?, updated_at = CURRENT_TIMESTAMP WHERE chest_uuid = ?', { json.encode(sharedWithList), chestUUID })
end

function Database.DeleteChest(chestUUID)
    return MySQL.query.await('DELETE FROM player_chests WHERE chest_uuid = ?', { chestUUID })
end

function Database.GetPlayerChestCount(citizenid)
    local result = MySQL.scalar.await('SELECT COUNT(chest_uuid) FROM player_chests WHERE owner = ?', { citizenid })
    return result or 0
end

-- [[ CORREÇÃO: Função GetChestsByOwner ajustada para evitar erro de tipo ]]
function Database.GetChestsByOwner(citizenid)
    local results = MySQL.query.await('SELECT coords FROM player_chests WHERE owner = ?', { citizenid })
    if not results then return {} end
    
    local coordsList = {}
    for _, data in ipairs(results) do
        -- Decodifica o JSON em um objeto especial
        local decodedCoords = json.decode(data.coords)
        -- Cria uma tabela Lua padrão a partir do objeto decodificado para garantir compatibilidade
        local plainTable = {
            x = decodedCoords.x,
            y = decodedCoords.y,
            z = decodedCoords.z
        }
        -- Insere a tabela padrão na lista
        table.insert(coordsList, plainTable)
    end
    return coordsList
end


return Database
