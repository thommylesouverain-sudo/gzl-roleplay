local screenW, screenH = guiGetScreenSize()
local baseW, baseH = 1920, 1080

function getScreenScale()
    local scale = math.min(screenW / baseW, screenH / baseH)
    return math.max(0.8, scale)
end

function isMouseInPosition(x, y, width, height)
    if not isCursorShowing() then return false end
    local cx, cy = getCursorPosition()
    if not cx or not cy then return false end
    cx, cy = cx * screenW, cy * screenH
    return (cx >= x and cx <= x + width and cy >= y and cy <= y + height)
end

local function uLen(s)
    if not s then return 0 end
    if utf8 and utf8.len then
        local l = utf8.len(s)
        if l then return l end
    end
    return string.len(s)
end

local function uSub(s, i, j)
    if not s then return "" end
    if utf8 and utf8.sub then
        return utf8.sub(s, i, j)
    end
    return string.sub(s, i, j)
end

local animStates = {}

function getAnimProgress(key, targetValue, speed, initialValue)
    speed = speed or 0.14
    if animStates[key] == nil then
        animStates[key] = (initialValue ~= nil) and initialValue or targetValue
    end
    animStates[key] = animStates[key] + (targetValue - animStates[key]) * speed
    if math.abs(targetValue - animStates[key]) < 0.001 then
        animStates[key] = targetValue
    end
    return animStates[key]
end

function resetAnimProgress(key, value)
    animStates[key] = value or 0
end

function drawGlassButton(id, text, x, y, w, h, options)
    options = options or {}
    local radius = options.radius or 10
    local font = options.font or getFont("bold", 12)
    local theme = options.theme or (options.color and options.color[2] > 180 and "green" or "blue")
    local disabled = options.disabled or false

    local hovered = not disabled and isMouseInPosition(x, y, w, h)
    local hoverProg = getAnimProgress("btn_hov_" .. tostring(id), (hovered and not disabled) and 1 or 0, 0.2)
    local state = hovered and "hover" or "normal"

    local ix = math.floor(x)
    local iy = math.floor(y - hoverProg * 2)
    local iw = math.floor(w)
    local ih = math.floor(h)

    if disabled then
        drawEditBoxSVG(ix, iy, iw, ih, radius, "normal")
        dxDrawText(text, ix, iy, ix + iw, iy + ih, tocolor(130, 140, 155, 180), 1, font, "center", "center", false, false, false, false)
        return false
    end

    drawLiquidButtonSVG(ix, iy, iw, ih, radius, theme, state)
    if hoverProg > 0.05 then
        drawRoundedBorder(ix, iy, iw, ih, radius, 1.0, tocolor(255, 255, 255, math.floor(hoverProg * 45)))
    end

    if options.icon then
        local iconSize = options.iconSize or 16
        local textW = dxGetTextWidth(text, 1, font)
        local totalW = iconSize + 6 + textW
        local startX = math.floor(ix + (iw - totalW) / 2)
        local iconY = math.floor(iy + (ih - iconSize) / 2)
        drawIconSVG(options.icon, startX, iconY, iconSize, tocolor(255, 255, 255, 240))
        dxDrawText(text, startX + iconSize + 6, iy, startX + iconSize + 6 + textW, iy + ih, tocolor(255, 255, 255, 255), 1, font, "left", "center", false, false, false, false)
    else
        dxDrawText(text, ix, iy, ix + iw, iy + ih, tocolor(255, 255, 255, 255), 1, font, "center", "center", false, false, false, false)
    end

    return hovered
end

local editBoxes = {}
local activeEditBox = nil
local lastClickTick = 0
local lastClickBox = nil

local function getCharIndexFromClick(data, clickX)
    local relX = clickX - (data.bounds.x + data.textPadX)
    local text = data.text or ""
    local font = data.font or getFont("regular", 11)
    local masked = data.masked or false
    local displayText = masked and string.rep("•", uLen(text)) or text

    if relX <= 0 then return 0 end

    local len = uLen(displayText)
    local prevW = 0
    for i = 1, len do
        local curW = dxGetTextWidth(uSub(displayText, 1, i), 1, font)
        local mid = prevW + (curW - prevW) / 2
        if relX < mid then
            return i - 1
        end
        prevW = curW
    end
    return len
