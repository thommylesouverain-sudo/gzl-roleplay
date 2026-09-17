
local screenW, screenH = guiGetScreenSize()
local currentTable = nil
local localBetAmount = 0
local hasCustomizedBet = false
local wasClickHandled = false
local cardTextures = {}
local chipTextures = {}

local rounded = {}
function dxDrawRoundedRectangle(id,x,y,w,h,radius,color,post)
    return exports.aura_ui:uiDrawRoundedRectangle(x,y,w,h,radius,color,post)
end

local function drawModernGlass(id, x, y, w, h, radius, bgAlpha, borderCol, accentColor, postGUI)
    radius = radius or 12
    bgAlpha = bgAlpha or 235

    dxDrawRoundedRectangle(id .. "_shd", x - 2, y + 2, w + 4, h + 4, radius + 2, tocolor(0, 0, 0, 95), postGUI)

    if borderCol then
        dxDrawRoundedRectangle(id .. "_brd", x, y, w, h, radius, borderCol, postGUI)
        dxDrawRoundedRectangle(id .. "_bg", x + 1, y + 1, w - 2, h - 2, math.max(0, radius - 1), tocolor(10, 14, 24, bgAlpha), postGUI)
    else
        dxDrawRoundedRectangle(id .. "_bg", x, y, w, h, radius, tocolor(10, 14, 24, bgAlpha), postGUI)
    end

    local innerW = w - radius * 2
    if innerW > 0 then
        exports.aura_ui:uiDrawRectangle(x + radius, y + 1, innerW, 1, tocolor(255, 255, 255, 30), postGUI)
    end

    if accentColor then
        local accW = math.min(w - 24, math.floor(w * 0.75))
        local accX = x + (w - accW) / 2
        exports.aura_ui:uiDrawRectangle(accX, y, accW, 2, accentColor, postGUI)
    end
end

local function formatMoney(amount)
    amount = math.floor(tonumber(amount) or 0)
    local formatted = tostring(amount)
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1.%2')
        if k == 0 then break end
    end
    return formatted
end

local function getPlayerBalances()
    local cash = tonumber(getElementData(localPlayer, "character:money") or getElementData(localPlayer, "char:money") or getPlayerMoney(localPlayer)) or 0
    local bank = tonumber(getElementData(localPlayer, "character:bank") or getElementData(localPlayer, "char:bank_money") or getElementData(localPlayer, "char:bank")) or 0
    cash = math.max(0, math.floor(cash))
    bank = math.max(0, math.floor(bank))
    return cash, bank, (cash + bank)
end

addEvent("blackjack:onTableSync", true)
addEventHandler("blackjack:onTableSync", resourceRoot, function(data)
    if data then
        if currentTable and currentTable.state ~= data.state and data.state == "BETTING" then
            localBetAmount = data.minBet or 10
            hasCustomizedBet = false
        elseif not currentTable or localBetAmount == 0 or localBetAmount < (data.minBet or 10) then
            localBetAmount = data.minBet or 10
            hasCustomizedBet = false
        end
    end
    currentTable = data
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    for k, tex in pairs(cardTextures) do
        if isElement(tex) then destroyElement(tex) end
    end
    cardTextures = {}
    for k, tex in pairs(chipTextures) do
        if isElement(tex) then destroyElement(tex) end
    end
    chipTextures = {}
    for id, sub in pairs(rounded) do
        for w, sub2 in pairs(sub) do
            for h, svg in pairs(sub2) do
                if isElement(svg) then destroyElement(svg) end
            end
        end
    end
    rounded = {}
end)

local function getCardTexture(card)
    if not card then return nil end
    if card.isHidden then
        local key = "card_back"
        if not cardTextures[key] then
            local path = "assets/cards/card_back.png"
            if fileExists(path) then
                cardTextures[key] = dxCreateTexture(path, "dxt5")
            end
        end
        return cardTextures[key]
    end

    local key = string.format("card_%s_%s", tostring(card.suit), tostring(card.rank))
    if not cardTextures[key] then
        local path = string.format("assets/cards/card_%s_%s.png", tostring(card.suit), tostring(card.rank))
        if fileExists(path) then
            cardTextures[key] = dxCreateTexture(path, "dxt5")
        end
    end
    return cardTextures[key]
end

local function getChipTexture(val)
    local key = "chip_" .. tostring(val)
    if not chipTextures[key] then
        local path = string.format("assets/chips/chip_%s.png", tostring(val))
        if fileExists(path) then
            chipTextures[key] = dxCreateTexture(path, "dxt5")
        end
    end
    return chipTextures[key]
end

local function isMouseInArea(x, y, w, h)
    if not isCursorShowing() then return false end
    local cx, cy = getCursorPosition()
    cx, cy = cx * screenW, cy * screenH
    return (cx >= x and cx <= x + w and cy >= y and cy <= y + h)
end

