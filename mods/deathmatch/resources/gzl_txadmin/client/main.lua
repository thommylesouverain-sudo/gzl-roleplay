local screenW, screenH = guiGetScreenSize()
local centerW, centerH = math.floor(screenW * 0.5), math.floor(screenH * 0.5)
local baseW, baseH = 1920, 1080
local scale = math.min(1.15, math.max(0.80, math.min(screenW / baseW, screenH / baseH)))

local S = {
    isOpen = false,
    currentTab = "ANA MENÜ",
    selectedIndex = 1,
    playerModes = {"NoClip", "Ölümsüzlük", "Süper Zıplama", "Normal"},
    playerModeIndex = 1,
    teleportIndex = 1,
    vehicleIndex = 1,
    healOptions = {
        { name = "Kendimi", target = "myself" },
        { name = "Herkesi", target = "all" },
        { name = "Canlandır", target = "revive" },
        { name = "Kıyafet Temizle", target = "clean" }
    },
    healIndex = 1,
    serverTimeOptions = {"12:00 (Gündüz)", "00:00 (Gece)", "06:00 (Şafak)", "18:00 (Akşam)"},
    serverTimeIndex = 1,
    serverWeatherOptions = {"Güneşli", "Açık", "Yağmurlu", "Sisli", "Fırtına"},
    serverWeatherIndex = 1,
    serverHealOptions = {"İyileştir", "Canlandır"},
    serverHealIndex = 1,
    txadminSelectedIndex = 1,
    isNoClipActive = false,
    isGodActive = false,
    isSuperJumpActive = false,
    showPlayerIDs = false,
    flySpeed = 1.4,
    flyFastMultiplier = 3.5,
    flySlowMultiplier = 0.25,
    activeModal = nil,
    modalInputText = "",
    playerList = {},
    selectedPlayerIndex = 1,
    playerSearchQuery = "",
    isSearchingPlayers = false,
    activePlayerDialog = nil,
    playerDialogTab = "İşlemler",
    playerNoteInput = "",
    banReasonInput = "Kural ihlali",
    banDurations = {
        { label = "2 saat", duration = 7200 },
        { label = "1 gün", duration = 86400 },
        { label = "3 gün", duration = 259200 },
        { label = "1 hafta", duration = 604800 },
        { label = "Kalıcı", duration = 0 }
    },
    banDurationIndex = 1,
    isBanDropdownOpen = false,
    toastMessage = nil,
    toastTick = 0,
    activeAnnouncement = nil,
    announcementStartTick = 0,
    announcementDuration = 8500,
    activeDirectMessage = nil,
    dmStartTick = 0,
    dmDuration = 10000,
    activeWarning = nil,
    warnStartTick = 0,
    warnSpaceHoldStart = 0,
    warnRequiredHoldTime = 3000,
    noclipRotX = 0,
    noclipRotY = 0,
    noclipMouseSensitivity = 0.18,
    isRenderAttached = false,
    isPreRenderAttached = false
}

local fonts = {}

local function getUIFont(style, size)
    size = math.max(8, math.floor(size * scale))
    if exports.gzl_ui and exports.gzl_ui.getFont then
        return exports.gzl_ui:getFont(style, size)
    end
    if style == "bold" or style == "heavy" then
        return "default-bold"
    end
    return "default"
end

local function initCachedFonts()
    fonts.brand = getUIFont("heavy", 17)
    fonts.ver = getUIFont("bold", 8)
    fonts.tab = getUIFont("bold", 9.5)
    fonts.item = getUIFont("semibold", 10.5)
    fonts.val = getUIFont("medium", 10)
    fonts.arrow = getUIFont("bold", 10.5)
    fonts.title = getUIFont("heavy", 13.5)
    fonts.sub = getUIFont("medium", 9.5)
    fonts.tiny = getUIFont("bold", 8)
    fonts.tag = getUIFont("heavy", 10.5)
    fonts.toast = getUIFont("semibold", 9.5)
    fonts.dialogTitle = getUIFont("bold", 11.5)
    fonts.sideTab = getUIFont("medium", 9)
    fonts.cat = getUIFont("semibold", 8)
    fonts.btn = getUIFont("bold", 7.5)
end
initCachedFonts()
addEventHandler("onClientRestore", root, initCachedFonts)

local renderTxAdmin

local function syncRenderState()
    local now = getTickCount()
    local isAnnounceActive = S.activeAnnouncement and (now - S.announcementStartTick < S.announcementDuration)
    local isDMActive = S.activeDirectMessage and (now - S.dmStartTick < S.dmDuration)
    local isWarningActive = (S.activeWarning ~= nil)
    local isToastActive = S.toastMessage and (now - S.toastTick < 3500)

    local needRender = S.isOpen or S.showPlayerIDs or isAnnounceActive or isDMActive or isWarningActive or isToastActive
    if needRender and not S.isRenderAttached then
        addEventHandler("onClientRender", root, renderTxAdmin)
        S.isRenderAttached = true
    elseif not needRender and S.isRenderAttached then
        removeEventHandler("onClientRender", root, renderTxAdmin)
        S.isRenderAttached = false
    end
end

local function showToast(text)
    S.toastMessage = text
    S.toastTick = getTickCount()
    syncRenderState()
end

addEvent("txadmin:displayAnnouncement", true)
addEventHandler("txadmin:displayAnnouncement", root, function(adminName, msg)
    S.activeAnnouncement = {
        admin = tostring(adminName or "Yetkili"),
        message = tostring(msg or "")
    }
    S.announcementStartTick = getTickCount()
    playSoundFrontEnd(40)
    syncRenderState()
end)

addEvent("txadmin:displayDirectMessage", true)
addEventHandler("txadmin:displayDirectMessage", root, function(adminName, msg)
    S.activeDirectMessage = {
        admin = tostring(adminName or "Yetkili"),
        message = tostring(msg or "")
    }
    S.dmStartTick = getTickCount()
    playSoundFrontEnd(40)
    syncRenderState()
end)

addEvent("txadmin:displayWarning", true)
addEventHandler("txadmin:displayWarning", root, function(adminName, reason)
    S.activeWarning = {
        admin = tostring(adminName or "Yetkili"),
        reason = tostring(reason or "Kural ihlali")
    }
    S.warnStartTick = getTickCount()
    S.warnSpaceHoldStart = 0
    playSoundFrontEnd(4)
    syncRenderState()
end)

local function isMouseInArea(x, y, w, h)
    if not isCursorShowing() then return false end
    local cx, cy = getCursorPosition()
    if not cx or not cy then return false end
    cx, cy = cx * screenW, cy * screenH
    return (cx >= x and cx <= x + w and cy >= y and cy <= y + h)
end

local function playElectricEffect(x, y, z)
    if not x or not y or not z then return end
    for i = 1, 3 do
        fxAddSparks(x, y, z + 0.8, 0, 0, 1.8, 3.5, 35, 0, 0, 0, true, 2.5, 1.2)
        fxAddSparks(x, y, z + 0.2, 0, 0, 1.0, 2.5, 25, 0, 0, 0, true, 2.0, 1.0)
    end
    playSoundFrontEnd(37)
    local light = createLight(0, x, y, z + 0.5, 4.5, 0, 245, 160)
    if isElement(light) then
        setTimer(function()
            if isElement(light) then destroyElement(light) end
        end, 280, 1)
    end
end

addEvent("txadmin:playElectricSparks", true)
addEventHandler("txadmin:playElectricSparks", root, function(x, y, z)
    playElectricEffect(x, y, z)
end)

local mouseFrameDelay = 0

local function handleNoClipCursorMove(rx, ry, ax, ay)
    if not S.isNoClipActive or isCursorShowing() or isChatBoxInputActive() or isMainMenuActive() then
        mouseFrameDelay = 5
        return
    elseif mouseFrameDelay > 0 then
        mouseFrameDelay = mouseFrameDelay - 1
        return
    end

    local diffX = ax - centerW
    local diffY = ay - centerH

    S.noclipRotX = S.noclipRotX + diffX * S.noclipMouseSensitivity
    S.noclipRotY = math.max(-88, math.min(88, S.noclipRotY - diffY * S.noclipMouseSensitivity))
end

local function handleNoClipMovement(dt)
    local delta = dt / 1000
    local speed = S.flySpeed * 45 * delta

    if getKeyState("lshift") or getKeyState("rshift") then
        speed = speed * S.flyFastMultiplier
    elseif getKeyState("lalt") or getKeyState("ralt") then
        speed = speed * S.flySlowMultiplier
    end

    local radX = math.rad(S.noclipRotX)
    local radY = math.rad(S.noclipRotY)
    local cosY = math.cos(radY)
    local sinY = math.sin(radY)
    local cosX = math.cos(radX)
    local sinX = math.sin(radX)

    local fx = cosY * sinX
    local fy = cosY * cosX
    local fz = sinY
    local rx = fy
    local ry = -fx

    local moveX, moveY, moveZ = 0, 0, 0

    if getKeyState("w") then
        moveX = moveX + fx * speed
        moveY = moveY + fy * speed
        moveZ = moveZ + fz * speed
    end
    if getKeyState("s") then
        moveX = moveX - fx * speed
        moveY = moveY - fy * speed
        moveZ = moveZ - fz * speed
    end
    if getKeyState("d") then
        moveX = moveX + rx * speed
        moveY = moveY + ry * speed
    end
    if getKeyState("a") then
        moveX = moveX - rx * speed
        moveY = moveY - ry * speed
    end
    if getKeyState("space") or getPedControlState(localPlayer, "jump") then
        moveZ = moveZ + speed
    end
    if getKeyState("lctrl") or getKeyState("c") or getPedControlState(localPlayer, "crouch") then
        moveZ = moveZ - speed
    end

    local targetElem = getPedOccupiedVehicle(localPlayer) or localPlayer
    local px, py, pz = getElementPosition(targetElem)

    local nextX = px + moveX
    local nextY = py + moveY
    local nextZ = pz + moveZ

    setElementPosition(targetElem, nextX, nextY, nextZ, false)
    setElementVelocity(targetElem, 0, 0, 0)
    setElementRotation(targetElem, 0, 0, -S.noclipRotX)
    setElementAlpha(targetElem, 0)

    local eyeZ = isPedInVehicle(localPlayer) and (nextZ + 0.45) or (nextZ + 0.68)
    local lookX = nextX + fx * 5.0
    local lookY = nextY + fy * 5.0
    local lookZ = eyeZ + fz * 5.0
    setCameraMatrix(nextX, nextY, eyeZ, lookX, lookY, lookZ, 0, 75)
end