end

function drawGlassEditBox(id, x, y, w, h, options)
    options = options or {}
    local placeholder = options.placeholder or ""
    local masked = options.masked or false
    local maxChars = options.maxChars or 32
    local font = options.font or getFont("regular", 11)
    local radius = options.radius or 10
    local icon = options.icon
    local textPadX = icon and 40 or 14

    if not editBoxes[id] then
        local initialText = tostring(options.defaultText or "")
        editBoxes[id] = {
            text = initialText,
            cursorPos = uLen(initialText),
            selectionStart = nil,
            cursorTick = getTickCount(),
            cursorVisible = true,
            isSelecting = false,
            bounds = { x = x, y = y, w = w, h = h },
            textPadX = textPadX,
            font = font,
            masked = masked,
            maxChars = maxChars
        }
    end

    local data = editBoxes[id]
    data.bounds = { x = x, y = y, w = w, h = h }
    data.lastRenderTick = getTickCount()
    data.textPadX = textPadX
    data.font = font
    data.masked = masked
    data.maxChars = maxChars

    if data.cursorPos > uLen(data.text) then
        data.cursorPos = uLen(data.text)
    end

    local hovered = isMouseInPosition(x, y, w, h)
    local isActive = (activeEditBox == id)
    local boxState = isActive and "active" or (hovered and "hover" or "normal")

    drawEditBoxSVG(x, y, w, h, radius, boxState)

    if icon then
        local iconSize = 18
        local iconY = y + (h - iconSize) / 2
        local iconColor = isActive and tocolor(56, 166, 255, 240) or (hovered and tocolor(200, 215, 235, 190) or tocolor(120, 140, 165, 140))
        drawIconSVG(icon, x + 13, iconY, iconSize, iconColor)
    end

    local displayText = data.text
    if masked then
        displayText = string.rep("•", uLen(displayText))
    end

    if uLen(displayText) == 0 and not isActive then
        dxDrawText(placeholder, x + textPadX, y, x + w - textPadX, y + h, tocolor(130, 145, 165, 160), 1, font, "left", "center", true, false)
    else
        if isActive and data.selectionStart and data.selectionStart ~= data.cursorPos then
            local selMin = math.min(data.selectionStart, data.cursorPos)
            local selMax = math.max(data.selectionStart, data.cursorPos)

            local subPre = uSub(displayText, 1, selMin)
            local subSel = uSub(displayText, selMin + 1, selMax)

            local selStartX = x + textPadX + dxGetTextWidth(subPre, 1, font)
            local selWidth = dxGetTextWidth(subSel, 1, font)
            local selH = math.max(18, math.floor(h * 0.55))
            local selY = y + (h - selH) / 2

            dxDrawRectangle(selStartX, selY, selWidth, selH, tocolor(0, 122, 255, 130))
        end

        dxDrawText(displayText, x + textPadX, y, x + w - textPadX, y + h, tocolor(245, 248, 255, 245), 1, font, "left", "center", true, false)

        if isActive then
            if (getTickCount() - data.cursorTick) > 500 then
                data.cursorVisible = not data.cursorVisible
                data.cursorTick = getTickCount()
            end

            if data.cursorVisible and (not data.selectionStart or data.selectionStart == data.cursorPos) then
                local textBeforeCursor = uSub(displayText, 1, data.cursorPos)
                local cursorX = x + textPadX + dxGetTextWidth(textBeforeCursor, 1, font)
                local cursorH = math.max(16, math.floor(h * 0.45))
                local cursorY = y + (h - cursorH) / 2
                dxDrawRectangle(cursorX, cursorY, 2, cursorH, tocolor(56, 166, 255, 255))
            end
        end
    end

    return {
        id = id,
        text = data.text,
        isActive = isActive,
        hovered = hovered,
        cursorPos = data.cursorPos
    }
end

