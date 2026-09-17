JobHUD = {}

local activeJobData = nil
local nearbyPromptWindow = nil

function JobHUD.setJobData(data)
    activeJobData = data
end

function JobHUD.clearJobData()
    activeJobData = nil
    nearbyPromptWindow = nil
end

function JobHUD.getJobData()
    return activeJobData
end

function JobHUD.getNearbyWindow()
    return nearbyPromptWindow
end

local function drawActiveJobCard()
    if not activeJobData then return end

    local sw, sh = guiGetScreenSize()
    local cardW = 460
    local cardH = 126
    local cardX = (sw - cardW) / 2
    local cardY = 20

    drawGlassPanel(cardX, cardY, cardW, cardH, 12, 0.94)

    -- Şirket Başlığı
    exports.aura_ui:uiDrawText("GZL TEMİZLİK HİZMETLERİ", cardX + 16, cardY + 10, cardX + cardW - 16, cardY + 28, tocolor(201,244,111,255), 0.85, "default-bold", "left", "center")

    -- Bina & Lokasyon Adı
    local buildingName = activeJobData.buildingName or "Bilinmeyen Bölge"
    exports.aura_ui:uiDrawText(buildingName, cardX + 16, cardY + 28, cardX + cardW - 16, cardY + 50, tocolor(255, 255, 255, 255), 1.05, "default-bold", "left", "center")

    local totalWins = math.max(1,activeJobData.totalWindows or 1)
    local cleanedWins = activeJobData.cleanedWindows or 0
    local progRatio = math.max(0, math.min(1, cleanedWins / totalWins))

    -- İlerleme ve Ekipman Durumu
    local eqStatus = Equipment.hasEquipment() and " Ekipman: Elde" or " Ekipman: Araçta"
    local progText = string.format("Vitrinler: %d / %d", cleanedWins, totalWins)
    exports.aura_ui:uiDrawText(progText, cardX + 16, cardY + 52, cardX + 190, cardY + 70, tocolor(226, 232, 240, 240), 0.9, "default-bold", "left", "center")
    exports.aura_ui:uiDrawText(eqStatus, cardX + 190, cardY + 52, cardX + cardW - 16, cardY + 70, tocolor(203, 213, 225, 220), 0.85, "default", "right", "center")

    -- İlerleme Çubuğu
    local progBarW = cardW - 32
    drawProgressBar(cardX + 16, cardY + 72, progBarW, 11, 4, progRatio, tocolor(201,244,111,255), tocolor(30, 41, 59, 220))

    -- Bilgilendirme / Yönlendirme Metni
    local statusText
    local statusCol
    if cleanedWins >= totalWins then
        statusText = "Tamamlandı. Ekipmanı araca bırakıp depoya dön."
        statusCol = tocolor(34, 197, 94, 255)
    elseif not Equipment.hasEquipment() then
        statusText = "→ Aracın bagajına gidip [E] ile temizlik ekipmanlarını alın."
        statusCol = tocolor(234, 179, 8, 255)
    else
        statusText = "→ Kirli vitrinlere yaklaşın ve [E] ile temizlemeye başlayın."
        statusCol = tocolor(148, 163, 184, 255)
    end
    exports.aura_ui:uiDrawText(statusText, cardX + 16, cardY + 88, cardX + cardW - 16, cardY + 118, statusCol, 0.82, "default", "center", "center", true)
end

