local screenW, screenH = guiGetScreenSize()
local isOpen = false
local animAlpha = 0
local activeTab = 1

local atmData = {
    cash = 0,
    bank = 0,
    charId = 0,
    charName = "Thommy Souverain",
    transactions = {}
}

local tabs = {
    { id = 1, title = "Genel Bakış", icon = "wallet" },
    { id = 2, title = "Para Çek", icon = "arrow_down" },
    { id = 3, title = "Para Yatır", icon = "arrow_up" },
    { id = 4, title = "Havale / EFT", icon = "refresh" },
    { id = 5, title = "Hesap Özeti", icon = "clock" }
}

local editFields = {
    withdraw_amount = "",
    deposit_amount = "",
    transfer_target = "",
    transfer_amount = "",
    transfer_note = ""
}
local activeField = nil

local function setActiveField(fieldId)
    activeField = fieldId
    if activeField then
        guiSetInputMode("no_binds")
        guiSetInputEnabled(true)
    else
        guiSetInputMode("allow_binds")
        guiSetInputEnabled(false)
    end
end

function isATMOpen()
    return isOpen
end

function isATMEditing()
    return isOpen and (activeField ~= nil)
end

function formatMoney(amount)
    amount = tonumber(amount) or 0
    local formatted = tostring(math.abs(amount))
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1.%2')
        if k == 0 then break end
    end
    return (amount < 0 and "-" or "") .. formatted
end

local function isMouseInPosition(x, y, w, h)
    if not isCursorShowing() then return false end
    local cx, cy = getCursorPosition()
    if not cx or not cy then return false end
    cx, cy = cx * screenW, cy * screenH
    return (cx >= x and cx <= x + w and cy >= y and cy <= y + h)
end

function openATM()
    if isOpen then return end
    isOpen = true
    animAlpha = 0
    activeTab = 1
    setActiveField(nil)
    editFields.withdraw_amount = ""
    editFields.deposit_amount = ""
    editFields.transfer_target = ""
    editFields.transfer_amount = ""
    editFields.transfer_note = ""

    local localCash = tonumber(getElementData(localPlayer, "character:money") or getElementData(localPlayer, "char:money") or getPlayerMoney(localPlayer)) or 0
    local localBank = tonumber(getElementData(localPlayer, "character:bank") or getElementData(localPlayer, "char:bank_money") or getElementData(localPlayer, "char:bank")) or 0
    local localName = getElementData(localPlayer, "character:name") or getElementData(localPlayer, "char:name") or getPlayerName(localPlayer)
    local localId = tonumber(getElementData(localPlayer, "character:id") or getElementData(localPlayer, "char:id")) or 0

    atmData.cash = localCash
    atmData.bank = localBank
    atmData.charName = localName
    atmData.charId = localId

    showCursor(true)
    triggerServerEvent("atm:requestData", resourceRoot)
end

function closeATM()
    if not isOpen then return end
    isOpen = false
    setActiveField(nil)
    showCursor(false)
end

addEvent("atm:receiveData", true)
addEventHandler("atm:receiveData", root, function(data)
    if type(data) == "table" then
        atmData.cash = tonumber(data.cash) or 0
        atmData.bank = tonumber(data.bank) or 0
        atmData.charId = tonumber(data.charId) or 0
        atmData.charName = tostring(data.charName or "Oyuncu")
        atmData.transactions = data.transactions or {}
    end
end)

addEventHandler("onClientCharacter", root, function(character)
    if not isOpen or not activeField then return end
    if activeField == "withdraw_amount" or activeField == "deposit_amount" or activeField == "transfer_amount" then
        if character:match("%d") then
            if string.len(editFields[activeField]) < 9 then
                editFields[activeField] = editFields[activeField] .. character
            end
        end
    elseif activeField == "transfer_target" or activeField == "transfer_note" then
        if string.len(editFields[activeField]) < 28 then
            editFields[activeField] = editFields[activeField] .. character
        end
    end
end)

addEventHandler("onClientKey", root, function(button, press)
    if not isOpen or not press then return end
    if button == "escape" then
        cancelEvent()
        closeATM()
        return
    elseif button == "backspace" and activeField then
        local text = editFields[activeField]
        if string.len(text) > 0 then
            editFields[activeField] = string.sub(text, 1, -2)
        end
        cancelEvent()
        return
    end

    if activeField then
        if button ~= "mouse1" and button ~= "mouse2" and button ~= "mouse_wheel_up" and button ~= "mouse_wheel_down" then
            cancelEvent()
        end
    end
end)

local function drawCustomEditBox(fieldId, x, y, w, h, placeholder, font, fontSmall)
    local isActive = (activeField == fieldId)
    local isHovered = isMouseInPosition(x, y, w, h)
    local text = editFields[fieldId] or ""

    local bgAlpha = isActive and 240 or (isHovered and 200 or 150)
    local borderColor = isActive and tocolor(56, 189, 248, 220) or (isHovered and tocolor(148, 163, 184, 140) or tocolor(51, 65, 85, 120))

    if exports.gzl_ui and exports.gzl_ui.drawRoundedRectangle then
        exports.gzl_ui:drawRoundedRectangle(x, y, w, h, 8, tocolor(15, 23, 42, bgAlpha))
        exports.gzl_ui:drawRoundedBorder(x, y, w, h, 8, 1.0, borderColor)
    else
        exports.aura_ui:uiDrawRectangle(x, y, w, h, tocolor(15, 23, 42, bgAlpha))
    end

    if string.len(text) == 0 and not isActive then
        exports.aura_ui:uiDrawText(placeholder, x + 12, y, x + w - 12, y + h, tocolor(100, 116, 139, 180), 1, font, "left", "center", true)
    else
        local displayText = text
        if isActive and (getTickCount() % 1000 < 500) then
            displayText = displayText .. "|"
        end
        exports.aura_ui:uiDrawText(displayText, x + 12, y, x + w - 12, y + h, tocolor(255, 255, 255, 240), 1, font, "left", "center", true)
    end

    return isHovered
