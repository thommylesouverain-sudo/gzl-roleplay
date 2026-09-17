local screenW, screenH = guiGetScreenSize()
local playerCountTick, playerCount = nil, 0
local function getCachedPlayerCount()
    local now = getTickCount()
    if not playerCountTick or now < playerCountTick or now - playerCountTick >= 1000 then
        playerCount = #getElementsByType("player")
        playerCountTick = now
    end
    return playerCount
end
local mapTexture = nil
local mapShader = nil
local fontTitle = nil
local fontBold = nil
local fontMedium = nil
local fontSmall = nil
local playerArrowSvg = nil

local icons = {}

local isOpen = false
local currentTab = "MAP"
local selectedGameMenuIndex = 1

local mapCenterX = 0
local mapCenterY = 0
local zoomLevel = 0.40
local minZoom = 0.10
local maxZoom = 0.95

local isDragging = false
local dragStartX = 0
local dragStartY = 0
local mapDragStartX = 0
local mapDragStartY = 0

local currentWaypoint = nil
local waypointBlip = nil

local tabs = {
    {id = "MAP", label = "HARİTA"},
    {id = "GAME", label = "OYUN"},
    {id = "INFO", label = "BİLGİ"},
    {id = "STATS", label = "İSTATİSTİK"},
    {id = "SETTINGS", label = "AYARLAR"},
    {id = "QUIT", label = "ÇIKIŞ"}
}

local gameMenuItems = {
    {title = "Karakter Profili", desc = "Detaylı kimlik bilgileri, aktif meslek ve vatandaşlık derecesi."},
    {title = "Finansal Durum", desc = "Cüzdandaki nakit para, banka mevduatı ve toplam net varlıklar."},
    {title = "Lisanslar & Ruhsatlar", desc = "Sürücü belgesi, silah taşıma ruhsatı ve resmi izinler."},
    {title = "Sunucu Bilgileri", desc = "Sunucu versiyonu, anlık gecikme süresi (ping) ve oyuncu sayısı."},
    {title = "Kontroller & Tuşlar", desc = "Varsayılan GTA ve sunucuya özel atanmış kısayol tuşları."}
}

local customBlips = {
    {name = "LSPD Merkez Karakolu (Pershing Sq)", x = 1554.0, y = -1675.0, iconKey = "police"},
    {name = "All Saints Tip Merkezi (Hastane)", x = 1172.0, y = -1323.0, iconKey = "hospital"},
    {name = "Commerce Merkez Bankasi", x = 1481.0, y = -1745.0, iconKey = "bank"},
    {name = "Fleeca Bank (Commerce)", x = 1423.2, y = -1623.2, iconKey = "bank"},
    {name = "SubUrban Kiyafet Magazasi", x = 2073.0, y = -1897.0, iconKey = "shirt"},
    {name = "Idlewood Petrol Istasyonu", x = 1938.0, y = -1772.0, iconKey = "gas"},
    {name = "Los Santos Customs (Modifiye)", x = 1041.0, y = -1025.0, iconKey = "wrench"},
    {name = "Benny's Original Motor Works", x = 2279.7, y = -1999.6, iconKey = "wrench"},
    {name = "Diamond Casino & Resort", x = 2026.0, y = 1008.0, iconKey = "diamond"},
    {name = "Gentleman Kuafor & Berber", x = 2070.0, y = -1790.0, iconKey = "scissors"},
    {name = "San Fierro Emniyet Mudurlugu", x = -1605.0, y = 716.0, iconKey = "police"},
    {name = "Las Venturas Bolge Hastanesi", x = 1607.0, y = 1818.0, iconKey = "hospital"}
}

local function loadTablerIcon(name, file)
    local hFile = fileOpen(file)
    if hFile then
        local content = fileRead(hFile, fileGetSize(hFile))
        fileClose(hFile)
        icons[name] = svgCreate(24, 24, content)
    end
end