local function draw3DWindowMarkers()
    if not activeJobData or not activeJobData.windows then return end

    local px, py, pz = getElementPosition(localPlayer)
    nearbyPromptWindow = nil
    local minDistance = 2.8

    for _, win in ipairs(activeJobData.windows) do
        local dist = getDistanceBetweenPoints3D(px, py, pz, win.x, win.y, win.z)
        if dist < 18.0 then
            local sx, sy = getScreenFromWorldPosition(win.x, win.y, win.z + 0.3)
            if sx and sy then
                local winTitle = win.label or ("Vitrin #" .. tostring(win.id))
                local isCleaned = win.isCleaned

                if isCleaned then
                    local badgeW = 130
                    local badgeH = 30
                    local badgeX = sx - badgeW / 2
                    local badgeY = sy - badgeH / 2

                    drawGlassPanel(badgeX, badgeY, badgeW, badgeH, 6, 0.85)
                    drawRoundedRectangle(badgeX + 2, badgeY + 2, badgeW - 4, badgeH - 4, 4, tocolor(30,34,39,245))
                    exports.aura_ui:uiDrawText("✓ " .. winTitle, badgeX, badgeY, badgeX + badgeW, badgeY + badgeH, tocolor(255, 255, 255, 255), 0.85, "default-bold", "center", "center")
                else
                    if dist < minDistance and not CleaningGame.isActive() then
                        nearbyPromptWindow = win
                        local promptW = 180
                        local promptH = 46
                        local pX = sx - promptW / 2
                        local pY = sy - promptH / 2

                        drawGlassPanel(pX, pY, promptW, promptH, 8, 0.95)
                        local boxCol = Equipment.hasEquipment() and tocolor(30,34,39,245) or tocolor(30,34,39,245)
                        drawRoundedRectangle(pX + 2, pY + 2, promptW - 4, promptH - 4, 6, boxCol)

                        local actionHint = Equipment.hasEquipment() and "[ E ] Vitrini Temizle" or "[ E ] Ekipman Gerekli"
                        exports.aura_ui:uiDrawText(" " .. winTitle .. "\n" .. actionHint, pX, pY, pX + promptW, pY + promptH, tocolor(255, 255, 255, 255), 0.85, "default-bold", "center", "center")
                    else
                        local badgeW = 140
                        local badgeH = 30
                        local badgeX = sx - badgeW / 2
                        local badgeY = sy - badgeH / 2

                        drawGlassPanel(badgeX, badgeY, badgeW, badgeH, 6, 0.85)
                        drawRoundedRectangle(badgeX + 2, badgeY + 2, badgeW - 4, badgeH - 4, 4, tocolor(30,34,39,245))
                        exports.aura_ui:uiDrawText(" " .. winTitle, badgeX, badgeY, badgeX + badgeW, badgeY + badgeH, tocolor(255, 255, 255, 255), 0.85, "default-bold", "center", "center")
                    end
                end
            end
        end
    end
end

local function drawDepotPrompt()
    if activeJobData then return end
    local px, py, pz = getElementPosition(localPlayer)
    local dPos = Config.DepotLocation.marker
    local dist = getDistanceBetweenPoints3D(px, py, pz, dPos.x, dPos.y, dPos.z)
    if dist < 3.2 and not LobbyUI.isOpen() then
        local sx, sy = getScreenFromWorldPosition(dPos.x, dPos.y, dPos.z + 1.2)
        if sx and sy then
            local cardW = 260
            local cardH = 50
            local cardX = sx - cardW / 2
            local cardY = sy - cardH / 2

            drawGlassPanel(cardX, cardY, cardW, cardH, 8, 0.95)
            drawRoundedRectangle(cardX + 2, cardY + 2, cardW - 4, cardH - 4, 6, tocolor(30,34,39,245))
            exports.aura_ui:uiDrawText("GZL TEMİZLİK MERKEZİ\n[ E ] Sözleşmeler & Lobi", cardX, cardY, cardX + cardW, cardY + cardH, tocolor(255, 255, 255, 255), 0.9, "default-bold", "center", "center")
        end
    end
end

local function drawVehicleReturnPrompt()
    if not activeJobData then return end
    local totalWins = math.max(1,activeJobData.totalWindows or 1)
    local cleanedWins = activeJobData.cleanedWindows or 0
    if cleanedWins < totalWins then return end

    local px, py, pz = getElementPosition(localPlayer)
    local ret = Config.DepotLocation.vehicleReturn
    local dist = getDistanceBetweenPoints3D(px, py, pz, ret.x, ret.y, ret.z)
    if dist <= 30.0 then
        local sx, sy = getScreenFromWorldPosition(ret.x, ret.y, ret.z + 1.2)
        if sx and sy then
            local cardW = 280
            local cardH = 50
            local cardX = sx - cardW / 2
            local cardY = sy - cardH / 2

            drawGlassPanel(cardX, cardY, cardW, cardH, 8, 0.95)
            drawRoundedRectangle(cardX + 2, cardY + 2, cardW - 4, cardH - 4, 6, tocolor(30,34,39,245))
            exports.aura_ui:uiDrawText("ARACI TESLİM ET\n[ E ] Mesaiyi Bitir & Ücreti Al", cardX, cardY, cardX + cardW, cardY + cardH, tocolor(255, 255, 255, 255), 0.9, "default-bold", "center", "center")
        end
    end
end

function JobHUD.render()
    if CleaningGame.isActive() then return end
    drawActiveJobCard()
    draw3DWindowMarkers()
    drawDepotPrompt()
    drawVehicleReturnPrompt()
end