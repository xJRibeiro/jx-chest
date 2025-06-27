-- server/admin.lua
print(_L("diag_loading_file", "server/admin.lua"))

local RSGCore = exports["rsg-core"]:GetCoreObject()
assert(RSGCore, "rsg-core not found, rsg-chest script cannot start.")

-- Funções Auxiliares para o Admin
-- Auxiliary Functions for Admin

-- Obtém os dados dos baús para o painel de administração
-- Gets chest data for the admin panel
local function getAdminChestData()
    local chests = JX.Cache.GetAllChests()
    local data = {}
    local summary = {totalChests = 0, chestsWithItems = 0, emptyChests = 0, totalItems = 0, totalWeight = 0}

    for _, chestData in pairs(chests) do
        local inv = exports["rsg-inventory"]:GetInventory(chestData.chest_uuid)
        local itemCount = inv and #inv.items or 0
        local totalWeight = 0
        if inv and inv.items then
            for _, item in ipairs(inv.items) do
                totalWeight = totalWeight + (item.weight * item.count)
            end
        end

        summary.totalChests = summary.totalChests + 1
        summary.totalItems = summary.totalItems + itemCount
        summary.totalWeight = summary.totalWeight + totalWeight
        if itemCount > 0 then
            summary.chestsWithItems = summary.chestsWithItems + 1
        else
            summary.emptyChests = summary.emptyChests + 1
        end

        local user = JX.Cache.GetChestUser(chestData.chest_uuid)
        local status
        if user then
            local userName = JX.Cache.GetPlayerName(RSGCore.Functions.GetPlayer(user).PlayerData.citizenid)
            status = _L("admin_status_in_use_by", userName)
        else
            status = _L("admin_status_available")
        end

        table.insert(
            data,
            {
                chest_uuid = chestData.chest_uuid,
                owner = chestData.owner,
                ownerName = JX.Cache.GetPlayerName(chestData.owner),
                coords = chestData.coords,
                heading = chestData.heading,
                model = chestData.model,
                shared_with = chestData.shared_with,
                created_at = chestData.created_at,
                last_updated = chestData.last_updated,
                itemCount = itemCount,
                totalWeight = totalWeight,
                slots = chestData.slots or Config.ChestSlots,
                maxWeight = chestData.maxWeight or Config.ChestWeight,
                status = status
            }
        )
    end
    return data, summary
end

-- Eventos do Servidor para o Admin
-- Server Events for Admin


RegisterNetEvent(
    "rsg_chest:server:getAdminChestData",
    function()
        local src = source
        if not RSGCore.Functions.HasPermission(src, "admin") then
            return
        end
        local data, summary = getAdminChestData()
        TriggerClientEvent("rsg_chest:client:receiveAdminChestData", src, data, summary)
    end
)

RegisterNetEvent(
    "rsg_chest:server:adminTeleport",
    function(chestUUID)
        local src = source
        if not RSGCore.Functions.HasPermission(src, "admin") then
            return
        end
        local chestData = JX.Cache.GetChest(chestUUID)
        if chestData then
            TriggerClientEvent("rsg_chest:client:teleportToCoords", src, chestData.coords)
            Global.Notify(src, _L("admin_teleported_to_chest"), "success")
            Global.LogToDiscord(
                "log_admin_teleport_title",
                string.format(
                    _L("log_admin_teleport"),
                    RSGCore.Functions.GetPlayer(src).PlayerData.character.firstname,
                    chestUUID
                ),
                "admin"
            )
        end
    end
)

RegisterNetEvent(
    "rsg_chest:server:adminRemove",
    function(chestUUID)
        local src = source
        if not RSGCore.Functions.HasPermission(src, "admin") then
            return
        end
        local chestData = JX.Cache.GetChest(chestUUID)
        if chestData then
            if JX.DB.DeleteChest(chestUUID) then
                JX.Cache.RemoveChest(chestUUID)
                exports["rsg-inventory"]:RemoveInventory(chestUUID)
                TriggerClientEvent("rsg_chest:client:removeProp", -1, chestUUID)
                Global.Notify(src, _L("admin_chest_removed"), "success")
                local ownerName = JX.Cache.GetPlayerName(chestData.owner)
                Global.LogToDiscord(
                    "log_admin_remove_title",
                    string.format(
                        _L("log_admin_remove"),
                        RSGCore.Functions.GetPlayer(src).PlayerData.character.firstname,
                        chestUUID,
                        ownerName
                    ),
                    "admin"
                )
            end
        end
    end
)

