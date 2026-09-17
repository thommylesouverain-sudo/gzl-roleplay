CleaningGame = {}

local isCleaningActive = false
local currentWindowData = nil

-- Doku ve SVG Önbellekleri (Maksimum Performans & 60 FPS)
local glassSvg = nil
local lastGlassSize = { w = 0, h = 0 }
local foamBubbleTexture = nil
local squeegeeTexture = nil

-- Köpük & Kir Izgarası (Dengeli Yoğunluk: 22 sütun x 14 satır = 308 köpük)
local GRID_COLS = 22
local GRID_ROWS = 14
local TOTAL_CELLS = GRID_COLS * GRID_ROWS
local dirtGrid = {}
local cleanRatio = 0.0

-- Silecek (Çekçek) Fizik & Durum Değişkenleri
local squeegeePos = { x = 0, y = 0 }
local lastMousePos = { x = 0, y = 0 }
local squeegeeTilt = 0
local isMouseDown = false
local isFinishing = false
local finishTick = 0

-- Efekt Değişkenleri
local waterDrops = {}
local sparkles = {}
local BLADE_WIDTH = 195
local BLADE_HEIGHT = 26
local WIPE_RADIUS = 52

-- 1. FiveM Tarzı Vektörel SVG Sıvı Cam & Işık Dalgaları (Liquid Glass Artwork)
local function getGlassTexture(sw, sh)
    if isElement(glassSvg) and lastGlassSize.w == sw and lastGlassSize.h == sh then
        return glassSvg
    end
    if isElement(glassSvg) then
        destroyElement(glassSvg)
        glassSvg = nil
    end

    local svgData = string.format([[<svg width="%d" height="%d" viewBox="0 0 %d %d" fill="none" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="glassBg" x1="0%%" y1="0%%" x2="100%%" y2="100%%">
      <stop offset="0%%" stop-color="#0f2942" stop-opacity="0.88"/>
      <stop offset="35%%" stop-color="#1e40af" stop-opacity="0.80"/>
      <stop offset="65%%" stop-color="#0284c7" stop-opacity="0.75"/>
      <stop offset="100%%" stop-color="#0369a1" stop-opacity="0.82"/>
    </linearGradient>

    <linearGradient id="glowWave1" x1="0%%" y1="20%%" x2="100%%" y2="80%%">
      <stop offset="0%%" stop-color="#38bdf8" stop-opacity="0.0"/>
      <stop offset="40%%" stop-color="#ffffff" stop-opacity="0.75"/>
      <stop offset="60%%" stop-color="#bae6fd" stop-opacity="0.65"/>
      <stop offset="100%%" stop-color="#0284c7" stop-opacity="0.0"/>
    </linearGradient>

    <linearGradient id="glowWave2" x1="100%%" y1="90%%" x2="0%%" y2="10%%">
      <stop offset="0%%" stop-color="#0369a1" stop-opacity="0.0"/>
      <stop offset="50%%" stop-color="#ffffff" stop-opacity="0.70"/>
      <stop offset="75%%" stop-color="#7dd3fc" stop-opacity="0.55"/>
      <stop offset="100%%" stop-color="#0284c7" stop-opacity="0.0"/>
    </linearGradient>
  </defs>

  <rect width="%d" height="%d" fill="url(#glassBg)"/>

  <path d="M %.1f,%.1f C %.1f,%.1f %.1f,%.1f %.1f,%.1f" stroke="url(#glowWave1)" stroke-width="32" fill="none" opacity="0.65"/>
  <path d="M %.1f,%.1f C %.1f,%.1f %.1f,%.1f %.1f,%.1f" stroke="#ffffff" stroke-width="3" fill="none" opacity="0.85"/>

  <path d="M %.1f,%.1f C %.1f,%.1f %.1f,%.1f %.1f,%.1f" stroke="url(#glowWave2)" stroke-width="40" fill="none" opacity="0.55"/>
  <path d="M %.1f,%.1f C %.1f,%.1f %.1f,%.1f %.1f,%.1f" stroke="#ffffff" stroke-width="4" fill="none" opacity="0.75"/>
</svg>]],
        sw, sh, sw, sh,
        sw, sh,
        -sw*0.1, sh*0.32, sw*0.25, sh*0.08, sw*0.55, sh*0.58, sw*1.1, sh*0.35,
        -sw*0.1, sh*0.32, sw*0.25, sh*0.08, sw*0.55, sh*0.58, sw*1.1, sh*0.35,
        -sw*0.08, sh*0.65, sw*0.35, sh*0.38, sw*0.68, sh*0.82, sw*1.1, sh*0.52,
        -sw*0.08, sh*0.65, sw*0.35, sh*0.38, sw*0.68, sh*0.82, sw*1.1, sh*0.52
    )

    glassSvg = svgCreate(sw, sh, svgData)
    lastGlassSize.w = sw
    lastGlassSize.h = sh
    return glassSvg
