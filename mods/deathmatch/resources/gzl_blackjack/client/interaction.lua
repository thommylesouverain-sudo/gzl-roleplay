
Interaction = {}

local screenW, screenH = guiGetScreenSize()
local seatedTableId = nil
local seatedSeatIndex = nil
local cachedTableObj = nil
local isCasinoCamActive = true
local cameraInterpolating = false
local camStartPos = nil
local camEndPos = nil
local camInterpolateStart = 0

local isAltHolding = false
local aimedTableId = nil
local aimedSeatIndex = nil
local wasMouse1Pressed = false

local blackjackTables = {}

local function indexBlackjackTables()
    blackjackTables = {}
    for _, obj in ipairs(getElementsByType("object")) do
        if getElementData(obj, "blackjack:isTable") then
            blackjackTables[obj] = true
        end
    end
end
indexBlackjackTables()

addEventHandler("onClientResourceStart", resourceRoot, function()
    indexBlackjackTables()
end)

addEventHandler("onClientElementDataChange", root, function(dataName, oldValue)
    if dataName == "blackjack:isTable" and getElementType(source) == "object" then
        if getElementData(source, "blackjack:isTable") then
            blackjackTables[source] = true
        else
            blackjackTables[source] = nil
        end
    end
end)

addEventHandler("onClientElementDestroy", root, function()
    if blackjackTables[source] then
        blackjackTables[source] = nil
        if cachedTableObj == source then
            cachedTableObj = nil
        end
    end
end)

function Interaction.getTableObject(tableId)
    if isElement(cachedTableObj) and getElementData(cachedTableObj, "blackjack:tableId") == tableId then
        return cachedTableObj
    end
    for obj in pairs(blackjackTables) do
        if isElement(obj) and getElementData(obj, "blackjack:tableId") == tableId then
            cachedTableObj = obj
            return obj
        end
    end
    for _, obj in ipairs(getElementsByType("object")) do
        if getElementData(obj, "blackjack:tableId") == tableId then
            cachedTableObj = obj
            blackjackTables[obj] = true
            return obj
        end
    end
    return nil
end

function Interaction.isSeatOccupied(tableId, seatIndex)
    local players = getElementsByType("player", root, true)
    for i = 1, #players do
        local p = players[i]
        if getElementData(p, "blackjack:tableId") == tableId and getElementData(p, "blackjack:seatIndex") == seatIndex then
            return true, getPlayerName(p)
        end
    end
    return false, nil
end

local nearbyTable = nil
local nearbyTableObj = nil
local nearestTableDist = 999.0

local function checkNearbyTable()
    if seatedTableId or isPedInVehicle(localPlayer) then
        nearbyTable = nil
        nearbyTableObj = nil
        nearestTableDist = 999.0
        return
    end

    local px, py, pz = getElementPosition(localPlayer)
    local myInt = getElementInterior(localPlayer)
    local myDim = getElementDimension(localPlayer)

    local bestTable = nil
    local bestObj = nil
    local bestDist = 999.0

    for obj in pairs(blackjackTables) do
        if isElement(obj) and getElementInterior(obj) == myInt and getElementDimension(obj) == myDim then
            local tId = getElementData(obj, "blackjack:tableId")
            if tId then
                local ox, oy, oz = getElementPosition(obj)
                local d = getDistanceBetweenPoints3D(px, py, pz, ox, oy, oz)
                if d < 6.0 and d < bestDist then
                    bestDist = d
                    bestTable = tId
                    bestObj = obj
                end
            end
        elseif not isElement(obj) then
            blackjackTables[obj] = nil
        end
    end

    nearbyTable = bestTable
    nearbyTableObj = bestObj
    nearestTableDist = bestDist
end
setTimer(checkNearbyTable, 200, 0)
checkNearbyTable()

addEvent("blackjack:onJoinedTable", true)
addEventHandler("blackjack:onJoinedTable", resourceRoot, function(tableId, seatIndex)
    seatedTableId = tableId
    seatedSeatIndex = seatIndex
    isCasinoCamActive = true
    isAltHolding = false
    aimedTableId = nil
    aimedSeatIndex = nil

    toggleControl("fire", true)
    toggleControl("aim_weapon", true)
    toggleControl("action", true)

    cachedTableObj = Interaction.getTableObject(tableId)

    showCursor(true)
    setElementCollisionsEnabled(localPlayer, false)
    setElementFrozen(localPlayer, true)
    toggleAllControls(false, true, false)
    setPedAnimation(localPlayer, "PED", "SEAT_idle", -1, true, false, false, false)

    Interaction.startCameraTransition(tableId, seatIndex)
end)

