
Views = {}

function Views.drawDashboard(cx, cy, cw, ch, state, fontScale)
    local colors = PDTheme.colors
    local curY = cy + 16

    local statW = math.floor((cw - 48) / 3)
    local statH = 68
    Components.drawStatBox(cx + 16, curY, statW, statH, "GÖREVDEKİ MEMURLAR", #(state.officers or {}), colors.policeBlue, fontScale)
    Components.drawStatBox(cx + 16 + statW + 8, curY, statW, statH, "ARANAN VATANDAŞLAR", state.wantedCount or 0, colors.accentRed, fontScale)
    Components.drawStatBox(cx + 16 + (statW * 2) + 16, curY, statW, statH, "BOLO (ARANAN ARAÇLAR)", state.boloCount or 0, colors.accentOrange, fontScale)
    curY = curY + statH + 16

    exports.aura_ui:uiDrawText("TELSİZ & GÖREV DURUMU", cx + 16, curY, cx + 300, curY + 20, colors.textDim, fontScale * 0.85, "default-bold", "left", "center")
    curY = curY + 24

    local codeW = math.floor((cw - 48) / 4)
    local codeH = 50

    for idx, tc in ipairs(PDConfig.TenCodes) do
        local tcX = cx + 16 + (idx - 1) * (codeW + 8)
        local isCurrent = (state.myStatus == tc.code)
        local isPanic = (tc.code == "10-99")
        local btnBg = isCurrent and colors.cardActive or (isPanic and colors.panicBtn or colors.cardBg)
        local btnHover = isPanic and colors.panicBtnHover or colors.cardHover

        local isHover = Components.drawButton(tcX, curY, codeW, codeH, tc.code .. " " .. tc.label, btnBg, btnHover, fontScale * 0.85)
        if isHover and getKeyState("mouse1") and not state.clickDebounce then
            state.handle10CodeClick(tc.code)
        end
    end
    curY = curY + codeH + 20

    local halfW = math.floor((cw - 40) / 2)
    local listH = ch - (curY - cy) - 16

    exports.aura_ui:uiDrawText("AKTİF DEVRİYE BİRLİKLERİ", cx + 16, curY, cx + 16 + halfW, curY + 20, colors.textDim, fontScale * 0.85, "default-bold", "left", "center")
    exports.aura_ui:uiDrawRectangle(cx + 16, curY + 24, halfW, listH, colors.cardBg)
    dxSetScissor(cx + 16, curY + 24, halfW, listH)

    if not state.officers or #state.officers == 0 then
        exports.aura_ui:uiDrawText("Aktif devriye memuru yok.", cx + 16, curY + 60, cx + 16 + halfW, curY + 100, colors.textDim, fontScale, "default", "center", "center")
    else
        local offY = curY + 28
        for _, off in ipairs(state.officers) do
            local statusCol = (off.status == "10-8" and colors.accentGreen) or (off.status == "10-99" and colors.accentRed or colors.accentOrange)
            exports.aura_ui:uiDrawText(off.name, cx + 28, offY, cx + 200, offY + 24, colors.textPrimary, fontScale * 0.9, "default-bold", "left", "center")
            exports.aura_ui:uiDrawText(off.status, cx + halfW - 70, offY, cx + halfW + 4, offY + 24, statusCol, fontScale * 0.85, "default-bold", "center", "center")
            exports.aura_ui:uiDrawRectangle(cx + 28, offY + 25, halfW - 24, 1, colors.separator)
            offY = offY + 30
        end
    end
    dxSetScissor()

    local rightX = cx + 24 + halfW
    exports.aura_ui:uiDrawText("GENEL ASAYİŞ BÜLTENİ (APB)", rightX, curY, rightX + halfW, curY + 20, colors.textDim, fontScale * 0.85, "default-bold", "left", "center")
    exports.aura_ui:uiDrawRectangle(rightX, curY + 24, halfW, listH, colors.cardBg)
    dxSetScissor(rightX, curY + 24, halfW, listH)

    if not state.bulletins or #state.bulletins == 0 then
        exports.aura_ui:uiDrawText("Yayınlanmış aktif bülten bulunmuyor.", rightX, curY + 60, rightX + halfW, curY + 100, colors.textDim, fontScale, "default", "center", "center")
    else
        local bY = curY + 28
        for _, b in ipairs(state.bulletins) do
            exports.aura_ui:uiDrawText(b.title, rightX + 16, bY, rightX + halfW - 16, bY + 20, colors.policeGold, fontScale * 0.95, "default-bold", "left", "center")
            exports.aura_ui:uiDrawText(b.description, rightX + 16, bY + 22, rightX + halfW - 16, bY + 54, colors.textSecondary, fontScale * 0.85, "default", "left", "top", true, true)
            exports.aura_ui:uiDrawRectangle(rightX + 16, bY + 58, halfW - 32, 1, colors.separator)
            bY = bY + 64
        end
    end
    dxSetScissor()
end

function Views.drawCitizenQuery(cx, cy, cw, ch, state, fontScale)
    local colors = PDTheme.colors
    local curY = cy + 16

    local searchW = cw - 160
    local isInputHover = Components.drawSearchBox(cx + 16, curY, searchW, 40, "Vatandaş Adı ve Soyadı girin (Örn: John_Doe)...", state.citizenInput, state.activeInput == "citizen", fontScale)
    if isInputHover and getKeyState("mouse1") and not state.clickDebounce then
        state.activeInput = "citizen"
        state.clickDebounce = true
        setTimer(function() state.clickDebounce = false end, 150, 1)
    end

    local isSearchBtn = Components.drawButton(cx + 24 + searchW, curY, 120, 40, "Sorgula", colors.policeBlue, colors.accentGreen, fontScale)
    if isSearchBtn and getKeyState("mouse1") and not state.clickDebounce then
        state.searchCitizen()
    end
    curY = curY + 54

    if state.searchedCitizenName and state.searchedCitizenName ~= "" then

        local cardH = 90
        exports.aura_ui:uiDrawRectangle(cx + 16, curY, cw - 32, cardH, colors.cardBg)
        exports.aura_ui:uiDrawRectangle(cx + 16, curY, 6, cardH, (state.citizenWarrant and colors.accentRed or colors.accentGreen))

        exports.aura_ui:uiDrawText("VATANDAŞ SİCİL DOSYASI: " .. string.upper(state.searchedCitizenName), cx + 32, curY + 12, cx + 500, curY + 36, colors.textPrimary, fontScale * 1.15, "default-bold", "left", "center")

        local statusStr = state.citizenWarrant and ("★ ARANIYOR (Seviye " .. tostring(state.citizenWarrant.wanted_level) .. ") - " .. state.citizenWarrant.reason) or "✓ TEMİZ (Aktif Yakalama Kararı Yok)"
        local statusCol = state.citizenWarrant and colors.accentRed or colors.accentGreen
        exports.aura_ui:uiDrawText(statusStr, cx + 32, curY + 38, cx + cw - 200, curY + 60, statusCol, fontScale * 0.9, "default-bold", "left", "center")

        local isFineBtn = Components.drawButton(cx + cw - 260, curY + 24, 110, 36, "+ Ceza Kes", colors.policeBlue, colors.cardHover, fontScale * 0.85)
        if isFineBtn and getKeyState("mouse1") and not state.clickDebounce then
            state.activeTab = "penal"
            state.clickDebounce = true
            setTimer(function() state.clickDebounce = false end, 200, 1)
        end

        local isWantedBtn = Components.drawButton(cx + cw - 140, curY + 24, 110, 36, (state.citizenWarrant and "Aranma Sil" or "Aranma Ekle"), (state.citizenWarrant and colors.accentGreen or colors.accentRed), colors.cardHover, fontScale * 0.85)
        if isWantedBtn and getKeyState("mouse1") and not state.clickDebounce then
            state.toggleWantedCitizen()
        end

        curY = curY + cardH + 16

        exports.aura_ui:uiDrawText("GEÇMİŞ SABIKA VE CEZA KAYITLARI", cx + 16, curY, cx + 400, curY + 20, colors.textDim, fontScale * 0.85, "default-bold", "left", "center")
        curY = curY + 24

        local tableH = ch - (curY - cy) - 16
        exports.aura_ui:uiDrawRectangle(cx + 16, curY, cw - 32, tableH, colors.cardBg)
        dxSetScissor(cx + 16, curY, cw - 32, tableH)

        if not state.citizenRecords or #state.citizenRecords == 0 then
            exports.aura_ui:uiDrawText("Bu vatandaşın adli sicil kaydı temizdir.", cx + 16, curY + 80, cx + cw - 16, curY + 120, colors.textDim, fontScale, "default", "center", "center")
        else
            local rowY = curY + 8 - state.scrollOffset
            for idx, rec in ipairs(state.citizenRecords) do
                local isHover = PDGeometry.isCursorIn(cx + 24, rowY, cw - 48, 44)
                exports.aura_ui:uiDrawRectangle(cx + 24, rowY, cw - 48, 44, (isHover and colors.cardHover or colors.inputBg))

                exports.aura_ui:uiDrawText(rec.crime_title, cx + 36, rowY, cx + 350, rowY + 44, colors.textPrimary, fontScale * 0.9, "default-bold", "left", "center", true)
                exports.aura_ui:uiDrawText("Ceza: $" .. tostring(rec.fine_amount) .. " | Hapis: " .. tostring(rec.jail_time) .. " dk", cx + 360, rowY, cx + 600, rowY + 44, colors.policeGold, fontScale * 0.85, "default", "left", "center")
                exports.aura_ui:uiDrawText("Memur: " .. tostring(rec.officer_name), cx + cw - 220, rowY, cx + cw - 40, rowY + 44, colors.textDim, fontScale * 0.8, "default", "right", "center")

                rowY = rowY + 50
            end
            state.maxScroll = math.max(0, (#state.citizenRecords * 50) - tableH + 20)
        end
        dxSetScissor()
    else
        exports.aura_ui:uiDrawText("Sorgulama yapmak için yukarıdaki arama kutusuna isim girin.", cx + 16, cy + 180, cx + cw, cy + 220, colors.textDim, fontScale, "default", "center", "center")
    end
end

function Views.drawVehicleQuery(cx, cy, cw, ch, state, fontScale)
    local colors = PDTheme.colors
    local curY = cy + 16

    local searchW = cw - 160
    local isInputHover = Components.drawSearchBox(cx + 16, curY, searchW, 40, "Araç Plakası girin (Örn: 34GZL99)...", state.vehicleInput, state.activeInput == "vehicle", fontScale)
    if isInputHover and getKeyState("mouse1") and not state.clickDebounce then
        state.activeInput = "vehicle"
        state.clickDebounce = true
        setTimer(function() state.clickDebounce = false end, 150, 1)
    end

    local isSearchBtn = Components.drawButton(cx + 24 + searchW, curY, 120, 40, "Sorgula", colors.policeBlue, colors.accentGreen, fontScale)
    if isSearchBtn and getKeyState("mouse1") and not state.clickDebounce then
        state.searchVehicle()
    end
    curY = curY + 54

    if state.searchedPlate and state.searchedPlate ~= "" then
        local cardH = 80
        exports.aura_ui:uiDrawRectangle(cx + 16, curY, cw - 32, cardH, colors.cardBg)
        exports.aura_ui:uiDrawRectangle(cx + 16, curY, 6, cardH, (state.vehicleBolo and colors.accentRed or colors.accentGreen))

        exports.aura_ui:uiDrawText("PLAKA SORGUSU: " .. string.upper(state.searchedPlate), cx + 32, curY + 12, cx + 500, curY + 36, colors.textPrimary, fontScale * 1.15, "default-bold", "left", "center")

        local statusStr = state.vehicleBolo and ("★ BOLO (ARANIYOR / ÇALINTI) - " .. state.vehicleBolo.reason .. " [Memur: " .. state.vehicleBolo.officer_name .. "]") or "✓ PLAKA TEMİZ (Kayıtlarda çalıntı veya aranma yok)"
        local statusCol = state.vehicleBolo and colors.accentRed or colors.accentGreen
        exports.aura_ui:uiDrawText(statusStr, cx + 32, curY + 38, cx + cw - 200, curY + 60, statusCol, fontScale * 0.9, "default-bold", "left", "center")

        local boloBtnText = state.vehicleBolo and "BOLO Kaldır" or "+ BOLO Aç"
        local boloBtnCol = state.vehicleBolo and colors.accentGreen or colors.accentRed
        local isBoloBtn = Components.drawButton(cx + cw - 160, curY + 22, 130, 36, boloBtnText, boloBtnCol, colors.cardHover, fontScale * 0.85)
        if isBoloBtn and getKeyState("mouse1") and not state.clickDebounce then
            state.toggleVehicleBolo()
        end

        curY = curY + cardH + 16
    end

    exports.aura_ui:uiDrawText("TÜM ARANAN / BOLO LİSTESİ", cx + 16, curY, cx + 400, curY + 20, colors.textDim, fontScale * 0.85, "default-bold", "left", "center")
    curY = curY + 24

    local listH = ch - (curY - cy) - 16
    exports.aura_ui:uiDrawRectangle(cx + 16, curY, cw - 32, listH, colors.cardBg)
    dxSetScissor(cx + 16, curY, cw - 32, listH)

    if not state.allWantedVehicles or #state.allWantedVehicles == 0 then
        exports.aura_ui:uiDrawText("Aktif aranan araç kaydı bulunmuyor.", cx + 16, curY + 80, cx + cw - 16, curY + 120, colors.textDim, fontScale, "default", "center", "center")
    else
        local rowY = curY + 8 - state.scrollOffset
        for idx, bolo in ipairs(state.allWantedVehicles) do
            local isHover = PDGeometry.isCursorIn(cx + 24, rowY, cw - 48, 44)
            exports.aura_ui:uiDrawRectangle(cx + 24, rowY, cw - 48, 44, (isHover and colors.cardHover or colors.inputBg))

            exports.aura_ui:uiDrawText("PLAKA: " .. bolo.plate, cx + 36, rowY, cx + 220, rowY + 44, colors.accentRed, fontScale * 0.95, "default-bold", "left", "center")
            exports.aura_ui:uiDrawText("Sebep: " .. bolo.reason, cx + 230, rowY, cx + 550, rowY + 44, colors.textPrimary, fontScale * 0.85, "default", "left", "center", true)
            exports.aura_ui:uiDrawText("Kayıt: " .. bolo.officer_name, cx + cw - 200, rowY, cx + cw - 40, rowY + 44, colors.textDim, fontScale * 0.8, "default", "right", "center")

            rowY = rowY + 50
        end
        state.maxScroll = math.max(0, (#state.allWantedVehicles * 50) - listH + 20)
    end
    dxSetScissor()
end

function Views.drawPenalCode(cx, cy, cw, ch, state, fontScale)
    local colors = PDTheme.colors
    local curY = cy + 16

    exports.aura_ui:uiDrawText("SAN ANDREAS CEZA KANUNU VE TARİFELERİ", cx + 16, curY, cx + 500, curY + 24, colors.textPrimary, fontScale * 1.1, "default-bold", "left", "center")
    if state.searchedCitizenName and state.searchedCitizenName ~= "" then
        exports.aura_ui:uiDrawText("Hedef Vatandaş: " .. state.searchedCitizenName, cx + cw - 300, curY, cx + cw - 16, curY + 24, colors.policeGold, fontScale * 0.9, "default-bold", "right", "center")
    end
    curY = curY + 32

    local listH = ch - (curY - cy) - 16
    exports.aura_ui:uiDrawRectangle(cx + 16, curY, cw - 32, listH, colors.cardBg)
    dxSetScissor(cx + 16, curY, cw - 32, listH)

    local rowY = curY + 8 - state.scrollOffset
    for idx, penal in ipairs(PDConfig.PenalCode) do
        local isHover = PDGeometry.isCursorIn(cx + 24, rowY, cw - 48, 54)
        exports.aura_ui:uiDrawRectangle(cx + 24, rowY, cw - 48, 54, (isHover and colors.cardHover or colors.inputBg))

        local catCol = (penal.category == "AĞIR SUÇ" and colors.accentRed) or (penal.category == "ASAYİŞ" and colors.accentOrange or colors.policeBlue)
        exports.aura_ui:uiDrawRectangle(cx + 24, rowY, 4, 54, catCol)

        exports.aura_ui:uiDrawText("[" .. penal.category .. "] " .. penal.title, cx + 36, rowY + 6, cx + cw - 260, rowY + 28, colors.textPrimary, fontScale * 0.95, "default-bold", "left", "center")
        exports.aura_ui:uiDrawText("Para Cezası: $" .. tostring(penal.fine) .. " | Kamu Hizmeti / Hapis: " .. tostring(penal.jail) .. " Dakika", cx + 36, rowY + 28, cx + cw - 260, rowY + 48, colors.policeGold, fontScale * 0.85, "default", "left", "center")

        local isApplyBtn = Components.drawButton(cx + cw - 170, rowY + 10, 130, 34, "Cezayı Kes", colors.policeBlue, colors.accentGreen, fontScale * 0.85)
        if isApplyBtn and getKeyState("mouse1") and not state.clickDebounce then
            state.applyPenalFine(penal)
        end

        rowY = rowY + 60
    end

    state.maxScroll = math.max(0, (#PDConfig.PenalCode * 60) - listH + 20)
    dxSetScissor()
end