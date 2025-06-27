-- server/main.lua
print(_L("diag_loading_file", "server/main.lua"))

local RSGCore = exports["rsg-core"]:GetCoreObject()
assert(RSGCore, "rsg-core not found, rsg-chest script cannot start.")


-- Evento para o cliente solicitar a abertura de um baú
-- Event for the client to request opening a chest
RegisterNetEvent(
    "rsg_chest:server:openChest",
    function(chestUUID)
        local src = source
        local Player = RSGCore.Functions.GetPlayer(src)
        if not Player then
            return
        end

        local chestData = JX.Cache.GetChest(chestUUID)
        if not chestData then
            return Global.Notify(src, _L("chest_not_found"), "error")
        end

        local hasPermission = (Player.PlayerData.citizenid == chestData.owner)
        if not hasPermission then
            for _, sharedPlayer in ipairs(chestData.shared_with) do
                if sharedPlayer.citizenid == Player.PlayerData.citizenid then
                    hasPermission = true
                    break
                end
            end
        end

        if not hasPermission then
            return Global.Notify(src, _L("no_permission"), "error")
        end

        local user = JX.Cache.GetChestUser(chestUUID)
        if user and user ~= src then
            local userInChest = RSGCore.Functions.GetPlayer(user)
            local name = userInChest and userInChest.PlayerData.character.firstname or _L("text_other_player")
            return Global.Notify(src, _L("chest_in_use_by", name), "error")
        end

        JX.Cache.SetChestInUse(chestUUID, src)
        TriggerClientEvent(
            "rsg_chest:client:updateChestStatus",
            -1,
            chestUUID,
            true,
            Player.PlayerData.character.firstname
        )
        exports["rsg-inventory"]:OpenInventory(
            "chest",
            chestUUID,
            {
                slots = chestData.slots or Config.ChestSlots,
                weight = chestData.maxWeight or Config.ChestWeight
            }
        )
        Global.Log(
            "DETAIL",
            string.format(_L("log_player_opened_chest"), Player.PlayerData.character.firstname, src, chestUUID)
        )
    end
)

-- Evento para quando um baú é fechado
-- Event for when a chest is closed
RegisterNetEvent(
    "rsg_chest:server:chestClosed",
    function(chestUUID)
        local src = source
        local Player = RSGCore.Functions.GetPlayer(src)
        if not Player then
            return
        end
        if JX.Cache.GetChestUser(chestUUID) == src then
            JX.Cache.SetChestAvailable(chestUUID)
            TriggerClientEvent("rsg_chest:client:updateChestStatus", -1, chestUUID, false, nil)
            Global.Log(
                "DETAIL",
                string.format(_L("log_player_closed_chest"), Player.PlayerData.character.firstname, src, chestUUID)
            )
        end
    end
)

-- Evento para colocar um novo baú no mundo
-- Event to place a new chest in the world
RegisterNetEvent(
    "rsg_chest:server:placeChest",
    function(coords, heading)
        local src = source
        local Player = RSGCore.Functions.GetPlayer(src)
        if not Player then
            return
        end

        if Config.MaxChestsPerPlayer > 0 then
            local chestCount = JX.DB.GetPlayerChestCount(Player.PlayerData.citizenid)
            if chestCount >= Config.MaxChestsPerPlayer then
                return Global.Notify(src, _L("max_chests_reached"), "error")
            end
        end

        local chestUUID = JX.DB.CreateChest(Player.PlayerData.citizenid, coords, heading, Config.ChestProp)
        if chestUUID then
            local chestData = {
                chest_uuid = chestUUID,
                owner = Player.PlayerData.citizenid,
                coords = coords,
                heading = heading,
                model = Config.ChestProp,
                shared_with = {},
                slots = Config.ChestSlots,
                maxWeight = Config.ChestWeight
            }
            JX.Cache.SetChest(chestUUID, chestData)
            Global.Notify(src, _L("chest_placed"), "success")
            Global.LogToDiscord(
                "log_chest_placed_title",
                string.format(
                    _L("log_chest_placed"),
                    Player.PlayerData.character.firstname,
                    src,
                    Player.PlayerData.citizenid,
                    chestUUID
                ),
                "success"
            )
        else
            Global.Notify(src, _L("generic_error"), "error")
        end
    end
)

