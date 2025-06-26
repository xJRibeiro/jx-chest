local RSGCore = exports["rsg-core"]:GetCoreObject()

Database = require("server.database")
Cache = require("server.cache")

local playerCooldowns = {}

Global = {}
Admin = {}

--------------------------------------------------------------------------------
-- FUNÇÕES GLOBAIS E AUXILIARES | GLOBAL AND AUXILIARY FUNCTIONS
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

function Global.Log(level, titleKey, message, color, isAdminAction)
    local numericLevel
    if type(level) == "string" then
        numericLevel = LOG_LEVEL_MAP[level] or 99
    elseif type(level) == "number" then
        numericLevel = level
    else
        return
    end
    if Config.Logging and numericLevel <= Config.LogLevel then
        local translatedTitle = _L(titleKey)
        local logMessage = string.format("[rsg_chest] [LOG-%s] %s: %s", tostring(level), translatedTitle, message)
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
                                    title = translatedTitle,
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

-- A função Global.Lang é substituída pela função global _L() que vem de shared/main_locale.lua
-- Apenas a mantemos aqui por segurança, caso algum script antigo a chame.
-- Function Global.Lang is replaced by the global function _L() which comes from shared/main_locale.lua
-- We keep it here for safety, in case some old script calls it.

function Global.Lang(key, ...)
    return _L(key, ...)
end

local function Notify(src, pType, titleKey, descriptionKey, ...)
    TriggerClientEvent("ox_lib:notify", src, {type = pType, title = _L(titleKey), description = _L(descriptionKey, ...)})
end

function GetPlayerIdentifier(playerSource)
    if not playerSource then
        return _L('admin_unknown_player')
    end
    local Player = RSGCore.Functions.GetPlayer(playerSource)
    if not Player then
        return string.format("%s (%s)", _L('admin_unknown_player'), tostring(playerSource))
    end
    local pData = Player.PlayerData
    local charinfo = pData.charinfo
    local name = _L('admin_unknown_player')
    if charinfo and charinfo.firstname then
        name = string.format("%s %s", charinfo.firstname, charinfo.lastname or "")
    end
    local serverId = tostring(playerSource)
    return string.format("%s (ID: %s)", name, serverId)
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
        for _, sharedData in ipairs(chest.shared_with) do
            if sharedData.citizenid == citizenid then
                return true
            end
        end
    end
    return false
end

local function IsOnCooldown(src)
    if playerCooldowns[src] and (GetGameTimer() - playerCooldowns[src] < Config.ActionCooldown) then
        Notify(src, "error", "error_title", "action_cooldown")
        return true
    end
    playerCooldowns[src] = GetGameTimer()
    return false
end

