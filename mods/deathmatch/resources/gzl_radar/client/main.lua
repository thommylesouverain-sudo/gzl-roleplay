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

local userRadarOffsetX = 0
local userRadarOffsetY = 0
local userRadarScale = 1.0

local radarDiameter = 216
local radarRadius = radarDiameter / 2
local radarX = 24
local radarY = screenH - radarDiameter - 86

local mapTexture = nil
local maskShader = nil
local mapShader = nil
local maskTexture = nil
local borderSvg = nil
local squareMaskTexture = nil
local squareBorderSvg = nil
local playerArrowSvg = nil
local cursorSvg = nil
local circleDiscSvg = nil
local circleRingSvg = nil

local fontTitle = nil
local fontBold = nil
local fontMedium = nil
local fontSmall = nil

local icons = {}

local isPauseOpen = false
local isMapInteractive = false
local currentTab = "MAP"
local selectedGameMenuIndex = 1
local selectedLegendIndex = 1

local mapCenterX = 0
local mapCenterY = 0
local zoomLevel = 0.40
local targetMapCenterX = 0
local targetMapCenterY = 0
local targetZoomLevel = 0.22
local minZoom = 0.08
local maxZoom = 0.95

local isDragging = false
local dragStartX = 0
local dragStartY = 0
local mapDragStartX = 0
local mapDragStartY = 0
local dragVelocityX = 0
local dragVelocityY = 0
local lastDragX = 0
local lastDragY = 0
local lastDragTime = 0

local currentWaypoint = nil
local waypointBlip = nil
local currentRoute = nil
local lastCalcPos = {x = 0, y = 0}

local radarShape = "circle"
local radarShowOnFoot = true
local radarBorderVisible = true
local radarGlobalVisible = true

local hoveredBlip = nil

local function createRadarSvgs()
    if isElement(maskTexture) then destroyElement(maskTexture) end
    if isElement(borderSvg) then destroyElement(borderSvg) end
    if isElement(squareMaskTexture) then destroyElement(squareMaskTexture) end
    if isElement(squareBorderSvg) then destroyElement(squareBorderSvg) end

    local maskData = string.format([[
        <svg width="%d" height="%d" viewBox="0 0 %d %d" fill="none" xmlns="http://www.w3.org/2000/svg">
            <circle cx="%d" cy="%d" r="%d" fill="white"/>
        </svg>
    ]], radarDiameter, radarDiameter, radarDiameter, radarDiameter, radarRadius, radarRadius, radarRadius - 2)
    maskTexture = svgCreate(radarDiameter, radarDiameter, maskData)

    local borderData = string.format([[
        <svg width="%d" height="%d" viewBox="0 0 %d %d" fill="none" xmlns="http://www.w3.org/2000/svg">
            <circle cx="%d" cy="%d" r="%d" stroke="white" stroke-width="1.8" stroke-opacity="0.55"/>
            <circle cx="%d" cy="%d" r="%d" stroke="#0a0d14" stroke-width="1.2" stroke-opacity="0.75"/>
        </svg>
    ]], radarDiameter, radarDiameter, radarDiameter, radarDiameter, radarRadius, radarRadius, radarRadius - 2, radarRadius, radarRadius, radarRadius - 4)
    borderSvg = svgCreate(radarDiameter, radarDiameter, borderData)

    local r = math.max(10, math.floor(16 * userRadarScale))
    local sqMaskData = string.format([[
        <svg width="%d" height="%d" viewBox="0 0 %d %d" fill="none" xmlns="http://www.w3.org/2000/svg">
            <rect x="2" y="2" width="%d" height="%d" rx="%d" ry="%d" fill="white"/>
        </svg>
    ]], radarDiameter, radarDiameter, radarDiameter, radarDiameter, radarDiameter - 4, radarDiameter - 4, r, r)
    squareMaskTexture = svgCreate(radarDiameter, radarDiameter, sqMaskData)

    local sqBorderData = string.format([[
        <svg width="%d" height="%d" viewBox="0 0 %d %d" fill="none" xmlns="http://www.w3.org/2000/svg">
            <rect x="2" y="2" width="%d" height="%d" rx="%d" ry="%d" stroke="white" stroke-width="1.8" stroke-opacity="0.55"/>
            <rect x="4" y="4" width="%d" height="%d" rx="%d" ry="%d" stroke="#0a0d14" stroke-width="1.2" stroke-opacity="0.75"/>
        </svg>
    ]], radarDiameter, radarDiameter, radarDiameter, radarDiameter, radarDiameter - 4, radarDiameter - 4, r, r, radarDiameter - 8, radarDiameter - 8, r - 2, r - 2)
    squareBorderSvg = svgCreate(radarDiameter, radarDiameter, sqBorderData)
end

local function recalcRadarDimensions()
    screenW, screenH = guiGetScreenSize()
    radarDiameter = math.floor(216 * userRadarScale)
    radarRadius = radarDiameter / 2
    local defaultX = 24
    local defaultY = screenH - radarDiameter - 86
    radarX = defaultX + (userRadarOffsetX or 0)
    radarY = defaultY + (userRadarOffsetY or 0)
    createRadarSvgs()
end

function setRadarShape(shape)
    radarShape = (shape == "square") and "square" or "circle"
end

function setRadarVisibleOnFoot(state)
    radarShowOnFoot = (state == true)
end

function setRadarBorderVisible(state)
    radarBorderVisible = (state ~= false)
end

function setRadarVisible(state)
    radarGlobalVisible = (state ~= false)
end

function setRadarLayout(x, y, scale)
    userRadarOffsetX = tonumber(x) or 0
    userRadarOffsetY = tonumber(y) or 0
    if scale and tonumber(scale) then
        userRadarScale = math.max(0.65, math.min(1.45, tonumber(scale)))
    end
    recalcRadarDimensions()
end

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
    {name = "Legion Square Garajı", x = 1478.4, y = -1741.2, iconKey = "garage", color = tocolor(56, 189, 248, 255), category = "GARAJ", sub = "Merkez Otopark"},
    {name = "Pillbox Hill Garajı", x = 1175.2, y = -1323.5, iconKey = "garage", color = tocolor(56, 189, 248, 255), category = "GARAJ", sub = "Katlı Otopark"},
    {name = "Idlewood Garajı", x = 1968.2, y = -1774.5, iconKey = "garage", color = tocolor(56, 189, 248, 255), category = "GARAJ", sub = "Doğu Otoparkı"},
    {name = "Çekilmiş Araçlar (Impound)", x = 1538.2, y = -1674.5, iconKey = "garage", color = tocolor(249, 115, 22, 255), category = "GARAJ", sub = "Yediemin Otoparkı"},
    {name = "LSPD Merkez Karakolu (Pershing Sq)", x = 1554.0, y = -1675.0, iconKey = "police", color = tocolor(59, 130, 246, 255), category = "KAMU", sub = "Emniyet Müdürlüğü"},
    {name = "All Saints Tıp Merkezi (Hastane)", x = 1172.0, y = -1323.0, iconKey = "hospital", color = tocolor(239, 68, 68, 255), category = "KAMU", sub = "Acil Servis & Klinik"},
    {name = "Commerce Merkez Bankası", x = 1481.0, y = -1745.0, iconKey = "bank", color = tocolor(16, 185, 129, 255), category = "TİCARET", sub = "Merkez Şube"},
    {name = "Fleeca Bank (Commerce)", x = 1423.2, y = -1623.2, iconKey = "bank", color = tocolor(16, 185, 129, 255), category = "TİCARET", sub = "Fleeca Şubesi"},
    {name = "SubUrban Kıyafet Mağazası", x = 2073.0, y = -1897.0, iconKey = "shirt", color = tocolor(236, 72, 153, 255), category = "HİZMET", sub = "Giyim & Moda"},
    {name = "Idlewood Petrol İstasyonu", x = 1938.0, y = -1772.0, iconKey = "gas", color = tocolor(245, 158, 11, 255), category = "HİZMET", sub = "LTD Akaryakıt"},
    {name = "Los Santos Customs (Modifiye)", x = 1041.0, y = -1025.0, iconKey = "wrench", color = tocolor(148, 163, 184, 255), category = "HİZMET", sub = "Oto Bakım & Modifiye"},
    {name = "Diamond Casino & Resort", x = 2026.0, y = 1008.0, iconKey = "diamond", color = tocolor(168, 85, 247, 255), category = "TİCARET", sub = "Eğlence & Kumarhane"},
    {name = "Gentleman Kuaför & Berber", x = 2070.0, y = -1790.0, iconKey = "scissors", color = tocolor(20, 184, 166, 255), category = "HİZMET", sub = "Saç & Sakal Tasarım"},
    {name = "San Fierro Emniyet Müdürlüğü", x = -1605.0, y = 716.0, iconKey = "police", color = tocolor(59, 130, 246, 255), category = "KAMU", sub = "SF Bölge Karakolu"},
    {name = "Las Venturas Bölge Hastanesi", x = 1607.0, y = 1818.0, iconKey = "hospital", color = tocolor(239, 68, 68, 255), category = "KAMU", sub = "LV Genel Hastanesi"}
}

local mtaIconMap = {
    [0] = "pin",
    [20] = "hospital",
    [22] = "hospital",
    [30] = "police",
    [41] = "pin",
    [45] = "shirt",
    [49] = "wrench",
    [52] = "bank",
    [55] = "gas",
    [56] = "scissors",
    [57] = "scissors",
    [59] = "diamond",
    [62] = "garage"
}

local selectedCategory = "TÜMÜ"
local categories = {"TÜMÜ", "GARAJ", "KAMU", "TİCARET", "HİZMET"}
local legendScrollOffset = 0
local panelLayout = {
    x = 0, y = 0, w = 310, h = 0,
    listY = 0, listH = 0,
    itemH = 40, itemGap = 4
}

local function getFilteredLegendList(px, py)
    local list = {
        { name = "Oyuncu (Siz)", x = px, y = py, iconKey = "user", color = tocolor(34, 197, 94, 255), category = "KAMU", sub = "Mevcut Konumunuz" }
    }
    for _, b in ipairs(customBlips) do
        if selectedCategory == "TÜMÜ" or (b.category and b.category == selectedCategory) then
            table.insert(list, b)
        end
    end
    return list
end

local function createBadgeSvgs()
    if not isElement(circleDiscSvg) then
        local discData = [[
            <svg width="64" height="64" viewBox="0 0 64 64" fill="none" xmlns="http://www.w3.org/2000/svg">
                <circle cx="32" cy="32" r="30" fill="white"/>
            </svg>
        ]]
        circleDiscSvg = svgCreate(64, 64, discData)
    end
    if not isElement(circleRingSvg) then
        local ringData = [[
            <svg width="64" height="64" viewBox="0 0 64 64" fill="none" xmlns="http://www.w3.org/2000/svg">
                <circle cx="32" cy="32" r="28" stroke="white" stroke-width="4.5"/>
            </svg>
        ]]
        circleRingSvg = svgCreate(64, 64, ringData)
    end
end