addEvent("blackjack:onLeftTable", true)
addEventHandler("blackjack:onLeftTable", resourceRoot, function()
    seatedTableId = nil
    seatedSeatIndex = nil
    cachedTableObj = nil
    cameraInterpolating = false
    isAltHolding = false
    aimedTableId = nil
    aimedSeatIndex = nil

    setCameraTarget(localPlayer)
    showCursor(false)
    toggleAllControls(true, true, true)
    setElementCollisionsEnabled(localPlayer, true)
    setElementFrozen(localPlayer, false)
    setPedAnimation(localPlayer, false)
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    toggleControl("fire", true)
    toggleControl("aim_weapon", true)
    toggleControl("action", true)
    toggleAllControls(true, true, true)
    if seatedTableId or isAltHolding then
        setCameraTarget(localPlayer)
        showCursor(false)
        setElementCollisionsEnabled(localPlayer, true)
        setElementFrozen(localPlayer, false)
        setPedAnimation(localPlayer, false)
    end
    for id, sub in pairs(rounded or {}) do
        for w, sub2 in pairs(sub) do
            for h, svg in pairs(sub2) do
                if isElement(svg) then destroyElement(svg) end
            end
        end
    end
    rounded = {}
end)

addEventHandler("onClientPlayerWasted", localPlayer, function()
    toggleControl("fire", true)
    toggleControl("aim_weapon", true)
    toggleControl("action", true)
    toggleAllControls(true, true, true)
    if seatedTableId or isAltHolding then
        seatedTableId = nil
        seatedSeatIndex = nil
        cachedTableObj = nil
        cameraInterpolating = false
        isAltHolding = false
        aimedTableId = nil
        aimedSeatIndex = nil
        setCameraTarget(localPlayer)
        showCursor(false)
        setElementFrozen(localPlayer, false)
    end
end)

function Interaction.notify(message, msgType)
    local gzlUi = getResourceFromName("gzl_ui")
    if gzlUi and getResourceState(gzlUi) == "running" then
        exports.gzl_ui:showToast(message, msgType or "info")
    else
        outputChatBox("[BLACKJACK] " .. message, 212, 175, 55)
    end
end

addEvent("blackjack:notify", true)
addEventHandler("blackjack:notify", resourceRoot, function(message, msgType)
    Interaction.notify(message, msgType)
end)

function Interaction.getSeatWorldPosition(tableObj, seatIndex)
    if not isElement(tableObj) then return 0, 0, 0, 0 end

    local off = Config.SeatOffsets[seatIndex]
    if not off then return 0, 0, 0, 0 end

    local mat = getElementMatrix(tableObj)
    local wx = off.x * mat[1][1] + off.y * mat[2][1] + off.z * mat[3][1] + mat[4][1]
    local wy = off.x * mat[1][2] + off.y * mat[2][2] + off.z * mat[3][2] + mat[4][2]
    local wz = off.x * mat[1][3] + off.y * mat[2][3] + off.z * mat[3][3] + mat[4][3]

    local _, _, rotZ = getElementRotation(tableObj)
    local seatRot = (rotZ + off.rot) % 360

    return wx, wy, wz, seatRot
end

function Interaction.getSeatedCameraCoords(tableObj, seatIndex)
    if not isElement(tableObj) then return nil end

    local mat = getElementMatrix(tableObj)
    seatIndex = seatIndex or seatedSeatIndex or 2
    local sCam = (Config.CameraOffsets.seats and Config.CameraOffsets.seats[seatIndex]) or Config.CameraOffsets.default

    local cx = sCam.camX * mat[1][1] + sCam.camY * mat[2][1] + sCam.camZ * mat[3][1] + mat[4][1]
    local cy = sCam.camX * mat[1][2] + sCam.camY * mat[2][2] + sCam.camZ * mat[3][2] + mat[4][2]
    local cz = sCam.camX * mat[1][3] + sCam.camY * mat[2][3] + sCam.camZ * mat[3][3] + mat[4][3]

    local tx = sCam.targetX * mat[1][1] + sCam.targetY * mat[2][1] + sCam.targetZ * mat[3][1] + mat[4][1]
    local ty = sCam.targetX * mat[1][2] + sCam.targetY * mat[2][2] + sCam.targetZ * mat[3][2] + mat[4][2]
    local tz = sCam.targetX * mat[1][3] + sCam.targetY * mat[2][3] + sCam.targetZ * mat[3][3] + mat[4][3]

    return cx, cy, cz, tx, ty, tz, sCam.fov or 66
