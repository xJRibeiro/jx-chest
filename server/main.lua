local RSGCore = exports["rsg-core"]:GetCoreObject()

Database = require("server.database")
Cache = require("server.cache")

local playerCooldowns = {}

Global = {}
Admin = {}

--------------------------------------------------------------------------------
-- FUNÇÕES GLOBAIS E AUXILIARES
--------------------------------------------------------------------------------
local LOG_LEVEL_MAP = {["CRITICAL"] = 1, ["INFO"] = 2, ["DETAIL"] = 3}
function Global.Debug(level, message)
    local numericLevel
    if type(level) == "string" then
        numericLevel = LOG_LEVEL_MAP[level] or 99
    elseif type(level) == "number" then
        numericLevel = level
    else
        return
    end
    if Config.Debug and numericLevel <= Config.DebugLevel then
        print(string.format("[rsg_chest] [DEBUG-%s] %s", tostring(level), message))
    end
end

-- Função de Log agora suporta o webhook de admin
function Global.Log(level, title, message, color, isAdminAction)
    local numericLevel
    if type(level) == "string" then
        numericLevel = LOG_LEVEL_MAP[level] or 99
    elseif type(level) == "number" then
        numericLevel = level
    else
        return
    end
    if Config.Logging and numericLevel <= Config.LogLevel then
        local logMessage = string.format("[rsg_chest] [LOG-%s] %s: %s", tostring(level), title, message)
        print(logMessage)

        local webhookUrl =
            (isAdminAction and Config.LogAdminActionsToDiscord) and Config.DiscordWebhookAdmin or Config.DiscordWebhook
        if (isAdminAction and Config.LogAdminActionsToDiscord) or (not isAdminAction and Config.LogToDiscord) then
            if webhookUrl and webhookUrl:sub(1, 4) == "http" then
                PerformHttpRequest(
                    webhookUrl,
                    function()
                    end,
                    "POST",
                    json.encode(
                        {
                            embeds = {
                                {
                                    title = title,
                                    description = message,
                                    color = color or 15158332,
                                    footer = {text = "Log de Baú | " .. os.date("!%Y-%m-%d %H:%M:%S")}
                                }
                            }
                        }
                    ),
                    {["Content-Type"] = "application/json"}
                )
            end
        end
    end
end
function Global.Lang(key, ...)
    local str = Config.Lang[key] or key
    return select("#", ...) > 0 and string.format(str, ...) or str
end
local function Notify(src, pType, title, description)
    TriggerClientEvent("ox_lib:notify", src, {type = pType, title = title, description = description})
end

function GetPlayerIdentifier(playerSource)
    if not playerSource then
        return "Fonte Desconhecida"
    end
    local Player = RSGCore.Functions.GetPlayer(playerSource)
    if not Player then
        return string.format("Fonte Inválida (%s)", tostring(playerSource))
    end
    local pData = Player.PlayerData
    local charinfo = pData.charinfo
    local name = "Nome Desconhecido"
    if charinfo and charinfo.firstname then
        name = string.format("%s %s", charinfo.firstname, charinfo.lastname or "")
    end
    local serverId = tostring(playerSource)
    return string.format("%s (%s)", name, serverId)
end

local function HasPermission(chestUUID, citizenid)
    local chest = Cache.GetChest(chestUUID)
    if not chest then
        return false
    end
    if chest.owner == citizenid then
        return true
    end
    if chest.shared_with then
        for _, sharedId in ipairs(chest.shared_with) do
            if sharedId == citizenid then
                return true
            end
        end
    end
    return false
end
local function IsOnCooldown(src)
    if playerCooldowns[src] and (GetGameTimer() - playerCooldowns[src] < Config.ActionCooldown) then
        Notify(src, "error", Global.Lang("error_title"), Global.Lang("action_cooldown"))
        return true
    end
    playerCooldowns[src] = GetGameTimer()
    return false
end

--------------------------------------------------------------------------------
-- EVENTOS DE JOGADOR
--------------------------------------------------------------------------------
RSGCore.Functions.CreateUseableItem(
    Config.ChestItem,
    function(source, item)
        TriggerClientEvent("rsg_chest:client:startPlacement", source)
    end
)
RegisterNetEvent(
    "rsg_chest:server:getActiveChests",
    function()
        local src = source
        local activeChests = {}
        for uuid, chest in pairs(Cache.GetAllChests()) do
            table.insert(activeChests, {uuid = uuid, coords = chest.coords})
        end
        TriggerClientEvent("rsg_chest:client:receiveActiveChests", src, activeChests)
    end
)

