local RSGCore = exports["rsg-core"]:GetCoreObject()

local function Notify(src, pType, titleKey, descriptionKey, ...)
    TriggerClientEvent("ox_lib:notify", src, {type = pType, title = _L(titleKey), description = _L(descriptionKey, ...)})
end

Admin.Events = {
    getAdminChestData = function(src)
        local allChests = Cache.GetAllChests()
        local chestData = {}
        local summary = {totalChests = 0, emptyChests = 0, chestsWithItems = 0, totalItems = 0, totalWeight = 0}
        for uuid, chest in pairs(allChests) do
            local ownerName = Cache.GetPlayerName(chest.owner) or _L("admin_unknown_player")
            local inventory = exports["rsg-inventory"]:GetInventory("chest_" .. uuid)
            local itemCount, totalWeight, items = 0, 0, {}
            if inventory and inventory.items and next(inventory.items) then
                for _, item in pairs(inventory.items) do
                    if item and item.amount > 0 then
                        itemCount = itemCount + 1
                        totalWeight = totalWeight + (item.weight * item.amount)
                        summary.totalItems = summary.totalItems + item.amount
                        table.insert(
                            items,
                            {name = item.name, label = item.label, amount = item.amount, weight = item.weight}
                        )
                    end
                end
            end
            summary.totalChests = summary.totalChests + 1
            summary.totalWeight = summary.totalWeight + totalWeight
            if itemCount == 0 then
                summary.emptyChests = summary.emptyChests + 1
            else
                summary.chestsWithItems = summary.chestsWithItems + 1
            end
            local status
            local userSrc = Cache.GetChestUser(uuid)
            if userSrc then
                local userName = GetPlayerIdentifier(userSrc) or _L("admin_unknown")
                status = _L("admin_status_in_use_by", userName)
            else
                status = _L("admin_status_available")
            end
            table.insert(
                chestData,
                {
                    chest_uuid = uuid,
                    owner = chest.owner,
                    ownerName = ownerName,
                    coords = chest.coords,
                    heading = chest.heading or 0.0,
                    model = chest.model,
                    status = status,
                    itemCount = itemCount,
                    totalWeight = totalWeight,
                    maxWeight = Config.ChestWeight,
                    slots = Config.ChestSlots,
                    items = items,
                    sharedWith = chest.shared_with or {},
                    created_at = chest.created_at,
                    updated_at = chest.last_updated
                }
            )
        end
        TriggerClientEvent("rsg_chest:client:receiveAdminChestData", src, chestData, summary)
    end,
    adminTeleport = function(src, chestUUID)
        local chest = Cache.GetChest(chestUUID)
        if not chest then
            Notify(src, "error", "error_title", "chest_not_found")
            return
        end
        TriggerClientEvent("rsg_chest:client:teleportToCoords", src, chest.coords)
        Notify(src, "success", "success_title", "admin_teleported_to_chest")
        Global.Log("CRITICAL", "log_admin_teleport_title", _L('log_admin_teleport', GetPlayerIdentifier(src), chestUUID), nil, true)
    end,
    adminRemove = function(src, chestUUID)
        local chest = Cache.GetChest(chestUUID)
        if not chest then
            Notify(src, "error", "error_title", "chest_not_found")
            return
        end
        local ownerName = Cache.GetPlayerName(chest.owner)
        exports["rsg-inventory"]:DeleteInventory("chest_" .. chestUUID)
        Database.DeleteChest(chestUUID)
        Cache.RemoveChest(chestUUID)
        TriggerClientEvent("rsg_chest:client:removeProp", -1, chestUUID)
        Notify(src, "success", "success_title", "admin_chest_removed")
        Global.Log("CRITICAL", "log_admin_remove_title", _L('log_admin_remove', GetPlayerIdentifier(src), chestUUID, ownerName), 16711680, true)
        Admin.Events.getAdminChestData(src)
    end,
    adminOpenInventory = function(src, chestUUID)
        if not Cache.GetChest(chestUUID) then
            Notify(src, "error", "error_title", "chest_not_found")
            return
        end
        local inventoryId = "chest_" .. chestUUID
        exports["rsg-inventory"]:OpenInventory(
            src,
            inventoryId,
            {
                label = string.format("ADMIN: Baú #%s", string.sub(chestUUID, 1, 8)),
                maxweight = Config.ChestWeight,
                slots = Config.ChestSlots
            }
        )
         Global.Log("CRITICAL", "log_admin_open_title", _L('log_admin_open', GetPlayerIdentifier(src), chestUUID), nil, true)
    end
}