function getEditBoxText(id)
    return editBoxes[id] and editBoxes[id].text or ""
end

function setEditBoxText(id, text)
    text = tostring(text or "")
    if editBoxes[id] then
        editBoxes[id].text = text
        editBoxes[id].cursorPos = uLen(text)
        editBoxes[id].selectionStart = nil
        editBoxes[id].cursorTick = getTickCount()
        editBoxes[id].cursorVisible = true
    else
        editBoxes[id] = {
            text = text,
            cursorPos = uLen(text),
            selectionStart = nil,
            cursorTick = getTickCount(),
            cursorVisible = true,
            isSelecting = false
        }
    end
end

local previousInputMode,previousInputEnabled
function setActiveEditBox(id)
    if not editBoxes[id] then id=nil end
    if id then
        triggerEvent("onAuraInputClaim",resourceRoot)
        if not activeEditBox then
            previousInputMode=guiGetInputMode()
            previousInputEnabled=guiGetInputEnabled()
        end
    elseif not activeEditBox then
        return
    end
    activeEditBox = id
    if id and editBoxes[id] then
        local data = editBoxes[id]
        data.cursorPos = uLen(data.text)
        data.selectionStart = nil
        data.cursorTick = getTickCount()
        data.cursorVisible = true
        pcall(guiSetInputMode, "no_binds")
        pcall(guiSetInputEnabled, true)
    else
        pcall(guiSetInputMode, previousInputMode or "allow_binds")
        pcall(guiSetInputEnabled, previousInputEnabled==true)
        previousInputMode,previousInputEnabled=nil,nil
    end
end

addEvent("onAuraInputClaim",false)
addEventHandler("onAuraInputClaim",root,function()
    if source~=resourceRoot then setActiveEditBox(nil) end
end)
addEventHandler("onClientResourceStop",resourceRoot,function() setActiveEditBox(nil) end)

function getActiveEditBox()
    return activeEditBox
end

local function isResRunning(name)
    local res = getResourceFromName(name)
    return res and getResourceState(res) == "running"
end

function isPlayerTyping()
    if isChatBoxInputActive and isChatBoxInputActive() then return true end
    if isConsoleActive and isConsoleActive() then return true end
    if guiGetInputEnabled and guiGetInputEnabled() then return true end
    if activeEditBox ~= nil then return true end
    if isResRunning("gzl_chat") and exports.gzl_chat.isChatInputOpen and exports.gzl_chat:isChatInputOpen() then return true end
    if isResRunning("gzl_atm") and exports.gzl_atm.isATMOpen and exports.gzl_atm:isATMOpen() then return true end
    if isResRunning("high_phone") and exports.high_phone.getActiveEditBox and exports.high_phone:getActiveEditBox() then return true end
    if isResRunning("high_phone") and exports.high_phone.isKeypadTypingActive and exports.high_phone:isKeypadTypingActive() then return true end
    if isResRunning("gzl_phone") and exports.gzl_phone.isPhoneOpenState and exports.gzl_phone:isPhoneOpenState() then
        if exports.gzl_phone.isKeypadTypingActive and exports.gzl_phone:isKeypadTypingActive() then return true end
    end
    if isResRunning("cylex_phone") and exports.cylex_phone.isPhoneOpenState and exports.cylex_phone:isPhoneOpenState() then return true end
    if isResRunning("gzl_pd") and exports.gzl_pd.isPDTabletOpen and exports.gzl_pd:isPDTabletOpen() then return true end
    return false
end