-- Evento para solicitar a remoção de um baú
-- Event to request the removal of a chest
RegisterNetEvent(
    "rsg_chest:server:requestToRemoveChest",
    function(chestUUID)
        local src = source
        local Player = RSGCore.Functions.GetPlayer(src)
        if not Player then
            return
        end
        local chestData = JX.Cache.GetChest(chestUUID)
        if not chestData or chestData.owner ~= Player.PlayerData.citizenid then
            return Global.Notify(src, _L("no_permission"), "error")
        end
        local inv = exports["rsg-inventory"]:GetInventory(chestUUID)
        if inv and #inv.items > 0 then
            return Global.Notify(src, _L("chest_not_empty"), "error")
        end
        TriggerClientEvent("rsg_chest:client:proceedWithRemoval", src, chestUUID)
    end
)

-- Evento que finaliza a remoção do baú
-- Event that finalizes the removal of the chest
RegisterNetEvent(
    "rsg_chest:server:removeChest",
    function(chestUUID)
        local src = source
        local Player = RSGCore.Functions.GetPlayer(src)
        if not Player then
            return
        end
        local chestData = JX.Cache.GetChest(chestUUID)
        if not chestData or chestData.owner ~= Player.PlayerData.citizenid then
            return Global.Notify(src, _L("no_permission"), "error")
        end
        if JX.DB.DeleteChest(chestUUID) then
            JX.Cache.RemoveChest(chestUUID)
            exports["rsg-inventory"]:RemoveInventory(chestUUID)
            TriggerClientEvent("rsg_chest:client:removeProp", -1, chestUUID)
            Global.Notify(src, _L("chest_removed"), "success")
            Global.LogToDiscord(
                "log_chest_removed_title",
                string.format(
                    _L("log_chest_removed"),
                    Player.PlayerData.character.firstname,
                    src,
                    Player.PlayerData.citizenid,
                    chestUUID
                ),
                "success"
            )
        else
            Global.Notify(src, _L("generic_error"), "error")
        end
    end
)

-- Evento para compartilhar o baú com outro jogador
-- Event to share the chest with another player
RegisterNetEvent(
    "rsg_chest:server:shareChest",
    function(chestUUID, targetPlayerId)
        local src = source
        local Player = RSGCore.Functions.GetPlayer(src)
        if not Player then
            return
        end
        local targetPlayer = RSGCore.Functions.GetPlayer(targetPlayerId)
        if not targetPlayer then
            return Global.Notify(src, _L("player_not_found"), "error")
        end
        local chestData = JX.Cache.GetChest(chestUUID)
        if not chestData or chestData.owner ~= Player.PlayerData.citizenid then
            return Global.Notify(src, _L("no_permission"), "error")
        end
        if targetPlayer.PlayerData.citizenid == Player.PlayerData.citizenid then
            return Global.Notify(src, _L("cannot_share_with_self"), "error")
        end

        local sharedList = chestData.shared_with
        if Config.MaxSharedPlayers > 0 and #sharedList >= Config.MaxSharedPlayers then
            return Global.Notify(src, _L("share_limit_reached"), "error")
        end

        for _, shared in ipairs(sharedList) do
            if shared.citizenid == targetPlayer.PlayerData.citizenid then
                return Global.Notify(src, _L("already_shared"), "error")
            end
        end

        local targetName =
            string.format(
            _L("text_full_name_format"),
            targetPlayer.PlayerData.character.firstname,
            targetPlayer.PlayerData.character.lastname or ""
        )
        table.insert(sharedList, {citizenid = targetPlayer.PlayerData.citizenid, name = targetName})

        if JX.DB.ShareChest(chestUUID, sharedList) then
            chestData.shared_with = sharedList
            JX.Cache.SetChest(chestUUID, chestData)
            Global.Notify(src, _L("chest_shared", targetName), "success")
            Global.LogToDiscord(
                "log_chest_shared_title",
                string.format(
                    _L("log_chest_shared"),
                    Player.PlayerData.character.firstname,
                    src,
                    chestUUID,
                    targetName,
                    targetPlayerId
                ),
                "info"
            )
        else
            Global.Notify(src, _L("generic_error"), "error")
        end
    end
)

