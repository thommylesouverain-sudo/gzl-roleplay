local depotBlip = nil
local parkingBlip = nil
local returnMarker = nil

local function createDepotElements()
    local d = Config.DepotLocation
    depotBlip = createBlip(d.marker.x, d.marker.y, d.marker.z, 42, 2, 56, 189, 248, 255, 0, 350)
end

local function syncRadarRoute()
    local jobData = JobHUD.getJobData()
    if not jobData then
        if exports.gzl_radar and exports.gzl_radar.clearWaypoint then
            exports.gzl_radar:clearWaypoint()
        end
        if isElement(parkingBlip) then
            destroyElement(parkingBlip)
            parkingBlip = nil
        end
        return
    end

    local totalWins = jobData.totalWindows or 1
    local cleanedWins = jobData.cleanedWindows or 0

    if cleanedWins >= totalWins then
        -- Tüm camlar bitti, depoya dönüş noktası
        local ret = Config.DepotLocation.vehicleReturn
        if exports.gzl_radar and exports.gzl_radar.setWaypoint then
            exports.gzl_radar:setWaypoint(ret.x, ret.y)
        end
        if isElement(parkingBlip) then
            destroyElement(parkingBlip)
            parkingBlip = nil
        end
        if not isElement(returnMarker) then
            returnMarker = createMarker(ret.x, ret.y, ret.z - 1.0, "cylinder", ret.radius, 34, 197, 94, 150)
        end
    else
        -- Hedef bina park alanı
        if jobData.parkingPos then
            if exports.gzl_radar and exports.gzl_radar.setWaypoint then
                exports.gzl_radar:setWaypoint(jobData.parkingPos.x, jobData.parkingPos.y)
            end
            if not isElement(parkingBlip) then
                parkingBlip = createBlip(jobData.parkingPos.x, jobData.parkingPos.y, jobData.parkingPos.z, 41, 2, 234, 179, 8, 255, 0, 500)
            end
        end
        if isElement(returnMarker) then
            destroyElement(returnMarker)
            returnMarker = nil
        end
    end
end

local function cleanupJobVisuals()
    if isElement(parkingBlip) then
        destroyElement(parkingBlip)
        parkingBlip = nil
    end
    if isElement(returnMarker) then
        destroyElement(returnMarker)
        returnMarker = nil
    end
    if exports.gzl_radar and exports.gzl_radar.clearWaypoint then
        exports.gzl_radar:clearWaypoint()
    end
    JobHUD.clearJobData()
    Equipment.clear()
    CleaningGame.stop(false)
end

addEventHandler("onClientResourceStart", resourceRoot, function()
    createDepotElements()
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    cleanupJobVisuals()
    LobbyUI.close()
    if isElement(depotBlip) then destroyElement(depotBlip) end
end)

addEventHandler("onClientPlayerWasted", localPlayer, function()
    if CleaningGame.isActive() then
        CleaningGame.stop(false)
    end
end)

addEventHandler("onClientPlayerVehicleEnter", localPlayer, function(veh, seat)
    if seat == 0 then
        syncRadarRoute()
    end
end)

addEventHandler("onClientRender", root, function()
    JobHUD.render()
    Equipment.render()
    CleaningGame.render()
end)