RegisterNetEvent(
    "rsg_chest:server:placeChest",
    function(coords, heading)
        local src = source
        local Player = RSGCore.Functions.GetPlayer(src)
        if not Player or IsOnCooldown(src) then
            return
        end

        -- [[ NOVO: Verificação de limite de baús por jogador ]]
        if Config.MaxChestsPerPlayer > 0 then
            local chestCount = Database.GetPlayerChestCount(Player.PlayerData.citizenid)
            if chestCount >= Config.MaxChestsPerPlayer then
                Notify(src, "error", Global.Lang("error_title"), Global.Lang("max_chests_reached"))
                return
            end
        end

        if not exports["rsg-inventory"]:RemoveItem(src, Config.ChestItem, 1) then
            Notify(src, "error", Global.Lang("error_title"), "Você não possui o item para criar um baú.")
            return
        end
        local chestUUID = Database.CreateChest(Player.PlayerData.citizenid, coords, heading, Config.ChestProp)
        if chestUUID then
            local ownerName = Player.PlayerData.name or Cache.GetPlayerName(Player.PlayerData.citizenid)
            local newLabel = string.format("Baú de %s (%s)", ownerName, string.sub(chestUUID, 1, 8))
            exports["rsg-inventory"]:CreateInventory(
                "chest_" .. chestUUID,
                {label = newLabel, maxweight = Config.ChestWeight, slots = Config.ChestSlots}
            )
            local chestData = {
                chest_uuid = chestUUID,
                owner = Player.PlayerData.citizenid,
                coords = coords,
                heading = heading,
                model = Config.ChestProp,
                shared_with = {}
            }
            Cache.SetChest(chestUUID, chestData)
            TriggerClientEvent("rsg_chest:client:createProp", -1, chestUUID, chestData)
            Notify(src, "success", Global.Lang("success_title"), Global.Lang("chest_placed"))
            Global.Log(
                "CRITICAL",
                "Baú Criado",
                string.format(
                    "Jogador: `%s`\nUUID: `%s`\nLocal: `%.1f, %.1f, %.1f`",
                    GetPlayerIdentifier(src),
                    chestUUID,
                    coords.x,
                    coords.y,
                    coords.z
                ),
                65280
            )
        else
            Notify(src, "error", Global.Lang("error_title"), "Não foi possível criar o baú no banco de dados.")
            exports["rsg-inventory"]:AddItem(src, Config.ChestItem, 1)
        end
    end
)