local function initResources()
    if isElement(mapTexture) then return end

    mapTexture = dxCreateTexture("assets/map.jpg", "dxt5", true, "clamp")
    mapShader = dxCreateShader("client/map.fx")

    fontTitle = dxCreateFont(":aura_ui/assets/Manrope-Bold.ttf", 22, true) or "default-bold"
    fontBold = dxCreateFont(":aura_ui/assets/Manrope-Bold.ttf", 12, true) or "default-bold"
    fontMedium = dxCreateFont(":aura_ui/assets/Manrope-Medium.ttf", 11, false) or "default"
    fontSmall = dxCreateFont(":aura_ui/assets/Manrope-Medium.ttf", 9, false) or "default"

    local arrowData = [[
        <svg width="26" height="26" viewBox="0 0 26 26" fill="none" xmlns="http://www.w3.org/2000/svg">
            <polygon points="13,2 24,24 13,18 2,24" fill="white" stroke="#0a0d14" stroke-width="1.8"/>
        </svg>
    ]]
    playerArrowSvg = svgCreate(26, 26, arrowData)

    loadTablerIcon("user", "assets/icons/user.svg")
    loadTablerIcon("police", "assets/icons/police.svg")
    loadTablerIcon("hospital", "assets/icons/hospital.svg")
    loadTablerIcon("bank", "assets/icons/bank.svg")
    loadTablerIcon("gas", "assets/icons/gas.svg")
    loadTablerIcon("shirt", "assets/icons/shirt.svg")
    loadTablerIcon("scissors", "assets/icons/scissors.svg")
    loadTablerIcon("wrench", "assets/icons/wrench.svg")
    loadTablerIcon("diamond", "assets/icons/diamond.svg")
    loadTablerIcon("pin", "assets/icons/pin.svg")
end

local function getMapRect()
    local marginX = math.floor(screenW * 0.05)
    local mapY = 138
    local mapW = screenW - (marginX * 2)
    local mapH = screenH - mapY - 65
    return marginX, mapY, mapW, mapH
end

local function worldToMapScreen(wx, wy)
    local mapX, mapY, mapW, mapH = getMapRect()
    local aspect = mapW / mapH

    local uCenter = (mapCenterX + 3000) / 6000
    local vCenter = (3000 - mapCenterY) / 6000

    local u = (wx + 3000) / 6000
    local v = (3000 - wy) / 6000

    local relU = (u - uCenter) / zoomLevel
    local relV = (v - vCenter) / zoomLevel

    local screenRelX = relU / aspect
    local screenRelY = relV

    local sx = mapX + (0.5 + screenRelX) * mapW
    local sy = mapY + (0.5 + screenRelY) * mapH

    return sx, sy
end

local function mapScreenToWorld(sx, sy)
    local mapX, mapY, mapW, mapH = getMapRect()
    local aspect = mapW / mapH

    local relX = (sx - mapX) / mapW - 0.5
    local relY = (sy - mapY) / mapH - 0.5

    local relU = relX * aspect
    local relV = relY

    local uCenter = (mapCenterX + 3000) / 6000
    local vCenter = (3000 - mapCenterY) / 6000

    local u = uCenter + relU * zoomLevel
    local v = vCenter + relV * zoomLevel

    local wx = (u * 6000) - 3000
    local wy = 3000 - (v * 6000)

    return math.max(-3000, math.min(3000, wx)), math.max(-3000, math.min(3000, wy))
end

function setWaypoint(x, y)
    if isElement(waypointBlip) then
        destroyElement(waypointBlip)
        waypointBlip = nil
    end
    currentWaypoint = {x = x, y = y}
    waypointBlip = createBlip(x, y, 0, 41, 2, 220, 38, 255, 255, 0, 99999.0)
    setElementData(waypointBlip, "isCustomWaypoint", true)
    if exports.gzl_ui then
        exports.gzl_ui:showNotification("GPS HEDEFİ", string.format("Hedef konumu ayarlandi (X: %d, Y: %d)", math.floor(x), math.floor(y)), "success", 2500)
    end
    playSoundFrontEnd(40)