end

-- 2. Vektörel 3D Parlak Köpük Baloncuğu Dokusu (1 Kez Üretilir, 0 FPS Kaybı)
local function getFoamBubbleTexture()
    if isElement(foamBubbleTexture) then return foamBubbleTexture end

    local bubbleSvgData = [[<svg width="128" height="128" viewBox="0 0 128 128" fill="none" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <radialGradient id="bubbleGrad" cx="38%" cy="35%" r="65%">
      <stop offset="0%" stop-color="#ffffff" stop-opacity="0.95"/>
      <stop offset="35%" stop-color="#e0f2fe" stop-opacity="0.85"/>
      <stop offset="70%" stop-color="#bae6fd" stop-opacity="0.65"/>
      <stop offset="90%" stop-color="#7dd3fc" stop-opacity="0.45"/>
      <stop offset="100%" stop-color="#38bdf8" stop-opacity="0.10"/>
    </radialGradient>
  </defs>
  <circle cx="64" cy="64" r="60" fill="url(#bubbleGrad)"/>
  <ellipse cx="46" cy="40" rx="16" ry="10" transform="rotate(-30 46 40)" fill="#ffffff" fill-opacity="0.85"/>
  <circle cx="56" cy="34" r="4" fill="#ffffff" fill-opacity="0.95"/>
  <path d="M 30,85 C 45,115 85,115 102,85" stroke="#ffffff" stroke-width="4" stroke-linecap="round" fill="none" opacity="0.5"/>
</svg>]]

    foamBubbleTexture = svgCreate(128, 128, bubbleSvgData)
    if not isElement(foamBubbleTexture) then
        local rt = dxCreateRenderTarget(128, 128, true)
        if rt then
            dxSetRenderTarget(rt, true)
            drawRoundedRectangle(4, 4, 120, 120, 60, tocolor(240, 248, 255, 220))
            drawRoundedRectangle(16, 16, 40, 30, 15, tocolor(255, 255, 255, 155))
            drawRoundedRectangle(24, 20, 12, 12, 6, tocolor(255, 255, 255, 255))
            dxSetRenderTarget()
            foamBubbleTexture = rt
        end
    end
    return foamBubbleTexture
end

