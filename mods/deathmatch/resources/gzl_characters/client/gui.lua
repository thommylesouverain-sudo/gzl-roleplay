local screenW, screenH = guiGetScreenSize()
local isVisible = false
local currentMode = "select"
local characterList = {}
local selectedSlot = nil
local lastClickSlot = nil
local lastClickTick = 0
local createGender = 1
local createSkinIndex = 1
local targetSlot = 1
local isProcessing = false
local fonts = nil
local fontTimer = nil

local hudComponents = {"all", "radar", "area_name", "vehicle_name", "breath", "clock", "money", "health", "armour", "weapon", "ammo"}

local layout = {
    scale = 1,
    drawX = 0,
    leftX = 0,
    leftY = 0,
    leftW = 0,
    rowX = 0,
    rowY = 0,
    rowW = 0,
    rowH = 0,
    rowGap = 0,
    logoutY = 0,
    actionX = 0,
    actionY = 0,
    actionW = 0,
    actionH = 0,
    creatorX = 0,
    creatorY = 0,
    creatorW = 0,
    creatorH = 0,
    creatorFormX = 0,
    creatorFormW = 0,
    nameLabelY = 0,
    nameBoxY = 0,
    genderLabelY = 0,
    genderTabY = 0,
    ageLabelY = 0,
    ageBoxY = 0,
    skinLabelY = 0,
    skinSelectorY = 0,
    submitY = 0,
    backY = 0
}

local nameOptions = {placeholder = "Ad Soyad", icon = "user", radius = 9, maxChars = 26}
local ageOptions = {placeholder = "24", defaultText = "24", radius = 9, maxChars = 2}
local selectActionOptions = {theme = "blue", icon = "check", radius = 9, disabled = false}
local createActionOptions = {theme = "blue", icon = "user", radius = 9, disabled = false}
local logoutOptions = {theme = "blue", icon = "logout", radius = 9, disabled = false}
local backOptions = {theme = "blue", icon = "arrow-left", radius = 9, disabled = false}

local requiredUIExports = {
    "getFont",
    "getAnimProgress",
    "resetAnimProgress",
    "drawRoundedRectangle",
    "drawGlassPanel",
    "drawDiagonalTabBarSVG",
    "drawIconSVG",
    "drawGlassButton",
    "drawGlassEditBox",
    "isMouseInPosition",
    "setActiveEditBox",
    "getEditBoxText",
    "setEditBoxText",
    "showNotification"
}

local function isUIReady()
    local resource = getResourceFromName("gzl_ui")
    if not resource or getResourceState(resource) ~= "running" or not exports.gzl_ui then
        return false
    end
    for i = 1, #requiredUIExports do
        if not exports.gzl_ui[requiredUIExports[i]] then
            return false
        end
    end
    return true
end

local function getSkinList(gender)
    if type(CharConfig) ~= "table" then
        return gender == 1 and {0} or {9}
    end
    return gender == 1 and CharConfig.MaleSkins or CharConfig.FemaleSkins
end

local function getCharacterInSlot(slot)
    if not slot then
        return nil
    end
    return characterList and characterList[slot] or nil
end