end

addEventHandler("onClientRender", root, function()
    if not isOpen and animAlpha <= 0 then return end

    local targetAlpha = isOpen and 1 or 0
    animAlpha = animAlpha + (targetAlpha - animAlpha) * 0.15
    if animAlpha < 0.01 and not isOpen then return end

    local alphaMult = math.min(1, math.max(0, animAlpha))
    local globalAlpha = math.floor(255 * alphaMult)

    local fontTitle = exports.gzl_ui and exports.gzl_ui.getFont and exports.gzl_ui:getFont("bold", 13) or "default-bold"
    local fontLarge = exports.gzl_ui and exports.gzl_ui.getFont and exports.gzl_ui:getFont("bold", 18) or "default-bold"
    local fontMedium = exports.gzl_ui and exports.gzl_ui.getFont and exports.gzl_ui:getFont("medium", 11) or "default"
    local fontSmall = exports.gzl_ui and exports.gzl_ui.getFont and exports.gzl_ui:getFont("regular", 9) or "default"
    local fontBold = exports.gzl_ui and exports.gzl_ui.getFont and exports.gzl_ui:getFont("bold", 11) or "default-bold"

    local panelW = 760
    local panelH = 490
    local panelX = (screenW - panelW) / 2
    local panelY = (screenH - panelH) / 2

    if exports.gzl_ui and exports.gzl_ui.drawGlassPanel then
        exports.gzl_ui:drawGlassPanel(panelX, panelY, panelW, panelH, 16, tocolor(255, 255, 255, globalAlpha))
    else
        exports.aura_ui:uiDrawRectangle(panelX, panelY, panelW, panelH, tocolor(15, 23, 42, math.floor(245 * alphaMult)))
    end

    local headerH = 62
    if exports.gzl_ui and exports.gzl_ui.drawRoundedRectangle then
        exports.gzl_ui:drawRoundedRectangle(panelX + 2, panelY + 2, panelW - 4, headerH, 14, tocolor(30, 41, 59, math.floor(160 * alphaMult)))
    else
        exports.aura_ui:uiDrawRectangle(panelX + 2, panelY + 2, panelW - 4, headerH, tocolor(30, 41, 59, math.floor(160 * alphaMult)))
    end

    local logoSize = 34
    local logoX = panelX + 16
    local logoY = panelY + (headerH - logoSize) / 2
    if exports.gzl_ui and exports.gzl_ui.drawRoundedRectangle then
        exports.gzl_ui:drawRoundedRectangle(logoX, logoY, logoSize, logoSize, 8, tocolor(56, 189, 248, math.floor(240 * alphaMult)))
    else
        exports.aura_ui:uiDrawRectangle(logoX, logoY, logoSize, logoSize, tocolor(56, 189, 248, math.floor(240 * alphaMult)))
    end
    exports.aura_ui:uiDrawText("$", logoX, logoY, logoX + logoSize, logoY + logoSize, tocolor(15, 23, 42, globalAlpha), 1, fontLarge, "center", "center")

    exports.aura_ui:uiDrawText("Bank of San Andreas", logoX + logoSize + 12, panelY + 12, panelX + 350, panelY + 32, tocolor(255, 255, 255, globalAlpha), 1, fontTitle, "left", "center")
    exports.aura_ui:uiDrawText("GZL Ulusal Finans & ATM Ağı", logoX + logoSize + 12, panelY + 32, panelX + 350, panelY + 50, tocolor(148, 163, 184, math.floor(200 * alphaMult)), 1, fontSmall, "left", "center")

    local infoRight = panelX + panelW - 55
    local userTitle = atmData.charName or "Oyuncu"
    local accountText = "Hesap ID: #" .. tostring(atmData.charId)
    exports.aura_ui:uiDrawText(userTitle, infoRight - 220, panelY + 12, infoRight, panelY + 32, tocolor(255, 255, 255, globalAlpha), 1, fontBold, "right", "center")
    exports.aura_ui:uiDrawText(accountText, infoRight - 220, panelY + 32, infoRight, panelY + 50, tocolor(56, 189, 248, math.floor(220 * alphaMult)), 1, fontSmall, "right", "center")

    local closeBtnX = panelX + panelW - 44
    local closeBtnY = panelY + 14
    local closeBtnSize = 34
    local isCloseHov = isMouseInPosition(closeBtnX, closeBtnY, closeBtnSize, closeBtnSize)
    local closeBgColor = isCloseHov and tocolor(239, 68, 68, math.floor(220 * alphaMult)) or tocolor(51, 65, 85, math.floor(150 * alphaMult))
    if exports.gzl_ui and exports.gzl_ui.drawRoundedRectangle then
        exports.gzl_ui:drawRoundedRectangle(closeBtnX, closeBtnY, closeBtnSize, closeBtnSize, 8, closeBgColor)
    else
        exports.aura_ui:uiDrawRectangle(closeBtnX, closeBtnY, closeBtnSize, closeBtnSize, closeBgColor)
    end
    exports.aura_ui:uiDrawText("✕", closeBtnX, closeBtnY, closeBtnX + closeBtnSize, closeBtnY + closeBtnSize, tocolor(255, 255, 255, globalAlpha), 1, fontBold, "center", "center")

    local navX = panelX + 16
    local navY = panelY + headerH + 16
    local navW = 165
    local navItemH = 44
    local navGap = 8

    for i, tab in ipairs(tabs) do
        local tabY = navY + (i - 1) * (navItemH + navGap)
        local isCurrent = (activeTab == tab.id)
        local isHov = isMouseInPosition(navX, tabY, navW, navItemH)

        local tabBg = isCurrent and tocolor(56, 189, 248, math.floor(230 * alphaMult)) or (isHov and tocolor(30, 41, 59, math.floor(200 * alphaMult)) or tocolor(15, 23, 42, math.floor(140 * alphaMult)))
        local tabTextColor = isCurrent and tocolor(15, 23, 42, globalAlpha) or (isHov and tocolor(255, 255, 255, globalAlpha) or tocolor(148, 163, 184, math.floor(220 * alphaMult)))

        if exports.gzl_ui and exports.gzl_ui.drawRoundedRectangle then
            exports.gzl_ui:drawRoundedRectangle(navX, tabY, navW, navItemH, 8, tabBg)
            if not isCurrent and isHov then
                exports.gzl_ui:drawRoundedBorder(navX, tabY, navW, navItemH, 8, 1.0, tocolor(56, 189, 248, math.floor(80 * alphaMult)))
            end
        else
            exports.aura_ui:uiDrawRectangle(navX, tabY, navW, navItemH, tabBg)
        end

        exports.aura_ui:uiDrawText(tab.title, navX + 14, tabY, navX + navW - 10, tabY + navItemH, tabTextColor, 1, fontBold, "left", "center")
    end

    local contentX = panelX + navW + 30
    local contentY = navY
    local contentW = panelW - navW - 46
    local contentH = panelH - headerH - 32

    if exports.gzl_ui and exports.gzl_ui.drawRoundedRectangle then
        exports.gzl_ui:drawRoundedRectangle(contentX, contentY, contentW, contentH, 12, tocolor(30, 41, 59, math.floor(120 * alphaMult)))
        exports.gzl_ui:drawRoundedBorder(contentX, contentY, contentW, contentH, 12, 1.0, tocolor(51, 65, 85, math.floor(140 * alphaMult)))
    else
        exports.aura_ui:uiDrawRectangle(contentX, contentY, contentW, contentH, tocolor(30, 41, 59, math.floor(120 * alphaMult)))
    end

    if activeTab == 1 then
        local cardW = (contentW - 36) / 2
        local cardH = 88
        local cardY = contentY + 16

        local bankCardX = contentX + 14
        if exports.gzl_ui and exports.gzl_ui.drawRoundedRectangle then
            exports.gzl_ui:drawRoundedRectangle(bankCardX, cardY, cardW, cardH, 10, tocolor(15, 23, 42, math.floor(200 * alphaMult)))
            exports.gzl_ui:drawRoundedBorder(bankCardX, cardY, cardW, cardH, 10, 1.0, tocolor(56, 189, 248, math.floor(90 * alphaMult)))
        else
            exports.aura_ui:uiDrawRectangle(bankCardX, cardY, cardW, cardH, tocolor(15, 23, 42, math.floor(200 * alphaMult)))
        end
        exports.aura_ui:uiDrawText("BANKA HESABI", bankCardX + 14, cardY + 12, bankCardX + cardW - 14, cardY + 28, tocolor(148, 163, 184, math.floor(220 * alphaMult)), 1, fontSmall, "left", "center")
        exports.aura_ui:uiDrawText("$" .. formatMoney(atmData.bank), bankCardX + 14, cardY + 36, bankCardX + cardW - 14, cardY + 74, tocolor(56, 189, 248, globalAlpha), 1, fontLarge, "left", "center")

        local cashCardX = contentX + 14 + cardW + 8
        if exports.gzl_ui and exports.gzl_ui.drawRoundedRectangle then
            exports.gzl_ui:drawRoundedRectangle(cashCardX, cardY, cardW, cardH, 10, tocolor(15, 23, 42, math.floor(200 * alphaMult)))
            exports.gzl_ui:drawRoundedBorder(cashCardX, cardY, cardW, cardH, 10, 1.0, tocolor(52, 211, 153, math.floor(90 * alphaMult)))
        else
            exports.aura_ui:uiDrawRectangle(cashCardX, cardY, cardW, cardH, tocolor(15, 23, 42, math.floor(200 * alphaMult)))
        end
        exports.aura_ui:uiDrawText("CÜZDAN NAKİT", cashCardX + 14, cardY + 12, cashCardX + cardW - 14, cardY + 28, tocolor(148, 163, 184, math.floor(220 * alphaMult)), 1, fontSmall, "left", "center")
        exports.aura_ui:uiDrawText("$" .. formatMoney(atmData.cash), cashCardX + 14, cardY + 36, cashCardX + cardW - 14, cardY + 74, tocolor(52, 211, 153, globalAlpha), 1, fontLarge, "left", "center")

        local secTitleY = cardY + cardH + 18
        exports.aura_ui:uiDrawText("HIZLI NAKİT ÇEKİM", contentX + 14, secTitleY, contentX + contentW, secTitleY + 20, tocolor(255, 255, 255, globalAlpha), 1, fontBold, "left", "center")
        exports.aura_ui:uiDrawText("Banka bakiyenizden tek tıkla nakit çekin.", contentX + 14, secTitleY + 20, contentX + contentW, secTitleY + 36, tocolor(148, 163, 184, math.floor(180 * alphaMult)), 1, fontSmall, "left", "center")

        local gridX = contentX + 14
        local gridY = secTitleY + 44
        local gridW = contentW - 28
        local colW = (gridW - 16) / 3
        local rowH = 56
        local rowGap = 12

        for i, val in ipairs(ATMConfig.QuickWithdrawAmounts) do
            local col = (i - 1) % 3
            local row = math.floor((i - 1) / 3)
            local btnX = gridX + col * (colW + 8)
            local btnY = gridY + row * (rowH + rowGap)

            local canAfford = (atmData.bank >= val)
            local isBtnHov = canAfford and isMouseInPosition(btnX, btnY, colW, rowH)

            local btnBg = isBtnHov and tocolor(56, 189, 248, math.floor(220 * alphaMult)) or (canAfford and tocolor(15, 23, 42, math.floor(200 * alphaMult)) or tocolor(15, 23, 42, math.floor(90 * alphaMult)))
            local textCol = isBtnHov and tocolor(15, 23, 42, globalAlpha) or (canAfford and tocolor(255, 255, 255, globalAlpha) or tocolor(100, 116, 139, math.floor(150 * alphaMult)))

            if exports.gzl_ui and exports.gzl_ui.drawRoundedRectangle then
                exports.gzl_ui:drawRoundedRectangle(btnX, btnY, colW, rowH, 8, btnBg)
                if canAfford and not isBtnHov then
                    exports.gzl_ui:drawRoundedBorder(btnX, btnY, colW, rowH, 8, 1.0, tocolor(51, 65, 85, math.floor(120 * alphaMult)))
                end
            else
                exports.aura_ui:uiDrawRectangle(btnX, btnY, colW, rowH, btnBg)
            end

            exports.aura_ui:uiDrawText("$" .. formatMoney(val), btnX, btnY + 8, btnX + colW, btnY + 30, textCol, 1, fontTitle, "center", "center")
            exports.aura_ui:uiDrawText("Nakit Çek", btnX, btnY + 28, btnX + colW, btnY + 48, isBtnHov and tocolor(15, 23, 42, math.floor(200 * alphaMult)) or tocolor(148, 163, 184, math.floor(180 * alphaMult)), 1, fontSmall, "center", "center")
        end

    elseif activeTab == 2 then
        local cardW = contentW - 28
        local cardH = 74
        local cardX = contentX + 14
        local cardY = contentY + 16

        if exports.gzl_ui and exports.gzl_ui.drawRoundedRectangle then
            exports.gzl_ui:drawRoundedRectangle(cardX, cardY, cardW, cardH, 10, tocolor(15, 23, 42, math.floor(200 * alphaMult)))
            exports.gzl_ui:drawRoundedBorder(cardX, cardY, cardW, cardH, 10, 1.0, tocolor(56, 189, 248, math.floor(90 * alphaMult)))
        else
            exports.aura_ui:uiDrawRectangle(cardX, cardY, cardW, cardH, tocolor(15, 23, 42, math.floor(200 * alphaMult)))
        end
        exports.aura_ui:uiDrawText("ÇEKİLEBİLİR BANKA BAKİYESİ", cardX + 14, cardY + 12, cardX + cardW - 14, cardY + 28, tocolor(148, 163, 184, math.floor(220 * alphaMult)), 1, fontSmall, "left", "center")
        exports.aura_ui:uiDrawText("$" .. formatMoney(atmData.bank), cardX + 14, cardY + 32, cardX + cardW - 14, cardY + 66, tocolor(56, 189, 248, globalAlpha), 1, fontLarge, "left", "center")

        local inputY = cardY + cardH + 24
        exports.aura_ui:uiDrawText("ÇEKİLECEK TUTAR ($)", cardX, inputY, cardX + cardW, inputY + 18, tocolor(255, 255, 255, globalAlpha), 1, fontBold, "left", "center")

        local inputH = 46
        drawCustomEditBox("withdraw_amount", cardX, inputY + 24, cardW, inputH, "Tutar girin... (örn. 500)", fontMedium, fontSmall)

        local pctY = inputY + 24 + inputH + 14
        local pctW = (cardW - 24) / 4
        local pctH = 34
        local pctOptions = {
            { label = "%25", val = math.floor(atmData.bank * 0.25) },
            { label = "%50", val = math.floor(atmData.bank * 0.50) },
            { label = "%75", val = math.floor(atmData.bank * 0.75) },
            { label = "Tümü", val = atmData.bank }
        }

        for i, opt in ipairs(pctOptions) do
            local pX = cardX + (i - 1) * (pctW + 8)
            local isPctHov = isMouseInPosition(pX, pctY, pctW, pctH)
            local pBg = isPctHov and tocolor(56, 189, 248, math.floor(180 * alphaMult)) or tocolor(15, 23, 42, math.floor(160 * alphaMult))

            if exports.gzl_ui and exports.gzl_ui.drawRoundedRectangle then
                exports.gzl_ui:drawRoundedRectangle(pX, pctY, pctW, pctH, 6, pBg)
                exports.gzl_ui:drawRoundedBorder(pX, pctY, pctW, pctH, 6, 1.0, tocolor(51, 65, 85, math.floor(120 * alphaMult)))
            else
                exports.aura_ui:uiDrawRectangle(pX, pctY, pctW, pctH, pBg)
            end
            exports.aura_ui:uiDrawText(opt.label, pX, pctY, pX + pctW, pctY + pctH, tocolor(255, 255, 255, globalAlpha), 1, fontBold, "center", "center")
        end

        local actBtnY = pctY + pctH + 24
        local actBtnH = 48
        local withdrawVal = tonumber(editFields.withdraw_amount) or 0
        local canWithdraw = (withdrawVal > 0 and withdrawVal <= atmData.bank)
        local isActHov = canWithdraw and isMouseInPosition(cardX, actBtnY, cardW, actBtnH)
        local actBg = isActHov and tocolor(56, 189, 248, math.floor(240 * alphaMult)) or (canWithdraw and tocolor(14, 165, 233, math.floor(220 * alphaMult)) or tocolor(51, 65, 85, math.floor(140 * alphaMult)))

        if exports.gzl_ui and exports.gzl_ui.drawRoundedRectangle then
            exports.gzl_ui:drawRoundedRectangle(cardX, actBtnY, cardW, actBtnH, 8, actBg)
        else
            exports.aura_ui:uiDrawRectangle(cardX, actBtnY, cardW, actBtnH, actBg)
        end
        exports.aura_ui:uiDrawText("PARAYI ÇEK", cardX, actBtnY, cardX + cardW, actBtnY + actBtnH, canWithdraw and tocolor(15, 23, 42, globalAlpha) or tocolor(148, 163, 184, math.floor(160 * alphaMult)), 1, fontTitle, "center", "center")

    elseif activeTab == 3 then
        local cardW = contentW - 28
        local cardH = 74
        local cardX = contentX + 14
        local cardY = contentY + 16

        if exports.gzl_ui and exports.gzl_ui.drawRoundedRectangle then
            exports.gzl_ui:drawRoundedRectangle(cardX, cardY, cardW, cardH, 10, tocolor(15, 23, 42, math.floor(200 * alphaMult)))
            exports.gzl_ui:drawRoundedBorder(cardX, cardY, cardW, cardH, 10, 1.0, tocolor(52, 211, 153, math.floor(90 * alphaMult)))
        else
            exports.aura_ui:uiDrawRectangle(cardX, cardY, cardW, cardH, tocolor(15, 23, 42, math.floor(200 * alphaMult)))
        end
        exports.aura_ui:uiDrawText("YATIRILABİLİR CÜZDAN NAKİTİ", cardX + 14, cardY + 12, cardX + cardW - 14, cardY + 28, tocolor(148, 163, 184, math.floor(220 * alphaMult)), 1, fontSmall, "left", "center")
        exports.aura_ui:uiDrawText("$" .. formatMoney(atmData.cash), cardX + 14, cardY + 32, cardX + cardW - 14, cardY + 66, tocolor(52, 211, 153, globalAlpha), 1, fontLarge, "left", "center")

        local inputY = cardY + cardH + 24
        exports.aura_ui:uiDrawText("YATIRILACAK TUTAR ($)", cardX, inputY, cardX + cardW, inputY + 18, tocolor(255, 255, 255, globalAlpha), 1, fontBold, "left", "center")

        local inputH = 46
        drawCustomEditBox("deposit_amount", cardX, inputY + 24, cardW, inputH, "Tutar girin... (örn. 500)", fontMedium, fontSmall)

        local pctY = inputY + 24 + inputH + 14
        local pctW = (cardW - 24) / 4
        local pctH = 34
        local pctOptions = {
            { label = "%25", val = math.floor(atmData.cash * 0.25) },
            { label = "%50", val = math.floor(atmData.cash * 0.50) },
            { label = "%75", val = math.floor(atmData.cash * 0.75) },
            { label = "Tümü", val = atmData.cash }
        }

        for i, opt in ipairs(pctOptions) do
            local pX = cardX + (i - 1) * (pctW + 8)
            local isPctHov = isMouseInPosition(pX, pctY, pctW, pctH)
            local pBg = isPctHov and tocolor(52, 211, 153, math.floor(180 * alphaMult)) or tocolor(15, 23, 42, math.floor(160 * alphaMult))

            if exports.gzl_ui and exports.gzl_ui.drawRoundedRectangle then
                exports.gzl_ui:drawRoundedRectangle(pX, pctY, pctW, pctH, 6, pBg)
                exports.gzl_ui:drawRoundedBorder(pX, pctY, pctW, pctH, 6, 1.0, tocolor(51, 65, 85, math.floor(120 * alphaMult)))
            else
                exports.aura_ui:uiDrawRectangle(pX, pctY, pctW, pctH, pBg)
            end
            exports.aura_ui:uiDrawText(opt.label, pX, pctY, pX + pctW, pctY + pctH, tocolor(255, 255, 255, globalAlpha), 1, fontBold, "center", "center")
        end

        local actBtnY = pctY + pctH + 24
        local actBtnH = 48
        local depositVal = tonumber(editFields.deposit_amount) or 0
        local canDeposit = (depositVal > 0 and depositVal <= atmData.cash)
        local isActHov = canDeposit and isMouseInPosition(cardX, actBtnY, cardW, actBtnH)
        local actBg = isActHov and tocolor(52, 211, 153, math.floor(240 * alphaMult)) or (canDeposit and tocolor(16, 185, 129, math.floor(220 * alphaMult)) or tocolor(51, 65, 85, math.floor(140 * alphaMult)))

        if exports.gzl_ui and exports.gzl_ui.drawRoundedRectangle then
            exports.gzl_ui:drawRoundedRectangle(cardX, actBtnY, cardW, actBtnH, 8, actBg)
        else
            exports.aura_ui:uiDrawRectangle(cardX, actBtnY, cardW, actBtnH, actBg)
        end
        exports.aura_ui:uiDrawText("PARAYI YATIR", cardX, actBtnY, cardX + cardW, actBtnY + actBtnH, canDeposit and tocolor(15, 23, 42, globalAlpha) or tocolor(148, 163, 184, math.floor(160 * alphaMult)), 1, fontTitle, "center", "center")

    elseif activeTab == 4 then
        local formW = contentW - 28
        local formX = contentX + 14
        local formY = contentY + 16

        exports.aura_ui:uiDrawText("HAVALE / EFT İŞLEMİ", formX, formY, formX + formW, formY + 20, tocolor(255, 255, 255, globalAlpha), 1, fontTitle, "left", "center")
        exports.aura_ui:uiDrawText("Banka bakiyeniz: $" .. formatMoney(atmData.bank), formX, formY + 20, formX + formW, formY + 36, tocolor(56, 189, 248, math.floor(200 * alphaMult)), 1, fontSmall, "left", "center")

        local f1Y = formY + 44
        exports.aura_ui:uiDrawText("ALICI HESAP (Karakter Adı veya Oyuncu ID)", formX, f1Y, formX + formW, f1Y + 16, tocolor(148, 163, 184, math.floor(220 * alphaMult)), 1, fontSmall, "left", "center")
        drawCustomEditBox("transfer_target", formX, f1Y + 20, formW, 42, "Örn: 1 veya Thommy_Souverain", fontMedium, fontSmall)

        local f2Y = f1Y + 70
        exports.aura_ui:uiDrawText("GÖNDERİLECEK TUTAR ($)", formX, f2Y, formX + formW, f2Y + 16, tocolor(148, 163, 184, math.floor(220 * alphaMult)), 1, fontSmall, "left", "center")
        drawCustomEditBox("transfer_amount", formX, f2Y + 20, formW, 42, "Örn: 1000", fontMedium, fontSmall)

        local f3Y = f2Y + 70
        exports.aura_ui:uiDrawText("AÇIKLAMA", formX, f3Y, formX + formW, f3Y + 16, tocolor(148, 163, 184, math.floor(220 * alphaMult)), 1, fontSmall, "left", "center")
        drawCustomEditBox("transfer_note", formX, f3Y + 20, formW, 42, "Örn: Araç borcu / Ticaret", fontMedium, fontSmall)

        local sendBtnY = f3Y + 72
        local sendBtnH = 46
        local tAmount = tonumber(editFields.transfer_amount) or 0
        local hasTarget = (string.len(editFields.transfer_target) > 0)
        local canSend = (hasTarget and tAmount > 0 and tAmount <= atmData.bank)
        local isSendHov = canSend and isMouseInPosition(formX, sendBtnY, formW, sendBtnH)
        local sendBg = isSendHov and tocolor(56, 189, 248, math.floor(240 * alphaMult)) or (canSend and tocolor(14, 165, 233, math.floor(220 * alphaMult)) or tocolor(51, 65, 85, math.floor(140 * alphaMult)))

        if exports.gzl_ui and exports.gzl_ui.drawRoundedRectangle then
            exports.gzl_ui:drawRoundedRectangle(formX, sendBtnY, formW, sendBtnH, 8, sendBg)
        else
            exports.aura_ui:uiDrawRectangle(formX, sendBtnY, formW, sendBtnH, sendBg)
        end
        exports.aura_ui:uiDrawText("HAVALEYİ ONAYLA VE GÖNDER", formX, sendBtnY, formX + formW, sendBtnY + sendBtnH, canSend and tocolor(15, 23, 42, globalAlpha) or tocolor(148, 163, 184, math.floor(160 * alphaMult)), 1, fontTitle, "center", "center")

    elseif activeTab == 5 then
        local listX = contentX + 14
        local listY = contentY + 16
        local listW = contentW - 28
        local listH = contentH - 32

        exports.aura_ui:uiDrawText("SON HESAP HAREKETLERİ", listX, listY, listX + listW, listY + 20, tocolor(255, 255, 255, globalAlpha), 1, fontTitle, "left", "center")
        exports.aura_ui:uiDrawText("Hesabınıza ait en son 10 adet dekont ve işlem kaydı.", listX, listY + 20, listX + listW, listY + 36, tocolor(148, 163, 184, math.floor(180 * alphaMult)), 1, fontSmall, "left", "center")

        local tableHeaderY = listY + 44
        local thH = 26
        if exports.gzl_ui and exports.gzl_ui.drawRoundedRectangle then
            exports.gzl_ui:drawRoundedRectangle(listX, tableHeaderY, listW, thH, 6, tocolor(15, 23, 42, math.floor(180 * alphaMult)))
        else
            exports.aura_ui:uiDrawRectangle(listX, tableHeaderY, listW, thH, tocolor(15, 23, 42, math.floor(180 * alphaMult)))
        end

        exports.aura_ui:uiDrawText("TÜR", listX + 10, tableHeaderY, listX + 110, tableHeaderY + thH, tocolor(148, 163, 184, math.floor(220 * alphaMult)), 1, fontSmall, "left", "center")
        exports.aura_ui:uiDrawText("AÇIKLAMA", listX + 115, tableHeaderY, listX + listW - 190, tableHeaderY + thH, tocolor(148, 163, 184, math.floor(220 * alphaMult)), 1, fontSmall, "left", "center")
        exports.aura_ui:uiDrawText("TUTAR", listX + listW - 180, tableHeaderY, listX + listW - 90, tableHeaderY + thH, tocolor(148, 163, 184, math.floor(220 * alphaMult)), 1, fontSmall, "right", "center")
        exports.aura_ui:uiDrawText("BAKİYE", listX + listW - 80, tableHeaderY, listX + listW - 10, tableHeaderY + thH, tocolor(148, 163, 184, math.floor(220 * alphaMult)), 1, fontSmall, "right", "center")

        local rowStartY = tableHeaderY + thH + 6
        local rowH = 28
        local rowGap = 4
        local txs = atmData.transactions or {}

        if #txs == 0 then
            exports.aura_ui:uiDrawText("Henüz herhangi bir hesap hareketi bulunmuyor.", listX, rowStartY + 30, listX + listW, rowStartY + 60, tocolor(100, 116, 139, math.floor(180 * alphaMult)), 1, fontMedium, "center", "center")
        else
            for idx, tx in ipairs(txs) do
                local curRowY = rowStartY + (idx - 1) * (rowH + rowGap)
                if curRowY + rowH <= contentY + contentH - 10 then
                    local isPositive = (tx.type == "deposit" or tx.type == "transfer_in")
                    local amountColor = isPositive and tocolor(52, 211, 153, globalAlpha) or tocolor(239, 68, 68, globalAlpha)
                    local amountPrefix = isPositive and "+$" or "-$"

                    local typeLabel = "İşlem"
                    if tx.type == "withdraw" then typeLabel = "Nakit Çekim"
                    elseif tx.type == "deposit" then typeLabel = "Nakit Yatırma"
                    elseif tx.type == "transfer_out" then typeLabel = "Giden Havale"
                    elseif tx.type == "transfer_in" then typeLabel = "Gelen Havale"
                    end

                    local rBg = (idx % 2 == 1) and tocolor(15, 23, 42, math.floor(140 * alphaMult)) or tocolor(15, 23, 42, math.floor(80 * alphaMult))
                    if exports.gzl_ui and exports.gzl_ui.drawRoundedRectangle then
                        exports.gzl_ui:drawRoundedRectangle(listX, curRowY, listW, rowH, 4, rBg)
                    else
                        exports.aura_ui:uiDrawRectangle(listX, curRowY, listW, rowH, rBg)
                    end

                    exports.aura_ui:uiDrawText(typeLabel, listX + 10, curRowY, listX + 110, curRowY + rowH, tocolor(255, 255, 255, math.floor(230 * alphaMult)), 1, fontSmall, "left", "center", true)
                    exports.aura_ui:uiDrawText(tostring(tx.note or "-"), listX + 115, curRowY, listX + listW - 190, curRowY + rowH, tocolor(148, 163, 184, math.floor(200 * alphaMult)), 1, fontSmall, "left", "center", true)
                    exports.aura_ui:uiDrawText(amountPrefix .. formatMoney(tx.amount), listX + listW - 180, curRowY, listX + listW - 90, curRowY + rowH, amountColor, 1, fontBold, "right", "center")
                    exports.aura_ui:uiDrawText("$" .. formatMoney(tx.balance_after), listX + listW - 80, curRowY, listX + listW - 10, curRowY + rowH, tocolor(203, 213, 225, math.floor(220 * alphaMult)), 1, fontSmall, "right", "center")
                end
            end
        end
    end
end)

