print('[BAU DIAGNÓSTICO] Carregando server/cache.lua...')
local Cache = {}

local chestCache = {}
local playerNameCache = {}
local chestUsers = {}

function Cache.Initialize()
    local allChests = Database.GetAllChests()
    for _, chestData in ipairs(allChests) do
        chestCache[chestData.chest_uuid] = chestData
    end
    print(string.format('[rsg_chest] Cache inicializado com %d baús.', #allChests))
end

function Cache.GetAllChests() return chestCache end
function Cache.GetChest(chestUUID) return chestCache[chestUUID] end
function Cache.SetChest(chestUUID, chestData) chestCache[chestUUID] = chestData end
function Cache.RemoveChest(chestUUID) chestCache[chestUUID] = nil end

function Cache.GetPlayerName(citizenid)
    if not citizenid then return Config.Lang['unknown_player'] end
    if playerNameCache[citizenid] then return playerNameCache[citizenid] end
    local result = MySQL.single.await('SELECT charinfo FROM players WHERE citizenid = ?', { citizenid })
    if result and result.charinfo then
        local success, charinfo = pcall(json.decode, result.charinfo)
        if success and charinfo and charinfo.firstname then
            local fullName = string.format('%s %s', charinfo.firstname, charinfo.lastname or ''); playerNameCache[citizenid] = fullName; return fullName
        end
    end
    playerNameCache[citizenid] = Config.Lang['unknown_player']; return playerNameCache[citizenid]
end

function Cache.SetChestInUse(chestUUID, source) chestUsers[chestUUID] = source end
function Cache.SetChestAvailable(chestUUID) chestUsers[chestUUID] = nil end
function Cache.GetChestUser(chestUUID) return chestUsers[chestUUID] end
function Cache.GetChestUsers() return chestUsers end
function Cache.ClearUserFromChests(source) for uuid, src in pairs(chestUsers) do if src == source then chestUsers[uuid] = nil; print(string.format('[rsg_chest] Baú %s liberado devido à desconexão do jogador %s.', uuid, source)) end end end

print('[BAU DIAGNÓSTICO] server/cache.lua carregado com sucesso.')
return Cache