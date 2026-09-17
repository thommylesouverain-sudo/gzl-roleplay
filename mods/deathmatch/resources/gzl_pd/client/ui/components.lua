
Components = {}

function Components.drawTabButton(x, y, w, h, icon, label, isActive, fontScale)
    local colors = PDTheme.colors
    local isHover = PDGeometry.isCursorIn(x, y, w, h)
    local bg = isActive and colors.cardActive or (isHover and colors.cardHover or colors.sidebarBg)

    exports.aura_ui:uiDrawRectangle(x, y, w, h, bg)
    if isActive then
        exports.aura_ui:uiDrawRectangle(x, y, 4, h, colors.policeBlue)
    end

    local textCol = (isActive or isHover) and colors.textPrimary or colors.textSecondary
    exports.aura_ui:uiDrawText(icon, x + 16, y, x + 40, y + h, (isActive and colors.policeBlue or textCol), fontScale * 1.1, "default-bold", "center", "center")
    exports.aura_ui:uiDrawText(label, x + 48, y, x + w - 10, y + h, textCol, fontScale * 0.95, "default-bold", "left", "center")

    return isHover
end

function Components.drawSearchBox(x, y, w, h, placeholder, text, isFocused, fontScale)
    local colors = PDTheme.colors
    local isHover = PDGeometry.isCursorIn(x, y, w, h)

    local borderCol = isFocused and colors.inputActive or (isHover and colors.inputBorder or colors.separator)
    exports.aura_ui:uiDrawRectangle(x - 1, y - 1, w + 2, h + 2, borderCol)
    exports.aura_ui:uiDrawRectangle(x, y, w, h, colors.inputBg)

    local displayStr = (text and text ~= "") and text or placeholder
    local textCol = (text and text ~= "") and colors.textPrimary or colors.textDim

    exports.aura_ui:uiDrawText("🔍", x + 10, y, x + 30, y + h, colors.textDim, fontScale * 0.9, "default-bold", "center", "center")
    exports.aura_ui:uiDrawText(displayStr, x + 34, y, x + w - 10, y + h, textCol, fontScale * 0.95, "default", "left", "center", true)

    return isHover
end

function Components.drawButton(x, y, w, h, text, bgCol, hoverCol, fontScale)
    local colors = PDTheme.colors
    local isHover = PDGeometry.isCursorIn(x, y, w, h)
    local finalBg = isHover and (hoverCol or colors.cardHover) or (bgCol or colors.cardBg)

    exports.aura_ui:uiDrawRectangle(x, y, w, h, finalBg)
    exports.aura_ui:uiDrawText(text, x, y, x + w, y + h, colors.textPrimary, fontScale * 0.95, "default-bold", "center", "center")

    return isHover
end

function Components.drawStatBox(x, y, w, h, title, value, color, fontScale)
    local colors = PDTheme.colors
    exports.aura_ui:uiDrawRectangle(x, y, w, h, colors.cardBg)
    exports.aura_ui:uiDrawRectangle(x, y, 4, h, color or colors.policeBlue)

    exports.aura_ui:uiDrawText(title, x + 14, y + 10, x + w - 14, y + 26, colors.textDim, fontScale * 0.85, "default-bold", "left", "center")
    exports.aura_ui:uiDrawText(tostring(value), x + 14, y + 28, x + w - 14, y + h - 8, colors.textPrimary, fontScale * 1.3, "default-bold", "left", "center")
end