function toggleNoClip(forcedState)
    if forcedState ~= nil then
        S.isNoClipActive = forcedState
    else
        S.isNoClipActive = not S.isNoClipActive
    end

    local targetElem = getPedOccupiedVehicle(localPlayer) or localPlayer
    setElementCollisionsEnabled(targetElem, not S.isNoClipActive)
    setElementFrozen(targetElem, S.isNoClipActive)

    local px, py, pz = getElementPosition(targetElem)
    playElectricEffect(px, py, pz)
    triggerServerEvent("txadmin:setNoClipState", localPlayer, S.isNoClipActive)

    if S.isNoClipActive then
        local cx, cy, cz, lx, ly, lz = getCameraMatrix()
        local dx = lx - cx
        local dy = ly - cy
        local dz = lz - cz
        local len = math.sqrt(dx * dx + dy * dy)
        S.noclipRotX = math.deg(math.atan2(dx, dy))
        S.noclipRotY = math.deg(math.atan2(dz, len))

        setElementPosition(targetElem, px, py, pz + 0.4, false)
        setElementVelocity(targetElem, 0, 0, 0)
        setElementAlpha(targetElem, 0)
        setElementAlpha(localPlayer, 0)
        mouseFrameDelay = 5

        if not S.isPreRenderAttached then
            addEventHandler("onClientPreRender", root, handleNoClipMovement)
            addEventHandler("onClientCursorMove", root, handleNoClipCursorMove)
            S.isPreRenderAttached = true
        end
        outputChatBox("#00f5a0[txAdmin]#ffffff NoClip (First-Person): #00f5a0AÇIK #ffffff(Fare: Bakış | WASD: Uçuş | Space: Yukarı | LCtrl: Aşağı | Shift: Turbo)", 255, 255, 255, true)
    else
        if S.isPreRenderAttached then
            removeEventHandler("onClientPreRender", root, handleNoClipMovement)
            removeEventHandler("onClientCursorMove", root, handleNoClipCursorMove)
            S.isPreRenderAttached = false
        end
        setCameraTarget(localPlayer)
        setElementAlpha(targetElem, 255)
        setElementAlpha(localPlayer, 255)
        setElementPosition(targetElem, px, py, pz, false)
        outputChatBox("#00f5a0[txAdmin]#ffffff NoClip: #f43f5eKAPALI (Görünür)", 255, 255, 255, true)
    end
end

function toggleGodMode(forcedState)
    if forcedState ~= nil then
        S.isGodActive = forcedState
    else
        S.isGodActive = not S.isGodActive
    end
    outputChatBox("#00f5a0[txAdmin]#ffffff Ölümsüzlük Modu: " .. (S.isGodActive and "#00f5a0AÇIK" or "#f43f5eKAPALI"), 255, 255, 255, true)
end

function togglePlayerIDs(forcedState)
    if forcedState ~= nil then
        S.showPlayerIDs = forcedState
    else
        S.showPlayerIDs = not S.showPlayerIDs
    end
    if S.showPlayerIDs then
        showToast("Yakındaki oyuncu ID'leri gösteriliyor")
    else
        showToast("Yakındaki oyuncu ID'leri gizlendi")
    end
    outputChatBox("#00f5a0[txAdmin]#ffffff Oyuncu ID Göstergesi: " .. (S.showPlayerIDs and "#00f5a0AÇIK" or "#f43f5eKAPALI"), 255, 255, 255, true)
    syncRenderState()
end

addEventHandler("onClientResourceStop", resourceRoot, function()
    if S.isNoClipActive then
        local targetElem = getPedOccupiedVehicle(localPlayer) or localPlayer
        setElementCollisionsEnabled(targetElem, true)
        setElementFrozen(targetElem, false)
        setElementAlpha(targetElem, 255)
        setElementAlpha(localPlayer, 255)
        setCameraTarget(localPlayer)
        triggerServerEvent("txadmin:setNoClipState", localPlayer, false)
    end
    if S.isPreRenderAttached then
        removeEventHandler("onClientPreRender", root, handleNoClipMovement)
        removeEventHandler("onClientCursorMove", root, handleNoClipCursorMove)
        S.isPreRenderAttached = false
    end
    if S.isRenderAttached then
        removeEventHandler("onClientRender", root, renderTxAdmin)
        S.isRenderAttached = false
    end
    showCursor(false)
end)

addEventHandler("onClientPlayerDamage", localPlayer, function()
    if S.isGodActive or S.isNoClipActive then
        cancelEvent()
    end
end)

local function openModal(modalType, placeholder)
    S.activeModal = modalType
    S.modalInputText = placeholder or ""
end

local function executeMainOption(index)
    playSoundFrontEnd(40)
    if index == 1 then
        local mode = S.playerModes[S.playerModeIndex]
        if mode == "NoClip" then
            toggleNoClip()
            if S.isNoClipActive and S.isOpen then
                toggleTxAdmin()
            end
        elseif mode == "Ölümsüzlük" then
            toggleGodMode()
        elseif mode == "Süper Zıplama" then
            S.isSuperJumpActive = not S.isSuperJumpActive
            outputChatBox("#00f5a0[txAdmin]#ffffff Süper Zıplama: " .. (S.isSuperJumpActive and "#00f5a0AÇIK" or "#f43f5eKAPALI"), 255, 255, 255, true)
        elseif mode == "Normal" then
            if S.isNoClipActive then toggleNoClip(false) end
            if S.isGodActive then toggleGodMode(false) end
            S.isSuperJumpActive = false
            outputChatBox("#00f5a0[txAdmin]#ffffff Normal moda dönüldü.", 255, 255, 255, true)
        end
    elseif index == 2 then
        local loc = Config.TeleportLocations[S.teleportIndex]
        if loc.type == "waypoint" then
            local wp = nil
            if exports.gzl_radar and exports.gzl_radar.getWaypoint then
                wp = exports.gzl_radar:getWaypoint()
            end
            if wp and wp.x and wp.y then
                triggerServerEvent("txadmin:teleportCoords", localPlayer, wp.x, wp.y, 25.0)
            else
                outputChatBox("#f43f5e[txAdmin]#ffffff Aktif bir GPS hedefiniz (Waypoint) bulunamadı!", 255, 255, 255, true)
            end
        elseif loc.type == "custom" then
            openModal("teleport", "340, 480, 12")
        else
            triggerServerEvent("txadmin:teleportCoords", localPlayer, loc.x, loc.y, loc.z)
        end
    elseif index == 3 then
        local opt = Config.Vehicles[S.vehicleIndex]
        if opt.action == "custom" then
            openModal("spawnVehicle", "")
        elseif opt.action == "spawn" then
            triggerServerEvent("txadmin:spawnVehicle", localPlayer, opt.model)
        elseif opt.action == "fix" then
            triggerServerEvent("txadmin:fixVehicle", localPlayer)
        elseif opt.action == "delete" then
            triggerServerEvent("txadmin:deleteVehicle", localPlayer)
        elseif opt.action == "upgrade" then
            triggerServerEvent("txadmin:upgradeVehicle", localPlayer)
        elseif opt.action == "boost" then
            local veh = getPedOccupiedVehicle(localPlayer)
            if veh then
                local vx, vy, vz = getElementVelocity(veh)
                setElementVelocity(veh, vx * 1.8, vy * 1.8, vz + 0.1)
                outputChatBox("#00f5a0[txAdmin]#ffffff Araç hızlandırıldı!", 255, 255, 255, true)
            end
        elseif opt.action == "clean" then
            local veh = getPedOccupiedVehicle(localPlayer)
            if veh then
                fixVehicle(veh)
                outputChatBox("#00f5a0[txAdmin]#ffffff Araç temizlendi.", 255, 255, 255, true)
            end
        end
    elseif index == 4 then
        local opt = S.healOptions[S.healIndex]
        triggerServerEvent("txadmin:healAction", localPlayer, opt.target)
    elseif index == 5 then
        openModal("announcement", "")
    elseif index == 6 then
        local px, py, pz = getElementPosition(localPlayer)
        triggerServerEvent("txadmin:resetWorldArea", localPlayer, px, py, pz, 300)
    elseif index == 7 then
        togglePlayerIDs()
    end
end

local function executeTxAdminOption(index)
    playSoundFrontEnd(40)
    if index == 1 then
        triggerServerEvent("txadmin:setServerTime", localPlayer, S.serverTimeIndex)
    elseif index == 2 then
        triggerServerEvent("txadmin:setServerWeather", localPlayer, S.serverWeatherIndex)
    elseif index == 3 then
        triggerServerEvent("txadmin:serverAction", localPlayer, "clearVehicles")
    elseif index == 4 then
        triggerServerEvent("txadmin:healAction", localPlayer, S.serverHealIndex == 1 and "all" or "all_revive")
    elseif index == 5 then
        openModal("announcement", "")
    elseif index == 6 then
        outputChatBox("#00f5a0[txAdmin]#ffffff txAdmin v6.0.2 Çalışıyor (Sistem Güncel).", 255, 255, 255, true)
    end
end

local function cycleOption(index, direction)
    playSoundFrontEnd(41)
    if S.currentTab == "ANA MENÜ" then
        if index == 1 then
            S.playerModeIndex = S.playerModeIndex + direction
            if S.playerModeIndex > #S.playerModes then S.playerModeIndex = 1 end
            if S.playerModeIndex < 1 then S.playerModeIndex = #S.playerModes end
        elseif index == 2 then
            S.teleportIndex = S.teleportIndex + direction
            if S.teleportIndex > #Config.TeleportLocations then S.teleportIndex = 1 end
            if S.teleportIndex < 1 then S.teleportIndex = #Config.TeleportLocations end
        elseif index == 3 then
            S.vehicleIndex = S.vehicleIndex + direction
            if S.vehicleIndex > #Config.Vehicles then S.vehicleIndex = 1 end
            if S.vehicleIndex < 1 then S.vehicleIndex = #Config.Vehicles end
        elseif index == 4 then
            S.healIndex = S.healIndex + direction
            if S.healIndex > #S.healOptions then S.healIndex = 1 end
            if S.healIndex < 1 then S.healIndex = #S.healOptions end
        end
    elseif S.currentTab == "TXADMIN" then
        if index == 1 then
            S.serverTimeIndex = S.serverTimeIndex + direction
            if S.serverTimeIndex > #S.serverTimeOptions then S.serverTimeIndex = 1 end
            if S.serverTimeIndex < 1 then S.serverTimeIndex = #S.serverTimeOptions end
        elseif index == 2 then
            S.serverWeatherIndex = S.serverWeatherIndex + direction
            if S.serverWeatherIndex > #S.serverWeatherOptions then S.serverWeatherIndex = 1 end
            if S.serverWeatherIndex < 1 then S.serverWeatherIndex = #S.serverWeatherOptions end
        elseif index == 4 then
            S.serverHealIndex = S.serverHealIndex + direction
            if S.serverHealIndex > #S.serverHealOptions then S.serverHealIndex = 1 end
            if S.serverHealIndex < 1 then S.serverHealIndex = #S.serverHealOptions end
        end
    end
end

local function refreshPlayers()
    S.playerList = {}
    local queryLower = string.lower(S.playerSearchQuery)
    local lx, ly, lz = getCameraMatrix()
    for _, p in ipairs(getElementsByType("player")) do
        local name = getPlayerName(p)
        local id = getElementData(p, "character:id") or getElementData(p, "id") or 0
        local ping = getPlayerPing(p)
        local px, py, pz = getElementPosition(p)
        local dist = math.floor(getDistanceBetweenPoints3D(lx, ly, lz, px, py, pz))
        local match = true
        if queryLower ~= "" then
            match = string.find(string.lower(name), queryLower, 1, true) or string.find(tostring(id), queryLower, 1, true)
        end
        if match then
            local pSerial = (p == localPlayer) and getPlayerSerial() or "Gizli"
            local pIP = (p == localPlayer) and "127.0.0.1" or "Gizli"
            table.insert(S.playerList, {
                element = p,
                name = name,
                id = id,
                ping = ping,
                dist = dist,
                health = math.floor(getElementHealth(p)),
                armor = math.floor(getPedArmor(p)),
                serial = pSerial,
                ip = pIP
            })
        end
    end
end

function toggleTxAdmin()
    if not isAdmin(localPlayer) then
        return
    end

    S.isOpen = not S.isOpen
    showCursor(false)
    if S.isOpen then
        playSoundFrontEnd(40)
        refreshPlayers()
    else
        playSoundFrontEnd(41)
        S.activeModal = nil
        S.activePlayerDialog = nil
        S.isSearchingPlayers = false
        S.isBanDropdownOpen = false
    end
    syncRenderState()
end

function isTxAdminOpen()
    return S.isOpen
end

addCommandHandler("txadmin", toggleTxAdmin)
addCommandHandler("tx", toggleTxAdmin)
bindKey("page_up", "down", toggleTxAdmin)