local function updateLayout()
    local scale = math.min(screenW / 1920, screenH / 1080)
    scale = math.max(0.78, math.min(1.18, scale))
    local leftX = math.max(34, 54 * scale)
    local leftY = math.max(28, 48 * scale)
    local leftW = 380 * scale
    local rowInset = 30 * scale
    local creatorH = 650 * scale

    layout.scale = scale
    layout.leftX = leftX
    layout.leftY = leftY
    layout.leftW = leftW
    layout.drawX = leftX
    layout.rowX = leftX + rowInset
    layout.rowY = leftY + 168 * scale
    layout.rowW = leftW - rowInset * 2
    layout.rowH = 58 * scale
    layout.rowGap = 8 * scale
    layout.logoutY = leftY + 522 * scale
    layout.actionW = 250 * scale
    layout.actionH = 44 * scale
    layout.actionX = screenW - layout.actionW - 52 * scale
    layout.actionY = screenH - layout.actionH - 42 * scale
    layout.creatorW = 430 * scale
    layout.creatorH = creatorH
    layout.creatorX = leftX
    layout.creatorY = math.max(24, (screenH - creatorH) / 2)
    layout.creatorFormX = leftX + 30 * scale
    layout.creatorFormW = layout.creatorW - 60 * scale
    layout.nameLabelY = layout.creatorY + 176 * scale
    layout.nameBoxY = layout.creatorY + 198 * scale
    layout.genderLabelY = layout.creatorY + 266 * scale
    layout.genderTabY = layout.creatorY + 288 * scale
    layout.ageLabelY = layout.creatorY + 350 * scale
    layout.ageBoxY = layout.creatorY + 372 * scale
    layout.skinLabelY = layout.creatorY + 440 * scale
    layout.skinSelectorY = layout.creatorY + 462 * scale
    layout.submitY = layout.creatorY + 536 * scale
    layout.backY = layout.creatorY + 590 * scale
end

local function prepareFonts()
    if fonts or not isUIReady() then
        return fonts ~= nil
    end

    local scale = layout.scale
    fonts = {
        display = exports.gzl_ui:getFont("heavy", math.max(21, math.floor(28 * scale))),
        displaySub = exports.gzl_ui:getFont("medium", math.max(10, math.floor(12 * scale))),
        section = exports.gzl_ui:getFont("bold", math.max(9, math.floor(10 * scale))),
        rowTitle = exports.gzl_ui:getFont("bold", math.max(10, math.floor(11 * scale))),
        rowMeta = exports.gzl_ui:getFont("medium", math.max(8, math.floor(9 * scale))),
        label = exports.gzl_ui:getFont("semibold", math.max(8, math.floor(9 * scale))),
        input = exports.gzl_ui:getFont("regular", math.max(9, math.floor(10 * scale))),
        button = exports.gzl_ui:getFont("bold", math.max(9, math.floor(10 * scale))),
        body = exports.gzl_ui:getFont("medium", math.max(9, math.floor(10 * scale))),
        creatorTitle = exports.gzl_ui:getFont("heavy", math.max(19, math.floor(24 * scale)))
    }

    nameOptions.font = fonts.input
    ageOptions.font = fonts.input
    selectActionOptions.font = fonts.button
    createActionOptions.font = fonts.button
    logoutOptions.font = fonts.button
    backOptions.font = fonts.button
    return true
end

local function queueFontPreparation()
    if fonts or isTimer(fontTimer) then
        return
    end
    fontTimer = setTimer(function()
        if prepareFonts() and isTimer(fontTimer) then
            killTimer(fontTimer)
            fontTimer = nil
        end
    end, 250, 20)
end

local function drawBackdrop(alpha)
    local scale = layout.scale
    exports.gzl_ui:drawRoundedRectangle(0, 0, screenW, screenH, 8, tocolor(5, 9, 16, math.floor(72 * alpha)))
    exports.gzl_ui:drawRoundedRectangle(0, 0, math.min(screenW, 610 * scale), screenH, 8, tocolor(6, 10, 18, math.floor(132 * alpha)))
    exports.gzl_ui:drawRoundedRectangle(0, 0, math.min(screenW, 940 * scale), screenH, 8, tocolor(7, 12, 20, math.floor(42 * alpha)))
end

local function drawBrand(x, y, alpha)
    local scale = layout.scale
    local markW = 5 * scale
    local markH = 52 * scale
    exports.gzl_ui:drawRoundedRectangle(x, y, markW, markH, 3 * scale, tocolor(95, 168, 255, math.floor(245 * alpha)))
    exports.aura_ui:uiDrawText("#5FA8FFKARAKTER", x + 24 * scale, y - 7 * scale, x + layout.leftW, y + 29 * scale, tocolor(244, 247, 252, math.floor(255 * alpha)), 1, fonts.display, "left", "center", false, false, false, true)
    exports.aura_ui:uiDrawText("S E Ç İ M İ", x + 26 * scale, y + 29 * scale, x + layout.leftW, y + 52 * scale, tocolor(225, 232, 243, math.floor(235 * alpha)), 1, fonts.displaySub, "left", "center")