end

function Interaction.startCameraTransition(tableId, seatIndex)
    local tableObj = Interaction.getTableObject(tableId)
    if not tableObj then return end

    local curX, curY, curZ, lookX, lookY, lookZ = getCameraMatrix()
    local cx, cy, cz, tx, ty, tz, fov = Interaction.getSeatedCameraCoords(tableObj, seatIndex)
    if not cx then return end

    camStartPos = { cx = curX, cy = curY, cz = curZ, tx = lookX, ty = lookY, tz = lookZ, fov = 70 }
    camEndPos = { cx = cx, cy = cy, cz = cz, tx = tx, ty = ty, tz = tz, fov = fov or 66 }
    camInterpolateStart = getTickCount()
    cameraInterpolating = true
end

addEventHandler("onClientPreRender", root, function()
    if not seatedTableId then return end
    if not isCasinoCamActive then return end

    local tableObj = cachedTableObj or Interaction.getTableObject(seatedTableId)
    if not isElement(tableObj) then return end

    if cameraInterpolating and camStartPos and camEndPos then
        local now = getTickCount()
        local elapsed = (now - camInterpolateStart) / 1200.0
        local progress = math.min(1.0, elapsed)

        local cx, cy, cz = interpolateBetween(camStartPos.cx, camStartPos.cy, camStartPos.cz,
            camEndPos.cx, camEndPos.cy, camEndPos.cz, progress, "InOutQuad")
        local tx, ty, tz = interpolateBetween(camStartPos.tx, camStartPos.ty, camStartPos.tz,
            camEndPos.tx, camEndPos.ty, camEndPos.tz, progress, "InOutQuad")
        local fov = interpolateBetween(camStartPos.fov, 0, 0, camEndPos.fov, 0, 0, progress, "InOutQuad")

        setCameraMatrix(cx, cy, cz, tx, ty, tz, 0, fov)

        if progress >= 1.0 then
            cameraInterpolating = false
        end
    else
        local cx, cy, cz, tx, ty, tz, fov = Interaction.getSeatedCameraCoords(tableObj, seatedSeatIndex)
        if cx then
            setCameraMatrix(cx, cy, cz, tx, ty, tz, 0, fov)
        end
    end
end)

addEventHandler("onClientKey", root, function(button, press)

    if isAltHolding and (button == "mouse1" or button == "fire") then
        cancelEvent()
        if press and aimedTableId and aimedSeatIndex then
            local isOcc, occName = Interaction.isSeatOccupied(aimedTableId, aimedSeatIndex)
            if not isOcc then
                triggerServerEvent("blackjack:requestJoinTable", resourceRoot, aimedTableId, aimedSeatIndex)
            else
                Interaction.notify("Bu koltuk dolu!", "error")
            end
        end
        return
    end

    if not press then return end

    if seatedTableId then

        if button == "f" or button == "escape" then
            triggerServerEvent("blackjack:requestLeaveTable", resourceRoot)
            cancelEvent()
            return
        end

        if button == "v" then
            isCasinoCamActive = not isCasinoCamActive
            if not isCasinoCamActive then
                setCameraTarget(localPlayer)
            else
                Interaction.startCameraTransition(seatedTableId, seatedSeatIndex)
            end
            cancelEvent()
            return
        end
        return
    end

    if button == "e" and not isAltHolding then
        if isPedInVehicle(localPlayer) then return end

        local px, py, pz = getElementPosition(localPlayer)
        local myInt = getElementInterior(localPlayer)
        local myDim = getElementDimension(localPlayer)
        local nearestTable = nil
        local nearestSeat = nil
        local minDist = 2.8

        for obj in pairs(blackjackTables) do
            if isElement(obj) and getElementInterior(obj) == myInt and getElementDimension(obj) == myDim then
                local tId = getElementData(obj, "blackjack:tableId")
                if tId then
                    for sIdx = 1, 4 do
                        if not Interaction.isSeatOccupied(tId, sIdx) then
                            local wx, wy, wz = Interaction.getSeatWorldPosition(obj, sIdx)
                            local dist = getDistanceBetweenPoints3D(px, py, pz, wx, wy, wz)
                            if dist < minDist then
                                minDist = dist
                                nearestTable = tId
                                nearestSeat = sIdx
                            end
                        end
                    end
                end
            end
        end

        if nearestTable and nearestSeat then
            triggerServerEvent("blackjack:requestJoinTable", resourceRoot, nearestTable, nearestSeat)
        end
    end
end)