-- Evento para buscar a lista de jogadores com acesso
-- Event to fetch the list of players with access to the chest
RegisterNetEvent(
    "rsg_chest:server:getSharedPlayers",
    function(chestUUID)
        local src = source
        local Player = RSGCore.Functions.GetPlayer(src)
        if not Player then
            return
        end
        local chestData = JX.Cache.GetChest(chestUUID)
        if not chestData or chestData.owner ~= Player.PlayerData.citizenid then
            return
        end
        TriggerClientEvent("rsg_chest:client:showSharedPlayersMenu", src, chestUUID, chestData.shared_with)
    end
)

-- Evento para revogar o acesso de um jogador
-- Event to revoke a player's access to the chest
RegisterNetEvent(
    "rsg_chest:server:revokeChestAccess",
    function(chestUUID, targetCitizenId)
        local src = source
        local Player = RSGCore.Functions.GetPlayer(src)
        if not Player then
            return
        end

        local chestData = JX.Cache.GetChest(chestUUID)
        if not chestData or chestData.owner ~= Player.PlayerData.citizenid then
            return
        end

        local sharedList = chestData.shared_with
        local targetName = _L("text_unknown")
        for i = #sharedList, 1, -1 do
            if sharedList[i].citizenid == targetCitizenId then
                targetName = sharedList[i].name
                table.remove(sharedList, i)
                break
            end
        end

        if JX.DB.ShareChest(chestUUID, sharedList) then
            chestData.shared_with = sharedList
            JX.Cache.SetChest(chestUUID, chestData)
            Global.Notify(src, _L("access_revoked", targetName), "success")
            Global.LogToDiscord(
                "log_access_revoked_title",
                string.format(
                    _L("log_access_revoked"),
                    Player.PlayerData.character.firstname,
                    src,
                    targetName,
                    targetCitizenId,
                    chestUUID
                ),
                "warning"
            )
        end
    end
)

-- Comando para mostrar os blips dos baús do jogador
-- Command to show the player's chest blips
RSGCore.Commands.Add(
    Config.CommandMyChests,
    _L("mychests_command_desc"),
    {},
    false,
    function(source, args)
        local src = source
        local Player = RSGCore.Functions.GetPlayer(src)
        if not Player then
            return
        end
        local coordsList = JX.DB.GetChestsByOwner(Player.PlayerData.citizenid)
        if #coordsList > 0 then
            TriggerClientEvent("rsg_chest:client:showBlips", src, coordsList)
            Global.Notify(src, _L("mychests_blips_created"), "success")
        else
            Global.Notify(src, _L("mychests_no_chests"), "inform")
        end
    end,
    "user"
)

-- Handlers de recurso
-- Resource start handler
AddEventHandler(
    "onResourceStart",
    function(resourceName)
        if GetCurrentResourceName() == resourceName then
            JX.Cache.Initialize()
        end
    end
)

AddEventHandler(
    "playerDropped",
    function(reason)
        JX.Cache.ClearUserFromChests(source)
    end
)

-- Sistema de Streaming de Props
-- Streaming system for props
local streamedProps = {}
CreateThread(
    function()
        while true do
            Wait(5000) -- Intervalo da verificação | Verification interval
            local activePlayers = RSGCore.Functions.GetPlayers()
            local allChests = JX.Cache.GetAllChests()

            for _, playerId in ipairs(activePlayers) do
                local player = RSGCore.Functions.GetPlayer(playerId)
                if player then
                    local playerCoords = GetEntityCoords(GetPlayerPed(playerId))
                    streamedProps[playerId] = streamedProps[playerId] or {}

                    for uuid, chestData in pairs(allChests) do
                        local distance =
                            #(playerCoords - vector3(chestData.coords.x, chestData.coords.y, chestData.coords.z))
                        if distance <= Config.StreamDistance then
                            if not streamedProps[playerId][uuid] then
                                TriggerClientEvent("rsg_chest:client:createProp", playerId, uuid, chestData)
                                streamedProps[playerId][uuid] = true
                            end
                        else
                            if streamedProps[playerId][uuid] then
                                TriggerClientEvent("rsg_chest:client:removeProp", playerId, uuid)
                                streamedProps[playerId][uuid] = nil
                            end
                        end
                    end
                end
            end
        end
    end
)

print(_L("diag_loaded_file", "server/main.lua"))