RegisterNetEvent(
    "rsg_chest:server:adminOpenInventory",
    function(chestUUID)
        local src = source
        if not RSGCore.Functions.HasPermission(src, "admin") then
            return
        end
        local chestData = JX.Cache.GetChest(chestUUID)
        if chestData then
            exports["rsg-inventory"]:OpenInventory(
                "chest",
                chestUUID,
                {
                    slots = chestData.slots or Config.ChestSlots,
                    weight = chestData.maxWeight or Config.ChestWeight
                }
            )
            Global.LogToDiscord(
                "log_admin_open_title",
                string.format(
                    _L("log_admin_open"),
                    RSGCore.Functions.GetPlayer(src).PlayerData.character.firstname,
                    chestUUID
                ),
                "admin"
            )
        end
    end
)

RegisterNetEvent(
    "rsg_chest:server:doRemoveAllChests",
    function()
        local src = source
        if not RSGCore.Functions.HasPermission(src, "admin") then
            return
        end
        local allChests = JX.Cache.GetAllChests()
        local count = 0
        for uuid, _ in pairs(allChests) do
            JX.DB.DeleteChest(uuid)
            JX.Cache.RemoveChest(uuid)
            exports["rsg-inventory"]:RemoveInventory(uuid)
            count = count + 1
        end
        TriggerClientEvent("rsg_chest:client:removeProp", -1) -- Envia um sinal para remover todos os baús de uma vez
        Global.Notify(src, _L("admin_all_chests_removed", count), "success")
        Global.LogToDiscord(
            "log_admin_remove_all_title",
            string.format(
                _L("log_admin_remove_all"),
                RSGCore.Functions.GetPlayer(src).PlayerData.character.firstname,
                count
            ),
            "admin"
        )
    end
)

-- Comandos de Admin
-- Admin Commands
RSGCore.Commands.Add(
    Config.CommandAdminChest,
    _L("admin_command_desc"),
    {},
    false,
    function(source)
        
        if not RSGCore.Functions.HasPermission(source, "admin") then
            return Global.Notify(source, _L("no_permission"), "error")
        end
        TriggerClientEvent("rsg_chest:client:openAdminPanel", source)
    end,
    "admin"
)

RSGCore.Commands.Add(
    Config.CommandCleanOrphanChests,
    _L("admin_clean_orphan_desc"),
    {},
    false,
    function(source)
        if not RSGCore.Functions.HasPermission(source, "admin") then
            return Global.Notify(source, _L("no_permission"), "error")
        end

        local allChests = JX.DB.GetAllChests()
        local removedCount = 0
        for _, chestData in ipairs(allChests) do
            local ownerExists =
                MySQL.scalar.await("SELECT COUNT(*) FROM players WHERE citizenid = ?", {chestData.owner}) > 0
            if not ownerExists then
                if JX.DB.DeleteChest(chestData.chest_uuid) then
                    JX.Cache.RemoveChest(chestData.chest_uuid)
                    exports["rsg-inventory"]:RemoveInventory(chestData.chest_uuid)
                    TriggerClientEvent("rsg_chest:client:removeProp", -1, chestData.chest_uuid)
                    removedCount = removedCount + 1
                end
            end
        end

        if removedCount > 0 then
            Global.Notify(source, _L("admin_orphan_cleaned", removedCount), "success")
            Global.LogToDiscord(
                "log_admin_clean_orphan_title",
                string.format(
                    _L("log_admin_clean_orphan"),
                    RSGCore.Functions.GetPlayer(source).PlayerData.character.firstname,
                    removedCount
                ),
                "admin"
            )
        else
            Global.Notify(source, _L("admin_orphan_none_found"), "inform")
        end
    end,
    "admin"
)

RSGCore.Commands.Add(
    Config.CommandRemoveAllChests,
    _L("admin_remove_all_button"),
    {},
    false,
    function(source)
        if not RSGCore.Functions.HasPermission(source, "admin") then
            return Global.Notify(source, _L("no_permission"), "error")
        end

        local chestCount = #table.keys(JX.Cache.GetAllChests())
        if chestCount == 0 then
            return Global.Notify(source, _L("admin_no_chests_to_remove"), "inform")
        end

        TriggerClientEvent("rsg_chest:client:confirmRemoveAll", source, chestCount)
    end,
    "admin"
)

print(_L("diag_loaded_file", "server/admin.lua"))