end

local function drawSlotRow(slot, x, y, alpha)
    local scale = layout.scale
    local rowW = layout.rowW
    local rowH = layout.rowH
    local charData = characterList[slot]
    local selected = selectedSlot == slot
    local hovered = exports.gzl_ui:isMouseInPosition(x, y, rowW, rowH)
    local hoverProgress = exports.gzl_ui:getAnimProgress("char_row_hover_" .. slot, hovered and 1 or 0, 0.18)
    local inset = selected and 2 * scale or 0

    if selected then
        exports.gzl_ui:drawRoundedRectangle(x, y, rowW, rowH, 9 * scale, tocolor(95, 168, 255, math.floor(225 * alpha)))
    end

    local rowColor
    if selected then
        rowColor = tocolor(17, 28, 45, math.floor(242 * alpha))
    elseif hovered then
        rowColor = tocolor(20, 29, 43, math.floor((210 + 28 * hoverProgress) * alpha))
    else
        rowColor = tocolor(14, 20, 31, math.floor(196 * alpha))
    end
    exports.gzl_ui:drawRoundedRectangle(x + inset, y + inset, rowW - inset * 2, rowH - inset * 2, 8 * scale, rowColor)

    local iconBox = 38 * scale
    local iconX = x + 12 * scale
    local iconY = y + (rowH - iconBox) / 2
    exports.gzl_ui:drawRoundedRectangle(iconX, iconY, iconBox, iconBox, 8 * scale, selected and tocolor(40, 91, 153, math.floor(220 * alpha)) or tocolor(28, 37, 51, math.floor(205 * alpha)))

    if charData then
        exports.gzl_ui:drawIconSVG("user", iconX + 9 * scale, iconY + 9 * scale, 20 * scale, tocolor(221, 232, 247, math.floor(245 * alpha)))
        local cleanName = tostring(charData.name or "Karakter"):gsub("_", " ")
        local genderText = tonumber(charData.gender) == 2 and "Kadın" or "Erkek"
        local metaText = tostring(charData.age or 24) .. " yaş  " .. genderText
        exports.aura_ui:uiDrawText(cleanName, x + 62 * scale, y + 9 * scale, x + rowW - 38 * scale, y + 31 * scale, tocolor(238, 243, 251, math.floor(250 * alpha)), 1, fonts.rowTitle, "left", "center", true)
        exports.aura_ui:uiDrawText(metaText, x + 62 * scale, y + 31 * scale, x + rowW - 38 * scale, y + 49 * scale, tocolor(142, 159, 181, math.floor(220 * alpha)), 1, fonts.rowMeta, "left", "center", true)
        if selected then
            exports.gzl_ui:drawIconSVG("check", x + rowW - 26 * scale, y + (rowH - 14 * scale) / 2, 14 * scale, tocolor(95, 168, 255, math.floor(255 * alpha)))
        end
    else
        exports.aura_ui:uiDrawText("+", iconX, iconY - 1 * scale, iconX + iconBox, iconY + iconBox, selected and tocolor(95, 168, 255, math.floor(255 * alpha)) or tocolor(127, 146, 170, math.floor(220 * alpha)), 1, fonts.displaySub, "center", "center")
        exports.aura_ui:uiDrawText("BOŞ SLOT", x + 62 * scale, y + 8 * scale, x + rowW - 18 * scale, y + 31 * scale, tocolor(208, 219, 234, math.floor(235 * alpha)), 1, fonts.rowTitle, "left", "center")
        exports.aura_ui:uiDrawText("Yeni karakter oluştur", x + 62 * scale, y + 31 * scale, x + rowW - 18 * scale, y + 49 * scale, tocolor(134, 151, 175, math.floor(205 * alpha)), 1, fonts.rowMeta, "left", "center")
    end