local function drawBlipBadge(x, y, iconKey, bgColor, radius, isSelected, postGUI)
    local r = radius or 11
    local pGUI = postGUI or false

    if not isElement(circleDiscSvg) or not isElement(circleRingSvg) then
        createBadgeSvgs()
    end

    if isSelected and isElement(circleRingSvg) then
        local ringR = r + 3.5
        dxDrawImage(x - ringR, y - ringR, ringR * 2, ringR * 2, circleRingSvg, 0, 0, 0, tocolor(255, 255, 255, 245), pGUI)
    end

    if isElement(circleDiscSvg) then
        local rimR = r + 1.5
        dxDrawImage(x - rimR, y - rimR, rimR * 2, rimR * 2, circleDiscSvg, 0, 0, 0, tocolor(10, 14, 23, 240), pGUI)

        dxDrawImage(x - r, y - r, r * 2, r * 2, circleDiscSvg, 0, 0, 0, bgColor or tocolor(56, 189, 248, 255), pGUI)
    else
        dxDrawCircle(x, y, r, 0, 360, bgColor or tocolor(56, 189, 248, 255), bgColor or tocolor(56, 189, 248, 255), 32, 1, pGUI)
    end

    local iconElem = iconKey and icons[iconKey] or nil
    if isElement(iconElem) then
        local iconSize = math.floor(r * 1.35)
        dxDrawImage(x - iconSize / 2, y - iconSize / 2, iconSize, iconSize, iconElem, 0, 0, 0, tocolor(255, 255, 255, 255), pGUI)
    end
end

local textureBindings = setmetatable({}, {__mode = "k"})
local function bindTexture(shader, key, value)
    if not isElement(shader) or not isElement(value) then return false end
    local values = textureBindings[shader]
    if not values then values = {}; textureBindings[shader] = values end
    if values[key] == value then return true end
    if dxSetShaderValue(shader, key, value) then values[key] = value; return true end
    return false
end

local blipCache, blipCacheTick, blipCacheDim, blipCacheInt = {}, nil, nil, nil
local function getActiveMtaBlips(pDim, pInt)
    local now = getTickCount()
    if blipCacheTick and now >= blipCacheTick and now - blipCacheTick < 100
        and pDim == blipCacheDim and pInt == blipCacheInt then
        for i = #blipCache, 1, -1 do
            local entry = blipCache[i]
            if isElement(entry.element) and getElementDimension(entry.element) == pDim
                and getElementInterior(entry.element) == pInt then
                entry.x, entry.y, entry.z = getElementPosition(entry.element)
            else
                table.remove(blipCache, i)
            end
        end
        return blipCache
    end
    local list = {}
    local blips = getElementsByType("blip")
    for _, b in ipairs(blips) do
        if isElement(b) and not getElementData(b, "isCustomWaypoint") then
            local bDim = getElementDimension(b)
            local bInt = getElementInterior(b)
            if bDim == pDim and bInt == pInt then
                local bx, by, bz = getElementPosition(b)
                local icon = getBlipIcon(b) or 0
                if icon ~= 41 then
                    local r, g, bCol, a = getBlipColor(b)
                    local name = getElementData(b, "name") or getElementData(b, "blip:name") or getElementData(b, "blipName")
                    local iconKey = mtaIconMap[icon]
                    table.insert(list, {
                        element = b,
                        x = bx,
                        y = by,
                        z = bz,
                        icon = icon,
                        iconKey = iconKey,
                        color = tocolor(r or 255, g or 255, bCol or 255, a or 255),
                        name = name or ("Nokta #" .. tostring(icon))
                    })
                end
            end
        end
    end
    blipCache, blipCacheTick, blipCacheDim, blipCacheInt = list, now, pDim, pInt
    return list
end

local function loadTablerIcon(name, file)
    if isElement(icons[name]) then return end
    local hFile = fileOpen(file)
    if hFile then
        local content = fileRead(hFile, fileGetSize(hFile))
        fileClose(hFile)
        if name ~= "pin" then
            content = string.gsub(content, 'stroke="currentColor"', 'stroke="#ffffff"')
            content = string.gsub(content, 'stroke="black"', 'stroke="#ffffff"')
            content = string.gsub(content, 'stroke="#000000"', 'stroke="#ffffff"')
            content = string.gsub(content, 'stroke="#000"', 'stroke="#ffffff"')
            content = string.gsub(content, 'fill="currentColor"', 'fill="#ffffff"')
            content = string.gsub(content, 'fill="black"', 'fill="#ffffff"')
            content = string.gsub(content, 'fill="#000000"', 'fill="#ffffff"')
            content = string.gsub(content, 'fill="#000"', 'fill="#ffffff"')
        end
        icons[name] = svgCreate(48, 48, content)
    end
end

local function initAllResources()
    if isElement(mapTexture) then return end

    mapTexture = dxCreateTexture("assets/map.jpg", "dxt5", true, "clamp")
    maskShader = dxCreateShader("client/mask.fx")
    mapShader = dxCreateShader("client/map.fx")

    recalcRadarDimensions()

    local arrowData = [[
        <svg width="26" height="26" viewBox="0 0 26 26" fill="none" xmlns="http://www.w3.org/2000/svg">
            <polygon points="13,2 24,24 13,18 2,24" fill="white" stroke="#0a0d14" stroke-width="1.8"/>
        </svg>
    ]]
    playerArrowSvg = svgCreate(26, 26, arrowData)

    local cursorData = [[
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
            <path d="M4 2 L4 19 L8.5 15 L12.5 22 L15.5 20.5 L11.5 13.5 L17 13.5 Z" fill="#ffffff" stroke="#0a0d14" stroke-width="1.6" stroke-linejoin="round"/>
        </svg>
    ]]
    cursorSvg = svgCreate(24, 24, cursorData)

    fontTitle = dxCreateFont(":aura_ui/assets/Manrope-Bold.ttf", 22, true) or "default-bold"
    fontBold = dxCreateFont(":aura_ui/assets/Manrope-Bold.ttf", 12, true) or "default-bold"
    fontMedium = dxCreateFont(":aura_ui/assets/Manrope-Medium.ttf", 11, false) or "default"
    fontSmall = dxCreateFont(":aura_ui/assets/Manrope-Medium.ttf", 9, false) or "default"

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
    loadTablerIcon("garage", "assets/icons/garage.svg")
end

local function updateGPSRoute()
    if not currentWaypoint then
        currentRoute = nil
        return
    end
    local px, py, pz = getElementPosition(localPlayer)
    triggerServerEvent("gzl_radar:requestRoute", resourceRoot, px, py, currentWaypoint.x, currentWaypoint.y)
    lastCalcPos = {x = px, y = py}
end

addEvent("gzl_radar:receiveRoute", true)
addEventHandler("gzl_radar:receiveRoute", resourceRoot, function(route)
    currentRoute = route
end)

local function getTrimmedRoute(px, py)
    if not currentRoute or #currentRoute == 0 then return nil end
    if not currentWaypoint then return nil end

    local distToGoal = getDistanceBetweenPoints2D(px, py, currentWaypoint.x, currentWaypoint.y)
    if distToGoal < 15 then
        clearWaypoint()
        return nil
    end

    local closestIdx = 1
    local minDistSq = 1e9
    for i, node in ipairs(currentRoute) do
        local dx = node.x - px
        local dy = node.y - py
        local distSq = dx * dx + dy * dy
        if distSq < minDistSq then
            minDistSq = distSq
            closestIdx = i
        end
    end

    if closestIdx > 1 then
        for k = 1, closestIdx - 1 do
            table.remove(currentRoute, 1)
        end
    end

    return currentRoute
end

local function getMenuLayout()
    local marginX = math.floor(screenW * 0.15)
    local menuW = screenW - (marginX * 2)
    local headerY = math.floor(screenH * 0.08)
    local tabY = headerY + 48
    local tabH = 34
    local mapY = tabY + tabH
    local mapH = screenH - mapY - 60
    return marginX, headerY, tabY, tabH, mapY, menuW, mapH
end

local function getMapRect()
    if isMapInteractive then
        return 0, 0, screenW, screenH
    else
        local marginX, _, _, _, mapY, mapW, mapH = getMenuLayout()
        return marginX, mapY, mapW, mapH
    end
end

local function getMapParams()
    local mapX, mapY, mapW, mapH = getMapRect()
    local aspect = mapW / mapH
    local zoom, uCenter, vCenter

    if isMapInteractive then
        zoom = zoomLevel
        uCenter = (mapCenterX + 3000) / 6000
        vCenter = (3000 - mapCenterY) / 6000
    else
        local px, py = getElementPosition(localPlayer)
        local rawU = (px + 3000) / 6000
        local rawV = (3000 - py) / 6000

        zoom = math.min(0.38, 0.96 / aspect)
        local halfU = (0.5 * aspect) * zoom
        local halfV = 0.5 * zoom

        if halfU >= 0.5 then
            uCenter = 0.5
        else
            uCenter = math.max(halfU, math.min(1.0 - halfU, rawU))
        end

        if halfV >= 0.5 then
            vCenter = 0.5
        else
            vCenter = math.max(halfV, math.min(1.0 - halfV, rawV))
        end
    end

    return mapX, mapY, mapW, mapH, aspect, zoom, uCenter, vCenter
end

local function worldToMapScreen(wx, wy)
    local mapX, mapY, mapW, mapH, aspect, zoom, uCenter, vCenter = getMapParams()

    local u = (wx + 3000) / 6000
    local v = (3000 - wy) / 6000

    local relU = (u - uCenter) / zoom
    local relV = (v - vCenter) / zoom

    local screenRelX = relU / aspect
    local screenRelY = relV

    local sx = mapX + (0.5 + screenRelX) * mapW
    local sy = mapY + (0.5 + screenRelY) * mapH

    return sx, sy
end

local function mapScreenToWorld(sx, sy)
    local mapX, mapY, mapW, mapH, aspect, zoom, uCenter, vCenter = getMapParams()

    local relX = (sx - mapX) / mapW - 0.5
    local relY = (sy - mapY) / mapH - 0.5

    local relU = relX * aspect
    local relV = relY

    local u = uCenter + relU * zoom
    local v = vCenter + relV * zoom

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
    waypointBlip = createBlip(x, y, 0, 41, 2, 255, 255, 255, 255, 0, 99999.0)
    setElementData(waypointBlip, "isCustomWaypoint", true)
    updateGPSRoute()
    if exports.gzl_ui and exports.gzl_ui.showNotification then
        exports.gzl_ui:showNotification("GPS", "Yeni hedef belirlendi, rota hesaplandı.", "info")
    end
    playSoundFrontEnd(40)
end

function clearWaypoint()
    if isElement(waypointBlip) then
        destroyElement(waypointBlip)
        waypointBlip = nil
    end
    currentWaypoint = nil
    currentRoute = nil
    if exports.gzl_ui and exports.gzl_ui.showNotification then
        exports.gzl_ui:showNotification("GPS", "Hedef ve rota temizlendi.", "info")
    end
    playSoundFrontEnd(41)
end

function getWaypoint()
    return currentWaypoint
end

function isPauseMenuOpen()
    return isPauseOpen
end