addEventHandler("onClientKey", root, function(button, press)
    if not press then return end
    if CleaningGame.isActive() then
        if button == "escape" or button == "backspace" then
            cancelEvent()
            CleaningGame.stop(false)
            return
        end
        return
    end

    if button ~= "e" then return end
    if LobbyUI.isOpen() then return end

    local jobData = JobHUD.getJobData()
    if not jobData then
        -- Depo önünde sözleşme lobi menüsü açma
        local px, py, pz = getElementPosition(localPlayer)
        local d = Config.DepotLocation.marker
        local dist = getDistanceBetweenPoints3D(px, py, pz, d.x, d.y, d.z)
        if dist < 3.2 then
            triggerServerEvent("windowCleaning:requestOpenLobby", localPlayer)
            return
        end
    else
        -- 1. Araç bagajından ekipman alma / bırakma kontrolü
        if Equipment.isNearTrunk() then
            Equipment.toggleEquipment()
            return
        end

        -- 2. Yakındaki kirli vitrini temizleme kontrolü
        local nearbyWin = JobHUD.getNearbyWindow()
        if nearbyWin and not nearbyWin.isCleaned then
            CleaningGame.start(nearbyWin)
            return
        end

        -- 3. Tüm camlar bittiyse ve depoda aracı teslim ediyorsa
        local totalWins = jobData.totalWindows or 1
        local cleanedWins = jobData.cleanedWindows or 0
        if cleanedWins >= totalWins then
            local px, py, pz = getElementPosition(localPlayer)
            local ret = Config.DepotLocation.vehicleReturn
            local dist = getDistanceBetweenPoints3D(px, py, pz, ret.x, ret.y, ret.z)
            if dist <= 10.0 then
                triggerServerEvent("windowCleaning:finishJob", localPlayer)
                return
            end
        end
    end
end)

-- Sunucudan Gelen Olaylar (Network Events)
addEventHandler("onClientEvent", root, function() end)

addEvent("windowCleaning:clientOpenLobby", true)
addEventHandler("windowCleaning:clientOpenLobby", root, function(lobbyData, nearbyPlayers)
    LobbyUI.open(lobbyData, nearbyPlayers)
end)

addEvent("windowCleaning:clientUpdateLobby", true)
addEventHandler("windowCleaning:clientUpdateLobby", root, function(lobbyData, nearbyPlayers)
    LobbyUI.updateData(lobbyData, nearbyPlayers)
end)

addEvent("windowCleaning:clientJobStarted", true)
addEventHandler("windowCleaning:clientJobStarted", root, function(data, vehElement)
    cleanupJobVisuals()
    JobHUD.setJobData(data)
    Equipment.setVehicle(vehElement)
    if isElement(vehElement) then
        VehicleLivery.apply(vehElement)
    end
    syncRadarRoute()
    exports.aura_ui:uiToast("Sözleşme İmzalandı", data.buildingName .. " bölgesine hareket edin!", "info", 5000)
end)

addEvent("windowCleaning:clientSyncWindowCleaned", true)
addEventHandler("windowCleaning:clientSyncWindowCleaned", root, function(windowId, newCleanedCount)
    local jobData = JobHUD.getJobData()
    if not jobData or not jobData.windows then return end

    jobData.cleanedWindows = newCleanedCount
    local targetId = tonumber(windowId)
    for _, w in ipairs(jobData.windows) do
        if tonumber(w.id) == targetId then
            w.isCleaned = true
            break
        end
    end

    syncRadarRoute()

    if newCleanedCount >= (jobData.totalWindows or 1) then
        Audio.playContractComplete()
        exports.aura_ui:uiToast("Tüm Vitrinler Bitti!", "Ekipmanları araca koyup şirkete dönün ve aracı teslim edin.", "success", 6000)
    end
end)

addEvent("windowCleaning:clientJobFinished", true)
addEventHandler("windowCleaning:clientJobFinished", root, function(earnedMoney)
    cleanupJobVisuals()
    Audio.playContractComplete()
    local msg = string.format("Sözleşme tamamlandı! Hesabınıza $%s yatırıldı.", tostring(earnedMoney))
    exports.aura_ui:uiToast("İş Başarıyla Tamamlandı", msg, "success", 7000)
end)

addEvent("windowCleaning:clientJobCancelled", true)
addEventHandler("windowCleaning:clientJobCancelled", root, function(reason)
    cleanupJobVisuals()
    exports.aura_ui:uiToast("Görev İptal Edildi", reason or "Temizlik görevi sonlandırıldı.", "warning", 5000)
end)

-- Görevi İptal Etme Komutu
addCommandHandler("goreviptal", function()
    local jobData = JobHUD.getJobData()
    if not jobData then
        exports.aura_ui:uiToast("Bilgi", "Şu anda aktif bir temizlik sözleşmeniz bulunmuyor.", "info", 3000)
        return
    end
    triggerServerEvent("windowCleaning:requestCancelJob", localPlayer)
end)