addEventHandler("onClientClick", root, function(button, state)
    if not isOpen or state ~= "down" or button ~= "left" then return end

    local panelW = 760
    local panelH = 490
    local panelX = (screenW - panelW) / 2
    local panelY = (screenH - panelH) / 2
    local headerH = 62

    local closeBtnX = panelX + panelW - 44
    local closeBtnY = panelY + 14
    local closeBtnSize = 34
    if isMouseInPosition(closeBtnX, closeBtnY, closeBtnSize, closeBtnSize) then
        playSoundFrontEnd(41)
        closeATM()
        return
    end

    local navX = panelX + 16
    local navY = panelY + headerH + 16
    local navW = 165
    local navItemH = 44
    local navGap = 8

    for i, tab in ipairs(tabs) do
        local tabY = navY + (i - 1) * (navItemH + navGap)
        if isMouseInPosition(navX, tabY, navW, navItemH) then
            if activeTab ~= tab.id then
                playSoundFrontEnd(41)
                activeTab = tab.id
                setActiveField(nil)
            end
            return
        end
    end

    local contentX = panelX + navW + 30
    local contentY = navY
    local contentW = panelW - navW - 46
    local contentH = panelH - headerH - 32

    if activeTab == 1 then
        local cardH = 88
        local secTitleY = contentY + 16 + cardH + 18
        local gridX = contentX + 14
        local gridY = secTitleY + 44
        local gridW = contentW - 28
        local colW = (gridW - 16) / 3
        local rowH = 56
        local rowGap = 12

        for i, val in ipairs(ATMConfig.QuickWithdrawAmounts) do
            local col = (i - 1) % 3
            local row = math.floor((i - 1) / 3)
            local btnX = gridX + col * (colW + 8)
            local btnY = gridY + row * (rowH + rowGap)

            if isMouseInPosition(btnX, btnY, colW, rowH) then
                if atmData.bank >= val then
                    playSoundFrontEnd(41)
                    triggerServerEvent("atm:withdraw", resourceRoot, val)
                else
                    playSoundFrontEnd(42)
                    if exports.gzl_ui and exports.gzl_ui.showToast then
                        exports.gzl_ui:showToast("Yetersiz Bakiye", "Banka hesabınızda yeterli bakiye yok!", "error")
                    end
                end
                return
            end
        end

    elseif activeTab == 2 then
        local cardW = contentW - 28
        local cardX = contentX + 14
        local cardY = contentY + 16
        local cardH = 74
        local inputY = cardY + cardH + 24
        local inputH = 46

        if isMouseInPosition(cardX, inputY + 24, cardW, inputH) then
            setActiveField("withdraw_amount")
            return
        end

        local pctY = inputY + 24 + inputH + 14
        local pctW = (cardW - 24) / 4
        local pctH = 34
        local pctOptions = {
            { label = "%25", val = math.floor(atmData.bank * 0.25) },
            { label = "%50", val = math.floor(atmData.bank * 0.50) },
            { label = "%75", val = math.floor(atmData.bank * 0.75) },
            { label = "Tümü", val = atmData.bank }
        }

        for i, opt in ipairs(pctOptions) do
            local pX = cardX + (i - 1) * (pctW + 8)
            if isMouseInPosition(pX, pctY, pctW, pctH) then
                playSoundFrontEnd(41)
                editFields.withdraw_amount = tostring(math.max(0, opt.val))
                return
            end
        end

        local actBtnY = pctY + pctH + 24
        local actBtnH = 48
        if isMouseInPosition(cardX, actBtnY, cardW, actBtnH) then
            local val = tonumber(editFields.withdraw_amount) or 0
            if val > 0 and val <= atmData.bank then
                playSoundFrontEnd(41)
                triggerServerEvent("atm:withdraw", resourceRoot, val)
                editFields.withdraw_amount = ""
                setActiveField(nil)
            else
                playSoundFrontEnd(42)
            end
            return
        end

    elseif activeTab == 3 then
        local cardW = contentW - 28
        local cardX = contentX + 14
        local cardY = contentY + 16
        local cardH = 74
        local inputY = cardY + cardH + 24
        local inputH = 46

        if isMouseInPosition(cardX, inputY + 24, cardW, inputH) then
            setActiveField("deposit_amount")
            return
        end

        local pctY = inputY + 24 + inputH + 14
        local pctW = (cardW - 24) / 4
        local pctH = 34
        local pctOptions = {
            { label = "%25", val = math.floor(atmData.cash * 0.25) },
            { label = "%50", val = math.floor(atmData.cash * 0.50) },
            { label = "%75", val = math.floor(atmData.cash * 0.75) },
            { label = "Tümü", val = atmData.cash }
        }

        for i, opt in ipairs(pctOptions) do
            local pX = cardX + (i - 1) * (pctW + 8)
            if isMouseInPosition(pX, pctY, pctW, pctH) then
                playSoundFrontEnd(41)
                editFields.deposit_amount = tostring(math.max(0, opt.val))
                return
            end
        end

        local actBtnY = pctY + pctH + 24
        local actBtnH = 48
        if isMouseInPosition(cardX, actBtnY, cardW, actBtnH) then
            local val = tonumber(editFields.deposit_amount) or 0
            if val > 0 and val <= atmData.cash then
                playSoundFrontEnd(41)
                triggerServerEvent("atm:deposit", resourceRoot, val)
                editFields.deposit_amount = ""
                setActiveField(nil)
            else
                playSoundFrontEnd(42)
            end
            return
        end

    elseif activeTab == 4 then
        local formW = contentW - 28
        local formX = contentX + 14
        local formY = contentY + 16
        local f1Y = formY + 44
        local f2Y = f1Y + 70
        local f3Y = f2Y + 70

        if isMouseInPosition(formX, f1Y + 20, formW, 42) then
            setActiveField("transfer_target")
            return
        elseif isMouseInPosition(formX, f2Y + 20, formW, 42) then
            setActiveField("transfer_amount")
            return
        elseif isMouseInPosition(formX, f3Y + 20, formW, 42) then
            setActiveField("transfer_note")
            return
        end

        local sendBtnY = f3Y + 72
        local sendBtnH = 46
        if isMouseInPosition(formX, sendBtnY, formW, sendBtnH) then
            local tTarget = editFields.transfer_target
            local tAmount = tonumber(editFields.transfer_amount) or 0
            local tNote = editFields.transfer_note
            if string.len(tTarget) > 0 and tAmount > 0 and tAmount <= atmData.bank then
                playSoundFrontEnd(41)
                triggerServerEvent("atm:transfer", resourceRoot, tTarget, tAmount, tNote)
                editFields.transfer_target = ""
                editFields.transfer_amount = ""
                editFields.transfer_note = ""
                setActiveField(nil)
            else
                playSoundFrontEnd(42)
            end
            return
        end
    end

    setActiveField(nil)
end)