-- 3. Profesyonel Çekçek (Squeegee) Dokusu (1 Kez Çizilir)
local function createSqueegeeTexture()
    if isElement(squeegeeTexture) then return squeegeeTexture end
    local tw, th = 240, 190
    local rt = dxCreateRenderTarget(tw, th, true)
    if not rt then return nil end

    dxSetRenderTarget(rt, true)
    local cx = tw / 2

    -- Siyah Kauçuk Silecek Lastiği
    dxDrawRectangle(cx - 95, 6, 190, 9, tocolor(22, 26, 32, 255))
    dxDrawRectangle(cx - 95, 14, 190, 2, tocolor(56, 189, 248, 140))

    -- Paslanmaz Çelik Kanal
    dxDrawRectangle(cx - 92, 14, 184, 13, tocolor(200, 214, 229, 255))
    dxDrawRectangle(cx - 90, 15, 180, 2, tocolor(255, 255, 255, 230))
    dxDrawRectangle(cx - 92, 24, 184, 3, tocolor(100, 116, 139, 255))

    -- Uç Kapakları
    dxDrawRectangle(cx - 98, 8, 6, 16, tocolor(15, 18, 24, 255))
    dxDrawRectangle(cx + 92, 8, 6, 16, tocolor(15, 18, 24, 255))

    -- Orta Mafsal & Pirinç Vida
    dxDrawRectangle(cx - 24, 27, 48, 28, tocolor(148, 163, 184, 255))
    dxDrawRectangle(cx - 20, 29, 40, 24, tocolor(226, 232, 240, 255))
    dxDrawRectangle(cx - 6, 35, 12, 12, tocolor(245, 158, 11, 255))
    dxDrawRectangle(cx - 3, 38, 6, 6, tocolor(217, 119, 6, 255))

    -- Ergonomik Tutma Sapı
    dxDrawRectangle(cx - 9, 55, 18, 16, tocolor(148, 163, 184, 255))
    dxDrawRectangle(cx - 12, 71, 24, 9, tocolor(249, 115, 22, 255))
    dxDrawRectangle(cx - 11, 80, 22, 90, tocolor(30, 41, 59, 255))
    for ry = 90, 150, 12 do
        dxDrawRectangle(cx - 10, ry, 20, 4, tocolor(51, 65, 85, 255))
    end
    dxDrawRectangle(cx - 5, 153, 10, 8, tocolor(15, 23, 42, 255))

    dxSetRenderTarget()
    squeegeeTexture = rt
    return squeegeeTexture
end

-- Köpük Izgarasını Başlat (Tüm Ekrana Doğal Yayılım)
local function initCleanTracker(sw, sh)
    dirtGrid = {}
    local cellW = sw / GRID_COLS
    local cellH = sh / GRID_ROWS
    local baseRadius = math.max(cellW, cellH) * 0.92

    for r = 1, GRID_ROWS do
        dirtGrid[r] = {}
        for c = 1, GRID_COLS do
            dirtGrid[r][c] = {
                cx = (c - 0.5) * cellW + math.random(-6, 6),
                cy = (r - 0.5) * cellH + math.random(-6, 6),
                radius = baseRadius * (0.88 + math.random(0, 26) / 100),
                dirt = 1.0,
                rot = math.random(0, 360),
                scale = 0.92 + math.random(0, 18) / 100
            }
        end
    end

    cleanRatio = 0.0
    waterDrops = {}
    sparkles = {}
    isFinishing = false
    finishTick = 0
end

-- Sileceğin Geçtiği Yerleri Köpükten Arındır
local function wipeAtPosition(x0, y0)
    local halfW = BLADE_WIDTH * 0.48

    for r = 1, GRID_ROWS do
        for c = 1, GRID_COLS do
            local cell = dirtGrid[r][c]
            if cell.dirt > 0 then
                local clampedX = math.max(x0 - halfW, math.min(x0 + halfW, cell.cx))
                local dist = math.sqrt((cell.cx - clampedX)^2 + (cell.cy - y0)^2)
                if dist <= WIPE_RADIUS then
                    local power = math.max(0.42, 1.0 - (dist / WIPE_RADIUS) * 0.45)
                    cell.dirt = math.max(0, cell.dirt - power)
                    if cell.dirt <= 0.04 then
                        cell.dirt = 0
                    end
                end
            end
        end
    end
end

-- Temizlik Oranını Hesapla
local function updateCleanRatio()
    local cleanCount = 0
    for r = 1, GRID_ROWS do
        for c = 1, GRID_COLS do
            if dirtGrid[r][c].dirt <= 0.04 then
                cleanCount = cleanCount + 1
            end
        end
    end
    cleanRatio = cleanCount / TOTAL_CELLS
end

function CleaningGame.isActive()
    return isCleaningActive
end

