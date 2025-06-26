print(_L('diag_loading_file', 'client/admin.lua (ox_lib version)'))

local AdminPanel = {}
AdminPanel.State = {chestData = {}, summary = {}}


AdminPanel.Network = {
    fetchAdminData = function()
        TriggerServerEvent("rsg_chest:server:getAdminChestData")
    end,
    teleportToChest = function(uuid)
        TriggerServerEvent("rsg_chest:server:adminTeleport", uuid)
    end,
    removeChest = function(uuid)
        TriggerServerEvent("rsg_chest:server:adminRemove", uuid)
    end,
    openChestInventory = function(uuid)
        TriggerServerEvent("rsg_chest:server:adminOpenInventory", uuid)
    end,
    requestRemoveAll = function()
        ExecuteCommand("removeallchests")
    end
}
AdminPanel.Formatters = {shortUUID = function(uuid)
        return uuid:sub(1, 8) .. "..."
    end, formatWeightKg = function(grams)
        return string.format("%.1f", (grams or 0) / 1000)
    end, formatCoords = function(coords)
        return string.format("X:%.1f Y:%.1f Z:%.1f", coords.x, coords.y, coords.z)
    end, getSharedWithText = function(chest)
        if chest.sharedWith and #chest.sharedWith > 0 then
            local entries = {}
            for _, shared in ipairs(chest.sharedWith) do
                table.insert(entries, "• " .. (shared.name or _L('admin_unknown_player')) .. " (" .. shared.citizenid .. ")")
            end
            return "\n\n**" .. _L("admin_shared_with") .. "**\n" .. table.concat(entries, "\n")
        end
        return "\n\n**" .. _L("admin_shared_with") .. "** " .. _L("admin_nobody")
    end, formatFullMysqlTimestamp = function(mysqlTimestamp)
        if not mysqlTimestamp or type(mysqlTimestamp) ~= "string" then
            return _L("admin_unknown")
        end
        local year, month, day, hour, min, sec = string.match(mysqlTimestamp, "(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
        if year then
            return string.format("%s-%s-%s %s:%s:%s", day, month, year, hour, min, sec)
        end
        return mysqlTimestamp
    end}

AdminPanel.UI = {
    createMenu = function(id, title, options)
        lib.registerContext({id = id, title = title, options = options})
        lib.showContext(id)
    end,
    createBackButton = function(onSelectCallback)
        return {title = _L("admin_back"), icon = "arrow-left", onSelect = onSelectCallback}
    end,
    openMainAdminMenu = function()
        local s = AdminPanel.State.summary
        local options = {
            {
                title = _L("admin_system_overview"),
                description = _L(
                    "admin_overview_desc",
                    s.totalChests or 0,
                    s.chestsWithItems or 0,
                    s.emptyChests or 0,
                    s.totalItems or 0,
                    AdminPanel.Formatters.formatWeightKg(s.totalWeight)
                ),
                icon = "chart-pie",
                disabled = true
            },
            {
                title = _L("admin_refresh_data"),
                description = _L("admin_refresh_desc"),
                icon = "sync-alt",
                onSelect = AdminPanel.Network.fetchAdminData
            },
            {
                title = _L("admin_chest_list"),
                description = _L("admin_chest_list_desc"),
                icon = "list",
                onSelect = function()
                    AdminPanel.UI.openChestListMenu()
                end
            },
            {
                title = _L("admin_search_chest"),
                description = _L("admin_search_desc"),
                icon = "search",
                onSelect = AdminPanel.UI.openSearchMenu
            },
            {
                title = _L("admin_remove_all_button"),
                description = _L("admin_remove_all_desc"),
                icon = "skull-crossbones",
                onSelect = function()
                    AdminPanel.Network.requestRemoveAll()
                end
            }
        }
        AdminPanel.UI.createMenu("chest_admin_main", _L("admin_panel_title"), options)
    end,
    openChestListMenu = function(filteredChests, searchTerm)
        local options = {}
        local chests = filteredChests or AdminPanel.State.chestData
        if #chests == 0 then
            local noResultsTitle = searchTerm and _L("admin_no_results") or _L("admin_no_chests")
            table.insert(options, {title = noResultsTitle, disabled = true, icon = "inbox"})
        else
            for _, chest in ipairs(chests) do
                local statusIcon = string.find(chest.status, _L("admin_status_in_use")) and "🔴" or "🟢"
                local weightPercent =
                    chest.maxWeight > 0 and chest.totalWeight > 0 and
                    math.floor((chest.totalWeight / chest.maxWeight) * 100) or
                    0
                table.insert(
                    options,
                    {
                        title = string.format(
                            "%s %s - %s",
                            statusIcon,
                            AdminPanel.Formatters.shortUUID(chest.chest_uuid),
                            chest.ownerName
                        ),
                        description = string.format(
                            "%s | %s: %d/%d (%d%%) | %s",
                            AdminPanel.Formatters.formatCoords(chest.coords),
                            _L("admin_items"),
                            chest.itemCount,
                            chest.slots,
                            weightPercent,
                            chest.status
                        ),
                        icon = "box",
                        onSelect = function()
                            AdminPanel.UI.openChestDetailsMenu(chest)
                        end
                    }
                )
            end
        end
        table.insert(options, AdminPanel.UI.createBackButton(AdminPanel.UI.openMainAdminMenu))
        local title =
            searchTerm and string.format('%s "%s"', _L("admin_search_results"), searchTerm) or
            _L("admin_chest_list")
        AdminPanel.UI.createMenu("chest_list_menu", title .. " (" .. #chests .. ")", options)
    end,
    openChestDetailsMenu = function(chest)
        local options = {
            {
                title = _L("admin_chest_info"),
                description = _L("admin_chest_info_desc"),
                icon = "info-circle",
                onSelect = function()
                    AdminPanel.UI.showChestDetailedInfo(chest)
                end
            },
            {
                title = _L("admin_view_items"),
                description = _L("admin_view_items_desc"),
                icon = "box-open",
                onSelect = function()
                    AdminPanel.Network.openChestInventory(chest.chest_uuid)
                    lib.hideContext(true)
                end
            },
            {
                title = _L("admin_teleport_to_chest"),
                description = _L("admin_teleport_desc"),
                icon = "map-marker-alt",
                onSelect = function()
                    AdminPanel.Network.teleportToChest(chest.chest_uuid)
                    lib.hideContext(true)
                end
            },
            {
                title = _L("admin_remove_chest"),
                description = _L("admin_remove_warning"),
                icon = "trash-alt",
                onSelect = function()
                    local alert =
                        lib.alertDialog(
                        {
                            header = _L("admin_confirm_removal"),
                            content = _L(
                                "admin_removal_warning",
                                AdminPanel.Formatters.shortUUID(chest.chest_uuid),
                                chest.ownerName
                            ),
                            centered = true,
                            cancel = true
                        }
                    )
                    if alert == "confirm" then
                        AdminPanel.Network.removeChest(chest.chest_uuid)
                    end
                end
            }
        }
        table.insert(
            options,
            AdminPanel.UI.createBackButton(
                function()
                    AdminPanel.UI.openChestListMenu()
                end
            )
        )
        AdminPanel.UI.createMenu(
            "chest_details_menu",
            _L("admin_chest_details") .. " #" .. AdminPanel.Formatters.shortUUID(chest.chest_uuid),
            options
        )
    end,
    showChestDetailedInfo = function(chest)
        local f = AdminPanel.Formatters
        local weightPercent =
            chest.maxWeight > 0 and chest.totalWeight > 0 and math.floor((chest.totalWeight / chest.maxWeight) * 100) or
            0
        local content = {
            string.format("**%s:** %s", _L("admin_chest_uuid"), chest.chest_uuid),
            string.format("**%s:** %s (%s)", _L("admin_owner"), chest.ownerName, chest.owner),
            string.format("**%s:** %s", _L("admin_model"), chest.model),
            string.format("**%s:** %s", _L("admin_location"), f.formatCoords(chest.coords)),
            string.format("**%s:** %.1f°", _L("admin_heading"), chest.heading),
            string.format("**%s:** %s", _L("admin_status"), chest.status),
            string.format("**%s:** %d/%d slots", _L("admin_inventory"), chest.itemCount, chest.slots),
            string.format(
                "**%s:** %s/%s kg (%s%%)",
                _L("admin_weight"),
                f.formatWeightKg(chest.totalWeight),
                f.formatWeightKg(chest.maxWeight),
                weightPercent
            ),
            string.format("**%s:** %s", _L("admin_created"), f.formatFullMysqlTimestamp(chest.created_at)),
            string.format(
                "**%s:** %s%s",
                _L("admin_updated"),
                f.formatFullMysqlTimestamp(chest.updated_at),
                f.getSharedWithText(chest)
            )
        }
        lib.alertDialog(
            {
                header = _L("admin_chest_info") .. " #" .. f.shortUUID(chest.chest_uuid),
                content = table.concat(content, "\n"),
                centered = true,
                size = "lg"
            }
        )
    end,
    openSearchMenu = function()
        local input =
            lib.inputDialog(
            _L("admin_search_chest"),
            {
                {
                    type = "input",
                    label = _L("admin_search_by"),
                    placeholder = _L("admin_search_placeholder"),
                    required = true
                }
            }
        )
        if not (input and input[1]) then
            return
        end
        local searchTerm = input[1]:lower()
        local results = {}
        for _, chest in ipairs(AdminPanel.State.chestData) do
            if
                (chest.ownerName and chest.ownerName:lower():find(searchTerm)) or
                    (chest.owner and chest.owner:lower():find(searchTerm)) or
                    (chest.chest_uuid:lower():find(searchTerm))
             then
                table.insert(results, chest)
            end
        end
        AdminPanel.UI.openChestListMenu(results, searchTerm)
    end
}

RegisterNetEvent(
    "rsg_chest:client:openAdminPanel",
    function()
        AdminPanel.Network.fetchAdminData()
    end
)
RegisterNetEvent(
    "rsg_chest:client:receiveAdminChestData",
    function(data, summaryData)
        AdminPanel.State.chestData = data
        AdminPanel.State.summary = summaryData
        AdminPanel.UI.openMainAdminMenu()
    end
)
RegisterNetEvent(
    "rsg_chest:client:teleportToCoords",
    function(coords)
        SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z + 0.5, true, false, false, true)
    end
)

RegisterNetEvent(
    "rsg_chest:client:confirmRemoveAll",
    function(chestCount)
        local alert =
            lib.alertDialog(
            {
                header = _L("admin_confirm_remove_all_header"),
                content = string.format(_L("admin_confirm_remove_all_content"), chestCount),
                centered = true,
                cancel = true,
                size = "lg"
            }
        )
        if alert == "confirm" then
            TriggerServerEvent("rsg_chest:server:doRemoveAllChests")
        end
    end
)

print(_L('diag_loaded_file', 'client/admin.lua (ox_lib version)'))