--------------------------------------------------------------------------------
-- EVENTOS DE JOGADOR | PLAYER EVENTS
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

        if Config.MaxChestsPerPlayer > 0 then
            local chestCount = Database.GetPlayerChestCount(Player.PlayerData.citizenid)
            if chestCount >= Config.MaxChestsPerPlayer then
                Notify(src, "error", "error_title", "max_chests_reached")
                return
            end
        end

        if not exports["rsg-inventory"]:RemoveItem(src, Config.ChestItem, 1) then
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
            Notify(src, "success", "success_title", "chest_placed")
            Global.Log(
                "CRITICAL",
                "log_chest_placed_title",
                _L('log_chest_placed', GetPlayerIdentifier(src), Player.PlayerData.source, Player.PlayerData.citizenid, chestUUID),
                65280
            )
        else
            Notify(src, "error", "error_title", "generic_error") -- Adicionar 'generic_error' aos locales
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
            Notify(src, "error", "error_title", "no_permission")
            return
        end
        local inventoryId = "chest_" .. chestUUID
        local inventory = exports["rsg-inventory"]:GetInventory(inventoryId)
        if inventory and inventory.items and next(inventory.items) then
            Notify(src, "error", "error_title", "chest_not_empty")
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
            Notify(src, "error", "error_title", "no_permission")
            return
        end
        exports["rsg-inventory"]:DeleteInventory("chest_" .. chestUUID)
        Database.DeleteChest(chestUUID)
        Cache.RemoveChest(chestUUID)
        TriggerClientEvent("rsg_chest:client:removeProp", -1, chestUUID)
        Notify(src, "success", "success_title", "chest_removed")
        Global.Log(
            "CRITICAL",
            "log_chest_removed_title",
             _L('log_chest_removed', GetPlayerIdentifier(src), Player.PlayerData.source, Player.PlayerData.citizenid, chestUUID),
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
            Notify(src, "error", "error_title", "no_permission")
            return
        end
        local userSrc = Cache.GetChestUser(chestUUID)
        if userSrc and userSrc ~= src then
            local currentUserIdentifier = GetPlayerIdentifier(userSrc)
            Notify(src, "error", "error_title", "chest_in_use", currentUserIdentifier)
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
            Notify(src, "error", "error_title", "player_not_found")
            return
        end
        local chest = Cache.GetChest(chestUUID)
        if not chest or chest.owner ~= Player.PlayerData.citizenid then
            Notify(src, "error", "error_title", "no_permission")
            return
        end
        if Player.PlayerData.citizenid == TargetPlayer.PlayerData.citizenid then
            Notify(src, "error", "error_title", "cannot_share_with_self")
            return
        end
        local sharedList = chest.shared_with or {}
        if Config.MaxSharedPlayers > 0 and #sharedList >= Config.MaxSharedPlayers then
            Notify(src, "error", "error_title", "share_limit_reached")
            return
        end
        for _, sharedData in ipairs(sharedList) do
            if sharedData.citizenid == TargetPlayer.PlayerData.citizenid then
                Notify(src, "error", "error_title", "already_shared")
                return
            end
        end
        table.insert(sharedList, {
            citizenid = TargetPlayer.PlayerData.citizenid,
            name = TargetPlayer.PlayerData.charinfo.firstname .. " " .. TargetPlayer.PlayerData.charinfo.lastname
        })
        chest.shared_with = sharedList
        Cache.SetChest(chestUUID, chest)
        Database.ShareChest(chestUUID, sharedList)
        Notify(src, "success", "success_title", "chest_shared", TargetPlayer.PlayerData.name)
        Global.Log(
            "INFO",
            "log_chest_shared_title",
            _L('log_chest_shared', GetPlayerIdentifier(src), src, chestUUID, GetPlayerIdentifier(targetServerId), targetServerId),
            3447003
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

-- Hooks de Inventário | Inventory Hooks
RegisterNetEvent(
    "rsg-inventory:server:add_item",
    function(source, inventoryId, item, amount)
        if type(inventoryId) == "string" and string.sub(inventoryId, 1, 6) == "chest_" then
            local chestUUID = string.gsub(inventoryId, "chest_", "")
            Global.Log("DETAIL", "log_item_add_title", _L('log_item_add', GetPlayerIdentifier(source), item.label or item.name, amount, chestUUID), 3447003)
        end
    end
)
RegisterNetEvent(
    "rsg-inventory:server:remove_item",
    function(source, inventoryId, item, amount)
        if type(inventoryId) == "string" and string.sub(inventoryId, 1, 6) == "chest_" then
            local chestUUID = string.gsub(inventoryId, "chest_", "")
             Global.Log("DETAIL", "log_item_remove_title", _L('log_item_remove', GetPlayerIdentifier(source), item.label or item.name, amount, chestUUID), 15105570)
        end
    end
)

-- Gestão de Compartilhamento | Sharing Management
RegisterNetEvent(
    "rsg_chest:server:getSharedPlayers",
    function(chestUUID)
        local src = source
        local chest = Cache.GetChest(chestUUID)
        if not chest or chest.owner ~= RSGCore.Functions.GetPlayer(src).PlayerData.citizenid then
            return
        end
        TriggerClientEvent("rsg_chest:client:showSharedPlayersMenu", src, chestUUID, chest.shared_with or {})
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
        local sharedList = chest.shared_with or {}
        local targetName
        for i = #sharedList, 1, -1 do
            if sharedList[i].citizenid == targetCitizenId then
                targetName = sharedList[i].name
                table.remove(sharedList, i)
                break
            end
        end
        if targetName then
            chest.shared_with = sharedList
            Cache.SetChest(chestUUID, chest)
            Database.ShareChest(chestUUID, sharedList)
            Notify(src, "success", "access_revoked_title", "access_revoked", targetName)
            Global.Log(
                "INFO",
                "log_access_revoked_title",
                _L('log_access_revoked', GetPlayerIdentifier(src), src, targetName, targetCitizenId, chestUUID),
                16744192
            )
        end
    end
)

AddEventHandler(
    "onResourceStart",
    function(resourceName)
        if GetCurrentResourceName() == resourceName then
            print(_L('diag_loading_file', 'onResourceStart'))
            Cache.Initialize()
            Global.Debug("DETAIL", "Cache inicializado. Verificando/Criando inventários...")
            local allChests = Cache.GetAllChests()
            for uuid, chestData in pairs(allChests) do
                local ownerName = Cache.GetPlayerName(chestData.owner)
                local newLabel = string.format("Baú de %s (%s)", ownerName, string.sub(uuid, 1, 8))
                exports["rsg-inventory"]:CreateInventory(
                    "chest_" .. uuid,
                    {label = newLabel, maxweight = Config.ChestWeight, slots = Config.ChestSlots}
                )
            end
            Global.Debug("DETAIL", "Verificação de inventários concluída.")
            Wait(1500)
            local chests = Cache.GetAllChests()
            if next(chests) then
                TriggerClientEvent("rsg_chest:client:updateProps", -1, chests)
                Global.Debug("DETAIL", "Transmissão inicial de props enviada.")
            else
                Global.Debug("DETAIL", "Nenhum baú no cache para transmitir.")
            end
            Admin.Initialize()
            print(_L('diag_loaded_file', 'onResourceStart'))
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

-- Comando para ver os baús do jogador | Command to see player's chests
RSGCore.Commands.Add(
    Config.CommandMyChests,
    _L("mychests_command_desc"),
    {},
    false,
    function(source)
        Global.Debug("DETAIL", "Comando /meusbaus chamado por: " .. GetPlayerIdentifier(source))
        local Player = RSGCore.Functions.GetPlayer(source)
        if not Player then
            return
        end

        local chestCoords = Database.GetChestsByOwner(Player.PlayerData.citizenid)
        if #chestCoords > 0 then
            TriggerClientEvent("rsg_chest:client:showBlips", source, chestCoords)
            Notify(source, "success", "info_title", "mychests_blips_created")
        else
            Notify(source, "info", "info_title", "mychests_no_chests")
        end
    end,
    "all"
)

print(_L('diag_loaded_file', 'server/main.lua'))