end

local function drawSelection(alpha)
    local scale = layout.scale
    local x = layout.drawX
    local y = layout.leftY
    local rowX = x + 30 * scale

    drawBrand(x, y, alpha)
    exports.aura_ui:uiDrawText("KARAKTERLERİN", rowX, y + 112 * scale, rowX + layout.rowW, y + 134 * scale, tocolor(229, 236, 246, math.floor(245 * alpha)), 1, fonts.section, "left", "center")

    for slot = 1, 5 do
        drawSlotRow(slot, rowX, layout.rowY + (slot - 1) * (layout.rowH + layout.rowGap), alpha)
    end

    local logoutW = 174 * scale
    exports.gzl_ui:drawGlassButton("character_logout", "GİRİŞE DÖN", rowX, layout.logoutY, logoutW, 38 * scale, logoutOptions)

    local selectedCharacter = getCharacterInSlot(selectedSlot)
    local actionText = selectedCharacter and "KARAKTERE GİR" or "KARAKTER OLUŞTUR"
    local actionOptions = selectedCharacter and selectActionOptions or createActionOptions
    exports.gzl_ui:drawGlassButton("character_primary_action", actionText, layout.actionX, layout.actionY, layout.actionW, layout.actionH, actionOptions)

    if selectedCharacter then
        local cleanName = tostring(selectedCharacter.name or "Karakter"):gsub("_", " ")
        exports.aura_ui:uiDrawText(cleanName, layout.actionX, layout.actionY - 48 * scale, layout.actionX + layout.actionW, layout.actionY - 24 * scale, tocolor(239, 245, 253, math.floor(250 * alpha)), 1, fonts.rowTitle, "right", "center")
        exports.aura_ui:uiDrawText("Seçili karakter", layout.actionX, layout.actionY - 27 * scale, layout.actionX + layout.actionW, layout.actionY - 8 * scale, tocolor(147, 164, 187, math.floor(215 * alpha)), 1, fonts.rowMeta, "right", "center")
    else
        exports.aura_ui:uiDrawText("Slot " .. tostring(selectedSlot or 1), layout.actionX, layout.actionY - 48 * scale, layout.actionX + layout.actionW, layout.actionY - 24 * scale, tocolor(239, 245, 253, math.floor(250 * alpha)), 1, fonts.rowTitle, "right", "center")
        exports.aura_ui:uiDrawText("Yeni bir hikâye başlat", layout.actionX, layout.actionY - 27 * scale, layout.actionX + layout.actionW, layout.actionY - 8 * scale, tocolor(147, 164, 187, math.floor(215 * alpha)), 1, fonts.rowMeta, "right", "center")
    end
end

