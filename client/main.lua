print("[BAU DIAGNÓSTICO] Carregando client/main.lua...")
local RSGCore = exports["rsg-core"]:GetCoreObject()

local propEntities = {}
local localChests = {}
local placementMode = false
local previewObject = nil
local activeBlips = {}
local currentlyOpenChest = nil

--------------------------------------------------------------------------------
-- FUNÇÕES AUXILIARES
--------------------------------------------------------------------------------

local function ClearAllBlips()
    if next(activeBlips) then
        for blip, _ in pairs(activeBlips) do
            if DoesBlipExist(blip) then
                RemoveBlip(blip)
            end
        end
        activeBlips = {}
    end
end

local function GetNearbyPlayers(radius)
    local nearbyPlayers = {}
    local myPlayerId = PlayerId()
    local myCoords = GetEntityCoords(PlayerPedId())
    for _, playerId in ipairs(GetActivePlayers()) do
        if playerId ~= myPlayerId then
            local targetPed = GetPlayerPed(playerId)
            local targetCoords = GetEntityCoords(targetPed)
            local distance = #(myCoords - targetCoords)
            if distance <= radius then
                table.insert(
                    nearbyPlayers,
                    {
                        label = string.format("%s (%s)", GetPlayerName(playerId), GetPlayerServerId(playerId)),
                        value = GetPlayerServerId(playerId),
                        description = string.format("Distância: %.1f metros", distance)
                    }
                )
            end
        end
    end
    return nearbyPlayers
end

local function DrawText3D(x, y, z, text)
    SetDrawOrigin(x, y, z, 0)
    SetTextScale(0.35, 0.35)
    SetTextFontForCurrentCommand(4)
    SetTextColor(255, 255, 255, 215)
    SetTextCentre(true)
    local str, str_len = CreateVarString(10, "LITERAL_STRING", text)
    DisplayText(str, 0.0, 0.0)
    ClearDrawOrigin()
end

local function RayCastGamePlayCamera(distance)
    local camRot = GetGameplayCamRot()
    local camCoord = GetGameplayCamCoord()
    local dir =
        vector3(
        -math.sin(math.rad(camRot.z)) * math.abs(math.cos(math.rad(camRot.x))),
        math.cos(math.rad(camRot.z)) * math.abs(math.cos(math.rad(camRot.x))),
        math.sin(math.rad(camRot.x))
    )
    local dest = camCoord + dir * distance
    local ray = StartShapeTestRay(camCoord.x, camCoord.y, camCoord.z, dest.x, dest.y, dest.z, -1, PlayerPedId(), 0)
    local _, hit, endCoords = GetShapeTestResult(ray)
    return hit, endCoords
end

--------------------------------------------------------------------------------
-- FUNÇÕES PRINCIPAIS
--------------------------------------------------------------------------------

local function AddTargetToProp(entity, chestUUID)
    exports["rsg-target"]:RemoveTargetEntity(entity)
    local chestData = localChests[chestUUID]
    if not chestData then
        return
    end
    local PlayerData = RSGCore.Functions.GetPlayerData()
    if not PlayerData then
        return
    end
    local isOwner = PlayerData.citizenid == chestData.owner

    local options = {
        {
            icon = "fas fa-box-open",
            label = Config.Lang["open_chest"] or "Abrir Baú",
            action = function()
                currentlyOpenChest = chestUUID
                TriggerServerEvent("rsg_chest:server:openChest", chestUUID)
            end
        }
    }
    if isOwner then
        table.insert(
            options,
            {
                icon = "fas fa-share-alt",
                label = "Compartilhar Baú",
                action = function()
                    local players = GetNearbyPlayers(15.0)
                    if #players == 0 then
                        lib.notify(
                            {
                                title = "Ninguém por perto",
                                description = "Não há jogadores próximos para compartilhar.",
                                type = "inform"
                            }
                        )
                        return
                    end
                    local result = lib.select({title = "Compartilhar com Jogador Próximo", options = players})
                    if result then
                        TriggerServerEvent("rsg_chest:server:shareChest", chestUUID, result.value)
                    end
                end
            }
        )
        table.insert(
            options,
            {icon = "fas fa-users-cog", label = Config.Lang["manage_access_label"], action = function()
                    TriggerServerEvent("rsg_chest:server:getSharedPlayers", chestUUID)
                end}
        )
        table.insert(
            options,
            {
                icon = "fas fa-trash-alt",
                label = "Remover Baú",
                action = function()
                    local alert =
                        lib.alertDialog(
                        {
                            header = "Remover Baú",
                            content = "Tem certeza que deseja remover este baú?",
                            centered = true,
                            cancel = true
                        }
                    )
                    if alert == "confirm" then
                        TriggerServerEvent("rsg_chest:server:requestToRemoveChest", chestUUID)
                    end
                end
            }
        )
    end
    exports["rsg-target"]:AddTargetEntity(entity, {options = options, distance = Config.MaxDistance})