end

function clearWaypoint()
    if isElement(waypointBlip) then
        destroyElement(waypointBlip)
        waypointBlip = nil
    end
    currentWaypoint = nil
    if exports.gzl_ui then
        exports.gzl_ui:showNotification("GPS HEDEFİ", "Hedef konumu kaldirildi.", "info", 2000)
    end
    playSoundFrontEnd(41)
end

function getWaypoint()
    return currentWaypoint
end

function isPauseMenuOpen()
    return isOpen
end

local function togglePauseMenu(forceState)
    if not getElementData(localPlayer, "char:id") and not getElementData(localPlayer, "loggedin_character") then return end

    if forceState ~= nil then
        isOpen = forceState
    else
        isOpen = not isOpen
    end

    showCursor(isOpen)
    showChat(false)
    if exports.gzl_chat and exports.gzl_chat.setChatVisible then
        exports.gzl_chat:setChatVisible(not isOpen)
    end

    if exports.gzl_hud then
        exports.gzl_hud:setHUDVisible(not isOpen)
    end

    if isOpen then
        initResources()
        local px, py, pz = getElementPosition(localPlayer)
        mapCenterX = px
        mapCenterY = py
        playSoundFrontEnd(43)
    else
        isDragging = false
        playSoundFrontEnd(44)
    end
end

addCommandHandler("openoldmap", function()
    togglePauseMenu()
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    initResources()
end)