local function drawCreator(alpha)
    local scale = layout.scale
    local x = layout.drawX
    local y = layout.creatorY
    local panelW = layout.creatorW
    local panelH = layout.creatorH
    local formX = x + 30 * scale
    local formW = layout.creatorFormW
    local railW = 3 * scale
    local hookW = 34 * scale

    exports.gzl_ui:drawGlassPanel(x, y, panelW, panelH, 16 * scale)
    exports.gzl_ui:drawRoundedRectangle(x, y, railW, panelH, 2 * scale, tocolor(95, 168, 255, math.floor(235 * alpha)))
    exports.gzl_ui:drawRoundedRectangle(x, y, hookW, railW, 2 * scale, tocolor(95, 168, 255, math.floor(235 * alpha)))
    exports.gzl_ui:drawRoundedRectangle(x, y + panelH - railW, hookW, railW, 2 * scale, tocolor(95, 168, 255, math.floor(235 * alpha)))

    exports.gzl_ui:drawIconSVG("badge", formX, y + 28 * scale, 34 * scale, tocolor(95, 168, 255, math.floor(250 * alpha)))
    exports.aura_ui:uiDrawText("YENİ KARAKTER", formX, y + 76 * scale, formX + formW, y + 110 * scale, tocolor(243, 247, 253, math.floor(255 * alpha)), 1, fonts.creatorTitle, "left", "center")
    exports.aura_ui:uiDrawText("Slot " .. targetSlot .. " için karakterini hazırla", formX, y + 109 * scale, formX + formW, y + 132 * scale, tocolor(150, 167, 189, math.floor(220 * alpha)), 1, fonts.body, "left", "center")

    exports.aura_ui:uiDrawText("AD VE SOYAD", formX, layout.nameLabelY, formX + formW, layout.nameLabelY + 18 * scale, tocolor(181, 195, 214, math.floor(230 * alpha)), 1, fonts.label, "left", "top")
    exports.gzl_ui:drawGlassEditBox("create_char_name", formX, layout.nameBoxY, formW, 44 * scale, nameOptions)

    exports.aura_ui:uiDrawText("CİNSİYET", formX, layout.genderLabelY, formX + formW, layout.genderLabelY + 18 * scale, tocolor(181, 195, 214, math.floor(230 * alpha)), 1, fonts.label, "left", "top")
    local genderHalfW = formW * 0.5
    local activeGender = createGender == 1 and "login" or "register"
    exports.gzl_ui:drawDiagonalTabBarSVG(formX, layout.genderTabY, formW, 40 * scale, 9 * scale, activeGender)
    exports.aura_ui:uiDrawText("ERKEK", formX, layout.genderTabY, formX + genderHalfW - 5 * scale, layout.genderTabY + 40 * scale, createGender == 1 and tocolor(248, 251, 255, 255) or tocolor(146, 162, 184, 190), 1, fonts.button, "center", "center")
    exports.aura_ui:uiDrawText("KADIN", formX + genderHalfW + 5 * scale, layout.genderTabY, formX + formW, layout.genderTabY + 40 * scale, createGender == 2 and tocolor(248, 251, 255, 255) or tocolor(146, 162, 184, 190), 1, fonts.button, "center", "center")

    local minAge = type(CharConfig) == "table" and tonumber(CharConfig.MinAge) or 18
    local maxAge = type(CharConfig) == "table" and tonumber(CharConfig.MaxAge) or 80
    exports.aura_ui:uiDrawText("YAŞ  " .. minAge .. "-" .. maxAge, formX, layout.ageLabelY, formX + formW, layout.ageLabelY + 18 * scale, tocolor(181, 195, 214, math.floor(230 * alpha)), 1, fonts.label, "left", "top")
    exports.gzl_ui:drawGlassEditBox("create_char_age", formX, layout.ageBoxY, formW, 44 * scale, ageOptions)

    exports.aura_ui:uiDrawText("GÖRÜNÜM", formX, layout.skinLabelY, formX + formW, layout.skinLabelY + 18 * scale, tocolor(181, 195, 214, math.floor(230 * alpha)), 1, fonts.label, "left", "top")
    local selectorH = 44 * scale
    local arrowW = 46 * scale
    local skins = getSkinList(createGender)
    local skinId = skins[createSkinIndex] or skins[1]
    local leftHover = exports.gzl_ui:isMouseInPosition(formX, layout.skinSelectorY, arrowW, selectorH)
    local rightHover = exports.gzl_ui:isMouseInPosition(formX + formW - arrowW, layout.skinSelectorY, arrowW, selectorH)
    exports.gzl_ui:drawRoundedRectangle(formX, layout.skinSelectorY, formW, selectorH, 9 * scale, tocolor(13, 19, 29, math.floor(225 * alpha)))
    exports.gzl_ui:drawRoundedRectangle(formX + 2 * scale, layout.skinSelectorY + 2 * scale, arrowW - 4 * scale, selectorH - 4 * scale, 7 * scale, leftHover and tocolor(42, 104, 177, 190) or tocolor(255, 255, 255, 12))
    exports.gzl_ui:drawRoundedRectangle(formX + formW - arrowW + 2 * scale, layout.skinSelectorY + 2 * scale, arrowW - 4 * scale, selectorH - 4 * scale, 7 * scale, rightHover and tocolor(42, 104, 177, 190) or tocolor(255, 255, 255, 12))
    exports.aura_ui:uiDrawText("<", formX, layout.skinSelectorY, formX + arrowW, layout.skinSelectorY + selectorH, tocolor(230, 238, 249, 245), 1, fonts.button, "center", "center")
    exports.aura_ui:uiDrawText(">", formX + formW - arrowW, layout.skinSelectorY, formX + formW, layout.skinSelectorY + selectorH, tocolor(230, 238, 249, 245), 1, fonts.button, "center", "center")
    exports.aura_ui:uiDrawText("MODEL " .. skinId .. "   " .. createSkinIndex .. "/" .. #skins, formX + arrowW, layout.skinSelectorY, formX + formW - arrowW, layout.skinSelectorY + selectorH, tocolor(229, 237, 248, 245), 1, fonts.button, "center", "center")

    createActionOptions.disabled = isProcessing
    exports.gzl_ui:drawGlassButton("creator_submit", isProcessing and "OLUŞTURULUYOR" or "KARAKTERİ OLUŞTUR", formX, layout.submitY, formW, 46 * scale, createActionOptions)
    exports.gzl_ui:drawGlassButton("creator_back", "SEÇİME DÖN", formX, layout.backY, formW, 40 * scale, backOptions)

    local hintW = 410 * scale
    local hintH = 42 * scale
    local hintX = screenW - hintW - 48 * scale
    local hintY = screenH - hintH - 38 * scale
    exports.gzl_ui:drawGlassPanel(hintX, hintY, hintW, hintH, 10 * scale)
    exports.gzl_ui:drawIconSVG("swap", hintX + 14 * scale, hintY + 11 * scale, 20 * scale, tocolor(95, 168, 255, 240))
    exports.aura_ui:uiDrawText("Karakteri döndürmek için fareyle sağa veya sola sürükle", hintX + 44 * scale, hintY, hintX + hintW - 12 * scale, hintY + hintH, tocolor(191, 204, 222, 225), 1, fonts.rowMeta, "left", "center")
end

local function renderCharacterGUI()
    if not isVisible or not fonts or not isUIReady() then
        return
    end

    local openProgress = exports.gzl_ui:getAnimProgress("char_hub_open", 1, 0.12, 0)
    if currentMode == "select" then
        layout.drawX = layout.leftX - (1 - openProgress) * 24 * layout.scale
    else
        layout.drawX = layout.creatorX - (1 - openProgress) * 24 * layout.scale
    end
    drawBackdrop(openProgress)
    if currentMode == "select" then
        drawSelection(openProgress)
    else
        drawCreator(openProgress)
    end
end

local function enterCreateMode(slot)

    isVisible = false
    isProcessing = false
    showCursor(false)
    stopCharacterStudio()
    removeEventHandler("onClientRender", root, renderCharacterGUI)

    if exports.gzl_creator and exports.gzl_creator.setCreatorVisible then
        exports.gzl_creator:setCreatorVisible(true)
    else
        triggerEvent("gzl_creator:open", localPlayer)
    end
end

local function returnToSelection()
    currentMode = "select"
    isProcessing = false
    if isUIReady() then
        exports.gzl_ui:resetAnimProgress("char_hub_open", 0)
        exports.gzl_ui:setActiveEditBox(nil)
    end
    local selectedCharacter = getCharacterInSlot(selectedSlot)
    if selectedCharacter then
        updateStudioPedSkin(selectedCharacter.skin, tonumber(selectedCharacter.gender) or 1, selectedCharacter.customization)
    else
        hideStudioPed()
    end
end

local function handlePrimaryAction()
    local selectedCharacter = getCharacterInSlot(selectedSlot)
    if selectedCharacter then
        triggerServerEvent("char:select", localPlayer, selectedCharacter.id)
    else
        enterCreateMode(selectedSlot or 1)
    end
end

addEventHandler("onClientClick", root, function(button, state)
    if not isVisible or not fonts or not isUIReady() or button ~= "left" or state ~= "down" then
        return
    end

    local scale = layout.scale
    if currentMode == "select" then
        local rowX = layout.drawX + 30 * scale
        for slot = 1, 5 do
            local rowY = layout.rowY + (slot - 1) * (layout.rowH + layout.rowGap)
            if exports.gzl_ui:isMouseInPosition(rowX, rowY, layout.rowW, layout.rowH) then
                local now = getTickCount()
                selectedSlot = slot
                if characterList[slot] then
                    updateStudioPedSkin(characterList[slot].skin, tonumber(characterList[slot].gender) or 1, characterList[slot].customization)
                    if lastClickSlot == slot and now - lastClickTick < 300 then
                        triggerServerEvent("char:select", localPlayer, characterList[slot].id)
                    end
                else
                    hideStudioPed()
                    if lastClickSlot == slot and now - lastClickTick < 300 then
                        enterCreateMode(slot)
                    end
                end
                lastClickSlot = slot
                lastClickTick = now
                return
            end
        end

        if exports.gzl_ui:isMouseInPosition(layout.actionX, layout.actionY, layout.actionW, layout.actionH) then
            handlePrimaryAction()
            return
        end

        local logoutW = 174 * scale
        local logoutX = layout.drawX + 30 * scale
        if exports.gzl_ui:isMouseInPosition(logoutX, layout.logoutY, logoutW, 38 * scale) then
            isVisible = false
            showCursor(false)
            stopCharacterStudio()
            removeEventHandler("onClientRender", root, renderCharacterGUI)
            triggerServerEvent("char:logout", localPlayer)
        end
    else
        local formX = layout.drawX + 30 * scale
        local formW = layout.creatorFormW
        local genderHalfW = formW * 0.5

        if exports.gzl_ui:isMouseInPosition(formX, layout.nameBoxY, formW, 44 * scale) then
            exports.gzl_ui:setActiveEditBox("create_char_name")
            return
        end
        if exports.gzl_ui:isMouseInPosition(formX, layout.ageBoxY, formW, 44 * scale) then
            exports.gzl_ui:setActiveEditBox("create_char_age")
            return
        end

        if exports.gzl_ui:isMouseInPosition(formX, layout.genderTabY, genderHalfW, 40 * scale) then
            createGender = 1
            createSkinIndex = 1
            local skins = getSkinList(1)
            updateStudioPedSkin(skins[1], 1)
            return
        end
        if exports.gzl_ui:isMouseInPosition(formX + genderHalfW, layout.genderTabY, genderHalfW, 40 * scale) then
            createGender = 2
            createSkinIndex = 1
            local skins = getSkinList(2)
            updateStudioPedSkin(skins[1], 2)
            return
        end

        local arrowW = 46 * scale
        local selectorH = 44 * scale
        local skins = getSkinList(createGender)
        if exports.gzl_ui:isMouseInPosition(formX, layout.skinSelectorY, arrowW, selectorH) then
            createSkinIndex = createSkinIndex - 1
            if createSkinIndex < 1 then
                createSkinIndex = #skins
            end
            updateStudioPedSkin(skins[createSkinIndex], createGender)
            return
        end
        if exports.gzl_ui:isMouseInPosition(formX + formW - arrowW, layout.skinSelectorY, arrowW, selectorH) then
            createSkinIndex = createSkinIndex + 1
            if createSkinIndex > #skins then
                createSkinIndex = 1
            end
            updateStudioPedSkin(skins[createSkinIndex], createGender)
            return
        end

        if exports.gzl_ui:isMouseInPosition(formX, layout.submitY, formW, 46 * scale) and not isProcessing then
            local characterName = exports.gzl_ui:getEditBoxText("create_char_name")
            local characterAge = tonumber(exports.gzl_ui:getEditBoxText("create_char_age")) or 24
            local characterSkin = skins[createSkinIndex]
            if string.len(characterName) == 0 then
                exports.gzl_ui:showNotification("HATA", "Lütfen bir karakter adı girin.", "error")
                return
            end
            isProcessing = true
            triggerServerEvent("char:create", localPlayer, characterName, createGender, characterAge, characterSkin)
            return
        end

        if exports.gzl_ui:isMouseInPosition(formX, layout.backY, formW, 40 * scale) and not isProcessing then
            returnToSelection()
        end
    end
end)

addEventHandler("onClientKey", root, function(button, press)
    if not press or not isVisible or currentMode ~= "create" then
        return
    end
    if button == "escape" and not isProcessing then
        returnToSelection()
        cancelEvent()
    elseif button == "enter" and not isProcessing and isUIReady() then
        local characterName = exports.gzl_ui:getEditBoxText("create_char_name")
        local characterAge = tonumber(exports.gzl_ui:getEditBoxText("create_char_age")) or 24
        local skins = getSkinList(createGender)
        if string.len(characterName) > 0 then
            isProcessing = true
            triggerServerEvent("char:create", localPlayer, characterName, createGender, characterAge, skins[createSkinIndex])
        end
    end
end)

addEvent("char:receiveList", true)
addEventHandler("char:receiveList", root, function(list)
    -- A database reply requested before spawning must not reopen the studio.
    if getElementData(localPlayer, "loggedin_character") then return end
    characterList = type(list) == "table" and list or {}
    for i = 1, #hudComponents do
        setPlayerHudComponentVisible(hudComponents[i], false)
    end

    currentMode = "select"
    isProcessing = false
    updateLayout()
    if not prepareFonts() then
        queueFontPreparation()
    end
    if isUIReady() then
        exports.gzl_ui:resetAnimProgress("char_hub_open", 0)
    end

    if #characterList > 0 then
        selectedSlot = 1
        startCharacterStudio(characterList[1].skin, tonumber(characterList[1].gender) or 1, characterList[1].customization)
    else
        selectedSlot = 1
        startCharacterStudio(nil)
    end

    isVisible = true
    showCursor(true)
    showChat(false)
    if exports.gzl_chat and exports.gzl_chat.setChatVisible then
        exports.gzl_chat:setChatVisible(false)
    end
    fadeCamera(true, 1.0)
    removeEventHandler("onClientRender", root, renderCharacterGUI)
    addEventHandler("onClientRender", root, renderCharacterGUI)
end)

addEvent("char:response", true)
addEventHandler("char:response", root, function(success, message)
    isProcessing = false
    if isUIReady() then
        exports.gzl_ui:showNotification(success and "BAŞARILI" or "HATA", message, success and "success" or "error")
        if success then
            exports.gzl_ui:setEditBoxText("create_char_name", "")
            exports.gzl_ui:setEditBoxText("create_char_age", "24")
        end
    end
end)

addEvent("char:spawnSuccess", true)
addEventHandler("char:spawnSuccess", root, function()
    isVisible = false
    isProcessing = false
    removeEventHandler("onClientRender", root, renderCharacterGUI)
    showCursor(false)
    stopCharacterStudio()
    fadeCamera(true, 0.5)
    if exports.gzl_ui and exports.gzl_ui.setActiveEditBox then
        exports.gzl_ui:setActiveEditBox(nil)
    end
    showCursor(false)
    showChat(false)
    if exports.gzl_chat and exports.gzl_chat.setChatVisible then
        exports.gzl_chat:setChatVisible(true)
    end
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    updateLayout()
    if not prepareFonts() then
        queueFontPreparation()
    end
    if getElementData(localPlayer, "account:id") and not getElementData(localPlayer, "loggedin_character") then
        triggerServerEvent("char:requestList", localPlayer)
    end
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    if isTimer(fontTimer) then
        killTimer(fontTimer)
        fontTimer = nil
    end
    if isVisible then
        isVisible = false
        showCursor(false)
        stopCharacterStudio()
        removeEventHandler("onClientRender", root, renderCharacterGUI)
    end
end)