RegisterNetEvent(
    "rsg_chest:server:requestToRemoveChest",
    function(chestUUID)
        local src = source
        local Player = RSGCore.Functions.GetPlayer(src)
        if not Player or IsOnCooldown(src) then
            return
        end
        local chest = Cache.GetChest(chestUUID)
        if not chest or chest.owner ~= Player.PlayerData.citizenid then
            Notify(src, "error", Global.Lang("error_title"), Global.Lang("no_permission"))
            return
        end
        local inventoryId = "chest_" .. chestUUID
        local inventory = exports["rsg-inventory"]:GetInventory(inventoryId)
        if inventory and inventory.items and next(inventory.items) then
            Notify(src, "error", Global.Lang("error_title"), Global.Lang("chest_not_empty"))
            return
        end
        TriggerClientEvent("rsg_chest:client:proceedWithRemoval", src, chestUUID)
    end
)
RegisterNetEvent(
    "rsg_chest:server:removeChest",
    function(chestUUID)
        local src = source
        local Player = RSGCore.Functions.GetPlayer(src)
        if not Player then
            return
        end
        local chest = Cache.GetChest(chestUUID)
        if not chest or chest.owner ~= Player.PlayerData.citizenid then
            Notify(src, "error", Global.Lang("error_title"), Global.Lang("no_permission"))
            return
        end
        exports["rsg-inventory"]:DeleteInventory("chest_" .. chestUUID)
        Database.DeleteChest(chestUUID)
        Cache.RemoveChest(chestUUID)
        TriggerClientEvent("rsg_chest:client:removeProp", -1, chestUUID)
        Notify(src, "success", Global.Lang("success_title"), Global.Lang("chest_removed"))
        Global.Log(
            "CRITICAL",
            "Baú Removido",
            string.format("Jogador: `%s`\nUUID: `%s`", GetPlayerIdentifier(src), chestUUID),
            16711680
        )
    end
)
RegisterNetEvent(
    "rsg_chest:server:openChest",
    function(chestUUID)
        local src = source
        local Player = RSGCore.Functions.GetPlayer(src)
        if not Player or IsOnCooldown(src) then
            return
        end
        if not HasPermission(chestUUID, Player.PlayerData.citizenid) then
            Notify(src, "error", Global.Lang("error_title"), Global.Lang("no_permission"))
            return
        end
        local userSrc = Cache.GetChestUser(chestUUID)
        if userSrc and userSrc ~= src then
            local currentUserIdentifier = GetPlayerIdentifier(userSrc)
            local errorMessage = string.format(Global.Lang("chest_in_use"), currentUserIdentifier)
            Notify(src, "error", Global.Lang("error_title"), errorMessage)
            return
        end
        local chest = Cache.GetChest(chestUUID)
        local ownerName = Cache.GetPlayerName(chest.owner)
        local newLabel = string.format("Baú de %s (%s)", ownerName, string.sub(chestUUID, 1, 8))
        local inventoryId = "chest_" .. chestUUID
        Cache.SetChestInUse(chestUUID, src)
        TriggerClientEvent("rsg_chest:client:updateChestStatus", -1, chestUUID, true, Player.PlayerData.name)
        Global.Debug("INFO", string.format("%s abriu o baú %s.", GetPlayerIdentifier(src), chestUUID))
        exports["rsg-inventory"]:OpenInventory(
            src,
            inventoryId,
            {label = newLabel, maxweight = Config.ChestWeight, slots = Config.ChestSlots}
        )

    end
)
RegisterNetEvent(
    "rsg_chest:server:shareChest",
    function(chestUUID, targetServerId)
        local src = source
        local Player = RSGCore.Functions.GetPlayer(src)
        local TargetPlayer = RSGCore.Functions.GetPlayer(tonumber(targetServerId))
        if not Player or not TargetPlayer or IsOnCooldown(src) then
            Notify(src, "error", Global.Lang("error_title"), Global.Lang("player_not_found"))
            return
        end
        local chest = Cache.GetChest(chestUUID)
        if not chest or chest.owner ~= Player.PlayerData.citizenid then
            Notify(src, "error", Global.Lang("error_title"), Global.Lang("no_permission"))
            return
        end
        if Player.PlayerData.citizenid == TargetPlayer.PlayerData.citizenid then
            Notify(src, "error", Global.Lang("error_title"), Global.Lang("cannot_share_with_self"))
            return
        end
        local sharedList = chest.shared_with or {}
        if #sharedList >= Config.MaxSharedPlayers then
            Notify(src, "error", Global.Lang("error_title"), Global.Lang("share_limit_reached"))
            return
        end
        for _, sharedId in ipairs(sharedList) do
            if sharedId == TargetPlayer.PlayerData.citizenid then
                Notify(src, "error", Global.Lang("error_title"), Global.Lang("already_shared"))
                return
            end
        end
        table.insert(sharedList, TargetPlayer.PlayerData.citizenid)
        chest.shared_with = sharedList
        Cache.SetChest(chestUUID, chest)
        Database.ShareChest(chestUUID, sharedList)
        Notify(src, "success", Global.Lang("success_title"), Global.Lang("chest_shared", TargetPlayer.PlayerData.name))
        Global.Log(
            "INFO",
            "Baú Compartilhado",
            string.format(
                "Dono: `%s`\nCompartilhou com: `%s`\nUUID: `%s`",
                GetPlayerIdentifier(src),
                GetPlayerIdentifier(TargetPlayer.PlayerData.source),
                chestUUID
            )
        )
    end
)
RegisterNetEvent(
    "rsg_chest:server:chestClosed",
    function(chestUUID)
        local src = source
        if Cache.GetChestUser(chestUUID) == src then
            Cache.SetChestAvailable(chestUUID)
            TriggerClientEvent("rsg_chest:client:updateChestStatus", -1, chestUUID, false)
            Global.Debug("INFO", string.format("%s fechou o baú %s.", GetPlayerIdentifier(src), chestUUID))
        end
    end
)

RegisterNetEvent(
    "rsg-inventory:server:add_item",
    function(source, inventoryId, item, amount)
        if type(inventoryId) == "string" and string.sub(inventoryId, 1, 6) == "chest_" then
            local chestUUID = string.gsub(inventoryId, "chest_", "")
            local playerIdentifier = GetPlayerIdentifier(source)
            local message =
                string.format(
                "**Jogador**: `%s`\n**Ação**: `ADICIONOU`\n**Item**: `%s`\n**Quantidade**: `%d`\n**Baú UUID**: `%s`",
                playerIdentifier,
                item.label or item.name,
                amount,
                chestUUID
            )
            Global.Log("INFO", "Movimentação de Item em Baú", message, 3447003)
        end
    end
)
RegisterNetEvent(
    "rsg-inventory:server:remove_item",
    function(source, inventoryId, item, amount)
        if type(inventoryId) == "string" and string.sub(inventoryId, 1, 6) == "chest_" then
            local chestUUID = string.gsub(inventoryId, "chest_", "")
            local playerIdentifier = GetPlayerIdentifier(source)
            local message =
                string.format(
                "**Jogador**: `%s`\n**Ação**: `REMOVEU`\n**Item**: `%s`\n**Quantidade**: `%d`\n**Baú UUID**: `%s`",
                playerIdentifier,
                item.label or item.name,
                amount,
                chestUUID
            )
            Global.Log("INFO", "Movimentação de Item em Baú", message, 15105570)
        end
    end
)