addEventHandler("onClientClick", root, function(button, state, absX, absY)
    if button == "left" then
        if state == "down" then
            local clickedBox = nil
            local now = getTickCount()
            for id, data in pairs(editBoxes) do
                if data.bounds and (data.lastRenderTick and (now - data.lastRenderTick) < 250) and isMouseInPosition(data.bounds.x, data.bounds.y, data.bounds.w, data.bounds.h) then
                    clickedBox = id
                    break
                end
            end

            setActiveEditBox(clickedBox)

            if clickedBox and editBoxes[clickedBox] then
                local data = editBoxes[clickedBox]
                local now = getTickCount()

                if lastClickBox == clickedBox and (now - lastClickTick) < 280 then
                    data.selectionStart = 0
                    data.cursorPos = uLen(data.text)
                    data.isSelecting = false
                else
                    local targetPos = getCharIndexFromClick(data, absX)
                    data.cursorPos = targetPos
                    data.selectionStart = targetPos
                    data.isSelecting = true
                end

                data.cursorVisible = true
                data.cursorTick = now
                lastClickTick = now
                lastClickBox = clickedBox
            end
        elseif state == "up" then
            for _, data in pairs(editBoxes) do
                if data.isSelecting then
                    data.isSelecting = false
                    if data.selectionStart == data.cursorPos then
                        data.selectionStart = nil
                    end
                end
            end
        end
    end
end)

addEventHandler("onClientCursorMove", root, function(cx, cy, absX, absY)
    if activeEditBox and editBoxes[activeEditBox] then
        local data = editBoxes[activeEditBox]
        if data.isSelecting then
            data.cursorPos = getCharIndexFromClick(data, absX)
            data.cursorVisible = true
            data.cursorTick = getTickCount()
        end
    end
end)

local function deleteSelection(data)
    if not data.selectionStart or data.selectionStart == data.cursorPos then
        return false
    end
    local selMin = math.min(data.selectionStart, data.cursorPos)
    local selMax = math.max(data.selectionStart, data.cursorPos)
    data.text = uSub(data.text, 1, selMin) .. uSub(data.text, selMax + 1)
    data.cursorPos = selMin
    data.selectionStart = nil
    data.cursorVisible = true
    data.cursorTick = getTickCount()
    return true
end

addEventHandler("onClientCharacter", root, function(character)
    if activeEditBox and editBoxes[activeEditBox] then
        local data = editBoxes[activeEditBox]
        if getKeyState("lctrl") or getKeyState("rctrl") then return end

        deleteSelection(data)

        local maxChars = data.maxChars or 32
        if uLen(data.text) < maxChars then
            local pos = data.cursorPos
            data.text = uSub(data.text, 1, pos) .. character .. uSub(data.text, pos + 1)
            data.cursorPos = pos + uLen(character)
            data.selectionStart = nil
            data.cursorVisible = true
            data.cursorTick = getTickCount()
        end
    end
end)