local function submitModal()
    playSoundFrontEnd(40)
    if S.activeModal == "teleport" then
        local parts = {}
        for part in string.gmatch(S.modalInputText, "[^,%s]+") do
            table.insert(parts, tonumber(part))
        end
        if #parts >= 3 then
            triggerServerEvent("txadmin:teleportCoords", localPlayer, parts[1], parts[2], parts[3])
        else
            outputChatBox("#f43f5e[txAdmin]#ffffff Lütfen x, y, z koordinatlarını doğru formatta girin.", 255, 255, 255, true)
        end
    elseif S.activeModal == "spawnVehicle" then
        if S.modalInputText ~= "" then
            triggerServerEvent("txadmin:spawnVehicle", localPlayer, S.modalInputText)
        end
    elseif S.activeModal == "announcement" then
        if S.modalInputText ~= "" then
            triggerServerEvent("txadmin:sendAnnouncement", localPlayer, S.modalInputText)
        end
    elseif S.activeModal == "player_dm" and S.activePlayerDialog then
        if S.modalInputText ~= "" then
            triggerServerEvent("txadmin:playerAction", localPlayer, S.activePlayerDialog.element, "dm", S.modalInputText)
        end
    elseif S.activeModal == "player_warn" and S.activePlayerDialog then
        if S.modalInputText ~= "" then
            triggerServerEvent("txadmin:playerAction", localPlayer, S.activePlayerDialog.element, "warn", S.modalInputText)
        end
    elseif S.activeModal == "player_kick" and S.activePlayerDialog then
        if S.modalInputText ~= "" then
            triggerServerEvent("txadmin:playerAction", localPlayer, S.activePlayerDialog.element, "kick", S.modalInputText)
            S.activePlayerDialog = nil
            refreshPlayers()
        end
    end
    S.activeModal = nil
    S.modalInputText = ""
end