setTimer(function()
    if currentWaypoint then
        local px, py, pz = getElementPosition(localPlayer)
        local distMoved = getDistanceBetweenPoints2D(px, py, lastCalcPos.x, lastCalcPos.y)
        if distMoved > 35 then
            updateGPSRoute()
        end
    end
end, 1500, 0)

local function togglePauseMenu(forceState)
    if not (getElementData(localPlayer, "char:id") or getElementData(localPlayer, "character:id") or getElementData(localPlayer, "loggedin_character")) then return end

    if forceState ~= nil then
        isPauseOpen = forceState
    else
        isPauseOpen = not isPauseOpen
    end

    setElementData(localPlayer, "bigmap:isOpen", isPauseOpen, false)

    if isPauseOpen then
        initAllResources()
        local px, py, pz = getElementPosition(localPlayer)
        mapCenterX = px
        mapCenterY = py
        targetMapCenterX = px
        targetMapCenterY = py
        targetZoomLevel = 0.22
        zoomLevel = 0.38
        dragVelocityX = 0
        dragVelocityY = 0
        playSoundFrontEnd(43)
        setPlayerHudComponentVisible("all", false)
    else
        isMapInteractive = false
        isDragging = false
        dragVelocityX = 0
        dragVelocityY = 0
        setPlayerHudComponentVisible("all", false)
        setPlayerHudComponentVisible("crosshair", true)
    end

    showCursor(isPauseOpen, false)
    showChat(not isPauseOpen)
    if exports.gzl_chat and exports.gzl_chat.setChatVisible then
        exports.gzl_chat:setChatVisible(not isPauseOpen)
    end

    if exports.gzl_hud then
        exports.gzl_hud:setHUDVisible(not isPauseOpen)
    end
end

addEventHandler("onClientKey", root, function(button, press)
    if not press then return end
    if not (getElementData(localPlayer, "char:id") or getElementData(localPlayer, "character:id") or getElementData(localPlayer, "loggedin_character")) then return end
    if isChatBoxInputActive() or isConsoleActive() then return end

    if button == "escape" or button == "F11" then
        cancelEvent()
        local nowTick = getTickCount()

        if button == "escape" and not isPauseOpen then
            if (exports.gzl_core and exports.gzl_core.isPlayerTyping and exports.gzl_core:isPlayerTyping()) or guiGetInputEnabled() then
                return
            end
            if exports.gzl_atm and exports.gzl_atm.isATMOpen and exports.gzl_atm:isATMOpen() then
                return
            end
            if exports.gzl_ui and exports.gzl_ui.getActiveEditBox and exports.gzl_ui:getActiveEditBox() then
                return
            end
            if isCursorShowing() then
                return
            end
        end

        local isFuelOpen = getElementData(localPlayer, "gzl_fuel:isOpen") == true
        local lastFuelClosed = tonumber(getElementData(localPlayer, "gzl_fuel:lastClosedTick")) or 0
        if isFuelOpen or (lastFuelClosed > 0 and nowTick - lastFuelClosed < 500) then return end

        local isChatOpen = getElementData(localPlayer, "gzl_chat:isOpen") == true
        if not isChatOpen then
            pcall(function()
                if exports.gzl_chat and exports.gzl_chat.isChatInputOpen then
                    isChatOpen = exports.gzl_chat:isChatInputOpen()
                end
            end)
        end

        local lastChatClosed = tonumber(getElementData(localPlayer, "gzl_chat:lastClosedTick")) or 0
        if isChatOpen or (nowTick - lastChatClosed < 450) then
            if isChatOpen then
                pcall(function()
                    if exports.gzl_chat and exports.gzl_chat.closeChat then
                        exports.gzl_chat:closeChat()
                    end
                end)
            end
            return
        end

        local isInvOpen = getElementData(localPlayer, "ox_inventory:isOpen") == true or getElementData(localPlayer, "gzl_inventory:isOpen") == true
        if not isInvOpen then
            pcall(function()
                if exports.gzl_inventory and exports.gzl_inventory.isInventoryOpenState then
                    isInvOpen = exports.gzl_inventory:isInventoryOpenState()
                elseif exports.ox_inventory and exports.ox_inventory.isInventoryOpenState then
                    isInvOpen = exports.ox_inventory:isInventoryOpenState()
                end
            end)
        end

        local lastClosed = tonumber(getElementData(localPlayer, "ox_inventory:lastClosedTick")) or tonumber(getElementData(localPlayer, "gzl_inventory:lastClosedTick")) or 0

        if isInvOpen or (nowTick - lastClosed < 500) then
            if isInvOpen then
                pcall(function()
                    if exports.gzl_inventory and exports.gzl_inventory.toggleInventory then
                        exports.gzl_inventory:toggleInventory(false)
                    elseif exports.ox_inventory and exports.ox_inventory.toggleInventory then
                        exports.ox_inventory:toggleInventory(false)
                    end
                end)
            end
            return
        end

        if button == "F11" then
            if isPauseOpen then
                togglePauseMenu(false)
            else
                togglePauseMenu(true)
                isMapInteractive = true
                currentTab = "MAP"
            end
            return
        end

        if button == "escape" then
            if isPauseOpen then
                if isMapInteractive then
                    isMapInteractive = false
                    playSoundFrontEnd(42)
                else
                    togglePauseMenu(false)
                end
            else
                togglePauseMenu(true)
                isMapInteractive = false
                currentTab = "MAP"
            end
            return
        end
    elseif isPauseOpen and not isMapInteractive then
        if button == "q" then
            local currIdx = 1
            for i, tab in ipairs(tabs) do if tab.id == currentTab then currIdx = i break end end
            currIdx = currIdx - 1
            if currIdx < 1 then currIdx = #tabs end
            currentTab = tabs[currIdx].id
            playSoundFrontEnd(41)
        elseif button == "e" then
            local currIdx = 1
            for i, tab in ipairs(tabs) do if tab.id == currentTab then currIdx = i break end end
            currIdx = currIdx + 1
            if currIdx > #tabs then currIdx = 1 end
            currentTab = tabs[currIdx].id
            playSoundFrontEnd(41)
        elseif button == "enter" or button == "space" then
            if currentTab == "QUIT" then
                togglePauseMenu(false)
                triggerServerEvent("gzl_radar:quitGame", resourceRoot)
                return
            elseif currentTab == "SETTINGS" then
                togglePauseMenu(false)
                executeCommandHandler("hud")
                return
            elseif currentTab == "MAP" then
                isMapInteractive = true
                playSoundFrontEnd(41)
                return
            end
        end
    elseif isPauseOpen and isMapInteractive then
        local px, py = getElementPosition(localPlayer)
        local legendList = {
            { name = "Oyuncu (Siz)", x = px, y = py }
        }
        for _, b in ipairs(customBlips) do
            table.insert(legendList, { name = b.name, x = b.x, y = b.y })
        end

        if button == "arrow_d" then
            selectedLegendIndex = selectedLegendIndex + 1
            if selectedLegendIndex > #legendList then selectedLegendIndex = 1 end
            targetMapCenterX = legendList[selectedLegendIndex].x
            targetMapCenterY = legendList[selectedLegendIndex].y
            mapCenterX = targetMapCenterX
            mapCenterY = targetMapCenterY
            dragVelocityX = 0
            dragVelocityY = 0
            playSoundFrontEnd(41)
        elseif button == "arrow_u" then
            selectedLegendIndex = selectedLegendIndex - 1
            if selectedLegendIndex < 1 then selectedLegendIndex = #legendList end
            targetMapCenterX = legendList[selectedLegendIndex].x
            targetMapCenterY = legendList[selectedLegendIndex].y
            mapCenterX = targetMapCenterX
            mapCenterY = targetMapCenterY
            dragVelocityX = 0
            dragVelocityY = 0
            playSoundFrontEnd(41)
        elseif button == "pgup" then
            targetZoomLevel = math.max(minZoom, targetZoomLevel * 0.82)
        elseif button == "pgdn" then
            targetZoomLevel = math.min(maxZoom, targetZoomLevel / 0.82)
        end
    end
end)

addCommandHandler("map", function()
    togglePauseMenu()
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    initAllResources()
end)

addEventHandler("onClientResourceStart", root, function(res)
    if res == getThisResource() then return end
    local isChar = (getElementData(localPlayer, "character:id") or getElementData(localPlayer, "char:id") or getElementData(localPlayer, "loggedin_character")) and true or false
    if isChar then
        initAllResources()
        setPlayerHudComponentVisible("radar", false)
        if not isPauseOpen then
            radarGlobalVisible = true
        end
    end
end)

addEventHandler("onClientResourceStop", root, function(res)
    if res == getThisResource() then
        if isElement(mapTexture) then destroyElement(mapTexture) end
        if isElement(maskShader) then destroyElement(maskShader) end
        if isElement(mapShader) then destroyElement(mapShader) end
        if isElement(maskTexture) then destroyElement(maskTexture) end
        if isElement(borderSvg) then destroyElement(borderSvg) end
        if isElement(squareMaskTexture) then destroyElement(squareMaskTexture) end
        if isElement(squareBorderSvg) then destroyElement(squareBorderSvg) end
        if isElement(playerArrowSvg) then destroyElement(playerArrowSvg) end
        if isElement(cursorSvg) then destroyElement(cursorSvg) end
        if isElement(circleDiscSvg) then destroyElement(circleDiscSvg) end
        if isElement(circleRingSvg) then destroyElement(circleRingSvg) end
        for k, v in pairs(icons) do
            if isElement(v) then destroyElement(v) end
        end
        icons = {}
        return
    end

    local isChar = (getElementData(localPlayer, "character:id") or getElementData(localPlayer, "char:id") or getElementData(localPlayer, "loggedin_character")) and true or false
    if isChar then
        initAllResources()
        setPlayerHudComponentVisible("radar", false)
        if not isPauseOpen then
            radarGlobalVisible = true
        end
    end
end)

addEventHandler("onClientRestore", root, function(didClearRenderTargets)
    setTimer(function()
        recalcRadarDimensions()
        if not isElement(mapTexture) or not isElement(maskShader) then
            initAllResources()
        end
    end, 100, 1)
end)

addEventHandler("onClientPlayerWasted", localPlayer, function()
    if currentWaypoint then
        updateGPSRoute()
    end
end)

setTimer(function()
    local isChar = (getElementData(localPlayer, "character:id") or getElementData(localPlayer, "char:id") or getElementData(localPlayer, "loggedin_character")) and true or false
    if isChar and not isPauseOpen and not isPlayerMapVisible() then
        setPlayerHudComponentVisible("radar", false)
        if not radarGlobalVisible then
            radarGlobalVisible = true
        end
        if not isElement(mapTexture) or not isElement(maskShader) then
            initAllResources()
        end
    end
end, 1000, 0)