addEventHandler("onClientKey", root, function(button, press)
    if not press or not activeEditBox or not editBoxes[activeEditBox] then return end
    local data = editBoxes[activeEditBox]
    local isCtrl = getKeyState("lctrl") or getKeyState("rctrl")
    local isShift = getKeyState("lshift") or getKeyState("rshift")

    if isCtrl and button == "a" then
        data.selectionStart = 0
        data.cursorPos = uLen(data.text)
        data.cursorVisible = true
        data.cursorTick = getTickCount()
        cancelEvent()
        return
    elseif isCtrl and button == "c" then
        if data.selectionStart and data.selectionStart ~= data.cursorPos then
            local selMin = math.min(data.selectionStart, data.cursorPos)
            local selMax = math.max(data.selectionStart, data.cursorPos)
            setClipboard(uSub(data.text, selMin + 1, selMax))
        end
        cancelEvent()
        return
    elseif isCtrl and button == "x" then
        if data.selectionStart and data.selectionStart ~= data.cursorPos then
            local selMin = math.min(data.selectionStart, data.cursorPos)
            local selMax = math.max(data.selectionStart, data.cursorPos)
            setClipboard(uSub(data.text, selMin + 1, selMax))
            deleteSelection(data)
        end
        cancelEvent()
        return
    elseif isCtrl and button == "v" then
        local clip = getClipboard()
        if clip and type(clip) == "string" then
            clip = string.gsub(clip, "[\r\n]", "")
            deleteSelection(data)
            local maxChars = data.maxChars or 32
            local remaining = maxChars - uLen(data.text)
            if remaining > 0 then
                clip = uSub(clip, 1, remaining)
                local pos = data.cursorPos
                data.text = uSub(data.text, 1, pos) .. clip .. uSub(data.text, pos + 1)
                data.cursorPos = pos + uLen(clip)
                data.selectionStart = nil
                data.cursorVisible = true
                data.cursorTick = getTickCount()
            end
        end
        cancelEvent()
        return
    end

    if button == "backspace" then
        if not deleteSelection(data) then
            if data.cursorPos > 0 then
                local pos = data.cursorPos
                data.text = uSub(data.text, 1, pos - 1) .. uSub(data.text, pos + 1)
                data.cursorPos = pos - 1
                data.cursorVisible = true
                data.cursorTick = getTickCount()
            end
        end
        cancelEvent()
    elseif button == "delete" then
        if not deleteSelection(data) then
            if data.cursorPos < uLen(data.text) then
                local pos = data.cursorPos
                data.text = uSub(data.text, 1, pos) .. uSub(data.text, pos + 2)
                data.cursorVisible = true
                data.cursorTick = getTickCount()
            end
        end
        cancelEvent()
    elseif button == "arrow_l" then
        if isShift then
            if not data.selectionStart then
                data.selectionStart = data.cursorPos
            end
            data.cursorPos = math.max(0, data.cursorPos - 1)
        else
            if data.selectionStart and data.selectionStart ~= data.cursorPos then
                data.cursorPos = math.min(data.selectionStart, data.cursorPos)
                data.selectionStart = nil
            else
                data.cursorPos = math.max(0, data.cursorPos - 1)
            end
        end
        data.cursorVisible = true
        data.cursorTick = getTickCount()
        cancelEvent()
    elseif button == "arrow_r" then
        if isShift then
            if not data.selectionStart then
                data.selectionStart = data.cursorPos
            end
            data.cursorPos = math.min(uLen(data.text), data.cursorPos + 1)
        else
            if data.selectionStart and data.selectionStart ~= data.cursorPos then
                data.cursorPos = math.max(data.selectionStart, data.cursorPos)
                data.selectionStart = nil
            else
                data.cursorPos = math.min(uLen(data.text), data.cursorPos + 1)
            end
        end
        data.cursorVisible = true
        data.cursorTick = getTickCount()
        cancelEvent()
    elseif button == "home" then
        if isShift then
            if not data.selectionStart then
                data.selectionStart = data.cursorPos
            end
            data.cursorPos = 0
        else
            data.cursorPos = 0
            data.selectionStart = nil
        end
        data.cursorVisible = true
        data.cursorTick = getTickCount()
        cancelEvent()
    elseif button == "end" then
        if isShift then
            if not data.selectionStart then
                data.selectionStart = data.cursorPos
            end
            data.cursorPos = uLen(data.text)
        else
            data.cursorPos = uLen(data.text)
            data.selectionStart = nil
        end
        data.cursorVisible = true
        data.cursorTick = getTickCount()
        cancelEvent()
    elseif button == "escape" then
        setActiveEditBox(nil)
        cancelEvent()
    else
        cancelEvent()
    end
end)

local notifications = {}
local notificationStyles = {
    info = { title = "BİLGİ", icon = "info", color = {79, 179, 224} },
    success = { title = "BAŞARILI", icon = "check", color = {67, 190, 139} },
    warning = { title = "UYARI", icon = "alert", color = {229, 169, 67} },
    error = { title = "HATA", icon = "cross", color = {224, 91, 105} }
}
local notificationWidth = math.floor(math.min(400, math.max(300, screenW * 0.27)))
local notificationContentX = 65
local notificationContentWidth = notificationWidth - notificationContentX - 16
local notificationTitleFont = getFont("semibold", 11)
local notificationMessageFont = getFont("regular", 10)
local notificationLineHeight = 17
local notificationMaxLines = 3
local notificationMaxVisible = 4
local notificationHudOffset = 24
local notificationHudCheckTick = 0