local function drawCard3D(tableObj, card, localX, localY, localZ, cardYaw, cardW, cardL)
    if not isElement(tableObj) or not card then return end

    local tex = getCardTexture(card)
    if not tex then return end

    cardW = cardW or 0.088
    cardL = cardL or 0.128

    local mat = getElementMatrix(tableObj)
    local wx = localX * mat[1][1] + localY * mat[2][1] + localZ * mat[3][1] + mat[4][1]
    local wy = localX * mat[1][2] + localY * mat[2][2] + localZ * mat[3][2] + mat[4][2]
    local wz = localX * mat[1][3] + localY * mat[2][3] + localZ * mat[3][3] + mat[4][3]

    local rad = math.rad(cardYaw or 0)
    local lDirX = math.sin(rad)
    local lDirY = math.cos(rad)
    local halfL = cardL * 0.5

    local lsX = localX - lDirX * halfL
    local lsY = localY - lDirY * halfL
    local leX = localX + lDirX * halfL
    local leY = localY + lDirY * halfL

    local sx = lsX * mat[1][1] + lsY * mat[2][1] + localZ * mat[3][1] + mat[4][1]
    local sy = lsX * mat[1][2] + lsY * mat[2][2] + localZ * mat[3][2] + mat[4][2]
    local sz = lsX * mat[1][3] + lsY * mat[2][3] + localZ * mat[3][3] + mat[4][3]

    local ex = leX * mat[1][1] + leY * mat[2][1] + localZ * mat[3][1] + mat[4][1]
    local ey = leX * mat[1][2] + leY * mat[2][2] + localZ * mat[3][2] + mat[4][2]
    local ez = leX * mat[1][3] + leY * mat[2][3] + localZ * mat[3][3] + mat[4][3]

    local faceX = wx + mat[3][1]
    local faceY = wy + mat[3][2]
    local faceZ = wz + mat[3][3]

    dxDrawMaterialLine3D(sx, sy, sz, ex, ey, ez, tex, cardW, tocolor(255, 255, 255, 255), false, faceX, faceY, faceZ)
end

