local nearestATM = nil
local lastATMScan = nil
local scanInterval = 250
local screenW, screenH = guiGetScreenSize()

local validATMModels = {
    [ATMConfig.ModelID or 2942] = true,
    [2942] = true
}

local streamedObjects = {}
local function trackObject(element)
    if getElementType(element) == "object" and isElementStreamedIn(element) then
        streamedObjects[element] = true
    end
end
addEventHandler("onClientResourceStart", resourceRoot, function()
    for _, object in ipairs(getElementsByType("object", root, true)) do trackObject(object) end
end)
addEventHandler("onClientElementStreamIn", root, function() trackObject(source) end)
addEventHandler("onClientElementStreamOut", root, function() streamedObjects[source] = nil end)
addEventHandler("onClientElementDestroy", root, function() streamedObjects[source] = nil end)

local function getClosestATM()
    local px, py, pz = getElementPosition(localPlayer)
    local pDim = getElementDimension(localPlayer)
    local pInt = getElementInterior(localPlayer)
    local minDist = ATMConfig.InteractionDistance or 2.2
    local closest = nil

    for obj in pairs(streamedObjects) do
        if isElement(obj) and (validATMModels[getElementModel(obj)] or getElementData(obj, "isATM")) then
            if getElementDimension(obj) == pDim and getElementInterior(obj) == pInt then
                local ox, oy, oz = getElementPosition(obj)
                local dist = getDistanceBetweenPoints3D(px, py, pz, ox, oy, oz)
                if dist <= minDist then
                    minDist = dist
                    closest = { x = ox, y = oy, z = oz, element = obj, dist = dist }
                end
            end
        end
    end

    if not closest and pDim == 0 and pInt == 0 then
        local _, _, pRot = getElementRotation(localPlayer)
        local rad = math.rad(-pRot)
        local lookX = px + math.sin(rad) * 2.2
        local lookY = py + math.cos(rad) * 2.2
        local hit, _, _, _, hitElement, _, _, _, _, _, _, worldModelID, worldModelX, worldModelY, worldModelZ = processLineOfSight(
            px, py, pz + 0.3, lookX, lookY, pz + 0.3,
            true, true, false, true, true, false, false, false, localPlayer, true
        )
        if hit then
            if isElement(hitElement) and getElementType(hitElement) == "object" then
                local m = getElementModel(hitElement)
                if validATMModels[m] or getElementData(hitElement, "isATM") then
                    local ox, oy, oz = getElementPosition(hitElement)
                    local dist = getDistanceBetweenPoints3D(px, py, pz, ox, oy, oz)
                    if dist <= minDist then
                        closest = { x = ox, y = oy, z = oz, element = hitElement, dist = dist }
                    end
                end
            elseif worldModelID and validATMModels[worldModelID] and worldModelX then
                local dist = getDistanceBetweenPoints3D(px, py, pz, worldModelX, worldModelY, worldModelZ)
                if dist <= minDist then
                    closest = { x = worldModelX, y = worldModelY, z = worldModelZ, dist = dist }
                end
            end
        end
    end

    return closest
end

addEventHandler("onClientRender", root, function()
    if isATMOpen and isATMOpen() then
        nearestATM = nil
        lastATMScan = nil
        return
    end

    if isPedInVehicle(localPlayer) then
        nearestATM = nil
        lastATMScan = nil
        return
    end

    local now = getTickCount()
    if not lastATMScan or now < lastATMScan or now - lastATMScan >= scanInterval then
        nearestATM = getClosestATM()
        lastATMScan = now
    end
    if not nearestATM then return end

    local sx, sy = getScreenFromWorldPosition(nearestATM.x, nearestATM.y, nearestATM.z + 1.15, 0.05, false)
    if not sx or not sy then return end

    local fontTitle = exports.gzl_ui and exports.gzl_ui.getFont and exports.gzl_ui:getFont("bold", 11) or "default-bold"
    local fontDesc = exports.gzl_ui and exports.gzl_ui.getFont and exports.gzl_ui:getFont("medium", 10) or "default"

    local badgeW = 205
    local badgeH = 52
    local badgeX = math.floor(sx - badgeW / 2)
    local badgeY = math.floor(sy - badgeH / 2)

    if exports.gzl_ui and exports.gzl_ui.drawRoundedRectangle then
        exports.gzl_ui:drawRoundedRectangle(badgeX, badgeY, badgeW, badgeH, 12, tocolor(10, 15, 26, 245))
    else
        exports.aura_ui:uiDrawRectangle(badgeX, badgeY, badgeW, badgeH, tocolor(10, 15, 26, 245))
    end

    local keyW = 28
    local keyH = 28
    local keyX = badgeX + 12
    local keyY = badgeY + math.floor((badgeH - keyH) / 2)

    if exports.gzl_ui and exports.gzl_ui.drawRoundedRectangle then
        exports.gzl_ui:drawRoundedRectangle(keyX, keyY, keyW, keyH, 6, tocolor(56, 189, 248, 255))
    else
        exports.aura_ui:uiDrawRectangle(keyX, keyY, keyW, keyH, tocolor(56, 189, 248, 255))
    end
    exports.aura_ui:uiDrawText("E", keyX, keyY, keyX + keyW, keyY + keyH, tocolor(10, 15, 26, 255), 1, fontTitle, "center", "center")

    local textX = keyX + keyW + 10
    local textMaxX = badgeX + badgeW - 10
    exports.aura_ui:uiDrawText("ATM'yi Kullan", textX, badgeY + 7, textMaxX, badgeY + 28, tocolor(255, 255, 255, 255), 1, fontTitle, "left", "center", true)
    exports.aura_ui:uiDrawText("Bank of San Andreas", textX, badgeY + 27, textMaxX, badgeY + 45, tocolor(56, 189, 248, 255), 1, fontDesc, "left", "center", true)
end)

bindKey("e", "down", function()
    if isATMOpen and isATMOpen() then return end
    if isCursorShowing() then return end
    if exports.gzl_core and exports.gzl_core.isPlayerTyping and exports.gzl_core:isPlayerTyping() then return end
    if isPedInVehicle(localPlayer) then return end
    nearestATM = getClosestATM()
    lastATMScan = getTickCount()
    if nearestATM and not isPedInVehicle(localPlayer) then
        if openATM then
            openATM()
            playSoundFrontEnd(41)
        end
    end
end)