local function preloadNotificationAssets()
    drawRoundedRectangle(0, 0, 36, 36, 10, tocolor(255, 255, 255, 0))
    drawRoundedRectangle(0, 0, 64, 2, 1, tocolor(255, 255, 255, 0))
    for nType, style in pairs(notificationStyles) do
        drawIconSVG(style.icon, 0, 0, 18, tocolor(255, 255, 255, 0))
        for lineCount = 1, notificationMaxLines do
            local height = math.max(76, 49 + lineCount * notificationLineHeight)
            drawNotificationCardSVG(0, 0, notificationWidth, height, 14, nType, false, 0)
        end
    end
end

preloadNotificationAssets()

local function isNotificationType(value)
    return type(value) == "string" and notificationStyles[string.lower(value)] ~= nil
end

local function fitNotificationText(text, maxWidth, font, ellipsis)
    local suffix = ellipsis and "…" or ""
    local length = uLen(text)
    while length > 0 and dxGetTextWidth(text .. suffix, 1, font) > maxWidth do
        length = length - 1
        text = uSub(text, 1, length)
    end
    return text .. suffix
end

local function wrapNotificationText(text, maxWidth, maxLines, font)
    local lines = {}
    local paragraphs = {}
    local overflow = false
    local sourceText = tostring(text or "")

    for paragraph in string.gmatch(sourceText .. "\n", "([^\n]*)\n") do
        paragraphs[#paragraphs + 1] = paragraph
    end

    for paragraphIndex, paragraph in ipairs(paragraphs) do
        local line = ""
        local hasWords = false

        for word in string.gmatch(paragraph, "%S+") do
            hasWords = true
            local candidate = line == "" and word or line .. " " .. word
            if dxGetTextWidth(candidate, 1, font) <= maxWidth then
                line = candidate
            else
                if line ~= "" then
                    lines[#lines + 1] = line
                    if #lines >= maxLines then
                        overflow = true
                        break
                    end
                end
                if dxGetTextWidth(word, 1, font) > maxWidth then
                    line = fitNotificationText(word, maxWidth, font, true)
                    overflow = true
                    break
                end
                line = word
            end
        end

        if overflow then
            break
        end

        if line ~= "" or not hasWords then
            lines[#lines + 1] = line
            if #lines >= maxLines then
                if paragraphIndex < #paragraphs then
                    overflow = true
                end
                break
            end
        end
    end

    if #lines == 0 then
        lines[1] = ""
    end

    if overflow then
        local lastIndex = math.min(#lines, maxLines)
        lines[lastIndex] = fitNotificationText(lines[lastIndex], maxWidth, font, true)
        while #lines > maxLines do
            table.remove(lines)
        end
    end

    return table.concat(lines, "\n"), #lines
end

local function normalizeNotificationArguments(title, message, nType, duration)
    if isNotificationType(title) and message ~= nil and nType ~= nil then
        local actualType = string.lower(title)
        title, message, nType = message, nType, actualType
    elseif isNotificationType(title) and message ~= nil then
        nType = string.lower(title)
        title = nil
    elseif isNotificationType(message) and (nType == nil or type(nType) == "number") then
        duration = type(nType) == "number" and nType or duration
        nType = string.lower(message)
        message = title
        title = nil
    elseif message == nil and title ~= nil then
        message = title
        title = nil
    end

    nType = isNotificationType(nType) and string.lower(nType) or "info"
    message = tostring(message or "")
    title = title ~= nil and tostring(title) or notificationStyles[nType].title
    duration = math.max(1500, math.min(12000, tonumber(duration) or 4500))

    return title, message, nType, duration
end

local function refreshNotificationHudOffset(now)
    if now - notificationHudCheckTick < 250 then
        return notificationHudOffset
    end

    notificationHudCheckTick = now
    notificationHudOffset = 24
    local hudResource = getResourceFromName("gzl_hud")
    if hudResource and getResourceState(hudResource) == "running" and exports.gzl_hud then
        if exports.gzl_hud.getTopBarHeight then
            local ok, height = pcall(function()
                return exports.gzl_hud:getTopBarHeight()
            end)
            if ok and type(height) == "number" then
                notificationHudOffset = height + 12
            end
        elseif exports.gzl_hud.isHUDVisible then
            local ok, visible = pcall(function()
                return exports.gzl_hud:isHUDVisible()
            end)
            notificationHudOffset = ok and visible and 224 or 24
        end
    end

    return notificationHudOffset
end

function showNotification(title, message, nType, duration)
    title, message, nType, duration = normalizeNotificationArguments(title, message, nType, duration)
    local displayMessage, lineCount = wrapNotificationText(message, notificationContentWidth, notificationMaxLines, notificationMessageFont)
    if dxGetTextWidth(title, 1, notificationTitleFont) > notificationContentWidth then
        title = fitNotificationText(title, notificationContentWidth, notificationTitleFont, true)
    end

    if #notifications >= notificationMaxVisible then
        table.remove(notifications, 1)
    end

    notifications[#notifications + 1] = {
        title = title,
        message = displayMessage,
        type = nType,
        startTime = getTickCount(),
        duration = duration,
        height = math.max(76, 49 + lineCount * notificationLineHeight)
    }

    return true
end

function showToast(message, toastType, duration)
    return showNotification(nil, message, toastType, duration)
end

addEvent("ui:showNotification", true)
addEventHandler("ui:showNotification", root, function(title, message, nType, duration)
    showNotification(title, message, nType, duration)
end)

addEventHandler("onClientRender", root, function()
    local now = getTickCount()
    local startY = refreshNotificationHudOffset(now)

    for i = #notifications, 1, -1 do
        if now - notifications[i].startTime >= notifications[i].duration then
            table.remove(notifications, i)
        end
    end

    local stackOffset = 0
    for i = #notifications, 1, -1 do
        local notif = notifications[i]
        local elapsed = now - notif.startTime
        local enterDuration = 300
        local exitDuration = 220
        local alphaProgress = 1
        local slideOffset = 0

        if elapsed < enterDuration then
            local progress = elapsed / enterDuration
            local eased = 1 - ((1 - progress) ^ 3)
            alphaProgress = eased
            slideOffset = (1 - eased) * 34
        elseif elapsed > notif.duration - exitDuration then
            local progress = (elapsed - (notif.duration - exitDuration)) / exitDuration
            alphaProgress = 1 - (progress * progress)
            slideOffset = progress * progress * 26
        end

        local targetY = startY + stackOffset
        if not notif.renderY then
            notif.renderY = targetY - 10
        end
        notif.renderY = notif.renderY + (targetY - notif.renderY) * 0.2

        local x = math.floor(screenW - notificationWidth - 24 + slideOffset)
        local y = math.floor(notif.renderY)
        local a = math.floor(math.max(0, math.min(1, alphaProgress)) * 255)
        local style = notificationStyles[notif.type]
        local r, g, b = style.color[1], style.color[2], style.color[3]

        drawNotificationCardSVG(x, y, notificationWidth, notif.height, 14, notif.type, false, a)
        drawRoundedRectangle(x + 15, y + 18, 36, 36, 10, tocolor(r, g, b, math.floor(a * 0.14)))
        drawIconSVG(style.icon, x + 24, y + 27, 18, tocolor(r, g, b, a))

        dxDrawText(notif.title, x + notificationContentX, y + 12, x + notificationWidth - 16, y + 31, tocolor(240, 244, 250, a), 1, notificationTitleFont, "left", "center", true, false)
        dxDrawText(notif.message, x + notificationContentX, y + 35, x + notificationWidth - 16, y + notif.height - 13, tocolor(195, 205, 219, a), 1, notificationMessageFont, "left", "top", true, false)

        local progressWidth = notificationWidth - notificationContentX - 16
        local remainingRatio = math.max(0, math.min(1, 1 - elapsed / notif.duration))
        drawRoundedRectangle(x + notificationContentX, y + notif.height - 7, progressWidth, 2, 1, tocolor(255, 255, 255, math.floor(a * 0.08)))
        if remainingRatio > 0 then
            drawRoundedRectangle(x + notificationContentX, y + notif.height - 7, math.max(2, math.floor(progressWidth * remainingRatio)), 2, 1, tocolor(r, g, b, math.floor(a * 0.82)))
        end

        stackOffset = stackOffset + notif.height + 10
    end
end)