end

local function CreateProp(chestUUID, chestData)
    if propEntities[chestUUID] then
        return
    end
    localChests[chestUUID] = chestData
    local propModel = joaat(chestData.model)
    RequestModel(propModel)
    while not HasModelLoaded(propModel) do
        Wait(10)
    end
    local prop =
        CreateObject(propModel, chestData.coords.x, chestData.coords.y, chestData.coords.z, false, false, false)
    SetEntityHeading(prop, chestData.heading or 0.0)
    FreezeEntityPosition(prop, true)
    propEntities[chestUUID] = prop
    AddTargetToProp(prop, chestUUID)
    SetModelAsNoLongerNeeded(propModel)
end

local function ClearAllProps()
    for uuid, entity in pairs(propEntities) do
        if DoesEntityExist(entity) then
            exports["rsg-target"]:RemoveTargetEntity(entity)
            DeleteEntity(entity)
        end
    end
    propEntities = {}
    localChests = {}
end

local function StartPlacementMode()
    if placementMode then
        return
    end
    placementMode = true
    TriggerServerEvent("rsg_chest:server:getActiveChests")
    local propModel = joaat(Config.ChestProp)
    RequestModel(propModel)
    while not HasModelLoaded(propModel) do
        Wait(10)
    end
    previewObject = CreateObject(propModel, GetEntityCoords(PlayerPedId()), false, false, false)
    SetEntityAlpha(previewObject, 180, false)
    SetEntityCollision(previewObject, false, false)
    CreateThread(
        function()
            local heading = GetEntityHeading(PlayerPedId())
            while placementMode do
                Wait(0)
                local hit, endCoords = RayCastGamePlayCamera(Config.PlacementDistance)
                if hit and DoesEntityExist(previewObject) then
                    local _, groundZ = GetGroundZFor_3dCoord(endCoords.x, endCoords.y, endCoords.z + 1.0, false)
                    local finalCoords = vector3(endCoords.x, endCoords.y, groundZ)
                    SetEntityCoordsNoOffset(
                        previewObject,
                        finalCoords.x,
                        finalCoords.y,
                        finalCoords.z,
                        false,
                        false,
                        false,
                        true
                    )
                    SetEntityHeading(previewObject, heading)
                    local isValid = true
                    for _, chest in pairs(localChests) do
                        if #(finalCoords - vector3(chest.coords.x, chest.coords.y, chest.coords.z)) < Config.MaxDistance then
                            isValid = false
                            break
                        end
                    end
                    SetEntityAlpha(previewObject, isValid and 220 or 100, false)
                    local helpText = "~y~Posicione seu baú~s~\n~b~← / →~s~ Girar\n"
                    helpText = helpText .. (isValid and "~g~[ENTER]~s~ Confirmar" or "~r~Local Inválido~s~")
                    helpText = helpText .. "\n~r~[BACKSPACE]~s~ Cancelar"
                    DrawText3D(finalCoords.x, finalCoords.y, finalCoords.z + 0.65, helpText)
                    if IsControlPressed(0, 0xA65EBAB4) then
                        heading = (heading + 1.0) % 360.0
                    end
                    if IsControlPressed(0, 0xDEB34313) then
                        heading = (heading - 1.0 + 360.0) % 360.0
                    end
                    if IsControlJustReleased(0, 0xC7B5340A) and isValid then
                        placementMode = false
                        if
                            lib.progressBar(
                                {
                                    duration = Config.PlacementTime,
                                    label = Config.Lang["placing_chest"],
                                    useWhileDead = false,
                                    canCancel = true,
                                    anim = {
                                        dict = "amb_work@world_human_box_pickup@1@male_a@stand_exit_withprop",
                                        clip = "exit_front"
                                    }
                                }
                            )
                         then
                            TriggerServerEvent("rsg_chest:server:placeChest", finalCoords, heading)
                        else
                            lib.notify(
                                {
                                    title = Config.Lang["info_title"],
                                    description = Config.Lang["placement_cancelled"],
                                    type = "inform"
                                }
                            )
                        end
                    end
                end
                if IsControlJustReleased(0, 0x156F7119) then
                    placementMode = false
                    lib.notify(
                        {
                            title = Config.Lang["info_title"],
                            description = Config.Lang["placement_cancelled"],
                            type = "inform"
                        }
                    )
                end
            end
            if DoesEntityExist(previewObject) then
                DeleteEntity(previewObject)
            end
            previewObject = nil
            SetModelAsNoLongerNeeded(propModel)
            placementMode = false
        end
    )
end