addEventHandler("onClientRender", root, function()
    local seatedTId, seatedSeatIdx = Interaction.getSeatedData()
    if not seatedTId or not currentTable then return end

    local tableObj = Interaction.getTableObject(seatedTId)
    if not isElement(tableObj) then return end

    local fontTitle = FontManager.get("bold", 12)
    local fontNormal = FontManager.get("medium", 10)
    local fontSmall = FontManager.get("regular", 9)
    local fontButton = FontManager.get("semibold", 11)
    local fontScoreBadge = FontManager.get("bold", 10)

    local isM1 = getKeyState("mouse1")
    local isM2 = getKeyState("mouse2")

    if currentTable.dealer and currentTable.dealer.cards and #currentTable.dealer.cards > 0 then
        local numCards = #currentTable.dealer.cards
        local cardSpacing = 0.096
        local startX = -((numCards - 1) * cardSpacing) * 0.5
        local baseDealerY = 0.28

        for cIdx, card in ipairs(currentTable.dealer.cards) do
            local clX = startX + (cIdx - 1) * cardSpacing
            local clY = baseDealerY
            local clZ = 0.948 + cIdx * 0.0008

            drawCard3D(tableObj, card, clX, clY, clZ, 180, 0.088, 0.128)
        end

        local dScoreText = "KURPİYER"
        if not currentTable.dealer.holeCardHidden and currentTable.dealer.score > 0 then
            if currentTable.dealer.isBlackjack then
                dScoreText = "KURPİYER: BLACKJACK!"
            elseif currentTable.dealer.isBust then
                dScoreText = "KURPİYER: BUST (" .. currentTable.dealer.score .. ")"
            else
                dScoreText = string.format("KURPİYER: %d%s", currentTable.dealer.score, currentTable.dealer.isSoft and " Soft" or "")
            end
        elseif #currentTable.dealer.cards == 2 and currentTable.dealer.holeCardHidden then
            local upScore, _ = Cards.calculateScore({ currentTable.dealer.cards[1] })
            dScoreText = string.format("KURPİYER: %d + ?", upScore)
        end

        local mat = getElementMatrix(tableObj)
        local dBadgeX = 0.0 * mat[1][1] + 0.42 * mat[2][1] + 0.970 * mat[3][1] + mat[4][1]
        local dBadgeY = 0.0 * mat[1][2] + 0.42 * mat[2][2] + 0.970 * mat[3][2] + mat[4][2]
        local dBadgeZ = 0.0 * mat[1][3] + 0.42 * mat[2][3] + 0.970 * mat[3][3] + mat[4][3]

        local dsX, dsY = getScreenFromWorldPosition(dBadgeX, dBadgeY, dBadgeZ, 0.05)
        if dsX and dsY then
            local bW, bH = 154, 28
            local bX, bY = dsX - bW/2, dsY - bH/2
            drawModernGlass("dealer_badge", bX, bY, bW, bH, 8, 235, tocolor(212, 175, 55, 180), tocolor(212, 175, 55, 255))
            exports.aura_ui:uiDrawText(dScoreText, bX, bY, bX + bW, bY + bH,
                tocolor(212, 175, 55, 255), 1.0, fontScoreBadge, "center", "center")
        end
    end

    for sIdx = 1, 4 do
        local seatData = currentTable.seats and currentTable.seats[sIdx]
        local sOff = Config.CardOffsets.seats and Config.CardOffsets.seats[sIdx]

        if seatData and seatData.occupied and sOff and seatData.hands and #seatData.hands > 0 then
            local isSplit = (#seatData.hands > 1)
            local isCurrentTurn = (currentTable.currentTurnSeat == sIdx)
            local isLocal = (sIdx == seatedSeatIdx)

            local sRad = math.rad(sOff.rot or 0)
            local forwardX = -math.sin(sRad)
            local forwardY = math.cos(sRad)
            local rightX = math.cos(sRad)
            local rightY = math.sin(sRad)

            for hIdx, hand in ipairs(seatData.hands) do
                local isActiveHand = (isCurrentTurn and hIdx == (seatData.activeHandIndex or 1))

                local handBaseX = sOff.x
                local handBaseY = sOff.y
                if isSplit then
                    local splitShift = (hIdx == 1) and -0.11 or 0.11
                    handBaseX = handBaseX + rightX * splitShift
                    handBaseY = handBaseY + rightY * splitShift
                end

                local cards = hand.cards or {}
                for cIdx, card in ipairs(cards) do
                    local step = 0.024
                    local sideStep = 0.012
                    local cLocalX = handBaseX - forwardX * ((cIdx - 1) * step) + rightX * ((cIdx - 1) * sideStep)
                    local cLocalY = handBaseY - forwardY * ((cIdx - 1) * step) + rightY * ((cIdx - 1) * sideStep)
                    local cLocalZ = 0.948 + ((hIdx - 1) * 10 + cIdx) * 0.0008

                    local playerCardYaw = ((sOff.rot or 0) + 180) % 360
                    drawCard3D(tableObj, card, cLocalX, cLocalY, cLocalZ, playerCardYaw, 0.088, 0.128)
                end

                local mat = getElementMatrix(tableObj)
                local tagLocalX = handBaseX - forwardX * (#cards * 0.020 + 0.04)
                local tagLocalY = handBaseY - forwardY * (#cards * 0.020 + 0.04)
                local tagLocalZ = 0.970

                local tagWX = tagLocalX * mat[1][1] + tagLocalY * mat[2][1] + tagLocalZ * mat[3][1] + mat[4][1]
                local tagWY = tagLocalX * mat[1][2] + tagLocalY * mat[2][2] + tagLocalZ * mat[3][2] + mat[4][2]
                local tagWZ = tagLocalX * mat[1][3] + tagLocalY * mat[2][3] + tagLocalZ * mat[3][3] + mat[4][3]

                local tagSX, tagSY = getScreenFromWorldPosition(tagWX, tagWY, tagWZ, 0.05)
                if tagSX and tagSY then
                    local scText = tostring(hand.score or 0)
                    if hand.isBlackjack then scText = "BJ"
                    elseif hand.isBust then scText = "BUST"
                    elseif hand.status == "surrendered" then scText = "TESLİM" end

                    local badgeText = string.format("%s (%s)", seatData.playerName or ("Koltuk " .. sIdx), scText)
                    if isSplit then
                        badgeText = string.format("El %d: %s", hIdx, scText)
                    end

                    local pillW, pillH = 126, 26
                    local pillX, pillY = tagSX - pillW/2, tagSY - pillH/2

                    local pillBorder = isActiveHand and tocolor(212, 175, 55, 240) or (isLocal and tocolor(56, 189, 248, 160) or tocolor(255, 255, 255, 50))
                    local pillAccent = isActiveHand and tocolor(212, 175, 55, 255) or nil
                    drawModernGlass("seat_badge_" .. sIdx .. "_" .. hIdx, pillX, pillY, pillW, pillH, 8, 230, pillBorder, pillAccent)

                    exports.aura_ui:uiDrawText(badgeText, pillX + 4, pillY, pillX + pillW, pillY + pillH,
                        isActiveHand and tocolor(212, 175, 55, 255) or (isLocal and tocolor(56, 189, 248, 240) or tocolor(230, 230, 230, 220)),
                        1.0, fontSmall, "center", "center")
                end
            end
        end
    end

    local headerW, headerH = 480, 58
    local headerX = (screenW - headerW) / 2
    local headerY = 16

    drawModernGlass("ui_header", headerX, headerY, headerW, headerH, 16, 235, tocolor(212, 175, 55, 80), tocolor(212, 175, 55, 240))

    exports.aura_ui:uiDrawText("♦ DIAMOND CASINO & RESORT ♦",
        headerX, headerY + 6, headerX + headerW, headerY + 24,
        tocolor(212, 175, 55, 255), 1.0, fontTitle, "center", "center")

    local stateText = "BEKLENİYOR"
    local stateBadgeCol = tocolor(100, 116, 139, 220)
    local stateTextCol = tocolor(241, 245, 249, 255)

    if currentTable.state == "BETTING" then
        stateText = "● BAHİSLER AÇIK (" .. (currentTable.timerSeconds or 0) .. "s)"
        stateBadgeCol = tocolor(16, 185, 129, 220)
    elseif currentTable.state == "DEALING" then
        stateText = "● KARTLAR DAĞITILIYOR..."
        stateBadgeCol = tocolor(14, 165, 233, 220)
    elseif currentTable.state == "INSURANCE" then
        stateText = "● SİGORTA TEKLİFİ (" .. (currentTable.timerSeconds or 0) .. "s)"
        stateBadgeCol = tocolor(168, 85, 247, 220)
    elseif currentTable.state == "PLAYER_TURNS" then
        local turnSeat = currentTable.currentTurnSeat
        local turnName = (currentTable.seats and currentTable.seats[turnSeat] and currentTable.seats[turnSeat].playerName) or ("Koltuk " .. turnSeat)
        stateText = string.format("● SIRA: %s (%ds)", turnName, currentTable.timerSeconds or 0)
        stateBadgeCol = tocolor(234, 179, 8, 220)
    elseif currentTable.state == "DEALER_TURN" then
        stateText = "● KURPİYER KART ÇEKİYOR..."
        stateBadgeCol = tocolor(244, 63, 94, 220)
    elseif currentTable.state == "PAYOUT" then
        stateText = "★ ÖDEMELER HESAPLANDI ★"
        stateBadgeCol = tocolor(212, 175, 55, 220)
    end

    local limitText = string.format("Limit: $%s - $%s",
        formatMoney(currentTable.minBet or 10), formatMoney(currentTable.maxBet or 5000))

    local statusW = 220
    local statusH = 20
    local statusX = headerX + (headerW - statusW) / 2
    local statusY = headerY + 28

    dxDrawRoundedRectangle("hdr_status_pill", statusX, statusY, statusW, statusH, 10, tocolor(15, 20, 32, 220))
    dxDrawRoundedRectangle("hdr_status_border", statusX, statusY, statusW, statusH, 10, stateBadgeCol)
    dxDrawRoundedRectangle("hdr_status_inner", statusX + 1, statusY + 1, statusW - 2, statusH - 2, 9, tocolor(15, 20, 32, 240))
    exports.aura_ui:uiDrawText(stateText, statusX, statusY, statusX + statusW, statusY + statusH,
        stateBadgeCol, 1.0, fontSmall, "center", "center")

    exports.aura_ui:uiDrawText(limitText, headerX + 16, headerY + 28, headerX + statusW, headerY + statusH + 28,
        tocolor(148, 163, 184, 200), 1.0, fontSmall, "left", "center")

    local hintW, hintH = 220, 30
    local hintX = screenW - hintW - 20
    local hintY = 16
    dxDrawRoundedRectangle("ui_hint_bg", hintX, hintY, hintW, hintH, 15, tocolor(10, 14, 24, 210))
    dxDrawRoundedRectangle("ui_hint_brd", hintX, hintY, hintW, hintH, 15, tocolor(255, 255, 255, 35))
    dxDrawRoundedRectangle("ui_hint_in", hintX + 1, hintY + 1, hintW - 2, hintH - 2, 14, tocolor(10, 14, 24, 240))
    exports.aura_ui:uiDrawText("[V] Kamera  •  [F] Masadan Kalk", hintX, hintY, hintX + hintW, hintY + hintH,
        tocolor(226, 232, 240, 200), 1.0, fontSmall, "center", "center")

    local sub = SoundManager.getActiveSubtitle()
    if sub then
        local subW = 420
        local subH = 34
        local subX = (screenW - subW) / 2
        local subY = headerY + headerH + 12

        drawModernGlass("ui_sub", subX, subY, subW, subH, 10, 240, tocolor(212, 175, 55, 80), tocolor(212, 175, 55, 255))
        exports.aura_ui:uiDrawText("“ " .. sub .. " ”", subX, subY, subX + subW, subY + subH,
            tocolor(255, 255, 255, 235), 1.0, fontNormal, "center", "center")
    end

    local localSeat = currentTable.seats and currentTable.seats[seatedSeatIdx]
    local charCash, charBank, totalMoney = getPlayerBalances()

    if currentTable.state == "BETTING" and localSeat then
        local maxPossible = math.min(currentTable.maxBet or 5000, totalMoney)
        local betPanelW, betPanelH = 660, 154
        local betPanelX = (screenW - betPanelW) / 2
        local betPanelY = screenH - 174

        drawModernGlass("ui_bet_panel", betPanelX, betPanelY, betPanelW, betPanelH, 16, 240, tocolor(212, 175, 55, 80), tocolor(212, 175, 55, 255))

        exports.aura_ui:uiDrawText("◆ BAHİS SEÇİMİ", betPanelX + 18, betPanelY + 6, betPanelX + 180, betPanelY + 28,
            tocolor(212, 175, 55, 255), 1.0, fontTitle, "left", "center")

        local finText = string.format("Nakit: #10b981$%s#ffffff  |  Banka: #38bdf8$%s#ffffff  •  Toplam: #f1f5f9$%s",
            formatMoney(charCash), formatMoney(charBank), formatMoney(totalMoney))
        exports.aura_ui:uiDrawText(finText, betPanelX + 180, betPanelY + 6, betPanelX + betPanelW - 18, betPanelY + 28,
            tocolor(255, 255, 255, 230), 1.0, fontNormal, "right", "center", false, false, false, true)

        exports.aura_ui:uiDrawRectangle(betPanelX + 16, betPanelY + 30, betPanelW - 32, 1, tocolor(255, 255, 255, 20))

        local chipSize = 48
        local chipGap = 12
        local chipStartX = betPanelX + 18
        local chipY = betPanelY + 40
        local totalChipsW = #Config.ChipValues * (chipSize + chipGap) - chipGap

        for i, val in ipairs(Config.ChipValues) do
            local cx = chipStartX + (i - 1) * (chipSize + chipGap)
            local tex = getChipTexture(val)
            local isHover = isMouseInArea(cx, chipY - 4, chipSize, chipSize + 8)
            local canAffordChip = (val <= totalMoney)

            local drawY = isHover and (chipY - 4) or chipY

            if isHover then

                dxDrawRoundedRectangle("chip_glow_" .. i, cx - 3, drawY - 3, chipSize + 6, chipSize + 6, math.floor((chipSize + 6) / 2), tocolor(212, 175, 55, 130))
            end

            if tex then
                local chipAlpha = canAffordChip and 255 or 90
                dxDrawImage(cx, drawY, chipSize, chipSize, tex, 0, 0, 0, tocolor(255, 255, 255, chipAlpha))
            else
                dxDrawRoundedRectangle("chip_def_" .. i, cx, drawY, chipSize, chipSize, 8, tocolor(200, 200, 200, 255))
            end

            if isHover and isM1 and not wasClickHandled then
                wasClickHandled = true

                if not hasCustomizedBet and localBetAmount == (currentTable.minBet or 10) and val ~= (currentTable.minBet or 10) then
                    if val <= maxPossible then
                        localBetAmount = val
                        hasCustomizedBet = true
                        SoundManager.play("chip_place", false)
                    end
                else
                    if localBetAmount + val <= maxPossible then
                        localBetAmount = localBetAmount + val
                        hasCustomizedBet = true
                        SoundManager.play("chip_place", false)
                    end
                end
            end

            if isHover and isM2 and not wasClickHandled then
                wasClickHandled = true
                if localBetAmount - val >= 0 then
                    localBetAmount = math.max(0, localBetAmount - val)
                    hasCustomizedBet = true
                    SoundManager.play("chip_collect", false)
                end
            end
        end

        local btnW = 74
        local btnH = 36
        local btnY = chipY + 6
        local btnStartX = chipStartX + totalChipsW + 18

        local clearX = btnStartX
        local isClearHov = isMouseInArea(clearX, btnY, btnW, btnH)
        local clearBg = isClearHov and tocolor(225, 29, 72, 235) or tocolor(190, 18, 60, 160)
        dxDrawRoundedRectangle("btn_clear_shd", clearX - 1, btnY + 1, btnW + 2, btnH + 2, 8, tocolor(0, 0, 0, 80))
        dxDrawRoundedRectangle("btn_clear", clearX, btnY, btnW, btnH, 8, clearBg)
        exports.aura_ui:uiDrawRectangle(clearX + 6, btnY + 1, btnW - 12, 1, tocolor(255, 255, 255, isClearHov and 80 or 40))
        exports.aura_ui:uiDrawText("TEMİZLE", clearX, btnY, clearX + btnW, btnY + btnH, tocolor(255, 255, 255, 255), 1.0, fontSmall, "center", "center")

        if isClearHov and isM1 and not wasClickHandled then
            wasClickHandled = true
            localBetAmount = 0
            hasCustomizedBet = true
            SoundManager.play("chip_collect", false)
        end

        local doubleX = clearX + btnW + 10
        local isDoubleHov = isMouseInArea(doubleX, btnY, btnW, btnH)
        local doubleBg = isDoubleHov and tocolor(37, 99, 235, 235) or tocolor(29, 78, 216, 160)
        dxDrawRoundedRectangle("btn_double_shd", doubleX - 1, btnY + 1, btnW + 2, btnH + 2, 8, tocolor(0, 0, 0, 80))
        dxDrawRoundedRectangle("btn_double", doubleX, btnY, btnW, btnH, 8, doubleBg)
        exports.aura_ui:uiDrawRectangle(doubleX + 6, btnY + 1, btnW - 12, 1, tocolor(255, 255, 255, isDoubleHov and 80 or 40))
        exports.aura_ui:uiDrawText("2X", doubleX, btnY, doubleX + btnW, btnY + btnH, tocolor(255, 255, 255, 255), 1.0, fontSmall, "center", "center")

        if isDoubleHov and isM1 and not wasClickHandled then
            wasClickHandled = true
            localBetAmount = math.min(localBetAmount * 2, maxPossible)
            hasCustomizedBet = true
            SoundManager.play("chip_place", false)
        end

        local maxX = doubleX + btnW + 10
        local isMaxHov = isMouseInArea(maxX, btnY, btnW, btnH)
        local maxBg = isMaxHov and tocolor(217, 119, 6, 235) or tocolor(180, 83, 9, 160)
        dxDrawRoundedRectangle("btn_max_shd", maxX - 1, btnY + 1, btnW + 2, btnH + 2, 8, tocolor(0, 0, 0, 80))
        dxDrawRoundedRectangle("btn_max", maxX, btnY, btnW, btnH, 8, maxBg)
        exports.aura_ui:uiDrawRectangle(maxX + 6, btnY + 1, btnW - 12, 1, tocolor(255, 255, 255, isMaxHov and 80 or 40))
        exports.aura_ui:uiDrawText("MAKS", maxX, btnY, maxX + btnW, btnY + btnH, tocolor(255, 255, 255, 255), 1.0, fontSmall, "center", "center")

        if isMaxHov and isM1 and not wasClickHandled then
            wasClickHandled = true
            localBetAmount = maxPossible
            hasCustomizedBet = true
            SoundManager.play("chip_place", false)
        end

        local confirmW, confirmH = betPanelW - 32, 42
        local confirmX = betPanelX + 16
        local confirmY = betPanelY + betPanelH - 52
        local isConfirmHov = isMouseInArea(confirmX, confirmY, confirmW, confirmH)
        local canBet = (localBetAmount >= (currentTable.minBet or 10) and localBetAmount <= maxPossible and localBetAmount <= totalMoney)

        local confirmBg
        local confirmText
        if canBet then
            confirmBg = isConfirmHov and tocolor(16, 185, 129, 255) or tocolor(5, 150, 105, 225)
            confirmText = string.format("BAHİSİ ONAYLA   •   $%s", formatMoney(localBetAmount))
        else
            confirmBg = tocolor(45, 55, 72, 160)
            if localBetAmount < (currentTable.minBet or 10) then
                confirmText = string.format("EN AZ $%s BAHİS GEREKLİ", formatMoney(currentTable.minBet or 10))
            else
                confirmText = "YETERSİZ BAKİYE"
            end
        end

        dxDrawRoundedRectangle("btn_conf_shd", confirmX - 1, confirmY + 1, confirmW + 2, confirmH + 2, 10, tocolor(0, 0, 0, 90))
        dxDrawRoundedRectangle("btn_conf", confirmX, confirmY, confirmW, confirmH, 10, confirmBg)
        if canBet then
            exports.aura_ui:uiDrawRectangle(confirmX + 12, confirmY + 1, confirmW - 24, 1, tocolor(255, 255, 255, isConfirmHov and 80 or 40))
        end

        exports.aura_ui:uiDrawText(confirmText, confirmX, confirmY, confirmX + confirmW, confirmY + confirmH,
            tocolor(255, 255, 255, canBet and 255 or 140), 1.0, fontButton, "center", "center")

        if canBet and isConfirmHov and isM1 and not wasClickHandled then
            wasClickHandled = true
            triggerServerEvent("blackjack:requestPlaceBet", resourceRoot, localBetAmount)
        end

    elseif currentTable.state == "PLAYER_TURNS" and currentTable.currentTurnSeat == seatedSeatIdx and localSeat then
        local activeHand = localSeat.hands and localSeat.hands[localSeat.activeHandIndex or 1]
        local handBet = activeHand and (activeHand.bet or localSeat.bet) or 0

        local canDouble = Config.Rules.allowDoubleDown and activeHand and (#activeHand.cards == 2) and (totalMoney >= handBet)
        local canSplit = Config.Rules.allowSplit and activeHand and (#activeHand.cards == 2) and (#(localSeat.hands or {}) < (Config.Rules.maxSplitHands or 2))
            and (activeHand.cards[1].rank == activeHand.cards[2].rank or activeHand.cards[1].value == activeHand.cards[2].value)
            and (totalMoney >= handBet)
        local canSurrender = Config.Rules.allowSurrender and activeHand and (#activeHand.cards == 2) and (not activeHand.isFromSplit)

        local actionPanelW, actionPanelH = 640, 86
        local actionPanelX = (screenW - actionPanelW) / 2
        local actionPanelY = screenH - 116

        drawModernGlass("ui_act_panel", actionPanelX, actionPanelY, actionPanelW, actionPanelH, 16, 240, tocolor(212, 175, 55, 80), tocolor(212, 175, 55, 255))

        local actions = {
            { id = "hit", key = "BOŞLUK", title = "KART ÇEK", color = tocolor(16, 185, 129, 190), hovColor = tocolor(16, 185, 129, 255), enabled = true },
            { id = "stand", key = "S", title = "DUR", color = tocolor(225, 29, 72, 190), hovColor = tocolor(225, 29, 72, 255), enabled = true },
            { id = "double", key = "D", title = "2X KATLA", color = tocolor(234, 179, 8, 190), hovColor = tocolor(234, 179, 8, 255), enabled = canDouble },
            { id = "split", key = "B", title = "BÖL", color = tocolor(14, 165, 233, 190), hovColor = tocolor(14, 165, 233, 255), enabled = canSplit },
            { id = "surrender", key = "T", title = "TESLİM", color = tocolor(100, 116, 139, 190), hovColor = tocolor(100, 116, 139, 255), enabled = canSurrender }
        }

        local btnGap = 8
        local btnW = (actionPanelW - 24 - (#actions - 1) * btnGap) / #actions
        local btnH = actionPanelH - 24
        local btnY = actionPanelY + 12

        for i, act in ipairs(actions) do
            local bx = actionPanelX + 12 + (i - 1) * (btnW + btnGap)
            local isHov = act.enabled and isMouseInArea(bx, btnY, btnW, btnH)
            local col = act.enabled and (isHov and act.hovColor or act.color) or tocolor(40, 48, 62, 140)

            dxDrawRoundedRectangle("act_shd_" .. act.id, bx - 1, btnY + 1, btnW + 2, btnH + 2, 10, tocolor(0, 0, 0, 80))
            dxDrawRoundedRectangle("act_bg_" .. act.id, bx, btnY, btnW, btnH, 10, col)

            if act.enabled then
                exports.aura_ui:uiDrawRectangle(bx + 8, btnY + 1, btnW - 16, 1, tocolor(255, 255, 255, isHov and 80 or 40))
            end

            local keyText = "[" .. act.key .. "]"
            exports.aura_ui:uiDrawText(keyText, bx, btnY + 8, bx + btnW, btnY + 24,
                tocolor(255, 255, 255, act.enabled and 210 or 80), 1.0, fontSmall, "center", "center")

            exports.aura_ui:uiDrawText(act.title, bx, btnY + 26, bx + btnW, btnY + btnH - 6,
                tocolor(255, 255, 255, act.enabled and 255 or 90), 1.0, fontButton, "center", "center")

            if isHov and isM1 and not wasClickHandled then
                wasClickHandled = true
                triggerServerEvent("blackjack:requestPlayerAction", resourceRoot, act.id)
            end
        end

    elseif currentTable.state == "INSURANCE" and localSeat and localSeat.bet > 0 then
        local insPanelW, insPanelH = 560, 100
        local insPanelX = (screenW - insPanelW) / 2
        local insPanelY = screenH - 130

        drawModernGlass("ui_ins_panel", insPanelX, insPanelY, insPanelW, insPanelH, 14, 240, tocolor(168, 85, 247, 120), tocolor(168, 85, 247, 255))

        local insCost = math.floor(localSeat.bet / 2)
        local canAffordIns = (totalMoney >= insCost)

        if localSeat.isInsured then
            exports.aura_ui:uiDrawText("★ SİGORTA KABUL EDİLDİ ★", insPanelX, insPanelY + 16, insPanelX + insPanelW, insPanelY + 40,
                tocolor(168, 85, 247, 255), 1.0, fontTitle, "center", "center")
            exports.aura_ui:uiDrawText(string.format("Sigorta: $%s (2:1)  •  Kurpiyerin kapalı kartı bekleniyor... (%ds)",
                formatMoney(localSeat.insuranceBet or insCost), currentTable.timerSeconds or 0),
                insPanelX, insPanelY + 46, insPanelX + insPanelW, insPanelY + 70,
                tocolor(255, 255, 255, 220), 1.0, fontNormal, "center", "center")
        elseif localSeat.insuranceDeclined then
            exports.aura_ui:uiDrawText("SİGORTA PAS GEÇİLDİ", insPanelX, insPanelY + 16, insPanelX + insPanelW, insPanelY + 40,
                tocolor(160, 160, 160, 255), 1.0, fontTitle, "center", "center")
            exports.aura_ui:uiDrawText(string.format("Kurpiyerin kapalı kart kontrolü bekleniyor... (%ds)", currentTable.timerSeconds or 0),
                insPanelX, insPanelY + 46, insPanelX + insPanelW, insPanelY + 70,
                tocolor(200, 200, 200, 200), 1.0, fontNormal, "center", "center")
        else
            exports.aura_ui:uiDrawText(string.format("KURPİYER AS AÇTI! SİGORTA ALMAK İSTİYOR MUSUNUZ? (%ds)", currentTable.timerSeconds or 0),
                insPanelX, insPanelY + 10, insPanelX + insPanelW, insPanelY + 32,
                tocolor(212, 175, 55, 255), 1.0, fontButton, "center", "center")

            local btnW, btnH = 220, 38
            local btnY = insPanelY + 46

            local insBtnX = insPanelX + 36
            local isInsHov = canAffordIns and isMouseInArea(insBtnX, btnY, btnW, btnH)
            local insBg = canAffordIns and (isInsHov and tocolor(168, 85, 247, 245) or tocolor(168, 85, 247, 180)) or tocolor(60, 70, 85, 140)

            dxDrawRoundedRectangle("btn_ins_shd", insBtnX - 1, btnY + 1, btnW + 2, btnH + 2, 8, tocolor(0, 0, 0, 80))
            dxDrawRoundedRectangle("btn_ins", insBtnX, btnY, btnW, btnH, 8, insBg)
            exports.aura_ui:uiDrawText(string.format("SİGORTA AL ($%s) [I]", formatMoney(insCost)),
                insBtnX, btnY, insBtnX + btnW, btnY + btnH,
                tocolor(255, 255, 255, canAffordIns and 255 or 120), 1.0, fontSmall, "center", "center")

            if canAffordIns and isInsHov and isM1 and not wasClickHandled then
                wasClickHandled = true
                triggerServerEvent("blackjack:requestPlayerAction", resourceRoot, "insurance")
            end

            local passBtnX = insPanelX + insPanelW - 36 - btnW
            local isPassHov = isMouseInArea(passBtnX, btnY, btnW, btnH)
            local passBg = isPassHov and tocolor(100, 116, 139, 245) or tocolor(100, 116, 139, 180)

            dxDrawRoundedRectangle("btn_pass_shd", passBtnX - 1, btnY + 1, btnW + 2, btnH + 2, 8, tocolor(0, 0, 0, 80))
            dxDrawRoundedRectangle("btn_pass", passBtnX, btnY, btnW, btnH, 8, passBg)
            exports.aura_ui:uiDrawText("PAS GEÇ [P]", passBtnX, btnY, passBtnX + btnW, btnY + btnH,
                tocolor(255, 255, 255, 255), 1.0, fontSmall, "center", "center")

            if isPassHov and isM1 and not wasClickHandled then
                wasClickHandled = true
                triggerServerEvent("blackjack:requestPlayerAction", resourceRoot, "pass_insurance")
            end
        end

    elseif currentTable.state == "PAYOUT" and currentTable.lastResults and currentTable.lastResults[seatedSeatIdx] then
        local myRes = currentTable.lastResults[seatedSeatIdx]
        local bannerW, bannerH = 460, 92
        local bannerX = (screenW - bannerW) / 2
        local bannerY = (screenH - bannerH) / 2 - 40

        local title = "RAUNT TAMAMLANDI"
        local subTitle = ""
        local accent = tocolor(212, 175, 55, 255)

        for _, h in ipairs(myRes.hands or {}) do
            if h.outcome == "blackjack" then
                title = "★ DOĞAL BLACKJACK! ★"
                subTitle = string.format("Ödül: +$%s (3:2)", formatMoney(h.payout))
                accent = tocolor(212, 175, 55, 255)
            elseif h.outcome == "win" or h.outcome == "dealer_bust" then
                title = "TEBRİKLER, KAZANDINIZ!"
                subTitle = string.format("Kazanç: +$%s", formatMoney(h.payout))
                accent = tocolor(16, 185, 129, 255)
            elseif h.outcome == "push" then
                title = "BERABERE (PUSH)"
                subTitle = "Bahsiniz iade edildi."
                accent = tocolor(59, 130, 246, 255)
            elseif h.outcome == "surrendered" then
                title = "TESLİM OLUNDU"
                subTitle = "%50 Bahis tutarı iade alındı."
                accent = tocolor(148, 163, 184, 255)
            else
                title = "BU ELİ KAYBETTİNİZ"
                subTitle = h.outcome == "bust" and "Puanınız 21'i aştı." or "Kurpiyer daha yüksek puana ulaştı."
                accent = tocolor(239, 68, 68, 255)
            end
        end

        if myRes.insurancePayout and myRes.insurancePayout > 0 then
            subTitle = subTitle .. string.format("  •  Sigorta: +$%s", formatMoney(myRes.insurancePayout))
        end

        drawModernGlass("ui_payout_banner", bannerX, bannerY, bannerW, bannerH, 16, 245, tocolor(255, 255, 255, 60), accent)
        exports.aura_ui:uiDrawText(title, bannerX, bannerY + 16, bannerX + bannerW, bannerY + 42,
            accent, 1.0, fontTitle, "center", "center")
        exports.aura_ui:uiDrawText(subTitle, bannerX, bannerY + 46, bannerX + bannerW, bannerY + 74,
            tocolor(255, 255, 255, 220), 1.0, fontNormal, "center", "center")
    end

    if localSeat and localSeat.hands and #localSeat.hands > 0 and currentTable.state ~= "BETTING" and currentTable.state ~= "WAITING" then
        local activeHand = localSeat.hands[localSeat.activeHandIndex or 1]
        local cards = activeHand and activeHand.cards
        if cards and #cards > 0 then
            local cardCount = #cards
            local cardW, cardH = 48, 66
            local cardGap = 8
            local totalCardsW = cardCount * cardW + (cardCount - 1) * cardGap

            local scText = tostring(activeHand.score or 0)
            if activeHand.isBlackjack then scText = "BLACKJACK! (21)"
            elseif activeHand.isBust then scText = "BUST (" .. (activeHand.score or 0) .. ")" end

            local hudW = math.max(270, totalCardsW + 120)
            local hudH = 96
            local hudX = (screenW - hudW) / 2
            local isTurnActive = (currentTable.state == "PLAYER_TURNS" and currentTable.currentTurnSeat == seatedSeatIdx)
            local hudY = isTurnActive and (screenH - 224) or (screenH - 116)

            drawModernGlass("my_cards_hud", hudX, hudY, hudW, hudH, 14, 235, tocolor(255, 255, 255, 40), isTurnActive and tocolor(212, 175, 55, 255) or tocolor(56, 189, 248, 200))

            local headerScore = string.format("ELİNİZ: %s", scText)
            exports.aura_ui:uiDrawText(headerScore, hudX + 16, hudY + 6, hudX + hudW - 16, hudY + 24,
                activeHand.isBlackjack and tocolor(212, 175, 55, 255) or (activeHand.isBust and tocolor(239, 68, 68, 255) or tocolor(255, 255, 255, 240)),
                1.0, fontTitle, "center", "center")

            local startX = hudX + (hudW - totalCardsW) / 2
            local cardsY = hudY + 26
            for cIdx, card in ipairs(cards) do
                local cx = startX + (cIdx - 1) * (cardW + cardGap)
                local tex = getCardTexture(card)
                if tex then
                    dxDrawImage(cx, cardsY, cardW, cardH, tex, 0, 0, 0, tocolor(255, 255, 255, 255))
                    dxDrawRoundedRectangle("card_frame_" .. cIdx, cx - 1, cardsY - 1, cardW + 2, cardH + 2, 4, tocolor(255, 255, 255, 30))
                else
                    dxDrawRoundedRectangle("card_fallback_" .. cIdx, cx, cardsY, cardW, cardH, 4, tocolor(240, 240, 240, 255))
                    local isRed = (card.suit == "H" or card.suit == "D")
                    local suitChar = (card.suit == "H" and "♥") or (card.suit == "D" and "♦") or (card.suit == "C" and "♣") or "♠"
                    exports.aura_ui:uiDrawText(tostring(card.rank) .. "\n" .. suitChar, cx, cardsY, cx + cardW, cardsY + cardH,
                        isRed and tocolor(220, 30, 30, 255) or tocolor(20, 20, 20, 255), 1.0, fontSmall, "center", "center")
                end
            end
        end
    end

    if not isM1 and not isM2 then
        wasClickHandled = false
    end
end)

addEventHandler("onClientKey", root, function(button, press)
    if not press then return end
    local seatedTId, seatedSeatIdx = Interaction.getSeatedData()
    if not seatedTId or not currentTable then return end
    local localSeat = currentTable.seats and currentTable.seats[seatedSeatIdx]

    if currentTable.state == "INSURANCE" and localSeat and localSeat.bet > 0 and not localSeat.isInsured and not localSeat.insuranceDeclined then
        if button == "i" then
            triggerServerEvent("blackjack:requestPlayerAction", resourceRoot, "insurance")
            cancelEvent()
            return
        elseif button == "p" then
            triggerServerEvent("blackjack:requestPlayerAction", resourceRoot, "pass_insurance")
            cancelEvent()
            return
        end
    end

    if currentTable.state == "PLAYER_TURNS" and currentTable.currentTurnSeat == seatedSeatIdx then
        if button == "space" then
            triggerServerEvent("blackjack:requestPlayerAction", resourceRoot, "hit")
            cancelEvent()
        elseif button == "s" then
            triggerServerEvent("blackjack:requestPlayerAction", resourceRoot, "stand")
            cancelEvent()
        elseif button == "d" then
            triggerServerEvent("blackjack:requestPlayerAction", resourceRoot, "double")
            cancelEvent()
        elseif button == "b" then
            triggerServerEvent("blackjack:requestPlayerAction", resourceRoot, "split")
            cancelEvent()
        elseif button == "t" then
            triggerServerEvent("blackjack:requestPlayerAction", resourceRoot, "surrender")
            cancelEvent()
        end
    end
end)