function CleaningGame.start(windowData)
    if isCleaningActive or not windowData then return end

    if not Equipment.hasEquipment() then
        Audio.playButtonClick()
        exports.aura_ui:uiToast("Ekipman Gerekli", "Önce aracın bagajından temizlik malzemelerini almalısın!", "warning", 3500)
        return
    end

    isCleaningActive = true
    currentWindowData = windowData

    -- Karakteri vitrine doğru çevir ve dondur
    local px, py, pz = getElementPosition(localPlayer)
    local targetRot = math.deg(math.atan2(windowData.y - py, windowData.x - px)) - 90
    setElementRotation(localPlayer, 0, 0, targetRot, "default", true)
    setElementFrozen(localPlayer, true)
    setPedAnimation(localPlayer, Config.Equipment.animBlock, Config.Equipment.animName, -1, true, false, false, false)

    showCursor(true)
    local sw, sh = guiGetScreenSize()
    squeegeePos.x = sw / 2
    squeegeePos.y = sh / 2
    lastMousePos.x = squeegeePos.x
    lastMousePos.y = squeegeePos.y
    squeegeeTilt = 0

    initCleanTracker(sw, sh)
    getGlassTexture(sw, sh)
    getFoamBubbleTexture()
    createSqueegeeTexture()
    Audio.playWipeEffect()

    triggerServerEvent("windowCleaning:startAnimation", localPlayer, windowData.id)
end

function CleaningGame.stop(success)
    if not isCleaningActive then return end
    isCleaningActive = false

    showCursor(false)
    setElementFrozen(localPlayer, false)
    setPedAnimation(localPlayer, false)

    if success and currentWindowData then
        local targetWin = currentWindowData
        local winId = tonumber(targetWin.id)
        Audio.playSuccess()

        local jobData = JobHUD.getJobData()
        if jobData and jobData.windows then
            for _, w in ipairs(jobData.windows) do
                if tonumber(w.id) == winId then
                    w.isCleaned = true
                    break
                end
            end
        end

        triggerServerEvent("windowCleaning:submitCleanWindow", localPlayer, winId)
        local winName = targetWin.label or ("Vitrin #" .. tostring(winId))
        exports.aura_ui:uiToast("Vitrin Temizlendi!", winName .. " pırıl pırıl parlıyor! ✨", "success", 4000)
    else
        triggerServerEvent("windowCleaning:stopAnimation", localPlayer)
        exports.aura_ui:uiToast("İptal Edildi", "Cam temizleme işlemi yarıda kesildi.", "info", 3000)
    end

    currentWindowData = nil
    waterDrops = {}
    sparkles = {}
end

local function handleInteractiveWiping(sw, sh)
    if isFinishing then return end

    local cx, cy = getCursorPosition()
    if not cx or not cy then return end
    cx = math.max(20, math.min(sw - 20, cx * sw))
    cy = math.max(30, math.min(sh - 30, cy * sh))

    -- Yumuşak Takip
    squeegeePos.x = squeegeePos.x + (cx - squeegeePos.x) * 0.45
    squeegeePos.y = squeegeePos.y + (cy - squeegeePos.y) * 0.45

    -- Eğilme Fiziği
    local deltaX = cx - lastMousePos.x
    local targetTilt = math.max(-22, math.min(22, deltaX * 1.6))
    squeegeeTilt = squeegeeTilt + (targetTilt - squeegeeTilt) * 0.25

    isMouseDown = getKeyState("mouse1")
    local moveDist = getDistanceBetweenPoints2D(cx, cy, lastMousePos.x, lastMousePos.y)

    if isMouseDown and moveDist > 3 then
        Audio.playWipeEffect()

        -- Hızlı hareketlerde ara noktaları da temizle (atlama olmasın)
        local steps = math.max(1, math.min(5, math.floor(moveDist / 18)))
        for s = 1, steps do
            local ix = lastMousePos.x + (cx - lastMousePos.x) * (s / steps)
            local iy = lastMousePos.y + (cy - lastMousePos.y) * (s / steps)
            wipeAtPosition(ix, iy)
        end

        -- Silecek ucundan süzülen su damlaları
        if math.random(1, 10) <= 4 and #waterDrops < 15 then
            table.insert(waterDrops, {
                x = (math.random(1, 2) == 1 and (squeegeePos.x - BLADE_WIDTH * 0.45) or (squeegeePos.x + BLADE_WIDTH * 0.45)) + math.random(-4, 4),
                y = squeegeePos.y + math.random(4, 10),
                speed = math.random(80, 160) / 100.0,
                size = math.random(3, 5),
                alpha = 1.0
            })
        end

        updateCleanRatio()

        -- %88 ve üzeri temizlendiğinde otomatik bitiş sekansı
        if cleanRatio >= 0.88 and not isFinishing then
            isFinishing = true
            finishTick = getTickCount()
            for i = 1, 14 do
                table.insert(sparkles, {
                    x = math.random(60, sw - 60),
                    y = math.random(60, sh - 60),
                    size = math.random(20, 36)
                })
            end
        end
    end

    lastMousePos.x = cx
    lastMousePos.y = cy