addEventHandler("onClientClick", root, function(button, state, absX, absY)
    if not isOpen then return end

    local mapX, mapY, mapW, mapH = getMapRect()

    if state == "down" then
        if button == "left" then
            if absY >= 82 and absY <= 126 then
                local tabStartX = mapX
                local tabW = math.floor(mapW / #tabs)
                for i, tab in ipairs(tabs) do
                    local tx = tabStartX + (i - 1) * tabW
                    if absX >= tx and absX <= tx + tabW then
                        if tab.id == "QUIT" then
                            togglePauseMenu(false)
                        elseif tab.id == "SETTINGS" then
                            togglePauseMenu(false)
                            executeCommandHandler("hud")
                        else
                            currentTab = tab.id
                            playSoundFrontEnd(41)
                        end
                        return
                    end
                end
            end

            if currentTab == "MAP" then
                if absX >= mapX and absX <= mapX + mapW and absY >= mapY and absY <= mapY + mapH then
                    isDragging = true
                    dragStartX = absX
                    dragStartY = absY
                    mapDragStartX = mapCenterX
                    mapDragStartY = mapCenterY
                end
            elseif currentTab == "GAME" or currentTab == "INFO" or currentTab == "STATS" then
                local listX = mapX
                local listY = mapY
                local listW = math.floor(mapW * 0.35)
                local itemH = 58
                for i, item in ipairs(gameMenuItems) do
                    local iy = listY + (i - 1) * (itemH + 8)
                    if absX >= listX and absX <= listX + listW and absY >= iy and absY <= iy + itemH then
                        selectedGameMenuIndex = i
                        playSoundFrontEnd(41)
                        return
                    end
                end
            end
        elseif button == "right" and currentTab == "MAP" then
            if absX >= mapX and absX <= mapX + mapW and absY >= mapY and absY <= mapY + mapH then
                local wx, wy = mapScreenToWorld(absX, absY)
                if currentWaypoint then
                    local dist = getDistanceBetweenPoints2D(wx, wy, currentWaypoint.x, currentWaypoint.y)
                    if dist < (zoomLevel * 450) then
                        clearWaypoint()
                    else
                        setWaypoint(wx, wy)
                    end
                else
                    setWaypoint(wx, wy)
                end
            end
        end
    elseif state == "up" and button == "left" then
        isDragging = false
    end
end)

addEventHandler("onClientCursorMove", root, function(relX, relY, absX, absY)
    if not isOpen or not isDragging or currentTab ~= "MAP" then return end

    local mapX, mapY, mapW, mapH = getMapRect()
    local aspect = mapW / mapH

    local deltaX = absX - dragStartX
    local deltaY = absY - dragStartY

    local worldRangeX = 6000 * zoomLevel * aspect
    local worldRangeY = 6000 * zoomLevel

    local worldDeltaX = (deltaX / mapW) * worldRangeX
    local worldDeltaY = (deltaY / mapH) * worldRangeY

    mapCenterX = math.max(-2800, math.min(2800, mapDragStartX - worldDeltaX))
    mapCenterY = math.max(-2800, math.min(2800, mapDragStartY + worldDeltaY))
end)

bindKey("mouse_wheel_up", "down", function()
    if not isOpen or currentTab ~= "MAP" then return end
    local cx, cy = getCursorPosition()
    if cx and cy then
        local absX, absY = cx * screenW, cy * screenH
        local mapX, mapY, mapW, mapH = getMapRect()
        if absX >= mapX and absX <= mapX + mapW and absY >= mapY and absY <= mapY + mapH then
            zoomLevel = math.max(minZoom, zoomLevel * 0.85)
        end
    end
end)

bindKey("mouse_wheel_down", "down", function()
    if not isOpen or currentTab ~= "MAP" then return end
    local cx, cy = getCursorPosition()
    if cx and cy then
        local absX, absY = cx * screenW, cy * screenH
        local mapX, mapY, mapW, mapH = getMapRect()
        if absX >= mapX and absX <= mapX + mapW and absY >= mapY and absY <= mapY + mapH then
            zoomLevel = math.min(maxZoom, zoomLevel / 0.85)
        end
    end
end)

bindKey("space", "down", function()
    if not isOpen or currentTab ~= "MAP" then return end
    local px, py, pz = getElementPosition(localPlayer)
    mapCenterX = px
    mapCenterY = py
    playSoundFrontEnd(40)
end)

addEventHandler("onClientRender", root, function()
    if currentWaypoint and not isOpen then
        local wx, wy = currentWaypoint.x, currentWaypoint.y
        local groundZ = getGroundPosition(wx, wy, 100) or 15
        dxDrawLine3D(wx, wy, groundZ, wx, wy, groundZ + 45, tocolor(168, 85, 247, 220), 4.0)
    end

    if not isOpen or not isElement(mapTexture) or not isElement(mapShader) then return end

    exports.aura_ui:uiDrawRectangle(0, 0, screenW, screenH, tocolor(8, 11, 16, 215))

    local mapX, mapY, mapW, mapH = getMapRect()

    local pName = getElementData(localPlayer, "char:name") or getPlayerName(localPlayer)
    local pId = getElementData(localPlayer, "char:id") or 1
    local pCash = getPlayerMoney(localPlayer) or 0
    local pBank = getElementData(localPlayer, "char:bank_money") or 0

    local realTime = getRealTime()
    local days = {"PAZAR", "PAZARTESİ", "SALI", "ÇARŞAMBA", "PERŞEMBE", "CUMA", "CUMARTESİ"}
    local dayName = days[realTime.weekday + 1] or "CUMA"
    local timeStr = string.format("%s %02d:%02d", dayName, realTime.hour, realTime.minute)

    exports.aura_ui:uiDrawText("GZL: ", mapX, 26, mapX + 60, 68, tocolor(255, 255, 255, 255), 1.0, fontTitle, "left", "top")
    local prefixW = exports.aura_ui:uiTextWidth("GZL: ", 1.0, fontTitle)
    exports.aura_ui:uiDrawText("Roleplay", mapX + prefixW, 26, mapX + 350, 68, tocolor(34, 197, 94, 255), 1.0, fontTitle, "left", "top")
    local logoW = prefixW + exports.aura_ui:uiTextWidth("Roleplay", 1.0, fontTitle)
    exports.aura_ui:uiDrawText(" | " .. string.upper(pName) .. " | Oyuncu ID: " .. tostring(pId), mapX + logoW, 26, screenW - 300, 68, tocolor(255, 255, 255, 240), 1.0, fontTitle, "left", "top")

    local metaRightX = screenW - mapX - 58
    exports.aura_ui:uiDrawText(string.upper(pName), mapX, 20, metaRightX, 36, tocolor(240, 245, 255, 255), 1.0, fontBold, "right", "top")
    exports.aura_ui:uiDrawText(timeStr, mapX, 36, metaRightX, 52, tocolor(175, 190, 205, 220), 1.0, fontMedium, "right", "top")
    exports.aura_ui:uiDrawText(string.format("BANKA $%s  NAKİT $%s", tostring(pBank), tostring(pCash)), mapX, 52, metaRightX, 70, tocolor(230, 240, 250, 245), 1.0, fontBold, "right", "top")

    local avatarBoxX = screenW - mapX - 48
    exports.aura_ui:uiDrawRectangle(avatarBoxX, 20, 48, 50, tocolor(15, 20, 28, 240))
    exports.aura_ui:uiDrawRectangle(avatarBoxX, 20, 48, 50, tocolor(255, 255, 255, 35), false)
    if isElement(icons["user"]) then
        dxDrawImage(avatarBoxX + 12, 33, 24, 24, icons["user"], 0, 0, 0, tocolor(255, 255, 255, 230))
    end

    local tabStartY = 84
    local tabH = 38
    local tabW = math.floor(mapW / #tabs)

    for i, tab in ipairs(tabs) do
        local tx = mapX + (i - 1) * tabW
        local isSelected = (currentTab == tab.id)
        if isSelected then
            exports.aura_ui:uiDrawRectangle(tx, tabStartY, tabW - 3, tabH, tocolor(255, 255, 255, 255))
            exports.aura_ui:uiDrawRectangle(tx, tabStartY, tabW - 3, 4, tocolor(234, 179, 8, 255))
            exports.aura_ui:uiDrawText(tab.label, tx, tabStartY + 4, tx + tabW - 3, tabStartY + tabH, tocolor(10, 14, 20, 255), 1.0, fontBold, "center", "center")
        else
            exports.aura_ui:uiDrawRectangle(tx, tabStartY, tabW - 3, tabH, tocolor(15, 20, 28, 220))
            exports.aura_ui:uiDrawText(tab.label, tx, tabStartY + 4, tx + tabW - 3, tabStartY + tabH, tocolor(180, 195, 215, 200), 1.0, fontBold, "center", "center")
        end
    end

    if currentTab == "MAP" then
        local uCenter = (mapCenterX + 3000) / 6000
        local vCenter = (3000 - mapCenterY) / 6000
        local aspect = mapW / mapH

        dxSetShaderValue(mapShader, "gTexture", mapTexture)
        dxSetShaderValue(mapShader, "gCenterUV", {uCenter, vCenter})
        dxSetShaderValue(mapShader, "gZoom", zoomLevel)
        dxSetShaderValue(mapShader, "gAspect", aspect)

        exports.aura_ui:uiDrawRectangle(mapX - 2, mapY - 2, mapW + 4, mapH + 4, tocolor(10, 14, 20, 255))
        dxDrawImage(mapX, mapY, mapW, mapH, mapShader, 0, 0, 0, tocolor(255, 255, 255, 255))

        local px, py, pz = getElementPosition(localPlayer)
        local _, _, pRot = getElementRotation(localPlayer)
        local psX, psY = worldToMapScreen(px, py)

        if currentWaypoint and psX and currentWaypoint.x then
            local wsX, wsY = worldToMapScreen(currentWaypoint.x, currentWaypoint.y)
            dxDrawLine(psX, psY, wsX, wsY, tocolor(168, 85, 247, 255), 3.5)
        end

        for _, b in ipairs(customBlips) do
            local bsX, bsY = worldToMapScreen(b.x, b.y)
            if bsX >= mapX + 14 and bsX <= mapX + mapW - 14 and bsY >= mapY + 14 and bsY <= mapY + mapH - 14 then
                dxDrawCircle(bsX, bsY, 13, tocolor(255, 255, 255, 255))
                dxDrawCircle(bsX, bsY, 14, tocolor(15, 20, 28, 220), false)

                local iconElem = icons[b.iconKey]
                if isElement(iconElem) then
                    dxDrawImage(bsX - 9, bsY - 9, 18, 18, iconElem, 0, 0, 0, tocolor(15, 20, 28, 255))
                end
            end
        end

        if psX >= mapX and psX <= mapX + mapW and psY >= mapY and psY <= mapY + mapH then
            if isElement(playerArrowSvg) then
                dxDrawImage(psX - 13, psY - 13, 26, 26, playerArrowSvg, 360 - pRot, 0, 0, tocolor(255, 255, 255, 255))
            end
        end

        if currentWaypoint then
            local wsX, wsY = worldToMapScreen(currentWaypoint.x, currentWaypoint.y)
            if wsX >= mapX and wsX <= mapX + mapW and wsY >= mapY and wsY <= mapY + mapH then
                if isElement(icons["pin"]) then
                    dxDrawImage(wsX - 14, wsY - 24, 28, 28, icons["pin"], 0, 0, 0, tocolor(168, 85, 247, 255))
                end
            end
        end

        exports.aura_ui:uiDrawRectangle(mapX, mapY, mapW, mapH, tocolor(255, 255, 255, 25), false)

        local footerY = mapY + mapH + 12
        local footerText = "[SOL TIK] Haritada Gezin   |   [SAĞ TIK] Hedef Belirle / Kaldır   |   [TEKERLEK] Yakınlaş / Uzaklaş   |   [SPACE] Konumuma Git   |   [ESC] Kapat"
        exports.aura_ui:uiDrawText(footerText, mapX, footerY, mapX + mapW, footerY + 30, tocolor(175, 190, 210, 240), 1.0, fontMedium, "center")
    elseif currentTab == "GAME" or currentTab == "INFO" or currentTab == "STATS" then
        local listX = mapX
        local listY = mapY
        local listW = math.floor(mapW * 0.35)
        local listH = mapH

        local cardX = listX + listW + 24
        local cardY = mapY
        local cardW = mapW - listW - 24
        local cardH = mapH

        local itemH = 62
        for i, item in ipairs(gameMenuItems) do
            local iy = listY + (i - 1) * (itemH + 8)
            local isSel = (selectedGameMenuIndex == i)

            if isSel then
                exports.aura_ui:uiDrawRectangle(listX, iy, listW, itemH, tocolor(255, 255, 255, 255))
                exports.aura_ui:uiDrawRectangle(listX, iy, 5, itemH, tocolor(234, 179, 8, 255))
                exports.aura_ui:uiDrawText(item.title, listX + 20, iy + 10, listX + listW - 20, iy + 32, tocolor(10, 14, 20, 255), 1.0, fontBold)
                exports.aura_ui:uiDrawText(item.desc, listX + 20, iy + 32, listX + listW - 20, iy + itemH, tocolor(70, 85, 100, 240), 1.0, fontSmall, "left", "top", true)
            else
                exports.aura_ui:uiDrawRectangle(listX, iy, listW, itemH, tocolor(15, 20, 28, 230))
                exports.aura_ui:uiDrawText(item.title, listX + 20, iy + 10, listX + listW - 20, iy + 32, tocolor(240, 245, 255, 240), 1.0, fontBold)
                exports.aura_ui:uiDrawText(item.desc, listX + 20, iy + 32, listX + listW - 20, iy + itemH, tocolor(140, 155, 175, 200), 1.0, fontSmall, "left", "top", true)
            end
        end

        exports.aura_ui:uiDrawRectangle(cardX, cardY, cardW, cardH, tocolor(12, 17, 24, 240))
        exports.aura_ui:uiDrawRectangle(cardX, cardY, cardW, 58, tocolor(16, 22, 32, 255))

        local selectedTitle = gameMenuItems[selectedGameMenuIndex] and gameMenuItems[selectedGameMenuIndex].title or "Genel Bakış"
        exports.aura_ui:uiDrawText(string.upper(selectedTitle), cardX + 28, cardY + 16, cardX + cardW, cardY + 58, tocolor(255, 255, 255, 255), 1.0, fontTitle)

        local pJob = getElementData(localPlayer, "char:job") or "Sivil - Freelancer"
        local infoRows = {}

        if selectedGameMenuIndex == 1 then
            infoRows = {
                {"Karakter Adı Soyadı", tostring(pName)},
                {"Vatandaşlık Numarası (ID)", "#" .. tostring(pId)},
                {"Mevcut Meslek / Rol", tostring(pJob)},
                {"Vatandaşlık Durumu", "Onaylı Vatandaş (Yasal)"},
                {"Sunucu Yetkisi", "Geliştirici & Kurucu"},
                {"Toplam İtibar / Saygınlık", "+1,450 Rep"}
            }
        elseif selectedGameMenuIndex == 2 then
            infoRows = {
                {"Nakit Para (Cüzdan)", "$ " .. tostring(pCash)},
                {"Fleeca Banka Mevduatı", "$ " .. tostring(pBank)},
                {"Toplam Net Servet", "$ " .. tostring(pCash + pBank)},
                {"Aktif Banka Kartları", "Fleeca Diamond Visa (1x)"},
                {"Kayıtlı İşletmeler", "0 Şirket"},
                {"Vergi Dilimi", "Standart Düşük Oran (%3.5)"}
            }
        elseif selectedGameMenuIndex == 3 then
            infoRows = {
                {"Sürücü Belgesi (B Sınıfı)", "Aktif & Geçerli"},
                {"Motosiklet Ehliyeti (A2)", "Aktif & Geçerli"},
                {"Ticari Ağır Vasıta (SRC/TIR)", "Verilmedi"},
                {"Silah Taşıma Ruhsatı (CCW)", "Aktif (Yetkili)"},
                {"Havacılık Pilot Lisansı", "Verilmedi"},
                {"Avcılık & Balıkçılık İzni", "Aktif & Geçerli"}
            }
        else
            infoRows = {
                {"Sunucu Adı", "GZL Roleplay v8.0"},
                {"Grafik Motoru", "MTA:SA 1.6 x64 (DirectX HLSL)"},
                {"Çevrim İçi Oyuncular", tostring(getCachedPlayerCount()) .. " Aktif"},
                {"İstemci Kare Hızı", "60 FPS (Donanım Hızlandırmalı)"},
                {"Gecikme Süresi (Ping)", tostring(getPlayerPing(localPlayer)) .. " ms"},
                {"Baş Geliştirici", "thommy"}
            }
        end

        for i, row in ipairs(infoRows) do
            local iy = cardY + 76 + (i - 1) * 54
            exports.aura_ui:uiDrawRectangle(cardX + 28, iy, cardW - 56, 46, tocolor(18, 24, 34, 220))
            exports.aura_ui:uiDrawText(row[1], cardX + 44, iy + 13, cardX + 320, iy + 46, tocolor(150, 165, 185, 240), 1.0, fontBold)
            exports.aura_ui:uiDrawText(row[2], cardX + 320, iy + 13, cardX + cardW - 44, iy + 46, tocolor(255, 255, 255, 255), 1.0, fontBold, "right")
        end
    end
end)