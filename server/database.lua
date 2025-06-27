-- server/database.lua
JX.DB = {}

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

function JX.DB.CreateChest(ownerCitizenId, coords, heading, model)
    local chestUUID = GenerateUUID()
    local normCoords = NormalizeCoords(coords)
    local result = MySQL.insert.await('INSERT INTO player_chests (chest_uuid, owner, coords, heading, model, shared_with) VALUES (?, ?, ?, ?, ?, ?)', { chestUUID, ownerCitizenId, json.encode(normCoords), heading or 0.0, model or Config.ChestProp, json.encode({}) })
    return result and chestUUID or nil
end

function JX.DB.GetAllChests()
    local results = MySQL.query.await('SELECT * FROM player_chests')
    if not results then return {} end
    for i = 1, #results do
        results[i].coords = json.decode(results[i].coords)
        results[i].shared_with = (results[i].shared_with and json.decode(results[i].shared_with)) or {}
    end
    return results
end

function JX.DB.ShareChest(chestUUID, sharedWithList)
    return MySQL.update.await('UPDATE player_chests SET shared_with = ?, last_updated = CURRENT_TIMESTAMP WHERE chest_uuid = ?', { json.encode(sharedWithList), chestUUID })
end

function JX.DB.DeleteChest(chestUUID)
    return MySQL.query.await('DELETE FROM player_chests WHERE chest_uuid = ?', { chestUUID })
end

function JX.DB.GetPlayerChestCount(citizenid)
    local result = MySQL.scalar.await('SELECT COUNT(chest_uuid) FROM player_chests WHERE owner = ?', { citizenid })
    return result or 0
end

function JX.DB.GetChestsByOwner(citizenid)
    local results = MySQL.query.await('SELECT coords FROM player_chests WHERE owner = ?', { citizenid })
    if not results then return {} end
    
    local coordsList = {}
    for _, data in ipairs(results) do
        local decodedCoords = json.decode(data.coords)
        local plainTable = { x = decodedCoords.x, y = decodedCoords.y, z = decodedCoords.z }
        table.insert(coordsList, plainTable)
    end
    return coordsList
end