rounded = {}
local function dxDrawRoundedRectangle(id, x, y, w, h, radius, color, post)
    if not id then id = "def" end
    w = math.max(1, math.floor(w))
    h = math.max(1, math.floor(h))
    radius = math.max(0, math.min(math.floor(radius or 0), math.floor(w * 0.5), math.floor(h * 0.5)))

    if not rounded[id] then rounded[id] = {} end
    if not rounded[id][w] then rounded[id][w] = {} end
    if not rounded[id][w][h] then
        local path = string.format([[<svg width="%s" height="%s" viewBox="0 0 %s %s" fill="none" xmlns="http://www.w3.org/2000/svg"><rect opacity="1" width="%s" height="%s" rx="%s" fill="#FFFFFF"/></svg>]], w, h, w, h, w, h, radius)
        rounded[id][w][h] = svgCreate(w, h, path)
    end
    if rounded[id][w][h] then
        dxDrawImage(x, y, w, h, rounded[id][w][h], 0, 0, 0, color, (post or false))
    end
end

local function drawGlassCard(id, x, y, w, h, radius, bgCol, borderCol, accentCol, postGUI)
    if type(id) == "number" then
        postGUI = accentCol
        accentCol = borderCol
        borderCol = bgCol
        bgCol = radius
        radius = h
        h = w
        w = y
        y = x
        x = id
        id = "glass_card"
    end
    radius = radius or 10

    dxDrawRoundedRectangle(id .. "_shd", x - 2, y + 2, w + 4, h + 4, radius + 2, tocolor(0, 0, 0, 85), postGUI)

    if borderCol then
        dxDrawRoundedRectangle(id .. "_brd", x, y, w, h, radius, borderCol, postGUI)
        dxDrawRoundedRectangle(id .. "_bg", x + 1, y + 1, w - 2, h - 2, math.max(0, radius - 1), bgCol or tocolor(10, 14, 24, 230), postGUI)
    else
        dxDrawRoundedRectangle(id .. "_bg", x, y, w, h, radius, bgCol or tocolor(10, 14, 24, 230), postGUI)
    end

    if accentCol then
        dxDrawRoundedRectangle(id .. "_acc", x + 2, y + 4, 3, h - 8, 2, accentCol, postGUI)
    end
end