addEventHandler("onClientClick", root, function(button, state, absX, absY)
    if not isPauseOpen then return end

    local mapX, mapY, mapW, mapH = getMapRect()

    if state == "down" then
        if button == "left" then
            if not isMapInteractive then
                local marginX, headerY, tabY, tabH, mapY, menuW, mapH = getMenuLayout()
                if absY >= tabY and absY <= tabY + tabH then
                    local tabStartX = marginX + 22
                    local tabTotalW = menuW - 44
                    local tabW = math.floor(tabTotalW / #tabs)
                    for i, tab in ipairs(tabs) do
                        local tx = tabStartX + (i - 1) * tabW
                        if absX >= tx and absX <= tx + tabW then
                            if tab.id == "QUIT" then
                                togglePauseMenu(false)
                                triggerServerEvent("gzl_radar:quitGame", resourceRoot)
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
            end

            if currentTab == "MAP" then
                if not isMapInteractive then
                    if absX >= mapX and absX <= mapX + mapW and absY >= mapY and absY <= mapY + mapH then
                        isMapInteractive = true
                        local px, py = getElementPosition(localPlayer)
                        targetMapCenterX = px
                        targetMapCenterY = py
                        mapCenterX = px
                        mapCenterY = py
                        targetZoomLevel = 0.22
                        zoomLevel = 0.38
                        dragVelocityX = 0
                        dragVelocityY = 0
                        playSoundFrontEnd(41)
                        return
                    end
                else
                    if absX >= panelLayout.x and absX <= panelLayout.x + panelLayout.w and absY >= panelLayout.y and absY <= panelLayout.y + panelLayout.h then

                        local catY = panelLayout.y + 62
                        local catH = 26
                        if absY >= catY and absY <= catY + catH then
                            local catStartX = panelLayout.x + 10
                            local availableW = panelLayout.w - 20
                            local catW = math.floor(availableW / #categories)
                            for i, cat in ipairs(categories) do
                                local cx = catStartX + (i - 1) * catW
                                if absX >= cx and absX <= cx + catW - 3 then
                                    selectedCategory = cat
                                    legendScrollOffset = 0
                                    selectedLegendIndex = 1
                                    playSoundFrontEnd(41)
                                    return
                                end
                            end
                        end

                        if absY >= panelLayout.listY and absY <= panelLayout.listY + panelLayout.listH then
                            local rowStride = panelLayout.itemH + panelLayout.itemGap
                            local clickedSlot = math.floor((absY - panelLayout.listY) / rowStride) + 1
                            local px, py = getElementPosition(localPlayer)
                            local filteredList = getFilteredLegendList(px, py)
                            local dataIdx = legendScrollOffset + clickedSlot
                            local item = filteredList[dataIdx]

                            if item then
                                selectedLegendIndex = dataIdx
                                targetMapCenterX = item.x
                                targetMapCenterY = item.y
                                targetZoomLevel = 0.20
                                playSoundFrontEnd(41)
                            end
                        end
                        return
                    end

                    isDragging = true
                    dragStartX = absX
                    dragStartY = absY
                    mapDragStartX = targetMapCenterX
                    mapDragStartY = targetMapCenterY
                    lastDragX = absX
                    lastDragY = absY
                    lastDragTime = getTickCount()
                    dragVelocityX = 0
                    dragVelocityY = 0
                end
            elseif currentTab == "GAME" or currentTab == "INFO" or currentTab == "STATS" then
                local marginX, _, _, _, mapY, menuW, mapH = getMenuLayout()
                local listW = math.floor(menuW * 0.35)
                local itemH = 58
                for i, item in ipairs(gameMenuItems) do
                    local iy = mapY + (i - 1) * (itemH + 6)
                    if absX >= marginX and absX <= marginX + listW and absY >= iy and absY <= iy + itemH then
                        selectedGameMenuIndex = i
                        playSoundFrontEnd(41)
                        return
                    end
                end
            end
        elseif button == "right" and currentTab == "MAP" then
            if not isMapInteractive then
                if absX >= mapX and absX <= mapX + mapW and absY >= mapY and absY <= mapY + mapH then
                    isMapInteractive = true
                    local wx, wy = mapScreenToWorld(absX, absY)
                    setWaypoint(wx, wy)
                    return
                end
            else

                if absX >= panelLayout.x and absX <= panelLayout.x + panelLayout.w and absY >= panelLayout.y and absY <= panelLayout.y + panelLayout.h then
                    if absY >= panelLayout.listY and absY <= panelLayout.listY + panelLayout.listH then
                        local rowStride = panelLayout.itemH + panelLayout.itemGap
                        local clickedSlot = math.floor((absY - panelLayout.listY) / rowStride) + 1
                        local px, py = getElementPosition(localPlayer)
                        local filteredList = getFilteredLegendList(px, py)
                        local dataIdx = legendScrollOffset + clickedSlot
                        local item = filteredList[dataIdx]
                        if item then
                            selectedLegendIndex = dataIdx
                            if currentWaypoint then
                                local dw = getDistanceBetweenPoints2D(currentWaypoint.x, currentWaypoint.y, item.x, item.y)
                                if dw < 40 then
                                    clearWaypoint()
                                else
                                    setWaypoint(item.x, item.y)
                                end
                            else
                                setWaypoint(item.x, item.y)
                            end
                            playSoundFrontEnd(40)
                        end
                    end
                    return
                end

                local wx, wy = mapScreenToWorld(absX, absY)
                if currentWaypoint then
                    local wsX, wsY = worldToMapScreen(currentWaypoint.x, currentWaypoint.y)
                    local screenDist = math.sqrt((absX - wsX)^2 + (absY - wsY)^2)
                    if screenDist < 26 then
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
    if not isPauseOpen or not isDragging or currentTab ~= "MAP" or not isMapInteractive then return end

    local mapX, mapY, mapW, mapH = getMapRect()
    local aspect = mapW / mapH

    local deltaX = absX - dragStartX
    local deltaY = absY - dragStartY

    local worldRangeX = 6000 * zoomLevel * aspect
    local worldRangeY = 6000 * zoomLevel

    local worldDeltaX = (deltaX / mapW) * worldRangeX
    local worldDeltaY = (deltaY / mapH) * worldRangeY

    local newTargetX = math.max(-2850, math.min(2850, mapDragStartX - worldDeltaX))
    local newTargetY = math.max(-2850, math.min(2850, mapDragStartY + worldDeltaY))

    local now = getTickCount()
    local dt = math.max(1, now - lastDragTime) / 1000.0
    if dt < 0.1 then
        dragVelocityX = (newTargetX - targetMapCenterX) / dt
        dragVelocityY = (newTargetY - targetMapCenterY) / dt
    end

    targetMapCenterX = newTargetX
    targetMapCenterY = newTargetY
    lastDragX = absX
    lastDragY = absY
    lastDragTime = now
end)

bindKey("mouse_wheel_up", "down", function()
    if not isPauseOpen or currentTab ~= "MAP" or not isMapInteractive then return end
    local cx, cy = getCursorPosition()
    if cx and cy then
        cx, cy = cx * screenW, cy * screenH
        if cx >= panelLayout.x and cx <= panelLayout.x + panelLayout.w and cy >= panelLayout.y and cy <= panelLayout.y + panelLayout.h then
            legendScrollOffset = math.max(0, legendScrollOffset - 1)
            return
        end
        local mapX, mapY, mapW, mapH, aspect = getMapParams()
        local relX = (cx - mapX) / mapW - 0.5
        local relY = (cy - mapY) / mapH - 0.5
        local relU = relX * aspect
        local relV = relY
        local oldZoom = targetZoomLevel
        local newZoom = math.max(minZoom, oldZoom * 0.82)
        local zoomDiff = oldZoom - newZoom
        targetMapCenterX = math.max(-2850, math.min(2850, targetMapCenterX + relU * zoomDiff * 6000))
        targetMapCenterY = math.max(-2850, math.min(2850, targetMapCenterY - relV * zoomDiff * 6000))
        targetZoomLevel = newZoom
    else
        targetZoomLevel = math.max(minZoom, targetZoomLevel * 0.82)
    end
end)

bindKey("mouse_wheel_down", "down", function()
    if not isPauseOpen or currentTab ~= "MAP" or not isMapInteractive then return end
    local cx, cy = getCursorPosition()
    if cx and cy then
        cx, cy = cx * screenW, cy * screenH
        if cx >= panelLayout.x and cx <= panelLayout.x + panelLayout.w and cy >= panelLayout.y and cy <= panelLayout.y + panelLayout.h then
            local px, py = getElementPosition(localPlayer)
            local filteredList = getFilteredLegendList(px, py)
            local rowStride = panelLayout.itemH + panelLayout.itemGap
            local visibleCount = math.max(1, math.floor(panelLayout.listH / rowStride))
            local maxScroll = math.max(0, #filteredList - visibleCount)
            legendScrollOffset = math.min(maxScroll, legendScrollOffset + 1)
            return
        end
        local mapX, mapY, mapW, mapH, aspect = getMapParams()
        local relX = (cx - mapX) / mapW - 0.5
        local relY = (cy - mapY) / mapH - 0.5
        local relU = relX * aspect
        local relV = relY
        local oldZoom = targetZoomLevel
        local newZoom = math.min(maxZoom, oldZoom / 0.82)
        local zoomDiff = oldZoom - newZoom
        targetMapCenterX = math.max(-2850, math.min(2850, targetMapCenterX + relU * zoomDiff * 6000))
        targetMapCenterY = math.max(-2850, math.min(2850, targetMapCenterY - relV * zoomDiff * 6000))
        targetZoomLevel = newZoom
    else
        targetZoomLevel = math.min(maxZoom, targetZoomLevel / 0.82)
    end
end)

bindKey("space", "down", function()
    if not isPauseOpen or currentTab ~= "MAP" or not isMapInteractive then return end
    local px, py, pz = getElementPosition(localPlayer)
    targetMapCenterX = px
    targetMapCenterY = py
    mapCenterX = px
    mapCenterY = py
    dragVelocityX = 0
    dragVelocityY = 0
    playSoundFrontEnd(40)
end)

addEventHandler("onClientRender", root, function()
    if not (getElementData(localPlayer, "char:id") or getElementData(localPlayer, "character:id") or getElementData(localPlayer, "loggedin_character")) then return end

    screenW, screenH = guiGetScreenSize()

    if isPauseOpen and isMapInteractive then
        if not isDragging then
            if math.abs(dragVelocityX) > 1 or math.abs(dragVelocityY) > 1 then
                targetMapCenterX = math.max(-2850, math.min(2850, targetMapCenterX - dragVelocityX * 0.012))
                targetMapCenterY = math.max(-2850, math.min(2850, targetMapCenterY - dragVelocityY * 0.012))
                dragVelocityX = dragVelocityX * 0.88
                dragVelocityY = dragVelocityY * 0.88
            else
                dragVelocityX = 0
                dragVelocityY = 0
            end
        end

        mapCenterX = mapCenterX + (targetMapCenterX - mapCenterX) * 0.22
        mapCenterY = mapCenterY + (targetMapCenterY - mapCenterY) * 0.22
        zoomLevel = zoomLevel + (targetZoomLevel - zoomLevel) * 0.20
    end

    if currentWaypoint and not isPauseOpen then
        local wx, wy = currentWaypoint.x, currentWaypoint.y
        local groundZ = getGroundPosition(wx, wy, 100) or 15
        dxDrawLine3D(wx, wy, groundZ, wx, wy, groundZ + 60, tocolor(168, 85, 247, 180), 5.0)
        dxDrawLine3D(wx, wy, groundZ, wx, wy, groundZ + 60, tocolor(255, 255, 255, 240), 2.0)

        local px, py, pz = getElementPosition(localPlayer)
        local distToWp = getDistanceBetweenPoints3D(px, py, pz, wx, wy, groundZ)
        if distToWp <= 1200 then
            local sx, sy = getScreenFromWorldPosition(wx, wy, groundZ + 3.2, 0.06, false)
            if sx and sy then
                local distText = (distToWp < 1000) and string.format("HEDEF: %d m", math.floor(distToWp)) or string.format("HEDEF: %.1f km", distToWp / 1000)
                local bw = 110
                local bh = 24
                exports.aura_ui:uiDrawRectangle(sx - bw / 2, sy - bh / 2, bw, bh, tocolor(10, 15, 26, 220))
                exports.aura_ui:uiDrawRectangle(sx - bw / 2, sy - bh / 2, bw, 2, tocolor(168, 85, 247, 255))
                exports.aura_ui:uiDrawText(distText, sx - bw / 2, sy - bh / 2, sx + bw / 2, sy + bh / 2, tocolor(255, 255, 255, 255), 1.0, "default-bold", "center", "center")
            end
        end
    end

    if not isPauseOpen and not isPlayerMapVisible() then
        setPlayerHudComponentVisible("radar", false)
    end

    if not isPauseOpen and not isPlayerMapVisible() and radarGlobalVisible then
        if not isElement(mapTexture) or not isElement(maskShader) then
            initAllResources()
        end
        if isElement(mapTexture) and isElement(maskShader) then
            local veh = getPedOccupiedVehicle(localPlayer)
            local inVeh = isElement(veh)

            if inVeh or radarShowOnFoot then
                local pInt = getElementInterior(localPlayer)
                local isInterior = (pInt > 0)

                local px, py, pz = getElementPosition(localPlayer)
                local _, _, camRot = getElementRotation(getCamera())
                local _, _, pRot = getElementRotation(localPlayer)

                local speed = 0
                if inVeh then
                    local vx, vy, vz = getElementVelocity(veh)
                    speed = (vx^2 + vy^2 + vz^2)^(0.5) * 180
                end

                local activeMask = (radarShape == "square" and isElement(squareMaskTexture)) and squareMaskTexture or maskTexture
                local activeBorder = (radarShape == "square" and isElement(squareBorderSvg)) and squareBorderSvg or borderSvg
                local isSquare = (radarShape == "square")
                local halfW = radarRadius - 14
                local halfH = radarRadius - 14

                local zoom = inVeh and (0.058 + math.min(0.032, speed / 180 * 0.032)) or 0.046
                local scale = radarDiameter / (6000.0 * zoom)
                local rotRad = math.rad(-camRot)
                local cosA = math.cos(rotRad)
                local sinA = math.sin(rotRad)

                if isInterior then
                    if isSquare then
                        exports.aura_ui:uiDrawRectangle(radarX, radarY, radarDiameter, radarDiameter, tocolor(15, 23, 42, 235))
                        exports.aura_ui:uiDrawRectangle(radarX + 8, radarY + 8, radarDiameter - 16, radarDiameter - 16, tocolor(24, 32, 52, 140))
                    else
                        dxDrawCircle(radarX + radarRadius, radarY + radarRadius, radarRadius - 2, 0, 360, tocolor(15, 23, 42, 235))
                        dxDrawCircle(radarX + radarRadius, radarY + radarRadius, radarRadius - 12, 0, 360, tocolor(24, 32, 52, 140))
                    end
                    exports.aura_ui:uiDrawText("İÇ MEKAN", radarX, radarY + 16, radarX + radarDiameter, radarY + 32, tocolor(148, 163, 184, 180), 1.0, "default-bold", "center", "center")
                else
                    local u = (px + 3000) / 6000
                    local v = (3000 - py) / 6000
                    local angleRad = math.rad(-camRot)

                    bindTexture(maskShader, "gTexture", mapTexture)
                    bindTexture(maskShader, "gMaskTexture", activeMask)
                    dxSetShaderValue(maskShader, "gPlayerUV", {u, v})
                    dxSetShaderValue(maskShader, "gAngle", angleRad)
                    dxSetShaderValue(maskShader, "gZoom", zoom)

                    dxDrawImage(radarX, radarY, radarDiameter, radarDiameter, maskShader, 0, 0, 0, tocolor(255, 255, 255, 255))
                end

                if not isInterior then
                    local route = getTrimmedRoute(px, py)
                    if route and #route > 0 then
                        local prevX = radarX + radarRadius
                        local prevY = radarY + radarRadius

                        for _, node in ipairs(route) do
                            local du = node.x - px
                            local dv = py - node.y
                            local cx = (du * cosA + dv * sinA) * scale
                            local cy = (-du * sinA + dv * cosA) * scale
                            local scrX = radarX + radarRadius + cx
                            local scrY = radarY + radarRadius + cy

                            local isPointInside = false
                            if isSquare then
                                isPointInside = (math.abs(cx) <= (radarRadius - 4) and math.abs(cy) <= (radarRadius - 4))
                            else
                                isPointInside = (math.sqrt(cx * cx + cy * cy) <= (radarRadius - 4))
                            end

                            if isPointInside then
                                dxDrawLine(prevX, prevY, scrX, scrY, tocolor(178, 75, 243, 240), 4.5)
                            end
                            prevX, prevY = scrX, scrY
                        end
                    elseif currentWaypoint then
                        local du = currentWaypoint.x - px
                        local dv = py - currentWaypoint.y
                        local cx = (du * cosA + dv * sinA) * scale
                        local cy = (-du * sinA + dv * cosA) * scale
                        local dist = math.sqrt(cx * cx + cy * cy)

                        local clampX, clampY = cx, cy
                        if isSquare then
                            local sX = halfW / (math.abs(clampX) > 0 and math.abs(clampX) or 1)
                            local sY = halfH / (math.abs(clampY) > 0 and math.abs(clampY) or 1)
                            local s = math.min(1.0, math.min(sX, sY))
                            clampX = clampX * s
                            clampY = clampY * s
                        else
                            local maxR = radarRadius - 6
                            if dist > maxR then
                                clampX = (clampX / dist) * maxR
                                clampY = (clampY / dist) * maxR
                            end
                        end
                        dxDrawLine(radarX + radarRadius, radarY + radarRadius, radarX + radarRadius + clampX, radarY + radarRadius + clampY, tocolor(178, 75, 243, 160), 3.0)
                    end
                end

                local activeBlips = {}
                if not isInterior then
                    for _, b in ipairs(customBlips) do
                        table.insert(activeBlips, b)
                    end
                end

                local dynamicBlips = getActiveMtaBlips(pDim, pInt)
                for _, b in ipairs(dynamicBlips) do
                    table.insert(activeBlips, b)
                end

                for _, b in ipairs(activeBlips) do
                    local du = b.x - px
                    local dv = py - b.y
                    local cx = (du * cosA + dv * sinA) * scale
                    local cy = (-du * sinA + dv * cosA) * scale

                    local isInside = false
                    if isSquare then
                        isInside = (math.abs(cx) <= halfW and math.abs(cy) <= halfH)
                    else
                        isInside = (math.sqrt(cx * cx + cy * cy) <= (radarRadius - 14))
                    end

                    if isInside then
                        local blipX = radarX + radarRadius + cx
                        local blipY = radarY + radarRadius + cy

                        drawBlipBadge(blipX, blipY, b.iconKey, b.color, 10, false, false)
                    end
                end

                if radarBorderVisible and isElement(activeBorder) then
                    dxDrawImage(radarX, radarY, radarDiameter, radarDiameter, activeBorder, 0, 0, 0, tocolor(255, 255, 255, 255))
                end

                if isElement(playerArrowSvg) then
                    dxDrawImage(radarX + radarRadius - 13, radarY + radarRadius - 13, 26, 26, playerArrowSvg, camRot - pRot, 0, 0, tocolor(255, 255, 255, 255))
                end

                if currentWaypoint and not isInterior and isElement(icons["pin"]) then
                    local du = currentWaypoint.x - px
                    local dv = py - currentWaypoint.y
                    local cx = (du * cosA + dv * sinA) * scale
                    local cy = (-du * sinA + dv * cosA) * scale
                    local dist = math.sqrt(cx * cx + cy * cy)

                    if isSquare then
                        if math.abs(cx) > halfW or math.abs(cy) > halfH then
                            local sX = halfW / (math.abs(cx) > 0 and math.abs(cx) or 1)
                            local sY = halfH / (math.abs(cy) > 0 and math.abs(cy) or 1)
                            local s = math.min(sX, sY)
                            cx = cx * s
                            cy = cy * s
                        end
                    else
                        local maxR = radarRadius - 14
                        if dist > maxR then
                            cx = (cx / dist) * maxR
                            cy = (cy / dist) * maxR
                        end
                    end

                    local pinX = radarX + radarRadius + cx
                    local pinY = radarY + radarRadius + cy
                    dxDrawImage(pinX - 11, pinY - 18, 22, 22, icons["pin"], 0, 0, 0, tocolor(255, 255, 255, 255))
                end

                local northAngle = math.rad(camRot)
                local northDist = radarRadius - 11
                local northX = radarX + radarRadius + math.sin(northAngle) * northDist
                local northY = radarY + radarRadius - math.cos(northAngle) * northDist

                if isSquare then
                    local nOffsetW = radarRadius - 12
                    northX = math.max(radarX + 12, math.min(radarX + radarDiameter - 12, northX))
                    northY = math.max(radarY + 12, math.min(radarY + radarDiameter - 12, northY))
                end

                dxDrawCircle(northX, northY, 8, 0, 360, tocolor(12, 16, 24, 230))
                exports.aura_ui:uiDrawText("N", northX - 8, northY - 8, northX + 8, northY + 8, tocolor(240, 245, 255, 240), 1.0, "default-bold", "center", "center")

                if currentWaypoint and not isInterior then
                    local distToGoal = getDistanceBetweenPoints2D(px, py, currentWaypoint.x, currentWaypoint.y)
                    local distText = (distToGoal < 1000) and string.format("%dm", math.floor(distToGoal)) or string.format("%.1fkm", distToGoal / 1000)
                    local badgeW = 54
                    local badgeH = 18
                    local badgeX = radarX + radarDiameter - badgeW
                    local badgeY = radarY + radarDiameter - badgeH
                    exports.aura_ui:uiDrawRectangle(badgeX, badgeY, badgeW, badgeH, tocolor(15, 23, 42, 220))
                    exports.aura_ui:uiDrawRectangle(badgeX, badgeY, 2, badgeH, tocolor(168, 85, 247, 255))
                    exports.aura_ui:uiDrawText(distText, badgeX + 4, badgeY, badgeX + badgeW, badgeY + badgeH, tocolor(255, 255, 255, 255), 1.0, fontSmall or "default-bold", "center", "center")
                end
            end
        end
    end

    hoveredBlip = nil

    if isPauseOpen and isElement(mapTexture) and isElement(mapShader) then
        exports.aura_ui:uiDrawRectangle(0, 0, screenW, screenH, tocolor(10, 14, 23, 255), true)

        local function drawSVGBox(x, y, w, h, r, color, postGUI)
            if exports.gzl_ui and exports.gzl_ui.drawRoundedRectangle then
                exports.gzl_ui:drawRoundedRectangle(x, y, w, h, r or 3, color, postGUI ~= false)
            else
                exports.aura_ui:uiDrawRectangle(x, y, w, h, color, postGUI ~= false)
            end
        end

        local function drawLocationPanel(cursorX, cursorY, px, py)
            local panelW = 316
            local panelX = screenW - panelW - 24
            local panelY = 32
            local panelH = screenH - 96

            panelLayout.x = panelX
            panelLayout.y = panelY
            panelLayout.w = panelW
            panelLayout.h = panelH

            drawSVGBox(panelX, panelY, panelW, panelH, 6, tocolor(10, 14, 23, 240), true)

            exports.aura_ui:uiDrawRectangle(panelX, panelY, panelW, 1, tocolor(255, 255, 255, 25), true)
            exports.aura_ui:uiDrawRectangle(panelX, panelY + panelH - 1, panelW, 1, tocolor(255, 255, 255, 15), true)
            exports.aura_ui:uiDrawRectangle(panelX, panelY, 1, panelH, tocolor(255, 255, 255, 20), true)
            exports.aura_ui:uiDrawRectangle(panelX + panelW - 1, panelY, 1, panelH, tocolor(255, 255, 255, 15), true)

            drawSVGBox(panelX + 1, panelY + 1, panelW - 2, 54, 4, tocolor(16, 23, 36, 245), true)
            exports.aura_ui:uiDrawRectangle(panelX + 1, panelY + 54, panelW - 2, 1, tocolor(255, 255, 255, 20), true)

            exports.aura_ui:uiDrawText("HARİTA REHBERİ", panelX + 14, panelY + 10, panelX + 200, panelY + 30, tocolor(255, 255, 255, 255), 1.0, fontBold, "left", "center", false, false, true)
            exports.aura_ui:uiDrawText("Hızlı Konum & GPS", panelX + 14, panelY + 28, panelX + 200, panelY + 46, tocolor(148, 163, 184, 230), 1.0, fontSmall, "left", "center", false, false, true)

            local filteredList = getFilteredLegendList(px, py)
            local totalCount = #filteredList
            local countStr = string.format("%d Nokta", totalCount)
            local cw = exports.aura_ui:uiTextWidth(countStr, 1.0, fontSmall) + 16
            local countX = panelX + panelW - cw - 14
            drawSVGBox(countX, panelY + 16, cw, 22, 3, tocolor(56, 189, 248, 35), true)
            exports.aura_ui:uiDrawText(countStr, countX, panelY + 16, countX + cw, panelY + 38, tocolor(56, 189, 248, 255), 1.0, fontSmall, "center", "center", false, false, true)

            local catY = panelY + 62
            local catH = 26
            local catStartX = panelX + 10
            local availableW = panelW - 20
            local catW = math.floor(availableW / #categories)

            for i, cat in ipairs(categories) do
                local cx = catStartX + (i - 1) * catW
                local isCatSel = (selectedCategory == cat)
                local isCatHover = (cursorX >= cx and cursorX <= cx + catW - 3 and cursorY >= catY and cursorY <= catY + catH)

                local bgCol = isCatSel and tocolor(56, 189, 248, 240) or (isCatHover and tocolor(255, 255, 255, 28) or tocolor(20, 28, 42, 200))
                local txtCol = isCatSel and tocolor(10, 14, 23, 255) or (isCatHover and tocolor(255, 255, 255, 255) or tocolor(148, 163, 184, 220))

                drawSVGBox(cx, catY, catW - 3, catH, 2, bgCol, true)
                exports.aura_ui:uiDrawText(cat, cx, catY, cx + catW - 3, catY + catH, txtCol, 1.0, fontSmall, "center", "center", false, false, true)
            end

            local listY = catY + catH + 10
            local footerH = 38
            local listH = panelH - (listY - panelY) - footerH
            panelLayout.listY = listY
            panelLayout.listH = listH

            local itemH = 40
            local itemGap = 4
            local rowStride = itemH + itemGap
            local visibleCount = math.floor(listH / rowStride)

            local maxScroll = math.max(0, totalCount - visibleCount)
            if legendScrollOffset > maxScroll then legendScrollOffset = maxScroll end
            if legendScrollOffset < 0 then legendScrollOffset = 0 end

            local hasScrollbar = (totalCount > visibleCount)
            local itemW = hasScrollbar and (panelW - 26) or (panelW - 20)

            for i = 1, visibleCount do
                local dataIdx = legendScrollOffset + i
                local item = filteredList[dataIdx]
                if item then
                    local iy = listY + (i - 1) * rowStride
                    local ix = panelX + 10

                    local isSel = (selectedLegendIndex == dataIdx)
                    local isHover = (cursorX >= ix and cursorX <= ix + itemW and cursorY >= iy and cursorY <= iy + itemH)

                    local rowBg
                    if isSel then
                        rowBg = tocolor(255, 255, 255, 32)
                    elseif isHover then
                        rowBg = tocolor(255, 255, 255, 18)
                    else
                        rowBg = tocolor(16, 23, 35, 180)
                    end
                    drawSVGBox(ix, iy, itemW, itemH, 3, rowBg, true)

                    if isSel then
                        exports.aura_ui:uiDrawRectangle(ix, iy + 3, 3, itemH - 6, tocolor(56, 189, 248, 255), true)
                    end

                    drawBlipBadge(ix + 20, iy + itemH / 2, item.iconKey, item.color, 11, isSel, true)

                    local dist = getDistanceBetweenPoints2D(px, py, item.x, item.y)
                    local distStr = (dist < 1000) and string.format("%d m", math.floor(dist)) or string.format("%.1f km", dist / 1000)

                    local isAtWaypoint = false
                    if currentWaypoint then
                        local dw = getDistanceBetweenPoints2D(currentWaypoint.x, currentWaypoint.y, item.x, item.y)
                        if dw < 40 then isAtWaypoint = true end
                    end

                    local tagW = 46
                    if isAtWaypoint then
                        drawSVGBox(ix + itemW - tagW - 8, iy + 10, tagW, 20, 2, tocolor(168, 85, 247, 240), true)
                        exports.aura_ui:uiDrawText("HEDEF", ix + itemW - tagW - 8, iy + 10, ix + itemW - 8, iy + 30, tocolor(255, 255, 255, 255), 1.0, fontSmall, "center", "center", false, false, true)
                    else
                        exports.aura_ui:uiDrawText(distStr, ix + itemW - tagW - 8, iy + 4, ix + itemW - 8, iy + 22, tocolor(148, 163, 184, 220), 1.0, fontSmall, "right", "center", false, false, true)
                    end

                    local textRight = ix + itemW - tagW - 12
                    exports.aura_ui:uiDrawText(item.name, ix + 38, iy + 4, textRight, iy + 22, tocolor(255, 255, 255, 255), 1.0, fontMedium, "left", "center", true, false, true)
                    local subText = item.sub or (getZoneName(item.x, item.y, 0) .. " (" .. (item.category or "Bölge") .. ")")
                    exports.aura_ui:uiDrawText(subText, ix + 38, iy + 20, textRight, iy + 36, tocolor(148, 163, 184, 200), 1.0, fontSmall, "left", "center", true, false, true)
                end
            end

            if hasScrollbar then
                local trackX = panelX + panelW - 10
                local trackY = listY
                local trackH = listH
                exports.aura_ui:uiDrawRectangle(trackX, trackY, 4, trackH, tocolor(255, 255, 255, 15), true)

                local thumbH = math.max(18, math.floor(trackH * (visibleCount / totalCount)))
                local thumbY = trackY + math.floor((trackH - thumbH) * (legendScrollOffset / maxScroll))
                exports.aura_ui:uiDrawRectangle(trackX, thumbY, 4, thumbH, tocolor(56, 189, 248, 200), true)
            end

            local footY = panelY + panelH - footerH
            exports.aura_ui:uiDrawRectangle(panelX + 1, footY, panelW - 2, 1, tocolor(255, 255, 255, 18), true)
            exports.aura_ui:uiDrawText("[Sol Tık] Odaklan  •  [Sağ Tık] GPS  •  [Tekerlek] Kaydır", panelX, footY, panelX + panelW, panelY + panelH, tocolor(148, 163, 184, 210), 1.0, fontSmall, "center", "center", false, false, true)
        end

        local function drawActionBar(actionList)
            local footerY = screenH - 44
            local footerH = 30
            local barPadding = 14

            local totalW = 0
            for i, act in ipairs(actionList) do
                if act.label and #act.label > 0 then
                    totalW = totalW + exports.aura_ui:uiTextWidth(act.label, 1.0, fontMedium) + 6
                end
                for j, k in ipairs(act.keys) do
                    local isTwoLines = string.find(k, "\n", 1, true)
                    local kw
                    if #k <= 2 then
                        kw = 20
                    elseif isTwoLines then
                        local p1, p2 = k:match("([^\n]+)\n([^\n]+)")
                        kw = math.max(exports.aura_ui:uiTextWidth(p1 or "", 1.0, fontSmall), exports.aura_ui:uiTextWidth(p2 or "", 1.0, fontSmall)) + 10
                    else
                        kw = exports.aura_ui:uiTextWidth(k, 1.0, fontMedium) + 10
                    end
                    totalW = totalW + kw + (j < #act.keys and 3 or 0)
                end
                if i < #actionList then
                    totalW = totalW + 14
                end
            end

            local bgW = totalW + barPadding * 2
            local startX = screenW - bgW - 24
            drawSVGBox(startX, footerY - 3, bgW, footerH + 6, 2, tocolor(0, 0, 0, 235), true)

            local curX = startX + barPadding
            for i, act in ipairs(actionList) do
                if act.label and #act.label > 0 then
                    local lw = exports.aura_ui:uiTextWidth(act.label, 1.0, fontMedium)
                    exports.aura_ui:uiDrawText(act.label, curX, footerY, curX + lw, footerY + footerH, tocolor(255, 255, 255, 255), 1.0, fontMedium, "left", "center", false, false, true)
                    curX = curX + lw + 6
                end
                for j, k in ipairs(act.keys) do
                    local isTwoLines = string.find(k, "\n", 1, true)
                    local kw
                    if #k <= 2 then
                        kw = 20
                    elseif isTwoLines then
                        local p1, p2 = k:match("([^\n]+)\n([^\n]+)")
                        kw = math.max(exports.aura_ui:uiTextWidth(p1 or "", 1.0, fontSmall), exports.aura_ui:uiTextWidth(p2 or "", 1.0, fontSmall)) + 10
                    else
                        kw = exports.aura_ui:uiTextWidth(k, 1.0, fontMedium) + 10
                    end

                    drawSVGBox(curX, footerY + 3, kw, 24, 2, tocolor(255, 255, 255, 255), true)

                    if isTwoLines then
                        local p1, p2 = k:match("([^\n]+)\n([^\n]+)")
                        exports.aura_ui:uiDrawText(p1 or "", curX, footerY + 3, curX + kw, footerY + 15, tocolor(0, 0, 0, 255), 1.0, fontSmall, "center", "center", false, false, true)
                        exports.aura_ui:uiDrawText(p2 or "", curX, footerY + 15, curX + kw, footerY + 27, tocolor(0, 0, 0, 255), 1.0, fontSmall, "center", "center", false, false, true)
                    else
                        exports.aura_ui:uiDrawText(k, curX, footerY + 3, curX + kw, footerY + 27, tocolor(0, 0, 0, 255), 1.0, fontMedium, "center", "center", false, false, true)
                    end

                    curX = curX + kw + 3
                end
                curX = curX + 11
            end
        end

        local cursorX, cursorY = 0, 0
        local cx, cy = getCursorPosition()
        if cx and cy then
            cursorX = cx * screenW
            cursorY = cy * screenH
        end

        if not isMapInteractive then
            exports.aura_ui:uiDrawRectangle(0, 0, screenW, screenH, tocolor(12, 18, 14, 210), true)

            local marginX, headerY, tabY, tabH, mapY, menuW, mapH = getMenuLayout()

            local pName = getElementData(localPlayer, "char:name") or getPlayerName(localPlayer)
            local pId = getElementData(localPlayer, "char:id") or 1
            local pCash = getPlayerMoney(localPlayer) or 0
            local pBank = getElementData(localPlayer, "char:bank_money") or 0

            local realTime = getRealTime()
            local days = {"PAZAR", "PAZARTESİ", "SALI", "ÇARŞAMBA", "PERŞEMBE", "CUMA", "CUMARTESİ"}
            local dayName = days[realTime.weekday + 1] or "CUMA"
            local timeStr = string.format("%s %02d:%02d", dayName, realTime.hour, realTime.minute)

            exports.aura_ui:uiDrawText("Grand Theft Auto V", marginX, headerY, marginX + 400, headerY + 40, tocolor(255, 255, 255, 255), 1.0, fontTitle, "left", "center", false, false, true)

            local profileRightX = marginX + menuW
            local avatarW, avatarH = 48, 44
            local avatarX = profileRightX - avatarW
            local avatarY = headerY - 8

            drawSVGBox(avatarX, avatarY, avatarW, avatarH, 4, tocolor(15, 20, 28, 240), true)
            if isElement(icons["user"]) then
                dxDrawImage(avatarX + 12, avatarY + 10, 24, 24, icons["user"], 0, 0, 0, tocolor(255, 255, 255, 240), true)
            end

            local metaTextRight = avatarX - 14
            exports.aura_ui:uiDrawText(string.upper(pName), marginX, headerY - 10, metaTextRight, headerY + 6, tocolor(255, 255, 255, 255), 1.0, fontBold, "right", "top", false, false, true)
            exports.aura_ui:uiDrawText(timeStr, marginX, headerY + 7, metaTextRight, headerY + 22, tocolor(210, 220, 230, 230), 1.0, fontMedium, "right", "top", false, false, true)
            exports.aura_ui:uiDrawText(string.format("$%s", tostring(pBank + pCash)), marginX, headerY + 23, metaTextRight, headerY + 40, tocolor(255, 255, 255, 255), 1.0, fontBold, "right", "top", false, false, true)

            drawSVGBox(marginX, tabY, menuW, tabH, 2, tocolor(0, 0, 0, 200), true)
            exports.aura_ui:uiDrawText("<", marginX, tabY, marginX + 22, tabY + tabH, tocolor(255, 255, 255, 200), 1.0, fontBold, "center", "center", false, false, true)
            exports.aura_ui:uiDrawText(">", marginX + menuW - 22, tabY, marginX + menuW, tabY + tabH, tocolor(255, 255, 255, 200), 1.0, fontBold, "center", "center", false, false, true)

            local tabStartX = marginX + 22
            local tabTotalW = menuW - 44
            local tabW = math.floor(tabTotalW / #tabs)

            for i, tab in ipairs(tabs) do
                local tx = tabStartX + (i - 1) * tabW
                local isSelected = (currentTab == tab.id)
                if isSelected then
                    drawSVGBox(tx, tabY, tabW - 2, tabH, 2, tocolor(255, 255, 255, 255), true)
                    drawSVGBox(tx, tabY, tabW - 2, 4, 1, tocolor(74, 222, 128, 255), true)
                    exports.aura_ui:uiDrawText(tab.label, tx, tabY + 4, tx + tabW - 2, tabY + tabH, tocolor(0, 0, 0, 255), 1.0, fontBold, "center", "center", false, false, true)
                else
                    drawSVGBox(tx, tabY, tabW - 2, tabH, 2, tocolor(0, 0, 0, 160), true)
                    exports.aura_ui:uiDrawText(tab.label, tx, tabY + 4, tx + tabW - 2, tabY + tabH, tocolor(230, 235, 245, 220), 1.0, fontBold, "center", "center", false, false, true)
                end
            end

            if currentTab == "MAP" then
                local mapX, mapY, mapW, mapH, aspect, zoom, uCenter, vCenter = getMapParams()

                bindTexture(mapShader, "gTexture", mapTexture)
                dxSetShaderValue(mapShader, "gCenterUV", {uCenter, vCenter})
                dxSetShaderValue(mapShader, "gZoom", zoom)
                dxSetShaderValue(mapShader, "gAspect", aspect)

                dxDrawImage(mapX, mapY, mapW, mapH, mapShader, 0, 0, 0, tocolor(255, 255, 255, 255), true)

                local px, py, pz = getElementPosition(localPlayer)
                local _, _, pRot = getElementRotation(localPlayer)
                local psX, psY = worldToMapScreen(px, py)

                local pDim = getElementDimension(localPlayer)
                local pInt = getElementInterior(localPlayer)
                local bigMapBlips = {}
                for _, b in ipairs(customBlips) do table.insert(bigMapBlips, b) end
                for _, b in ipairs(getActiveMtaBlips(pDim, pInt)) do table.insert(bigMapBlips, b) end

                for _, b in ipairs(bigMapBlips) do
                    local bsX, bsY = worldToMapScreen(b.x, b.y)
                    if bsX >= marginX + 10 and bsX <= marginX + menuW - 10 and bsY >= mapY + 10 and bsY <= mapY + mapH - 10 then
                        drawBlipBadge(bsX, bsY, b.iconKey, b.color, 12, false, true)
                    end
                end

                if currentRoute and #currentRoute > 0 then
                    local prevX, prevY = psX, psY
                    for _, pt in ipairs(currentRoute) do
                        local scrX, scrY = worldToMapScreen(pt.x, pt.y)
                        dxDrawLine(prevX, prevY, scrX, scrY, tocolor(178, 75, 243, 240), 4.5, true)
                        prevX, prevY = scrX, scrY
                    end
                elseif currentWaypoint and psX and currentWaypoint.x then
                    local wsX, wsY = worldToMapScreen(currentWaypoint.x, currentWaypoint.y)
                    dxDrawLine(psX, psY, wsX, wsY, tocolor(178, 75, 243, 240), 4.5, true)
                end

                if psX >= marginX and psX <= marginX + menuW and psY >= mapY and psY <= mapY + mapH then
                    if isElement(playerArrowSvg) then
                        dxDrawImage(psX - 12, psY - 12, 24, 24, playerArrowSvg, 360 - pRot, 0, 0, tocolor(255, 255, 255, 255), true)
                    end
                end

                if currentWaypoint then
                    local wsX, wsY = worldToMapScreen(currentWaypoint.x, currentWaypoint.y)
                    if wsX >= marginX and wsX <= marginX + menuW and wsY >= mapY and wsY <= mapY + mapH then
                        if isElement(icons["pin"]) then
                            dxDrawImage(wsX - 12, wsY - 20, 24, 24, icons["pin"], 0, 0, 0, tocolor(255, 255, 255, 255), true)
                        end
                    end
                end

                drawActionBar({
                    { label = "Gözat", keys = {"Q", "E"} },
                    { label = "Tam Ekran Harita", keys = {"Sol Tık / Enter"} },
                    { label = "Hedef Belirle", keys = {"Sağ Tık"} },
                    { label = "Geri", keys = {"Esc"} }
                })
            elseif currentTab == "GAME" or currentTab == "INFO" or currentTab == "STATS" then
                local listW = math.floor(menuW * 0.35)
                local listH = mapH
                local cardX = marginX + listW + 16
                local cardW = menuW - listW - 16
                local cardH = mapH

                local itemH = 58
                for i, item in ipairs(gameMenuItems) do
                    local iy = mapY + (i - 1) * (itemH + 6)
                    local isSel = (selectedGameMenuIndex == i)
                    if isSel then
                        drawSVGBox(marginX, iy, listW, itemH, 2, tocolor(255, 255, 255, 255), true)
                        drawSVGBox(marginX, iy, 4, itemH, 1, tocolor(74, 222, 128, 255), true)
                        exports.aura_ui:uiDrawText(item.title, marginX + 16, iy + 8, marginX + listW - 16, iy + 30, tocolor(10, 14, 20, 255), 1.0, fontBold, "left", "top", false, false, true)
                        exports.aura_ui:uiDrawText(item.desc, marginX + 16, iy + 30, marginX + listW - 16, iy + itemH, tocolor(70, 85, 100, 240), 1.0, fontSmall, "left", "top", true, false, true)
                    else
                        drawSVGBox(marginX, iy, listW, itemH, 2, tocolor(0, 0, 0, 190), true)
                        exports.aura_ui:uiDrawText(item.title, marginX + 16, iy + 8, marginX + listW - 16, iy + 30, tocolor(240, 245, 255, 240), 1.0, fontBold, "left", "top", false, false, true)
                        exports.aura_ui:uiDrawText(item.desc, marginX + 16, iy + 30, marginX + listW - 16, iy + itemH, tocolor(140, 155, 175, 200), 1.0, fontSmall, "left", "top", true, false, true)
                    end
                end

                drawSVGBox(cardX, mapY, cardW, cardH, 2, tocolor(0, 0, 0, 190), true)
                drawSVGBox(cardX, mapY, cardW, 48, 2, tocolor(0, 0, 0, 230), true)
                local selectedTitle = gameMenuItems[selectedGameMenuIndex] and gameMenuItems[selectedGameMenuIndex].title or "Genel Bakış"
                exports.aura_ui:uiDrawText(string.upper(selectedTitle), cardX + 24, mapY + 12, cardX + cardW, mapY + 48, tocolor(255, 255, 255, 255), 1.0, fontBold, "left", "top", false, false, true)

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
                    local iy = mapY + 60 + (i - 1) * 48
                    drawSVGBox(cardX + 20, iy, cardW - 40, 42, 2, tocolor(15, 20, 28, 200), true)
                    exports.aura_ui:uiDrawText(row[1], cardX + 32, iy + 11, cardX + 300, iy + 42, tocolor(150, 165, 185, 240), 1.0, fontBold, "left", "top", false, false, true)
                    exports.aura_ui:uiDrawText(row[2], cardX + 300, iy + 11, cardX + cardW - 32, iy + 42, tocolor(255, 255, 255, 255), 1.0, fontBold, "right", "top", false, false, true)
                end
            end
        else
            local uCenter = (mapCenterX + 3000) / 6000
            local vCenter = (3000 - mapCenterY) / 6000
            local aspect = screenW / screenH

            bindTexture(mapShader, "gTexture", mapTexture)
            dxSetShaderValue(mapShader, "gCenterUV", {uCenter, vCenter})
            dxSetShaderValue(mapShader, "gZoom", zoomLevel)
            dxSetShaderValue(mapShader, "gAspect", aspect)

            dxDrawImage(0, 0, screenW, screenH, mapShader, 0, 0, 0, tocolor(255, 255, 255, 255), true)

            local px, py, pz = getElementPosition(localPlayer)
            local _, _, pRot = getElementRotation(localPlayer)
            local psX, psY = worldToMapScreen(px, py)

            local route = getTrimmedRoute(px, py)
            if route and #route > 0 then
                local prevX, prevY = psX, psY
                for _, node in ipairs(route) do
                    local nx, ny = worldToMapScreen(node.x, node.y)
                    dxDrawLine(prevX, prevY, nx, ny, tocolor(178, 75, 243, 240), 5.5, true)
                    prevX, prevY = nx, ny
                end
                if currentWaypoint then
                    local wsX, wsY = worldToMapScreen(currentWaypoint.x, currentWaypoint.y)
                    dxDrawLine(prevX, prevY, wsX, wsY, tocolor(178, 75, 243, 240), 5.5, true)
                end
            elseif currentWaypoint and psX and currentWaypoint.x then
                local wsX, wsY = worldToMapScreen(currentWaypoint.x, currentWaypoint.y)
                dxDrawLine(psX, psY, wsX, wsY, tocolor(178, 75, 243, 240), 5.5, true)
            end

            local pDim = getElementDimension(localPlayer)
            local pInt = getElementInterior(localPlayer)
            local bigMapBlips = {}
            for _, b in ipairs(customBlips) do table.insert(bigMapBlips, b) end
            for _, b in ipairs(getActiveMtaBlips(pDim, pInt)) do table.insert(bigMapBlips, b) end

            for _, b in ipairs(bigMapBlips) do
                local bsX, bsY = worldToMapScreen(b.x, b.y)
                if bsX >= 14 and bsX <= screenW - 14 and bsY >= 14 and bsY <= screenH - 14 then
                    local isSel = (hoveredBlip and hoveredBlip.name == b.name)
                    drawBlipBadge(bsX, bsY, b.iconKey, b.color, 13, isSel, true)

                    local mDist = math.sqrt((cursorX - bsX)^2 + (cursorY - bsY)^2)
                    if mDist <= 18 and not hoveredBlip then
                        hoveredBlip = {
                            name = b.name,
                            x = bsX,
                            y = bsY,
                            worldX = b.x,
                            worldY = b.y
                        }
                    end
                end
            end

            if psX >= 0 and psX <= screenW and psY >= 0 and psY <= screenH then
                if isElement(playerArrowSvg) then
                    dxDrawImage(psX - 13, psY - 13, 26, 26, playerArrowSvg, 360 - pRot, 0, 0, tocolor(255, 255, 255, 255), true)
                end
            end

            if currentWaypoint then
                local wsX, wsY = worldToMapScreen(currentWaypoint.x, currentWaypoint.y)
                if wsX >= 0 and wsX <= screenW and wsY >= 0 and wsY <= screenH then
                    if isElement(icons["pin"]) then
                        dxDrawImage(wsX - 14, wsY - 24, 28, 28, icons["pin"], 0, 0, 0, tocolor(255, 255, 255, 255), true)
                    end
                end
            end

            drawLocationPanel(cursorX, cursorY, px, py)

            local currentZone = getZoneName(mapCenterX, mapCenterY, 0)
            local scaleY = screenH - 65
            exports.aura_ui:uiDrawText("0", 32, scaleY - 14, 46, scaleY, tocolor(255, 255, 255, 240), 1.0, fontSmall, "left", "bottom", false, false, true)
            exports.aura_ui:uiDrawText(string.format("%dft", math.floor(zoomLevel * 4500)), 32, scaleY - 14, 132, scaleY, tocolor(255, 255, 255, 240), 1.0, fontSmall, "right", "bottom", false, false, true)
            dxDrawLine(32, scaleY, 132, scaleY, tocolor(255, 255, 255, 240), 1.5, true)
            dxDrawLine(32, scaleY - 6, 32, scaleY, tocolor(255, 255, 255, 240), 1.5, true)
            dxDrawLine(132, scaleY - 6, 132, scaleY, tocolor(255, 255, 255, 240), 1.5, true)

            local zoneDisplay = string.upper(currentZone)
            if currentWaypoint then
                local dw = getDistanceBetweenPoints2D(px, py, currentWaypoint.x, currentWaypoint.y)
                local dwStr = (dw < 1000) and string.format("%d m", math.floor(dw)) or string.format("%.1f km", dw / 1000)
                zoneDisplay = zoneDisplay .. "  #a855f7|  HEDEF: " .. dwStr
            end
            exports.aura_ui:uiDrawText(zoneDisplay, 32, scaleY + 8, 450, scaleY + 28, tocolor(255, 255, 255, 255), 1.0, fontBold, "left", "top", false, false, true, true)

            if hoveredBlip then
                local hText = hoveredBlip.name
                local distFromP = getDistanceBetweenPoints2D(px, py, hoveredBlip.worldX, hoveredBlip.worldY)
                local distStr = (distFromP < 1000) and string.format("%d m", math.floor(distFromP)) or string.format("%.1f km", distFromP / 1000)
                local tipLine1 = hText
                local tipLine2 = "Mesafe: " .. distStr
                local tipW = math.max(exports.aura_ui:uiTextWidth(tipLine1, 1.0, fontBold), exports.aura_ui:uiTextWidth(tipLine2, 1.0, fontSmall)) + 24
                local tipH = 40
                local tipX = math.max(10, math.min(screenW - tipW - 10, hoveredBlip.x - tipW / 2))
                local tipY = hoveredBlip.y - tipH - 12
                drawSVGBox(tipX, tipY, tipW, tipH, 4, tocolor(10, 15, 26, 245), true)
                drawSVGBox(tipX, tipY + tipH - 2, tipW, 2, 0, tocolor(56, 189, 248, 255), true)
                exports.aura_ui:uiDrawText(tipLine1, tipX + 12, tipY + 4, tipX + tipW - 12, tipY + 22, tocolor(255, 255, 255, 255), 1.0, fontBold, "left", "center", false, false, true)
                exports.aura_ui:uiDrawText(tipLine2, tipX + 12, tipY + 20, tipX + tipW - 12, tipY + 36, tocolor(148, 163, 184, 255), 1.0, fontSmall, "left", "center", false, false, true)
            end

            drawActionBar({
                { label = "Yakınlaş", keys = {"Tekerlek", "PgUp/Dn"} },
                { label = "Blip Seç", keys = {"↑", "↓"} },
                { label = "Karaktere Odaklan", keys = {"Space"} },
                { label = "Hedef Koy/Kaldır", keys = {"Sağ Tık / Enter"} },
                { label = "Geri", keys = {"Esc / F11"} }
            })
        end
    end

    if isPauseOpen and isElement(cursorSvg) then
        local cx, cy = getCursorPosition()
        if cx and cy then
            dxDrawImage(cx * screenW, cy * screenH, 22, 22, cursorSvg, 0, 0, 0, tocolor(255, 255, 255, 255), true)
        end
    end
end, false, "low-9999")

bindKey("enter", "down", function()
    if not isPauseOpen or currentTab ~= "MAP" then return end
    local px, py = getElementPosition(localPlayer)
    local filteredList = getFilteredLegendList(px, py)
    if isMapInteractive and selectedLegendIndex and filteredList[selectedLegendIndex] then
        local item = filteredList[selectedLegendIndex]
        if currentWaypoint and getDistanceBetweenPoints2D(currentWaypoint.x, currentWaypoint.y, item.x, item.y) < 10 then
            clearWaypoint()
        else
            setWaypoint(item.x, item.y)
        end
    elseif currentWaypoint then
        local dist = getDistanceBetweenPoints2D(mapCenterX, mapCenterY, currentWaypoint.x, currentWaypoint.y)
        if dist < (zoomLevel * 450) then
            clearWaypoint()
        else
            setWaypoint(mapCenterX, mapCenterY)
        end
    else
        setWaypoint(mapCenterX, mapCenterY)
    end
end)

bindKey("arrow_u", "down", function()
    if not isPauseOpen or currentTab ~= "MAP" then return end
    local px, py = getElementPosition(localPlayer)
    local filteredList = getFilteredLegendList(px, py)
    local totalItems = #filteredList
    if totalItems == 0 then return end
    selectedLegendIndex = (selectedLegendIndex or 1) - 1
    if selectedLegendIndex < 1 then selectedLegendIndex = totalItems end
    local visibleCount = panelLayout and panelLayout.visibleCount or 7
    if selectedLegendIndex <= legendScrollOffset then
        legendScrollOffset = math.max(0, selectedLegendIndex - 1)
    elseif selectedLegendIndex > legendScrollOffset + visibleCount then
        legendScrollOffset = math.min(math.max(0, totalItems - visibleCount), selectedLegendIndex - visibleCount)
    end
    local item = filteredList[selectedLegendIndex]
    if item then
        targetMapCenterX = item.x
        targetMapCenterY = item.y
        mapCenterX = item.x
        mapCenterY = item.y
        dragVelocityX = 0
        dragVelocityY = 0
    end
    playSoundFrontEnd(41)
end)

bindKey("arrow_d", "down", function()
    if not isPauseOpen or currentTab ~= "MAP" then return end
    local px, py = getElementPosition(localPlayer)
    local filteredList = getFilteredLegendList(px, py)
    local totalItems = #filteredList
    if totalItems == 0 then return end
    selectedLegendIndex = (selectedLegendIndex or 0) + 1
    if selectedLegendIndex > totalItems then selectedLegendIndex = 1 end
    local visibleCount = panelLayout and panelLayout.visibleCount or 7
    if selectedLegendIndex <= legendScrollOffset then
        legendScrollOffset = math.max(0, selectedLegendIndex - 1)
    elseif selectedLegendIndex > legendScrollOffset + visibleCount then
        legendScrollOffset = math.min(math.max(0, totalItems - visibleCount), selectedLegendIndex - visibleCount)
    end
    local item = filteredList[selectedLegendIndex]
    if item then
        targetMapCenterX = item.x
        targetMapCenterY = item.y
        mapCenterX = item.x
        mapCenterY = item.y
        dragVelocityX = 0
        dragVelocityY = 0
    end
    playSoundFrontEnd(41)
end)

bindKey("pgup", "down", function()
    if not isPauseOpen or currentTab ~= "MAP" then return end
    targetZoomLevel = math.max(minZoom, targetZoomLevel * 0.82)
end)

bindKey("pgdn", "down", function()
    if not isPauseOpen or currentTab ~= "MAP" then return end
    targetZoomLevel = math.min(maxZoom, targetZoomLevel / 0.82)
end)