-- [[ NOVOS EVENTOS PARA GESTÃO DE COMPARTILHAMENTO ]]
RegisterNetEvent(
    "rsg_chest:server:getSharedPlayers",
    function(chestUUID)
        local src = source
        local chest = Cache.GetChest(chestUUID)
        if not chest or chest.owner ~= RSGCore.Functions.GetPlayer(src).PlayerData.citizenid then
            return
        end

        local sharedPlayers = {}
        if chest.shared_with and next(chest.shared_with) then
            for _, citizenid in ipairs(chest.shared_with) do
                table.insert(
                    sharedPlayers,
                    {
                        citizenid = citizenid,
                        name = Cache.GetPlayerName(citizenid)
                    }
                )
            end
        end
        TriggerClientEvent("rsg_chest:client:showSharedPlayersMenu", src, chestUUID, sharedPlayers)
    end
)

RegisterNetEvent(
    "rsg_chest:server:revokeChestAccess",
    function(chestUUID, targetCitizenId)
        local src = source
        local Player = RSGCore.Functions.GetPlayer(src)
        if not Player then
            return
        end

        local chest = Cache.GetChest(chestUUID)
        if not chest or chest.owner ~= Player.PlayerData.citizenid then
            return
        end

        local targetName
        local sharedList = chest.shared_with or {}
        for i = #sharedList, 1, -1 do
            if sharedList[i] == targetCitizenId then
                targetName = Cache.GetPlayerName(sharedList[i])
                table.remove(sharedList, i)
            end
        end

        chest.shared_with = sharedList
        Cache.SetChest(chestUUID, chest)
        Database.ShareChest(chestUUID, sharedList)
        Notify(
            src,
            "success",
            "Acesso Revogado",
            string.format(Global.Lang("access_revoked"), targetName or targetCitizenId)
        )
    end
)

AddEventHandler(
    "onResourceStart",
    function(resourceName)
        if GetCurrentResourceName() == resourceName then
            print("[BAU DIAGNÓSTICO] onResourceStart chamado.")
            Cache.Initialize()
            print("[BAU DIAGNÓSTICO] Cache inicializado. Verificando/Criando inventários do rsg-inventory...")
            local allChests = Cache.GetAllChests()
            for uuid, chestData in pairs(allChests) do
                local ownerName = Cache.GetPlayerName(chestData.owner)
                local newLabel = string.format("Baú de %s (%s)", ownerName, string.sub(uuid, 1, 8))
                exports["rsg-inventory"]:CreateInventory(
                    "chest_" .. uuid,
                    {label = newLabel, maxweight = Config.ChestWeight, slots = Config.ChestSlots}
                )
            end
            print("[BAU DIAGNÓSTICO] Verificação de inventários concluída.")
            print("[BAU DIAGNÓSTICO] Aguardando para transmitir props aos clientes...")
            Wait(1500)
            local chests = Cache.GetAllChests()
            if next(chests) then
                TriggerClientEvent("rsg_chest:client:updateProps", -1, chests)
                print("[BAU DIAGNÓSTICO] Transmissão inicial de props enviada para todos os clientes.")
            else
                print("[BAU DIAGNÓSTICO] Nenhum baú no cache para transmitir.")
            end
            print("[BAU DIAGNÓSTICO] Inicializando módulo Admin...")
            Admin.Initialize()
        end
    end
)
AddEventHandler(
    "playerDropped",
    function(reason)
        local src = source
        Cache.ClearUserFromChests(src)
    end
)
RegisterNetEvent(
    "rsg_chest:server:requestAllProps",
    function()
        local src = source
        TriggerClientEvent("rsg_chest:client:updateProps", src, Cache.GetAllChests())
    end
)
print("[BAU DIAGNÓSTICO] server/main.lua carregado com sucesso.")

-- [[ NOVO: Comando /meusbaus ]]
RSGCore.Commands.Add(
    "meusbaus",
    Global.Lang("mychests_command_desc"),
    {},
    false,
    function(source)
        print("[BAU DIAGNÓSTICO] Comando /meusbaus chamado por: " .. GetPlayerIdentifier(source))
        local Player = RSGCore.Functions.GetPlayer(source)
        if not Player then
            return
        end

        local chestCoords = Database.GetChestsByOwner(Player.PlayerData.citizenid)
        if #chestCoords > 0 then
            TriggerClientEvent("rsg_chest:client:showBlips", source, chestCoords)
            Notify(source, "success", "Baús Localizados", Global.Lang("mychests_blips_created"))
        else
            Notify(source, "info", "Aviso", Global.Lang("mychests_no_chests"))
        end
    end,
    "all"
)