end

function CleaningGame.render()
    if not isCleaningActive or not currentWindowData then return end

    local sw, sh = guiGetScreenSize()
    handleInteractiveWiping(sw, sh)

    -- 1. Full-Screen FiveM Tarzı Vektörel SVG Sıvı Cam & Yansıma Katmanı
    local glassTex = getGlassTexture(sw, sh)
    if isElement(glassTex) then
        dxDrawImage(0, 0, sw, sh, glassTex, 0, 0, 0, tocolor(255, 255, 255, 155))
    else
        dxDrawRectangle(0, 0, sw, sh, tocolor(15, 41, 74, 195))
        dxDrawRectangle(0, 0, sw, sh, tocolor(56, 189, 248, 25))
    end

    -- 2. Doğal Köpüklü Sabun Katmanı (Ultra Hızlı Donanım Render)
    local bubbleTex = getFoamBubbleTexture()
    for r = 1, GRID_ROWS do
        for c = 1, GRID_COLS do
            local cell = dirtGrid[r][c]
            if cell and cell.dirt > 0.02 then
                local alpha = math.floor(155 * cell.dirt)
                local rRad = cell.radius * cell.scale
                if isElement(bubbleTex) then
                    dxDrawImage(cell.cx - rRad, cell.cy - rRad, rRad * 2, rRad * 2, bubbleTex, cell.rot, 0, 0, tocolor(255, 255, 255, alpha))
                else
                    dxDrawRectangle(cell.cx - rRad * 0.7, cell.cy - rRad * 0.7, rRad * 1.4, rRad * 1.4, tocolor(240, 248, 255, alpha))
                end
            end
        end
    end

    -- 3. Aşağıya Süzülen Su Damlaları
    for idx = #waterDrops, 1, -1 do
        local drop = waterDrops[idx]
        drop.y = drop.y + drop.speed
        drop.alpha = drop.alpha - 0.012
        if drop.alpha <= 0 or drop.y > sh then
            table.remove(waterDrops, idx)
        else
            dxDrawRectangle(drop.x, drop.y, drop.size, drop.size * 2.6, tocolor(224, 242, 254, math.floor(190 * drop.alpha)))
        end
    end

    -- 4. Vitrin Çerçevesi (Alüminyum Mağaza Vitrini Kenarları)
    local frameThick = 14
    dxDrawRectangle(0, 0, sw, frameThick, tocolor(15, 23, 42, 235))
    dxDrawRectangle(0, sh - frameThick, sw, frameThick, tocolor(15, 23, 42, 235))
    dxDrawRectangle(0, 0, frameThick, sh, tocolor(15, 23, 42, 235))
    dxDrawRectangle(sw - frameThick, 0, frameThick, sh, tocolor(15, 23, 42, 235))
    dxDrawRectangle(frameThick, frameThick, sw - frameThick * 2, 1, tocolor(56, 189, 248, 140))

    -- 5. Sağ Üst FiveM Tarzı "TEMİZLİK POV" Rozeti (AURA Glass Panel)
    local povW = 180
    local povH = 34
    local povX = sw - povW - 24
    local povY = sh - 64
    drawGlassPanel(povX, povY, povW, povH, 8, 0.90)
    exports.aura_ui:uiDrawText(" TEMİZLİK POV", povX, povY, povX + povW, povY + povH, tocolor(255, 255, 255, 230), 0.9, "default-bold", "center", "center")

    -- 6. Üst Orta Modern AURA İlerleme Kartı (Liquid Glass & Glassmorphism)
    local cardW = 440
    local cardH = 82
    local cardX = (sw - cardW) / 2
    local cardY = 26

    drawGlassPanel(cardX, cardY, cardW, cardH, 14, 0.94)

    local winLabel = currentWindowData and (currentWindowData.label or ("Vitrin #" .. tostring(currentWindowData.id))) or "Vitrin"
    local percent = math.min(100, math.floor(cleanRatio / 0.88 * 100))

    exports.aura_ui:uiDrawText(" " .. winLabel, cardX + 18, cardY + 10, cardX + cardW - 100, cardY + 34, tocolor(255, 255, 255, 255), 1.05, "default-bold", "left", "center")

    local percentCol = percent >= 100 and tocolor(34, 197, 94, 255) or tocolor(201,244,111,255)
    exports.aura_ui:uiDrawText(string.format("%%%d", percent), cardX + cardW - 90, cardY + 10, cardX + cardW - 18, cardY + 34, percentCol, 1.15, "default-bold", "right", "center")

    -- İlerleme Çubuğu (AURA Rounded Progress Bar)
    local barW = cardW - 36
    local progNormalized = math.min(1.0, cleanRatio / 0.88)
    drawProgressBar(cardX + 18, cardY + 38, barW, 14, 5, progNormalized, tocolor(201,244,111,255), tocolor(30, 41, 59, 220))

    local hintMsg = isMouseDown and " Silecek çekiliyor..." or " Sol Tık Basılı Tutup Sürükleyin  •  [ESC] İptal"
    exports.aura_ui:uiDrawText(hintMsg, cardX + 18, cardY + 56, cardX + cardW - 18, cardY + 76, tocolor(203, 213, 225, 220), 0.85, "default", "center", "center")

    -- 7. Cam Çekçeki (Squeegee) - Ultra Gerçekçi
    if not isElement(squeegeeTexture) then
        createSqueegeeTexture()
    end

    local tw, th = 240, 190
    local drawX = squeegeePos.x - tw / 2
    local drawY = squeegeePos.y - 14

    if isElement(squeegeeTexture) then
        dxDrawImage(drawX, drawY, tw, th, squeegeeTexture, squeegeeTilt, 0, -65, tocolor(255, 255, 255, 255))
    end

    -- 8. Bitiş Parıltıları ve Beyaz Parlama Efekti
    if isFinishing then
        local now = getTickCount()
        local elapsed = now - finishTick

        for _, sp in ipairs(sparkles) do
            dxDrawRectangle(sp.x - sp.size * 0.2, sp.y - sp.size * 0.2, sp.size * 0.4, sp.size * 0.4, tocolor(255, 255, 255, 220))
            dxDrawRectangle(sp.x - sp.size * 0.1, sp.y - sp.size * 0.1, sp.size * 0.2, sp.size * 0.2, tocolor(201,244,111,255))
        end

        local flashAlpha = math.max(0, 1.0 - (elapsed / 600))
        dxDrawRectangle(0, 0, sw, sh, tocolor(255, 255, 255, math.floor(flashAlpha * 150)))

        if elapsed >= 550 then
            CleaningGame.stop(true)
        end
    end
end

addEventHandler("onClientResourceStop", resourceRoot, function()
    if isElement(glassSvg) then
        destroyElement(glassSvg)
        glassSvg = nil
    end
    if isElement(foamBubbleTexture) then
        destroyElement(foamBubbleTexture)
        foamBubbleTexture = nil
    end
    if isElement(squeegeeTexture) then
        destroyElement(squeegeeTexture)
        squeegeeTexture = nil
    end
end)