Admin.Commands = {
    cleanOrphanChests = function(src)
        Global.Debug("DETAIL", "Iniciando verificação de baús órfãos.")
        local allChests = Cache.GetAllChests()
        if not next(allChests) then
            Notify(src, "info", "info_title", "admin_orphan_none_found")
            return
        end
        local ownerIds = {}
        for _, chest in pairs(allChests) do
            ownerIds[chest.owner] = true
        end
        local ownerIdList = {}
        for id in pairs(ownerIds) do
            table.insert(ownerIdList, id)
        end
        if #ownerIdList == 0 then
            Notify(src, "info", "info_title", "admin_orphan_none_found")
            return
        end
        local playersResult =
            MySQL.query.await(
            "SELECT citizenid FROM players WHERE citizenid IN (?" .. string.rep(",?", #ownerIdList - 1) .. ")",
            ownerIdList
        )
        local existingPlayers = {}
        for _, row in ipairs(playersResult) do
            existingPlayers[row.citizenid] = true
        end
        local orphanCount = 0
        for uuid, chest in pairs(allChests) do
            if not existingPlayers[chest.owner] then
                Global.Debug("INFO", string.format("Baú órfão encontrado: %s, Dono: %s. Removendo.", uuid, chest.owner))
                exports["rsg-inventory"]:DeleteInventory("chest_" .. uuid)
                Database.DeleteChest(uuid)
                Cache.RemoveChest(uuid)
                TriggerClientEvent("rsg_chest:client:removeProp", -1, uuid)
                orphanCount = orphanCount + 1
            end
        end
        Notify(src, "success", "success_title", "admin_orphan_cleaned", orphanCount)
        Global.Log("CRITICAL", "log_admin_clean_orphan_title", _L('log_admin_clean_orphan', GetPlayerIdentifier(src), orphanCount), nil, true)
    end,
    removeAllChests = function(src)
        local allChests = Cache.GetAllChests()
        local chestCount = 0
        for _ in pairs(allChests) do
            chestCount = chestCount + 1
        end
        for uuid, _ in pairs(allChests) do
            exports["rsg-inventory"]:DeleteInventory("chest_" .. uuid)
            Database.DeleteChest(uuid)
            Cache.RemoveChest(uuid)
            TriggerClientEvent("rsg_chest:client:removeProp", -1, uuid)
        end
        Cache.Initialize()
        Notify(src, "success", "success_title", "admin_all_chests_removed", chestCount)
        Global.Log("CRITICAL", "log_admin_remove_all_title", _L('log_admin_remove_all', GetPlayerIdentifier(src), chestCount), 16711680, true)
    end
}

function Admin.Initialize()
    local function RegisterAdminEvent(eventName, handler)
        RegisterNetEvent("rsg_chest:server:" .. eventName, function(...)
            local s = source
            if not RSGCore.Functions.HasPermission(s, "admin") then
                Notify(s, "error", "error_title", "no_permission")
                return
            end
            handler(s, ...)
        end)
    end

    RegisterAdminEvent("getAdminChestData", Admin.Events.getAdminChestData)
    RegisterAdminEvent("adminTeleport", Admin.Events.adminTeleport)
    RegisterAdminEvent("adminRemove", Admin.Events.adminRemove)
    RegisterAdminEvent("adminOpenInventory", Admin.Events.adminOpenInventory)
    RegisterAdminEvent("doRemoveAllChests", Admin.Commands.removeAllChests)

    local function RegisterAdminCommand(command, descriptionKey, handler)
        RSGCore.Commands.Add(command, _L(descriptionKey), {}, false, function(s)
            if not RSGCore.Functions.HasPermission(s, "admin") then
                Notify(s, "error", "error_title", "no_permission")
                return
            end
            handler(s)
        end, "admin")
    end

    RegisterAdminCommand(Config.CommandAdminChest, "admin_command_desc", function(s)
        TriggerClientEvent("rsg_chest:client:openAdminPanel", s)
    end)
    RegisterAdminCommand(Config.CommandCleanOrphanChests, "admin_clean_orphan_desc", Admin.Commands.cleanOrphanChests)
    RegisterAdminCommand(Config.CommandRemoveAllChests, "admin_remove_all_desc", function(s)
        local allChests = Cache.GetAllChests()
        local chestCount = 0
        for _ in pairs(allChests) do chestCount = chestCount + 1 end
        if chestCount == 0 then
            Notify(s, "info", "info_title", "admin_no_chests_to_remove")
            return
        end
        TriggerClientEvent("rsg_chest:client:confirmRemoveAll", s, chestCount)
    end)
    Global.Debug("DETAIL", "Módulo Admin inicializado.")
end

print(_L('diag_loaded_file', 'server/admin.lua'))