addEventHandler("onClientKey", root, function(button, press)
    if not S.isOpen or not press then return end

    if S.activeModal then
        if button == "escape" then
            S.activeModal = nil
            cancelEvent()
        elseif button == "enter" or button == "num_enter" then
            submitModal()
            cancelEvent()
        elseif button == "backspace" then
            if #S.modalInputText > 0 then
                S.modalInputText = string.sub(S.modalInputText, 1, #S.modalInputText - 1)
            end
            cancelEvent()
        end
        return
    end

    if S.isSearchingPlayers then
        if button == "escape" or button == "enter" or button == "num_enter" then
            S.isSearchingPlayers = false
            cancelEvent()
        elseif button == "backspace" then
            if #S.playerSearchQuery > 0 then
                S.playerSearchQuery = string.sub(S.playerSearchQuery, 1, #S.playerSearchQuery - 1)
                refreshPlayers()
            end
            cancelEvent()
        end
        return
    end

    if S.activePlayerDialog and S.playerDialogTab == "Bilgiler" then
        if button == "backspace" then
            if #S.playerNoteInput > 0 then
                S.playerNoteInput = string.sub(S.playerNoteInput, 1, #S.playerNoteInput - 1)
            end
            cancelEvent()
            return
        end
    end

    if S.activePlayerDialog and S.playerDialogTab == "Yasakla" then
        if button == "backspace" then
            if #S.banReasonInput > 0 then
                S.banReasonInput = string.sub(S.banReasonInput, 1, #S.banReasonInput - 1)
            end
            cancelEvent()
            return
        end
    end

    if button == "m" and not S.activeModal and not S.isSearchingPlayers and not (S.activePlayerDialog and (S.playerDialogTab == "Bilgiler" or S.playerDialogTab == "Yasakla")) then
        cancelEvent()
        showCursor(not isCursorShowing())
        playSoundFrontEnd(41)
        return
    end

    if button == "arrow_u" then
        cancelEvent()
        playSoundFrontEnd(41)
        if S.currentTab == "ANA MENÜ" then
            S.selectedIndex = S.selectedIndex - 1
            if S.selectedIndex < 1 then S.selectedIndex = 7 end
        elseif S.currentTab == "TXADMIN" then
            S.txadminSelectedIndex = S.txadminSelectedIndex - 1
            if S.txadminSelectedIndex < 1 then S.txadminSelectedIndex = 6 end
        elseif S.currentTab == "OYUNCULAR" and not S.activePlayerDialog then
            S.selectedPlayerIndex = S.selectedPlayerIndex - 1
            if S.selectedPlayerIndex < 1 then S.selectedPlayerIndex = math.max(1, #S.playerList) end
        end
    elseif button == "arrow_d" then
        cancelEvent()
        playSoundFrontEnd(41)
        if S.currentTab == "ANA MENÜ" then
            S.selectedIndex = S.selectedIndex + 1
            if S.selectedIndex > 7 then S.selectedIndex = 1 end
        elseif S.currentTab == "TXADMIN" then
            S.txadminSelectedIndex = S.txadminSelectedIndex + 1
            if S.txadminSelectedIndex > 6 then S.txadminSelectedIndex = 1 end
        elseif S.currentTab == "OYUNCULAR" and not S.activePlayerDialog then
            S.selectedPlayerIndex = S.selectedPlayerIndex + 1
            if S.selectedPlayerIndex > #S.playerList then S.selectedPlayerIndex = 1 end
        end
    elseif button == "arrow_l" then
        cancelEvent()
        if S.currentTab == "ANA MENÜ" then
            cycleOption(S.selectedIndex, -1)
        elseif S.currentTab == "TXADMIN" then
            cycleOption(S.txadminSelectedIndex, -1)
        elseif S.activePlayerDialog and S.playerDialogTab == "Yasakla" then
            S.banDurationIndex = S.banDurationIndex - 1
            if S.banDurationIndex < 1 then S.banDurationIndex = #S.banDurations end
            playSoundFrontEnd(41)
        end
    elseif button == "arrow_r" then
        cancelEvent()
        if S.currentTab == "ANA MENÜ" then
            cycleOption(S.selectedIndex, 1)
        elseif S.currentTab == "TXADMIN" then
            cycleOption(S.txadminSelectedIndex, 1)
        elseif S.activePlayerDialog and S.playerDialogTab == "Yasakla" then
            S.banDurationIndex = S.banDurationIndex + 1
            if S.banDurationIndex > #S.banDurations then S.banDurationIndex = 1 end
            playSoundFrontEnd(41)
        end
    elseif button == "enter" or button == "num_enter" then
        cancelEvent()
        if S.currentTab == "ANA MENÜ" then
            executeMainOption(S.selectedIndex)
        elseif S.currentTab == "TXADMIN" then
            executeTxAdminOption(S.txadminSelectedIndex)
        elseif S.currentTab == "OYUNCULAR" and not S.activePlayerDialog and S.playerList[S.selectedPlayerIndex] then
            S.activePlayerDialog = S.playerList[S.selectedPlayerIndex]
            S.playerDialogTab = "İşlemler"
            playSoundFrontEnd(40)
        end
    elseif button == "tab" then
        cancelEvent()
        playSoundFrontEnd(41)
        if S.currentTab == "ANA MENÜ" then
            S.currentTab = "OYUNCULAR"
            refreshPlayers()
        elseif S.currentTab == "OYUNCULAR" then
            S.currentTab = "TXADMIN"
            S.activePlayerDialog = nil
        else
            S.currentTab = "ANA MENÜ"
        end
    elseif button == "escape" then
        cancelEvent()
        if S.activePlayerDialog then
            S.activePlayerDialog = nil
        else
            toggleTxAdmin()
        end
    end
end)

addEventHandler("onClientCharacter", root, function(ch)
    if not S.isOpen then return end
    if S.activeModal then
        if string.len(S.modalInputText) < 120 then
            S.modalInputText = S.modalInputText .. ch
        end
    elseif S.isSearchingPlayers then
        if string.len(S.playerSearchQuery) < 40 then
            S.playerSearchQuery = S.playerSearchQuery .. ch
            refreshPlayers()
        end
    elseif S.activePlayerDialog and S.playerDialogTab == "Bilgiler" then
        if string.len(S.playerNoteInput) < 180 then
            S.playerNoteInput = S.playerNoteInput .. ch
        end
    elseif S.activePlayerDialog and S.playerDialogTab == "Yasakla" then
        if string.len(S.banReasonInput) < 120 then
            S.banReasonInput = S.banReasonInput .. ch
        end
    end
end)

local function drawFastOutlinedText(text, x, y, w, h, color, scaleVal, font, stroke)
    local black = tocolor(0, 0, 0, 255)
    exports.aura_ui:uiDrawText(text, x - stroke, y, x + w - stroke, y + h, black, scaleVal, font, "center", "center")
    exports.aura_ui:uiDrawText(text, x + stroke, y, x + w + stroke, y + h, black, scaleVal, font, "center", "center")
    exports.aura_ui:uiDrawText(text, x, y - stroke, x + w, y + h - stroke, black, scaleVal, font, "center", "center")
    exports.aura_ui:uiDrawText(text, x, y + stroke, x + w, y + h + stroke, black, scaleVal, font, "center", "center")
    exports.aura_ui:uiDrawText(text, x, y, x + w, y + h, color, scaleVal, font, "center", "center")
end

local function drawOverheadPlayerIDs()
    if not S.showPlayerIDs then return end

    local lx, ly, lz = getCameraMatrix()
    local font = fonts.tag

    for _, p in ipairs(getElementsByType("player", root, true)) do
        local px, py, pz = getElementPosition(p)
        local dist = getDistanceBetweenPoints3D(lx, ly, lz, px, py, pz)

        if dist < 50.0 then
            local hx, hy, hz
            local boneX, boneY, boneZ = getPedBonePosition(p, 8)
            if boneX and boneY and boneZ then
                hx, hy, hz = boneX, boneY, boneZ + 0.38
            else
                hx, hy, hz = px, py, pz + (isPedInVehicle(p) and 0.85 or 1.15)
            end

            local sx, sy = getScreenFromWorldPosition(hx, hy, hz, 0.06)
            if sx and sy then
                local distScale = math.max(0.7, math.min(1.15, 1.0 - (dist / 85)))
                local textScale = 1.0 * distScale

                local id = getElementData(p, "character:id") or getElementData(p, "id") or 0
                local name = getPlayerName(p)
                local hp = math.max(0, math.min(100, getElementHealth(p)))
                local armor = math.max(0, math.min(100, getPedArmor(p)))

                local text = string.format("[%d] %s", id, name)
                local textW = exports.aura_ui:uiTextWidth(text, textScale, font)
                local textH = exports.aura_ui:uiFontHeight(textScale, font)

                local textX = math.floor(sx - textW * 0.5)
                local textY = math.floor(sy - textH)

                local stroke = math.max(1.0, 1.4 * distScale)
                drawFastOutlinedText(text, textX, textY, textW, textH, tocolor(255, 255, 255, 255), textScale, font, stroke)

                local barW = math.floor(58 * distScale)
                local barH = math.floor(7 * distScale)
                local barX = math.floor(sx - barW * 0.5)
                local barY = textY + textH + math.floor(2 * distScale)

                exports.aura_ui:uiDrawRectangle(barX - 1, barY - 1, barW + 2, barH + 2, tocolor(0, 0, 0, 230))
                exports.aura_ui:uiDrawRectangle(barX, barY, barW, barH, tocolor(25, 100, 80, 255))

                local hpW = math.floor(barW * (hp / 100))
                if hpW > 0 then
                    exports.aura_ui:uiDrawRectangle(barX, barY, hpW, barH, tocolor(55, 250, 218, 255))
                end

                if armor > 0 then
                    local armY = barY + barH + math.floor(2 * distScale)
                    exports.aura_ui:uiDrawRectangle(barX - 1, armY - 1, barW + 2, barH + 2, tocolor(0, 0, 0, 230))
                    exports.aura_ui:uiDrawRectangle(barX, armY, barW, barH, tocolor(20, 50, 80, 255))
                    local armW = math.floor(barW * (armor / 100))
                    if armW > 0 then
                        exports.aura_ui:uiDrawRectangle(barX, armY, armW, barH, tocolor(56, 189, 248, 255))
                    end
                end
            end
        end
    end
end

addEventHandler("onClientClick", root, function(button, state, absoluteX, absoluteY)
    if not S.isOpen or button ~= "left" or state ~= "down" then return end

    local cardW = math.floor(330 * scale)
    local cardH = (S.currentTab == "OYUNCULAR") and math.floor(82 * scale) or math.floor(460 * scale)
    local cardX = math.floor(36 * scale)
    local cardY = math.floor(screenH * 0.12)

    local tabY = cardY + math.floor(48 * scale)
    local tabW = math.floor(cardW / 3)
    local tabH = math.floor(28 * scale)

    if absoluteY >= tabY and absoluteY <= tabY + tabH then
        if absoluteX >= cardX and absoluteX < cardX + tabW then
            S.currentTab = "ANA MENÜ"
            S.activePlayerDialog = nil
            playSoundFrontEnd(41)
            return
        elseif absoluteX >= cardX + tabW and absoluteX < cardX + tabW * 2 then
            S.currentTab = "OYUNCULAR"
            refreshPlayers()
            playSoundFrontEnd(41)
            return
        elseif absoluteX >= cardX + tabW * 2 and absoluteX <= cardX + cardW then
            S.currentTab = "TXADMIN"
            S.activePlayerDialog = nil
            playSoundFrontEnd(41)
            return
        end
    end

    if S.activeModal then
        local mw = math.floor(420 * scale)
        local mh = math.floor(165 * scale)
        local mx = math.floor((screenW - mw) / 2)
        local my = math.floor((screenH - mh) / 2)

        local btnCancelX = mx + mw - math.floor(145 * scale)
        local btnCancelY = my + mh - math.floor(38 * scale)
        local btnCancelW = math.floor(60 * scale)
        local btnCancelH = math.floor(26 * scale)

        local btnSubmitX = mx + mw - math.floor(78 * scale)
        local btnSubmitY = btnCancelY
        local btnSubmitW = math.floor(65 * scale)
        local btnSubmitH = btnCancelH

        if absoluteX >= btnCancelX and absoluteX <= btnCancelX + btnCancelW and absoluteY >= btnCancelY and absoluteY <= btnCancelY + btnCancelH then
            S.activeModal = nil
            playSoundFrontEnd(41)
            return
        elseif absoluteX >= btnSubmitX and absoluteX <= btnSubmitX + btnSubmitW and absoluteY >= btnSubmitY and absoluteY <= btnSubmitY + btnSubmitH then
            submitModal()
            return
        end
        return
    end

    if S.activePlayerDialog then
        local dw = math.floor(580 * scale)
        local dh = math.floor(410 * scale)
        local dx = math.floor((screenW - dw) / 2)
        local dy = math.floor((screenH - dh) / 2)

        local closeBtnSize = 22
        local closeBtnX = dx + dw - closeBtnSize - 16
        local closeBtnY = dy + 14
        if absoluteX >= closeBtnX and absoluteX <= closeBtnX + closeBtnSize and absoluteY >= closeBtnY and absoluteY <= closeBtnY + closeBtnSize then
            S.activePlayerDialog = nil
            playSoundFrontEnd(41)
            return
        end

        local sideW = math.floor(135 * scale)
        local sideTabs = {"İşlemler", "Bilgiler", "Kimlikler", "Geçmiş", "Yasakla"}
        local sepY = dy + math.floor(46 * scale)
        local tabStartY = sepY + 12
        local tabItemH = math.floor(34 * scale)

        for i, sTab in ipairs(sideTabs) do
            local sy = tabStartY + (i - 1) * (tabItemH + 6)
            if absoluteX >= dx + 12 and absoluteX <= dx + sideW and absoluteY >= sy and absoluteY <= sy + tabItemH then
                S.playerDialogTab = sTab
                playSoundFrontEnd(41)
                return
            end
        end

        local contentX = dx + sideW + math.floor(18 * scale)
        local target = S.activePlayerDialog.element

        if S.playerDialogTab == "İşlemler" and isElement(target) then
            local modBtns = {
                { label = "MESAJ", act = function() openModal("player_dm", "") end },
                { label = "UYARI", act = function() openModal("player_warn", "Kural ihlali") end },
                { label = "AT", act = function() openModal("player_kick", "Yönetici tarafından atıldınız") end },
                { label = "YETKİ VER", act = function() triggerServerEvent("txadmin:playerAction", localPlayer, target, "giveAdmin") end }
            }
            local by1 = sepY + math.floor(56 * scale)
            local bw1 = math.floor(78 * scale)
            local bh1 = math.floor(25 * scale)
            for i, b in ipairs(modBtns) do
                local bx = contentX + (i - 1) * (bw1 + 6)
                if absoluteX >= bx and absoluteX <= bx + bw1 and absoluteY >= by1 and absoluteY <= by1 + bh1 then
                    playSoundFrontEnd(40)
                    b.act()
                    return
                end
            end

            local intBtns = {
                { label = "İYİLEŞTİR", act = function() triggerServerEvent("txadmin:playerAction", localPlayer, target, "heal") end },
                { label = "GİT", act = function() triggerServerEvent("txadmin:playerAction", localPlayer, target, "goto") end },
                { label = "ÇEK", act = function() triggerServerEvent("txadmin:playerAction", localPlayer, target, "bring") end },
                { label = "İZLE", act = function() triggerServerEvent("txadmin:playerAction", localPlayer, target, "spectate") end },
                { label = "DONDUR", act = function() triggerServerEvent("txadmin:playerAction", localPlayer, target, "freeze") end }
            }
            local by2 = sepY + math.floor(114 * scale)
            local bw2 = math.floor(64 * scale)
            for i, b in ipairs(intBtns) do
                local bx = contentX + (i - 1) * (bw2 + 5)
                if absoluteX >= bx and absoluteX <= bx + bw2 and absoluteY >= by2 and absoluteY <= by2 + bh1 then
                    playSoundFrontEnd(40)
                    b.act()
                    return
                end
            end

            local isDrunk = getElementData(target, "txadmin:isDrunk")
            local drunkLabel = isDrunk and "AYILT" or "SARHOŞ ET"
            local trollBtns = {
                { label = drunkLabel, act = function() triggerServerEvent("txadmin:playerAction", localPlayer, target, "drunk") end },
                { label = "ATEŞE VER", act = function() triggerServerEvent("txadmin:playerAction", localPlayer, target, "fire") end },
                { label = "TOKATLA", act = function() triggerServerEvent("txadmin:playerAction", localPlayer, target, "slap") end }
            }
            local by3 = sepY + math.floor(172 * scale)
            local bw3 = math.floor(88 * scale)
            for i, b in ipairs(trollBtns) do
                local bx = contentX + (i - 1) * (bw3 + 6)
                if absoluteX >= bx and absoluteX <= bx + bw3 and absoluteY >= by3 and absoluteY <= by3 + bh1 then
                    playSoundFrontEnd(40)
                    b.act()
                    return
                end
            end

        elseif S.playerDialogTab == "Bilgiler" and isElement(target) then
            local noteBoxY = sepY + math.floor(134 * scale)
            local noteBoxH = math.floor(70 * scale)
            local btnSaveY = noteBoxY + noteBoxH + math.floor(12 * scale)
            local btnSaveW = math.floor(100 * scale)
            local btnSaveH = math.floor(25 * scale)
            if absoluteX >= contentX and absoluteX <= contentX + btnSaveW and absoluteY >= btnSaveY and absoluteY <= btnSaveY + btnSaveH then
                playSoundFrontEnd(40)
                triggerServerEvent("txadmin:savePlayerNote", localPlayer, target, S.playerNoteInput)
                return
            end

        elseif S.playerDialogTab == "Yasakla" and isElement(target) then
            local box1Y = sepY + math.floor(58 * scale)
            local box1H = math.floor(30 * scale)
            local box2Y = box1Y + box1H + math.floor(32 * scale)
            local box2W = math.floor(220 * scale)
            local box2H = math.floor(30 * scale)

            local dropItemH = math.floor(26 * scale)
            local dropY = box2Y + box2H + 2
            local dropH = #S.banDurations * dropItemH

            if S.isBanDropdownOpen then
                if absoluteX >= contentX and absoluteX <= contentX + box2W and absoluteY >= dropY and absoluteY <= dropY + dropH then
                    local clickedIndex = math.floor((absoluteY - dropY) / dropItemH) + 1
                    if S.banDurations[clickedIndex] then
                        S.banDurationIndex = clickedIndex
                        playSoundFrontEnd(41)
                    end
                    S.isBanDropdownOpen = false
                    return
                end
            end

            if absoluteX >= contentX and absoluteX <= contentX + box2W and absoluteY >= box2Y and absoluteY <= box2Y + box2H then
                S.isBanDropdownOpen = not S.isBanDropdownOpen
                playSoundFrontEnd(41)
                return
            else
                S.isBanDropdownOpen = false
            end

            local btnBanY = box2Y + box2H + math.floor(28 * scale)
            local btnBanW = math.floor(90 * scale)
            local btnBanH = math.floor(28 * scale)
            if absoluteX >= contentX and absoluteX <= contentX + btnBanW and absoluteY >= btnBanY and absoluteY <= btnBanY + btnBanH then
                playSoundFrontEnd(40)
                local dur = S.banDurations[S.banDurationIndex].duration
                triggerServerEvent("txadmin:banPlayer", localPlayer, target, S.banReasonInput, dur)
                S.activePlayerDialog = nil
                refreshPlayers()
                return
            end
        end

        return
    end

    if S.currentTab == "ANA MENÜ" then
        local startY = cardY + math.floor(94 * scale)
        local rowH = math.floor(38 * scale)
        local rowW = cardW - math.floor(22 * scale)
        local rowX = cardX + math.floor(11 * scale)

        for i = 1, 7 do
            local ry = startY + (i - 1) * (rowH + math.floor(3 * scale))
            if absoluteX >= rowX and absoluteX <= rowX + rowW and absoluteY >= ry and absoluteY <= ry + rowH then
                S.selectedIndex = i
                local arrowBoxW = math.floor(46 * scale)
                local arrowRightX = rowX + rowW - arrowBoxW

                if i <= 4 and absoluteX >= arrowRightX then
                    if absoluteX <= arrowRightX + arrowBoxW / 2 then
                        cycleOption(i, -1)
                    else
                        cycleOption(i, 1)
                    end
                else
                    executeMainOption(i)
                end
                return
            end
        end
    elseif S.currentTab == "TXADMIN" then
        local startY = cardY + math.floor(94 * scale)
        local rowH = math.floor(38 * scale)
        local rowW = cardW - math.floor(22 * scale)
        local rowX = cardX + math.floor(11 * scale)

        for i = 1, 6 do
            local ry = startY + (i - 1) * (rowH + math.floor(3 * scale))
            if absoluteX >= rowX and absoluteX <= rowX + rowW and absoluteY >= ry and absoluteY <= ry + rowH then
                S.txadminSelectedIndex = i
                local arrowBoxW = math.floor(46 * scale)
                local arrowRightX = rowX + rowW - arrowBoxW

                if (i == 1 or i == 2 or i == 4) and absoluteX >= arrowRightX then
                    if absoluteX <= arrowRightX + arrowBoxW / 2 then
                        cycleOption(i, -1)
                    else
                        cycleOption(i, 1)
                    end
                else
                    executeTxAdminOption(i)
                end
                return
            end
        end
    elseif S.currentTab == "OYUNCULAR" then
        local wideX = math.floor(36 * scale)
        local wideY = cardY + math.floor(94 * scale)
        local wideW = screenW - wideX * 2
        local wideH = screenH - wideY - math.floor(64 * scale)

        local searchBoxW = math.floor(180 * scale)
        local searchBoxH = math.floor(28 * scale)
        local searchBoxX = wideX + wideW - searchBoxW - math.floor(200 * scale)
        local searchBoxY = wideY + math.floor(22 * scale)

        if absoluteX >= searchBoxX and absoluteX <= searchBoxX + searchBoxW and absoluteY >= searchBoxY and absoluteY <= searchBoxY + searchBoxH then
            S.isSearchingPlayers = true
            return
        else
            S.isSearchingPlayers = false
        end

        local pStartY = wideY + math.floor(74 * scale)
        local cardItemW = math.floor(240 * scale)
        local cardItemH = math.floor(46 * scale)

        for i = 1, math.min(10, #S.playerList) do
            local ry = pStartY + (i - 1) * (cardItemH + 8)
            if absoluteX >= wideX + 24 and absoluteX <= wideX + 24 + cardItemW and absoluteY >= ry and absoluteY <= ry + cardItemH then
                S.activePlayerDialog = S.playerList[i]
                S.playerDialogTab = "İşlemler"
                playSoundFrontEnd(40)
                return
            end
        end
    end
end)

local function renderBannerNotifications()
    local now = getTickCount()

    if S.toastMessage then
        local elapsed = now - S.toastTick
        if elapsed < 3500 then
            local tFont = fonts.toast
            local tText = "ℹ  " .. S.toastMessage
            local tw = exports.aura_ui:uiTextWidth(tText, 1.0, tFont) + 32
            local th = 28
            local tx = math.floor((screenW - tw) / 2)
            local ty = screenH - 68

            drawRoundedRectangle(tx, ty, tw, th, 6, tocolor(2, 132, 199, 240))
            exports.aura_ui:uiDrawText(tText, tx, ty, tx + tw, ty + th, tocolor(255, 255, 255, 255), 1.0, tFont, "center", "center")
        else
            S.toastMessage = nil
            syncRenderState()
        end
    end

    if S.activeAnnouncement then
        local elapsed = now - S.announcementStartTick
        if elapsed < S.announcementDuration then
            local titleText = "Sunucu Duyurusu (" .. S.activeAnnouncement.admin .. "):"
            local msgText = S.activeAnnouncement.message
            local titleW = exports.aura_ui:uiTextWidth(titleText, 1.0, fonts.item)
            local msgW = exports.aura_ui:uiTextWidth(msgText, 1.0, fonts.val)
            local contentW = math.max(titleW, msgW)
            local bannerW = math.max(math.floor(340 * scale), math.min(math.floor(680 * scale), contentW + math.floor(75 * scale)))
            local bannerH = math.floor(56 * scale)
            local bannerX = math.floor((screenW - bannerW) / 2)

            local bannerTargetY = math.floor(32 * scale)
            local bannerY = bannerTargetY
            if elapsed < 280 then
                local p = elapsed / 280
                bannerY = math.floor(-bannerH + (bannerTargetY + bannerH) * p)
            elseif elapsed > (S.announcementDuration - 350) then
                local p = (elapsed - (S.announcementDuration - 350)) / 350
                bannerY = math.floor(bannerTargetY - (bannerTargetY + bannerH) * p)
            end

            drawRoundedRectangle(bannerX, bannerY, bannerW, bannerH, 8, tocolor(245, 158, 11, 245), true)
            drawRoundedBorder(bannerX, bannerY, bannerW, bannerH, 8, tocolor(217, 119, 6, 255), 1.2, true)

            local iconSize = math.floor(24 * scale)
            local iconX = bannerX + math.floor(14 * scale)
            local iconY = bannerY + math.floor((bannerH - iconSize) / 2)
            drawIconSVG("warning", iconX, iconY, iconSize, tocolor(28, 25, 23, 255), true)

            local textX = iconX + iconSize + math.floor(12 * scale)
            local line1Y = bannerY + math.floor(9 * scale)
            local line2Y = bannerY + math.floor(29 * scale)

            exports.aura_ui:uiDrawText(titleText, textX, line1Y, bannerX + bannerW - 14, line1Y + 18, tocolor(28, 25, 23, 255), 1.0, fonts.item, "left", "center", true, false, true)
            exports.aura_ui:uiDrawText(msgText, textX, line2Y, bannerX + bannerW - 14, line2Y + 20, tocolor(41, 37, 36, 255), 1.0, fonts.val, "left", "center", true, false, true)
        else
            S.activeAnnouncement = nil
            syncRenderState()
        end
    end

    if S.activeDirectMessage then
        local elapsed = now - S.dmStartTick
        if elapsed < S.dmDuration then
            local titleText = S.activeDirectMessage.admin .. " yöneticisinden DM:"
            local msgText = S.activeDirectMessage.message
            local titleW = exports.aura_ui:uiTextWidth(titleText, 1.0, fonts.item)
            local msgW = exports.aura_ui:uiTextWidth(msgText, 1.0, fonts.val)
            local contentW = math.max(titleW, msgW)
            local bannerW = math.max(math.floor(340 * scale), math.min(math.floor(680 * scale), contentW + math.floor(75 * scale)))
            local bannerH = math.floor(56 * scale)
            local bannerX = math.floor((screenW - bannerW) / 2)

            local bannerTargetY = S.activeAnnouncement and math.floor(96 * scale) or math.floor(32 * scale)
            local bannerY = bannerTargetY
            if elapsed < 280 then
                local p = elapsed / 280
                bannerY = math.floor(-bannerH + (bannerTargetY + bannerH) * p)
            elseif elapsed > (S.dmDuration - 350) then
                local p = (elapsed - (S.dmDuration - 350)) / 350
                bannerY = math.floor(bannerTargetY - (bannerTargetY + bannerH) * p)
            end

            drawRoundedRectangle(bannerX, bannerY, bannerW, bannerH, 8, tocolor(2, 132, 199, 245), true)
            drawRoundedBorder(bannerX, bannerY, bannerW, bannerH, 8, tocolor(14, 165, 233, 255), 1.2, true)

            local iconSize = math.floor(22 * scale)
            local iconX = bannerX + math.floor(14 * scale)
            local iconY = bannerY + math.floor((bannerH - iconSize) / 2)
            drawIconSVG("info", iconX, iconY, iconSize, tocolor(255, 255, 255, 255), true)

            local textX = iconX + iconSize + math.floor(12 * scale)
            local line1Y = bannerY + math.floor(9 * scale)
            local line2Y = bannerY + math.floor(29 * scale)

            exports.aura_ui:uiDrawText(titleText, textX, line1Y, bannerX + bannerW - 14, line1Y + 18, tocolor(255, 255, 255, 255), 1.0, fonts.item, "left", "center", true, false, true)
            exports.aura_ui:uiDrawText(msgText, textX, line2Y, bannerX + bannerW - 14, line2Y + 20, tocolor(224, 242, 254, 255), 1.0, fonts.val, "left", "center", true, false, true)
        else
            S.activeDirectMessage = nil
            syncRenderState()
        end
    end

    if S.activeWarning then
        local pulseAlpha = math.floor(235 + 20 * math.sin(now / 300))
        exports.aura_ui:uiDrawRectangle(0, 0, screenW, screenH, tocolor(133, 3, 3, pulseAlpha), true)

        local cardW = math.floor(640 * scale)
        local cardH = math.floor(240 * scale)
        local cardX = math.floor((screenW - cardW) / 2)
        local cardY = math.floor((screenH - cardH) / 2 - 30 * scale)

        drawRoundedRectangle(cardX, cardY, cardW, cardH, 12, tocolor(20, 10, 10, 200), true)
        drawRoundedBorder(cardX, cardY, cardW, cardH, 12, tocolor(245, 245, 245, 240), 2.2, true)

        local titleW = exports.aura_ui:uiTextWidth("UYARI", 1.0, fonts.title)
        local titleCenterY = cardY + math.floor(24 * scale)
        local titleLineW = titleW + 80 * scale
        local titleLineX = cardX + math.floor((cardW - titleLineW) / 2)

        drawIconSVG("warning", titleLineX + 8 * scale, titleCenterY - 2, 24 * scale, tocolor(233, 150, 122, 255), true)
        exports.aura_ui:uiDrawText("UYARI", cardX, titleCenterY - 4, cardX + cardW, titleCenterY + 24, tocolor(245, 245, 245, 255), 1.0, fonts.title, "center", "center", false, false, true)
        drawIconSVG("warning", titleLineX + titleLineW - 32 * scale, titleCenterY - 2, 24 * scale, tocolor(233, 150, 122, 255), true)

        dxDrawLine(titleLineX, titleCenterY + 30 * scale, titleLineX + titleLineW, titleCenterY + 30 * scale, tocolor(245, 245, 245, 220), 1.5, true)

        local reasonY = cardY + math.floor(75 * scale)
        local reasonH = math.floor(90 * scale)
        exports.aura_ui:uiDrawText(S.activeWarning.reason, cardX + 24 * scale, reasonY, cardX + cardW - 24 * scale, reasonY + reasonH, tocolor(255, 255, 255, 255), 1.0, fonts.dialogTitle, "center", "center", true, true, true)

        local authorText = "Uyaran Yetkili: " .. S.activeWarning.admin
        local authorY = cardY + cardH - math.floor(32 * scale)
        exports.aura_ui:uiDrawText(authorText, cardX + 24 * scale, authorY, cardX + cardW - 24 * scale, authorY + 20 * scale, tocolor(245, 245, 245, 210), 1.0, fonts.sub, "right", "center", false, false, true)

        local instrY = cardY + cardH + math.floor(28 * scale)
        local isSpaceDown = getKeyState("space")
        if isSpaceDown then
            if S.warnSpaceHoldStart == 0 then
                S.warnSpaceHoldStart = now
            end
        else
            S.warnSpaceHoldStart = 0
        end

        local holdProgress = 0
        local secsLeft = 3
        if S.warnSpaceHoldStart > 0 then
            local heldTime = now - S.warnSpaceHoldStart
            holdProgress = math.min(1.0, heldTime / S.warnRequiredHoldTime)
            secsLeft = math.max(0, math.floor((S.warnRequiredHoldTime - heldTime) / 1000) + 1)
            if heldTime >= S.warnRequiredHoldTime then
                S.activeWarning = nil
                S.warnSpaceHoldStart = 0
                playSoundFrontEnd(41)
                syncRenderState()
                return
            end
        end

        local instrText = string.format("Bu mesajı geçmek için [BOŞLUK] tuşunu %d saniye basılı tutun.", secsLeft)
        exports.aura_ui:uiDrawText(instrText, 0, instrY, screenW, instrY + 24 * scale, tocolor(245, 245, 245, 255), 1.0, fonts.item, "center", "center", false, false, true)

        if holdProgress > 0 then
            local pBarW = math.floor(260 * scale)
            local pBarH = math.floor(6 * scale)
            local pBarX = math.floor((screenW - pBarW) / 2)
            local pBarY = instrY + math.floor(30 * scale)
            exports.aura_ui:uiDrawRectangle(pBarX, pBarY, pBarW, pBarH, tocolor(0, 0, 0, 180), true)
            exports.aura_ui:uiDrawRectangle(pBarX, pBarY, math.floor(pBarW * holdProgress), pBarH, tocolor(0, 245, 160, 255), true)
        end
    end
end

local function renderPlayerModalDialog()
    if not S.activePlayerDialog then return end

    local dw = math.floor(580 * scale)
    local dh = math.floor(410 * scale)
    local dx = math.floor((screenW - dw) / 2)
    local dy = math.floor((screenH - dh) / 2)

    drawRoundedRectangle(dx, dy, dw, dh, 14, tocolor(17, 24, 34, 252))
    drawRoundedRectangle(dx, dy, dw, dh, 14, tocolor(255, 255, 255, 14))

    local titleStr = string.format("[%d] %s", S.activePlayerDialog.id, S.activePlayerDialog.name)
    exports.aura_ui:uiDrawText(titleStr, dx + 20, dy + 14, dx + 300, dy + 38, tocolor(255, 255, 255, 255), 1.0, fonts.dialogTitle, "left", "center")

    drawIconSVG("cross", dx + dw - 30, dy + 14, 16, tocolor(148, 163, 184, 255))

    local sepY = dy + math.floor(46 * scale)
    dxDrawLine(dx, sepY, dx + dw, sepY, tocolor(255, 255, 255, 14), 1.0)

    local sideW = math.floor(135 * scale)
    local sideTabs = {
        { name = "İşlemler", icon = "bolt" },
        { name = "Bilgiler", icon = "user" },
        { name = "Kimlikler", icon = "list" },
        { name = "Geçmiş", icon = "history" },
        { name = "Yasakla", icon = "ban", isBan = true }
    }

    local tabStartY = sepY + 12
    local tabItemH = math.floor(34 * scale)

    for i, sTab in ipairs(sideTabs) do
        local sy = tabStartY + (i - 1) * (tabItemH + 6)
        local isSel = (S.playerDialogTab == sTab.name)
        local isHover = isMouseInArea(dx + 12, sy, sideW, tabItemH)

        if isSel then
            if sTab.isBan then
                drawRoundedRectangle(dx + 12, sy, sideW, tabItemH, 6, tocolor(225, 29, 72, 255))
            else
                drawRoundedRectangle(dx + 12, sy, sideW, tabItemH, 6, tocolor(42, 53, 68, 255))
            end
        elseif isHover then
            drawRoundedRectangle(dx + 12, sy, sideW, tabItemH, 6, tocolor(28, 36, 48, 200))
        end

        drawIconSVG(sTab.icon, dx + 20, sy + 9, 15, tocolor(255, 255, 255, 240))
        exports.aura_ui:uiDrawText(sTab.name, dx + 44, sy, dx + 12 + sideW, sy + tabItemH, tocolor(255, 255, 255, 255), 1.0, fonts.sideTab, "left", "center")
    end

    local contentX = dx + sideW + math.floor(18 * scale)

    if S.playerDialogTab == "İşlemler" then
        exports.aura_ui:uiDrawText("Oyuncu İşlemleri", contentX, sepY + 12, contentX + 300, sepY + 30, tocolor(255, 255, 255, 255), 1.0, fonts.dialogTitle, "left", "center")

        exports.aura_ui:uiDrawText("Yönetim", contentX, sepY + 38, contentX + 300, sepY + 52, tocolor(148, 163, 184, 255), 1.0, fonts.cat, "left", "center")
        local modBtns = {"MESAJ", "UYARI", "AT", "YETKİ VER"}
        local by1 = sepY + math.floor(56 * scale)
        local bw1 = math.floor(78 * scale)
        local bh1 = math.floor(25 * scale)
        for i, bName in ipairs(modBtns) do
            local bx = contentX + (i - 1) * (bw1 + 6)
            local isHov = isMouseInArea(bx, by1, bw1, bh1)
            drawRoundedRectangle(bx, by1, bw1, bh1, 4, isHov and tocolor(0, 245, 160, 30) or tocolor(15, 23, 33, 220))
            drawRoundedBorder(bx, by1, bw1, bh1, 4, tocolor(0, 245, 160, 240), 1.2)
            exports.aura_ui:uiDrawText(bName, bx, by1, bx + bw1, by1 + bh1, tocolor(0, 245, 160, 255), 1.0, fonts.btn, "center", "center")
        end

        exports.aura_ui:uiDrawText("Etkileşim", contentX, sepY + math.floor(96 * scale), contentX + 300, sepY + math.floor(110 * scale), tocolor(148, 163, 184, 255), 1.0, fonts.cat, "left", "center")
        local intBtns = {"İYİLEŞTİR", "GİT", "ÇEK", "İZLE", "DONDUR"}
        local by2 = sepY + math.floor(114 * scale)
        local bw2 = math.floor(64 * scale)
        for i, bName in ipairs(intBtns) do
            local bx = contentX + (i - 1) * (bw2 + 5)
            local isHov = isMouseInArea(bx, by2, bw2, bh1)
            drawRoundedRectangle(bx, by2, bw2, bh1, 4, isHov and tocolor(0, 245, 160, 30) or tocolor(15, 23, 33, 220))
            drawRoundedBorder(bx, by2, bw2, bh1, 4, tocolor(0, 245, 160, 240), 1.2)
            exports.aura_ui:uiDrawText(bName, bx, by2, bx + bw2, by2 + bh1, tocolor(0, 245, 160, 255), 1.0, fonts.btn, "center", "center")
        end

        exports.aura_ui:uiDrawText("Eğlence", contentX, sepY + math.floor(154 * scale), contentX + 300, sepY + math.floor(168 * scale), tocolor(148, 163, 184, 255), 1.0, fonts.cat, "left", "center")
        local isTargetDrunk = getElementData(S.activePlayerDialog.element, "txadmin:isDrunk")
        local drunkLabel = isTargetDrunk and "AYILT" or "SARHOŞ ET"
        local trollBtns = {drunkLabel, "ATEŞE VER", "TOKATLA"}
        local by3 = sepY + math.floor(172 * scale)
        local bw3 = math.floor(88 * scale)
        for i, bName in ipairs(trollBtns) do
            local bx = contentX + (i - 1) * (bw3 + 6)
            local isHov = isMouseInArea(bx, by3, bw3, bh1)
            drawRoundedRectangle(bx, by3, bw3, bh1, 4, isHov and tocolor(0, 245, 160, 30) or tocolor(15, 23, 33, 220))
            drawRoundedBorder(bx, by3, bw3, bh1, 4, tocolor(0, 245, 160, 240), 1.2)
            exports.aura_ui:uiDrawText(bName, bx, by3, bx + bw3, by3 + bh1, tocolor(0, 245, 160, 255), 1.0, fonts.btn, "center", "center")
        end

    elseif S.playerDialogTab == "Bilgiler" then
        exports.aura_ui:uiDrawText("Oyuncu Bilgisi", contentX, sepY + 12, contentX + 300, sepY + 30, tocolor(255, 255, 255, 255), 1.0, fonts.dialogTitle, "left", "center")

        local line1Y = sepY + math.floor(38 * scale)
        exports.aura_ui:uiDrawText("Oturum Süresi: #ffffff8 dakika", contentX, line1Y, contentX + 300, line1Y + 18, tocolor(148, 163, 184, 255), 1.0, fonts.val, "left", "center", false, false, false, true)
        local line2Y = line1Y + math.floor(22 * scale)
        exports.aura_ui:uiDrawText("Oynama Süresi: #ffffff1 gün, 2 saat, 39 dakika", contentX, line2Y, contentX + 300, line2Y + 18, tocolor(148, 163, 184, 255), 1.0, fonts.val, "left", "center", false, false, false, true)
        local line3Y = line2Y + math.floor(22 * scale)
        exports.aura_ui:uiDrawText("Kayıt Tarihi: #ffffff13 Ekim 2022 - 21:01:29", contentX, line3Y, contentX + 300, line3Y + 18, tocolor(148, 163, 184, 255), 1.0, fonts.val, "left", "center", false, false, false, true)

        local noteLabelY = line3Y + math.floor(30 * scale)
        exports.aura_ui:uiDrawText("Bu oyuncu hakkında notlar", contentX, noteLabelY, contentX + 300, noteLabelY + 16, tocolor(0, 245, 160, 255), 1.0, fonts.cat, "left", "center")

        local noteBoxY = noteLabelY + math.floor(22 * scale)
        local noteBoxW = dw - (contentX - dx) - 24
        local noteBoxH = math.floor(70 * scale)
        drawRoundedRectangle(contentX, noteBoxY, noteBoxW, noteBoxH, 6, tocolor(15, 23, 33, 255))
        drawRoundedBorder(contentX, noteBoxY, noteBoxW, noteBoxH, 6, tocolor(0, 245, 160, 180), 1.2)

        local dispNote = (S.playerNoteInput == "") and "Not girin..." or S.playerNoteInput .. (getTickCount() % 1000 > 500 and "|" or "")
        exports.aura_ui:uiDrawText(dispNote, contentX + 10, noteBoxY + 8, contentX + noteBoxW - 10, noteBoxY + noteBoxH - 8, tocolor(255, 255, 255, 255), 1.0, fonts.val, "left", "top", true, true)

        local btnSaveW = math.floor(100 * scale)
        local btnSaveH = math.floor(25 * scale)
        local btnSaveY = noteBoxY + noteBoxH + math.floor(12 * scale)
        drawRoundedRectangle(contentX, btnSaveY, btnSaveW, btnSaveH, 4, tocolor(15, 23, 33, 255))
        drawRoundedBorder(contentX, btnSaveY, btnSaveW, btnSaveH, 4, tocolor(0, 245, 160, 240), 1.2)
        exports.aura_ui:uiDrawText("NOTU KAYDET", contentX, btnSaveY, contentX + btnSaveW, btnSaveY + btnSaveH, tocolor(0, 245, 160, 255), 1.0, fonts.btn, "center", "center")

    elseif S.playerDialogTab == "Kimlikler" then
        exports.aura_ui:uiDrawText("Oyuncu Kimlikleri", contentX, sepY + 12, contentX + 300, sepY + 30, tocolor(255, 255, 255, 255), 1.0, fonts.dialogTitle, "left", "center")

        local idList = {
            { label = "license:9660e7e3327b8f6ae2a7cff7836c666b7663eed2" },
            { label = "serial:" .. S.activePlayerDialog.serial },
            { label = "ip:" .. S.activePlayerDialog.ip },
            { label = "discord:506285943708188683" },
            { label = "character_id:" .. tostring(S.activePlayerDialog.id) }
        }
        local idStartY = sepY + math.floor(40 * scale)
        local idRowW = dw - (contentX - dx) - 24
        local idRowH = math.floor(32 * scale)

        for i, item in ipairs(idList) do
            local iy = idStartY + (i - 1) * (idRowH + 7)
            drawRoundedRectangle(contentX, iy, idRowW, idRowH, 6, tocolor(25, 33, 46, 255))
            exports.aura_ui:uiDrawText(item.label, contentX + 10, iy, contentX + idRowW - 36, iy + idRowH, tocolor(226, 232, 240, 255), 1.0, fonts.ver, "left", "center", true, false)
            drawIconSVG("copy", contentX + idRowW - 26, iy + 8, 15, tocolor(148, 163, 184, 255))
        end

    elseif S.playerDialogTab == "Geçmiş" then
        exports.aura_ui:uiDrawText("Oyuncu Geçmişi", contentX, sepY + 12, contentX + 300, sepY + 30, tocolor(255, 255, 255, 255), 1.0, fonts.dialogTitle, "left", "center")
        exports.aura_ui:uiDrawText("Bu oyuncu için geçmiş kayıt bulunamadı.", contentX, sepY + 44, contentX + 300, sepY + 68, tocolor(148, 163, 184, 255), 1.0, fonts.val, "left", "center")

    elseif S.playerDialogTab == "Yasakla" then
        exports.aura_ui:uiDrawText("Oyuncuyu Yasakla", contentX, sepY + 12, contentX + 300, sepY + 30, tocolor(255, 255, 255, 255), 1.0, fonts.dialogTitle, "left", "center")

        local label1Y = sepY + math.floor(38 * scale)
        exports.aura_ui:uiDrawText("Sebep *", contentX, label1Y, contentX + 300, label1Y + 16, tocolor(0, 245, 160, 255), 1.0, fonts.cat, "left", "center")

        local box1Y = label1Y + math.floor(20 * scale)
        local boxW = dw - (contentX - dx) - 24
        local box1H = math.floor(30 * scale)
        drawRoundedRectangle(contentX, box1Y, boxW, box1H, 6, tocolor(15, 23, 33, 255))
        drawRoundedBorder(contentX, box1Y, boxW, box1H, 6, tocolor(0, 245, 160, 180), 1.2)

        local dispReason = S.banReasonInput .. (getTickCount() % 1000 > 500 and "|" or "")
        exports.aura_ui:uiDrawText(dispReason, contentX + 10, box1Y, contentX + boxW - 10, box1Y + box1H, tocolor(255, 255, 255, 255), 1.0, fonts.val, "left", "center", true, false)

        local label2Y = box1Y + box1H + math.floor(14 * scale)
        exports.aura_ui:uiDrawText("Süre *", contentX, label2Y, contentX + 300, label2Y + 16, tocolor(100, 116, 139, 255), 1.0, fonts.cat, "left", "center")

        local box2Y = label2Y + math.floor(20 * scale)
        local box2W = math.floor(220 * scale)
        local box2H = math.floor(30 * scale)
        drawRoundedRectangle(contentX, box2Y, box2W, box2H, 6, tocolor(15, 23, 33, 255))
        drawRoundedBorder(contentX, box2Y, box2W, box2H, 6, tocolor(100, 116, 139, 120), 1.2)

        local curDurText = S.banDurations[S.banDurationIndex].label
        exports.aura_ui:uiDrawText(curDurText, contentX + 10, box2Y, contentX + math.floor(180 * scale), box2Y + box2H, tocolor(255, 255, 255, 255), 1.0, fonts.val, "left", "center")
        drawIconSVG(S.isBanDropdownOpen and "chevron_up" or "chevron_down", contentX + math.floor(195 * scale), box2Y + 7, 15, tocolor(148, 163, 184, 255))

        local helpY = box2Y + box2H + math.floor(6 * scale)
        exports.aura_ui:uiDrawText("Lütfen bir süre seçin.", contentX, helpY, contentX + 300, helpY + 16, tocolor(100, 116, 139, 255), 1.0, fonts.cat, "left", "center")

        local btnBanW = math.floor(90 * scale)
        local btnBanH = math.floor(28 * scale)
        local btnBanY = helpY + math.floor(22 * scale)
        drawRoundedRectangle(contentX, btnBanY, btnBanW, btnBanH, 4, tocolor(0, 245, 160, 255))
        exports.aura_ui:uiDrawText("YASAKLA", contentX, btnBanY, contentX + btnBanW, btnBanY + btnBanH, tocolor(10, 15, 22, 255), 1.0, fonts.btn, "center", "center")

        if S.isBanDropdownOpen then
            local dropItemH = math.floor(26 * scale)
            local dropY = box2Y + box2H + 2
            local dropH = #S.banDurations * dropItemH
            drawRoundedRectangle(contentX, dropY, box2W, dropH, 6, tocolor(13, 19, 28, 254), true)
            drawRoundedBorder(contentX, dropY, box2W, dropH, 6, tocolor(51, 65, 85, 255), 1.2, true)
            for i, d in ipairs(S.banDurations) do
                local iy = dropY + (i - 1) * dropItemH
                local isHover = isMouseInArea(contentX, iy, box2W, dropItemH)
                local isSel = (i == S.banDurationIndex)
                if isSel then
                    drawRoundedRectangle(contentX + 2, iy + 1, box2W - 4, dropItemH - 2, 4, tocolor(0, 245, 160, 35), true)
                elseif isHover then
                    drawRoundedRectangle(contentX + 2, iy + 1, box2W - 4, dropItemH - 2, 4, tocolor(30, 41, 56, 240), true)
                end
                local textColor = isSel and tocolor(0, 245, 160, 255) or (isHover and tocolor(255, 255, 255, 255) or tocolor(203, 213, 225, 255))
                exports.aura_ui:uiDrawText(d.label, contentX + 12, iy, contentX + box2W - 28, iy + dropItemH, textColor, 1.0, fonts.val, "left", "center", false, false, true)
                if isSel then
                    drawIconSVG("check", contentX + box2W - 22, iy + 5, 14, tocolor(0, 245, 160, 255), true)
                end
            end
        end
    end
end

local function renderInputModal()
    if not S.activeModal then return end

    local mw = math.floor(420 * scale)
    local mh = math.floor(165 * scale)
    local mx = math.floor((screenW - mw) / 2)
    local my = math.floor((screenH - mh) / 2)

    drawRoundedRectangle(mx, my, mw, mh, 14, tocolor(15, 22, 32, 254))
    drawRoundedRectangle(mx, my, mw, mh, 14, tocolor(255, 255, 255, 15))

    local mTitle = "İşlem"
    local mSub = "Bilgileri girin."
    if S.activeModal == "teleport" then
        mTitle = "Işınlan"
        mSub = "Solucan deliğinden geçmek için x, y, z koordinatlarını girin."
    elseif S.activeModal == "spawnVehicle" then
        mTitle = "Araç Çıkar"
        mSub = "Çıkarmak istediğiniz aracın model adını veya ID'sini girin."
    elseif S.activeModal == "announcement" then
        mTitle = "Duyuru Gönder"
        mSub = "Tüm oyunculara yayınlamak istediğiniz mesajı girin."
    elseif S.activeModal == "player_dm" then
        mTitle = "Özel Mesaj Gönder"
        mSub = "Oyuncuya iletmek istediğiniz özel mesajı girin."
    elseif S.activeModal == "player_warn" then
        mTitle = "Oyuncuyu Uyar"
        mSub = "Oyuncuya gönderilecek uyarı sebebini girin."
    elseif S.activeModal == "player_kick" then
        mTitle = "Oyuncuyu Sunucudan At"
        mSub = "Atılma sebebini girin."
    end

    exports.aura_ui:uiDrawText(mTitle, mx + 22, my + 14, mx + mw - 22, my + 38, tocolor(0, 245, 160, 255), 1.0, fonts.item, "left", "center")
    exports.aura_ui:uiDrawText(mSub, mx + 22, my + 38, mx + mw - 22, my + 56, tocolor(148, 163, 184, 255), 1.0, fonts.ver, "left", "center")

    local inY = my + math.floor(74 * scale)
    local inW = mw - 44
    local inX = mx + 22
    local inH = math.floor(26 * scale)

    drawIconSVG("pencil", inX + 2, inY + 5, 15, tocolor(148, 163, 184, 255))
    local displayModalText = (S.modalInputText == "") and "" or S.modalInputText
    exports.aura_ui:uiDrawText(displayModalText .. (getTickCount() % 1000 > 500 and "|" or "") , inX + 26, inY, inX + inW, inY + inH, tocolor(255, 255, 255, 255), 1.0, fonts.val, "left", "center")
    dxDrawLine(inX, inY + inH + 2, inX + inW, inY + inH + 2, tocolor(0, 245, 160, 255), 1.8)

    local btnCancelX = mx + mw - math.floor(145 * scale)
    local btnCancelY = my + mh - math.floor(38 * scale)
    local btnCancelW = math.floor(60 * scale)
    local btnCancelH = math.floor(24 * scale)

    exports.aura_ui:uiDrawText("İPTAL", btnCancelX, btnCancelY, btnCancelX + btnCancelW, btnCancelY + btnCancelH, tocolor(148, 163, 184, 255), 1.0, fonts.item, "center", "center")

    local btnSubmitX = mx + mw - math.floor(78 * scale)
    local btnSubmitY = btnCancelY
    local btnSubmitW = math.floor(65 * scale)
    local btnSubmitH = btnCancelH

    exports.aura_ui:uiDrawText("ONAYLA", btnSubmitX, btnSubmitY, btnSubmitX + btnSubmitW, btnSubmitY + btnSubmitH, tocolor(0, 245, 160, 255), 1.0, fonts.item, "center", "center")
end

renderTxAdmin = function()
    drawOverheadPlayerIDs()
    renderBannerNotifications()

    if not S.isOpen then return end

    local cardW = math.floor(330 * scale)
    local cardH = (S.currentTab == "OYUNCULAR") and math.floor(82 * scale) or math.floor(460 * scale)
    local cardX = math.floor(36 * scale)
    local cardY = math.floor(screenH * 0.12)

    drawTxAdminCard(cardX, cardY, cardW, cardH, 20)

    local brandFont = fonts.brand
    local verFont = fonts.ver
    local tabFont = fonts.tab
    local itemFont = fonts.item
    local valFont = fonts.val
    local arrowFont = fonts.arrow

    local headerY = cardY + math.floor(14 * scale)
    local logoStartX = cardX + math.floor(20 * scale)

    exports.aura_ui:uiDrawText("tx", logoStartX, headerY, logoStartX + 26, headerY + 28, tocolor(0, 245, 160, 255), 1.0, brandFont, "left", "center")
    local txW = exports.aura_ui:uiTextWidth("tx", 1.0, brandFont)
    exports.aura_ui:uiDrawText("Admin", logoStartX + txW, headerY, logoStartX + txW + 90, headerY + 28, tocolor(0, 245, 160, 255), 1.0, brandFont, "left", "center")
    local adminW = exports.aura_ui:uiTextWidth("Admin", 1.0, brandFont)

    exports.aura_ui:uiDrawText("v6.0.2", logoStartX + txW + adminW + 5, headerY + 3, logoStartX + txW + adminW + 60, headerY + 28, tocolor(100, 116, 139, 255), 1.0, verFont, "left", "center")
    exports.aura_ui:uiDrawText("[M: İmleç]", cardX + cardW - math.floor(80 * scale), headerY + 3, cardX + cardW - math.floor(16 * scale), headerY + 28, tocolor(100, 116, 139, 200), 1.0, verFont, "right", "center")

    local tabY = cardY + math.floor(48 * scale)
    local tabW = math.floor(cardW / 3)
    local tabH = math.floor(26 * scale)

    local tabs = {"ANA MENÜ", "OYUNCULAR", "TXADMIN"}
    for i, tabName in ipairs(tabs) do
        local tx = cardX + (i - 1) * tabW
        local isCurrent = (S.currentTab == tabName)
        local isHover = isMouseInArea(tx, tabY, tabW, tabH)

        local tabColor = isCurrent and tocolor(0, 245, 160, 255) or (isHover and tocolor(203, 213, 225, 255) or tocolor(100, 116, 139, 255))
        exports.aura_ui:uiDrawText(tabName, tx, tabY, tx + tabW, tabY + tabH, tabColor, 1.0, tabFont, "center", "center")

        if isCurrent then
            local lineW = math.floor(tabW * 0.58)
            local lineX = tx + math.floor((tabW - lineW) / 2)
            local lineY = tabY + tabH - 2
            drawRoundedRectangle(lineX, lineY, lineW, 2.0, 1.0, tocolor(0, 245, 160, 255))
        end
    end

    if S.currentTab == "ANA MENÜ" then
        local startY = cardY + math.floor(94 * scale)
        local rowH = math.floor(38 * scale)
        local rowW = cardW - math.floor(22 * scale)
        local rowX = cardX + math.floor(11 * scale)

        local items = {
            { icon = "noclip", title = "Oyuncu Modu:", val = S.playerModes[S.playerModeIndex], hasArrows = true },
            { icon = "teleport", title = "Işınlanma:", val = Config.TeleportLocations[S.teleportIndex].name, hasArrows = true },
            { icon = "vehicle", title = "Araç:", val = Config.Vehicles[S.vehicleIndex].name, hasArrows = true },
            { icon = "heal", title = "İyileştir:", val = S.healOptions[S.healIndex].name, hasArrows = true },
            { icon = "announcement", title = "Duyuru Gönder", val = "", hasArrows = false },
            { icon = "reset_world", title = "Bölgeyi Sıfırla", val = "", hasArrows = false },
            { icon = "player_ids", title = "Oyuncu ID'lerini Aç/Kapat", val = "", hasArrows = false }
        }

        for i, item in ipairs(items) do
            local ry = startY + (i - 1) * (rowH + math.floor(3 * scale))
            local isSelected = (S.selectedIndex == i)
            local isHover = isMouseInArea(rowX, ry, rowW, rowH)

            if isSelected or isHover then
                drawSelectedPill(rowX, ry, rowW, rowH, 10)
            end

            local iconSize = math.floor(16 * scale)
            local iconX = rowX + math.floor(12 * scale)
            local iconY = ry + math.floor((rowH - iconSize) / 2)
            local iconColor = isSelected and tocolor(255, 255, 255, 255) or tocolor(100, 116, 139, 255)
            drawIconSVG(item.icon, iconX, iconY, iconSize, iconColor)

            local textX = iconX + iconSize + math.floor(10 * scale)
            local titleColor = tocolor(255, 255, 255, 255)
            local titleW = exports.aura_ui:uiTextWidth(item.title, 1.0, itemFont)

            exports.aura_ui:uiDrawText(item.title, textX, ry, textX + titleW, ry + rowH, titleColor, 1.0, itemFont, "left", "center")

            if item.val ~= "" then
                local valX = textX + titleW + math.floor(5 * scale)
                local valColor = tocolor(116, 133, 152, 255)
                exports.aura_ui:uiDrawText(item.val, valX, ry, rowX + rowW - math.floor(36 * scale), ry + rowH, valColor, 1.0, valFont, "left", "center", true, false)
            end

            if item.hasArrows then
                local arrowBoxW = math.floor(32 * scale)
                local arrowX = rowX + rowW - arrowBoxW - math.floor(8 * scale)
                local arrowColor = tocolor(82, 98, 116, 255)
                exports.aura_ui:uiDrawText("< >", arrowX, ry, arrowX + arrowBoxW, ry + rowH, arrowColor, 1.0, arrowFont, "center", "center")
            end
        end

        local downIconSize = math.floor(14 * scale)
        local downIconX = cardX + math.floor((cardW - downIconSize) / 2)
        local downIconY = cardY + cardH - math.floor(20 * scale)
        drawIconSVG("chevron_down", downIconX, downIconY, downIconSize, tocolor(82, 98, 116, 255))

    elseif S.currentTab == "TXADMIN" then
        local startY = cardY + math.floor(94 * scale)
        local rowH = math.floor(38 * scale)
        local rowW = cardW - math.floor(22 * scale)
        local rowX = cardX + math.floor(11 * scale)

        local items = {
            { icon = "server", title = "Sunucu Saati:", val = S.serverTimeOptions[S.serverTimeIndex], hasArrows = true },
            { icon = "server", title = "Hava Durumu:", val = S.serverWeatherOptions[S.serverWeatherIndex], hasArrows = true },
            { icon = "vehicle", title = "Sahipsiz Araçlar:", val = "Temizle", hasArrows = false },
            { icon = "heal", title = "Tüm Oyuncular:", val = S.serverHealOptions[S.serverHealIndex], hasArrows = true },
            { icon = "announcement", title = "Sunucu Duyurusu:", val = "Yayınla", hasArrows = false },
            { icon = "info", title = "txAdmin Sürümü:", val = "v6.0.2 Güncel", hasArrows = false }
        }

        for i, item in ipairs(items) do
            local ry = startY + (i - 1) * (rowH + math.floor(3 * scale))
            local isSelected = (S.txadminSelectedIndex == i)
            local isHover = isMouseInArea(rowX, ry, rowW, rowH)

            if isSelected or isHover then
                drawSelectedPill(rowX, ry, rowW, rowH, 10)
            end

            local iconSize = math.floor(16 * scale)
            local iconX = rowX + math.floor(12 * scale)
            local iconY = ry + math.floor((rowH - iconSize) / 2)
            local iconColor = isSelected and tocolor(255, 255, 255, 255) or tocolor(100, 116, 139, 255)
            drawIconSVG(item.icon, iconX, iconY, iconSize, iconColor)

            local textX = iconX + iconSize + math.floor(10 * scale)
            local titleColor = tocolor(255, 255, 255, 255)
            local titleW = exports.aura_ui:uiTextWidth(item.title, 1.0, itemFont)

            exports.aura_ui:uiDrawText(item.title, textX, ry, textX + titleW, ry + rowH, titleColor, 1.0, itemFont, "left", "center")

            if item.val ~= "" then
                local valX = textX + titleW + math.floor(5 * scale)
                local valColor = tocolor(116, 133, 152, 255)
                exports.aura_ui:uiDrawText(item.val, valX, ry, rowX + rowW - math.floor(36 * scale), ry + rowH, valColor, 1.0, valFont, "left", "center", true, false)
            end

            if item.hasArrows then
                local arrowBoxW = math.floor(32 * scale)
                local arrowX = rowX + rowW - arrowBoxW - math.floor(8 * scale)
                local arrowColor = tocolor(82, 98, 116, 255)
                exports.aura_ui:uiDrawText("< >", arrowX, ry, arrowX + arrowBoxW, ry + rowH, arrowColor, 1.0, arrowFont, "center", "center")
            end
        end

        local downIconSize = math.floor(14 * scale)
        local downIconX = cardX + math.floor((cardW - downIconSize) / 2)
        local downIconY = cardY + cardH - math.floor(20 * scale)
        drawIconSVG("chevron_down", downIconX, downIconY, downIconSize, tocolor(82, 98, 116, 255))

    elseif S.currentTab == "OYUNCULAR" then
        local wideX = math.floor(36 * scale)
        local wideY = cardY + math.floor(94 * scale)
        local wideW = screenW - wideX * 2
        local wideH = screenH - wideY - math.floor(64 * scale)

        drawRoundedRectangle(wideX, wideY, wideW, wideH, 16, tocolor(13, 19, 27, 248))
        drawRoundedRectangle(wideX, wideY, wideW, wideH, 16, tocolor(255, 255, 255, 10))

        local titleFont = fonts.title
        local subFont = fonts.sub
        local tinyLabelFont = fonts.tiny

        exports.aura_ui:uiDrawText("Çevrimiçi Oyuncular", wideX + 24, wideY + 16, wideX + 300, wideY + 38, tocolor(0, 245, 160, 255), 1.0, titleFont, "left", "center")
        local countStr = string.format("%d/48 Oyuncu - (Aktif)", #S.playerList)
        exports.aura_ui:uiDrawText(countStr, wideX + 24, wideY + 38, wideX + 300, wideY + 54, tocolor(100, 116, 139, 255), 1.0, subFont, "left", "center")

        local sortW = math.floor(140 * scale)
        local sortX = wideX + wideW - sortW - math.floor(24 * scale)
        local sortY = wideY + math.floor(28 * scale)
        exports.aura_ui:uiDrawText("Sıralama", sortX, sortY - 14, sortX + sortW, sortY, tocolor(100, 116, 139, 255), 1.0, tinyLabelFont, "left", "center")
        exports.aura_ui:uiDrawText("A-Z  ID (İlk Giren) ▾", sortX, sortY, sortX + sortW, sortY + 20, tocolor(148, 163, 184, 255), 1.0, subFont, "left", "center")

        local searchW = math.floor(180 * scale)
        local searchX = sortX - searchW - math.floor(24 * scale)
        local searchY = sortY
        exports.aura_ui:uiDrawText("Arama", searchX, searchY - 14, searchX + searchW, searchY, tocolor(100, 116, 139, 255), 1.0, tinyLabelFont, "left", "center")
        drawIconSVG("search", searchX, searchY + 2, 14, tocolor(100, 116, 139, 255))
        local sDisplay = (S.playerSearchQuery == "" and not S.isSearchingPlayers) and "" or S.playerSearchQuery .. (S.isSearchingPlayers and (getTickCount() % 1000 > 500 and "|" or "") or "")
        exports.aura_ui:uiDrawText(sDisplay, searchX + 20, searchY, searchX + searchW, searchY + 20, tocolor(255, 255, 255, 255), 1.0, subFont, "left", "center", true, false)
        dxDrawLine(searchX, searchY + 20, searchX + searchW, searchY + 20, tocolor(51, 65, 85, 255), 1.0)

        local pStartY = wideY + math.floor(74 * scale)
        local cardItemW = math.floor(240 * scale)
        local cardItemH = math.floor(46 * scale)

        if #S.playerList == 0 then
            exports.aura_ui:uiDrawText("Çevrimiçi oyuncu bulunamadı.", wideX + 24, pStartY + 30, wideX + 300, pStartY + 70, tocolor(100, 116, 139, 255), 1.0, itemFont, "left", "center")
        else
            for i = 1, math.min(10, #S.playerList) do
                local ply = S.playerList[i]
                local ry = pStartY + (i - 1) * (cardItemH + 8)
                local isHover = isMouseInArea(wideX + 24, ry, cardItemW, cardItemH)

                drawRoundedRectangle(wideX + 24, ry, cardItemW, cardItemH, 8, isHover and tocolor(30, 41, 56, 255) or tocolor(20, 28, 40, 255))

                drawIconSVG("ped_walk", wideX + 34, ry + 11, 18, tocolor(16, 185, 129, 255))

                local idText = string.format("%d |", ply.id)
                local idW = exports.aura_ui:uiTextWidth(idText, 1.0, subFont)
                exports.aura_ui:uiDrawText(idText, wideX + 58, ry, wideX + 58 + idW, ry + cardItemH - 6, tocolor(255, 255, 255, 255), 1.0, subFont, "left", "center")

                drawCircle(wideX + 68 + idW, ry + (cardItemH - 6) * 0.5, 4.5, tocolor(56, 189, 248, 255))

                local nameStr = ply.name
                local nameW = exports.aura_ui:uiTextWidth(nameStr, 1.0, subFont)
                exports.aura_ui:uiDrawText(nameStr, wideX + 78 + idW, ry, wideX + 78 + idW + nameW, ry + cardItemH - 6, tocolor(255, 255, 255, 255), 1.0, subFont, "left", "center")

                local distStr = string.format("%dm", ply.dist)
                exports.aura_ui:uiDrawText(distStr, wideX + 84 + idW + nameW, ry, wideX + 24 + cardItemW - 10, ry + cardItemH - 6, tocolor(100, 116, 139, 255), 1.0, subFont, "left", "center")

                local hpBarW = cardItemW - 20
                local hpBarH = 2.5
                local hpBarX = wideX + 34
                local hpBarY = ry + cardItemH - 5

                exports.aura_ui:uiDrawRectangle(hpBarX, hpBarY, hpBarW, hpBarH, tocolor(15, 23, 42, 255))
                local curW = math.floor(hpBarW * (ply.health / 100))
                if curW > 0 then
                    exports.aura_ui:uiDrawRectangle(hpBarX, hpBarY, curW, hpBarH, tocolor(16, 185, 129, 255))
                end
            end
        end
    end

    renderPlayerModalDialog()
    renderInputModal()
end