addEventHandler("onClientRender", root, function()
    if seatedTableId then return end
    if isPedInVehicle(localPlayer) then return end

    if not nearbyTable or not isElement(nearbyTableObj) or nearestTableDist > 4.8 then
        if isAltHolding then
            isAltHolding = false
            aimedTableId = nil
            aimedSeatIndex = nil
            toggleControl("fire", true)
            toggleControl("aim_weapon", true)
            toggleControl("action", true)
        end
        wasMouse1Pressed = false
        return
    end

    local px, py, pz = getElementPosition(localPlayer)
    local ox, oy, oz = getElementPosition(nearbyTableObj)
    local curDist = getDistanceBetweenPoints3D(px, py, pz, ox, oy, oz)
    if curDist > 4.8 then
        nearestTableDist = curDist
        if isAltHolding then
            isAltHolding = false
            aimedTableId = nil
            aimedSeatIndex = nil
            toggleControl("fire", true)
            toggleControl("aim_weapon", true)
            toggleControl("action", true)
        end
        wasMouse1Pressed = false
        return
    end
    nearestTableDist = curDist

    local isAltPressed = getKeyState("lalt") or getKeyState("ralt") or getKeyState("alt")
    if isAltPressed ~= isAltHolding then
        isAltHolding = isAltPressed
        toggleControl("fire", not isAltHolding)
        toggleControl("aim_weapon", not isAltHolding)
        toggleControl("action", not isAltHolding)
        if not isAltHolding then
            aimedTableId = nil
            aimedSeatIndex = nil
        end
    end

    local fontTitle = FontManager.get("bold", 11)
    local fontSub = FontManager.get("medium", 9)
    local fontHint = FontManager.get("medium", 10)

    local targetX, targetY = screenW * 0.5, screenH * 0.5
    local hasCursor = isCursorShowing()
    if hasCursor then
        local rawX, rawY = getCursorPosition()
        targetX, targetY = rawX * screenW, rawY * screenH
    end

    if isAltHolding then
        local bestSeatIdx = nil
        local bestDist = 180.0
        local bestScreenX, bestScreenY = nil, nil

        for sIdx = 1, 4 do
            local wx, wy, wz = Interaction.getSeatWorldPosition(nearbyTableObj, sIdx)
            local seatDist = getDistanceBetweenPoints3D(px, py, pz, wx, wy, wz)

            if seatDist < 4.5 then
                local sx, sy = getScreenFromWorldPosition(wx, wy, wz + 0.35, 0.05)
                if sx and sy then
                    local d = math.sqrt((sx - targetX)^2 + (sy - targetY)^2)
                    if d < bestDist then
                        bestDist = d
                        bestSeatIdx = sIdx
                        bestScreenX = sx
                        bestScreenY = sy
                    end
                end
            end
        end

        local isTargetingSeat = (bestSeatIdx ~= nil)
        aimedSeatIndex = bestSeatIdx
        aimedTableId = isTargetingSeat and nearbyTable or nil

        local eyeRadius = isTargetingSeat and 14 or 8
        local eyeAlpha = isTargetingSeat and 255 or 180
        local eyeColor = isTargetingSeat and tocolor(212, 175, 55, eyeAlpha) or tocolor(255, 255, 255, eyeAlpha)
        local pupilColor = isTargetingSeat and tocolor(255, 255, 255, 255) or tocolor(255, 255, 255, 220)

        dxDrawCircle(targetX, targetY, eyeRadius, 0, 360, eyeColor, eyeColor, 32, 1)
        dxDrawCircle(targetX, targetY, 3, 0, 360, pupilColor, pupilColor, 16, 1)

        if isTargetingSeat then
            local isOcc, occName = Interaction.isSeatOccupied(nearbyTable, bestSeatIdx)
            local cardW, cardH = 190, 56
            local cardX = targetX + 24
            local cardY = targetY - cardH * 0.5

            if cardX + cardW > screenW - 10 then cardX = targetX - cardW - 24 end
            if cardY < 10 then cardY = 10 end
            if cardY + cardH > screenH - 10 then cardY = screenH - cardH - 10 end

            local borderCol = tocolor(212, 175, 55, 220)
            local accentCol = isOcc and tocolor(239, 68, 68, 255) or tocolor(212, 175, 55, 255)
            drawGlassCard(cardX, cardY, cardW, cardH, 8, tocolor(10, 14, 24, 235), borderCol, accentCol)

            local titleText = string.format("♦ KOLTUK %d", bestSeatIdx)
            exports.aura_ui:uiDrawText(titleText, cardX + 14, cardY + 8, cardX + cardW - 8, cardY + 28,
                tocolor(212, 175, 55, 255), 1.0, fontTitle, "left", "center")

            local subText = isOcc and ("👤 " .. (occName or "Dolu")) or "✦ [Sol Tık] Masaya Otur"
            local subColor = isOcc and tocolor(248, 113, 113, 230) or tocolor(80, 220, 100, 255)
            exports.aura_ui:uiDrawText(subText, cardX + 14, cardY + 28, cardX + cardW - 8, cardY + 48,
                subColor, 1.0, fontSub, "left", "center")

            if bestScreenX and bestScreenY then
                dxDrawCircle(bestScreenX, bestScreenY, 6, 0, 360, tocolor(212, 175, 55, 200), tocolor(212, 175, 55, 200), 16, 1)
            end

            if getKeyState("mouse1") and not wasMouse1Pressed then
                wasMouse1Pressed = true
                if not isOcc then
                    triggerServerEvent("blackjack:requestJoinTable", resourceRoot, nearbyTable, bestSeatIdx)
                else
                    Interaction.notify("Bu koltuk dolu!", "error")
                end
            end
        end

    else
        aimedSeatIndex = nil
        aimedTableId = nil
        if nearestTableDist < 3.8 then
            local hintW, hintH = 360, 34
            local hintX = (screenW - hintW) * 0.5
            local hintY = screenH - 68

            drawGlassCard(hintX, hintY, hintW, hintH, 17, tocolor(10, 14, 24, 210), tocolor(212, 175, 55, 120), tocolor(212, 175, 55, 255))
            exports.aura_ui:uiDrawText("✦  [L-ALT] Masaya Bak & Koltuk Seç  •  [E] Hızlı Otur",
                hintX, hintY, hintX + hintW, hintY + hintH,
                tocolor(255, 255, 255, 230), 1.0, fontHint, "center", "center")
        end
    end

    if not getKeyState("mouse1") then
        wasMouse1Pressed = false
    end
end)

function Interaction.getSeatedData()
    return seatedTableId, seatedSeatIndex
end