--------------------------------------------------------------------------------
-- REGISTRO DE EVENTOS E THREADS
--------------------------------------------------------------------------------
RegisterNetEvent(
    "rsg_chest:client:proceedWithRemoval",
    function(chestUUID)
        if
            lib.progressBar(
                {
                    duration = Config.RemovalTime,
                    label = Config.Lang["removing_chest"],
                    useWhileDead = false,
                    canCancel = true,
                    anim = {dict = "amb_work@world_human_box_pickup@1@male_a@stand_exit_withprop", clip = "exit_front"}
                }
            )
         then
            TriggerServerEvent("rsg_chest:server:removeChest", chestUUID)
        end
    end
)
RegisterNetEvent(
    "rsg_chest:client:updateProps",
    function(chests)
        ClearAllProps()
        if chests then
            for uuid, chestData in pairs(chests) do
                CreateProp(uuid, chestData)
            end
        end
    end
)
RegisterNetEvent(
    "rsg_chest:client:createProp",
    function(uuid, data)
        CreateProp(uuid, data)
    end
)
RegisterNetEvent(
    "rsg_chest:client:removeProp",
    function(uuid)
        if propEntities[uuid] then
            if DoesEntityExist(propEntities[uuid]) then
                exports["rsg-target"]:RemoveTargetEntity(propEntities[uuid])
                DeleteEntity(propEntities[uuid])
            end
            propEntities[uuid] = nil
            localChests[uuid] = nil
        end
    end
)
RegisterNetEvent(
    "rsg_chest:client:receiveActiveChests",
    function(chests)
        localChests = {}
        if chests then
            for _, chestData in ipairs(chests) do
                localChests[chestData.uuid] = chestData
            end
        end
    end
)
RegisterNetEvent(
    "rsg_chest:client:updateChestStatus",
    function(chestUUID, inUse, playerName)
        local entity = propEntities[chestUUID]
        if entity then
            AddTargetToProp(entity, chestUUID)
        end
    end
)
RegisterNetEvent(
    "rsg_chest:client:startPlacement",
    function()
        StartPlacementMode()
    end
)

RegisterNetEvent(
    "rsg_chest:client:showBlips",
    function(coordsList)
        ClearAllBlips()
        for _, coords in ipairs(coordsList) do
            local blip = Citizen.InvokeNative(0x3C631476, coords.x, coords.y, coords.z)
            SetBlipSprite(blip, joaat("blip_safehouse"))
            SetBlipColour(blip, 2)
            SetBlipScale(blip, 0.8)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString("Meu Baú")
            EndTextCommandSetBlipName(blip)
            activeBlips[blip] = true
            CreateThread(
                function()
                    Wait(Config.BlipDuration * 1000)
                    if DoesBlipExist(blip) then
                        RemoveBlip(blip)
                    end
                    activeBlips[blip] = nil
                end
            )
        end
    end
)

RegisterNetEvent(
    "rsg_chest:client:showSharedPlayersMenu",
    function(chestUUID, sharedPlayers)
        if #sharedPlayers == 0 then
            lib.notify(
                {
                    title = Config.Lang["manage_access_title"],
                    description = Config.Lang["no_one_shared_with"],
                    type = "inform"
                }
            )
            return
        end
        local options = {}
        for _, playerData in ipairs(sharedPlayers) do
            table.insert(
                options,
                {
                    title = playerData.name,
                    description = string.format(Config.Lang["revoke_access_label"], playerData.name),
                    icon = "user-times",
                    onSelect = function()
                        local alert =
                            lib.alertDialog(
                            {
                                header = "Revogar Acesso",
                                content = string.format(Config.Lang["confirm_revoke_access"], playerData.name),
                                centered = true,
                                cancel = true
                            }
                        )
                        if alert == "confirm" then
                            TriggerServerEvent("rsg_chest:server:revokeChestAccess", chestUUID, playerData.citizenid)
                        end
                    end
                }
            )
        end
        lib.registerContext({id = "manage_chest_access", title = Config.Lang["manage_access_title"], options = options})
        lib.showContext("manage_chest_access")
    end
)

AddEventHandler(
    "RSGCore:Client:OnPlayerLoaded",
    function()
        TriggerServerEvent("rsg_chest:server:requestAllProps")
    end
)
AddEventHandler(
    "onResourceStop",
    function(resourceName)
        if GetCurrentResourceName() == resourceName then
            ClearAllProps()
            ClearAllBlips()
        end
    end
)

CreateThread(function()
    while not RSGCore or not LocalPlayer or not LocalPlayer.state do
        Wait(500)
    end

    while true do
        Wait(250)
        
        if currentlyOpenChest then
            local isInventoryBusy = LocalPlayer.state.inv_busy
            
            if not isInventoryBusy then
                TriggerServerEvent('rsg_chest:server:chestClosed', currentlyOpenChest)
                currentlyOpenChest = nil
            end
        end
    end
end)

print("[BAU DIAGNÓSTICO] client/main.lua carregado com sucesso.")
