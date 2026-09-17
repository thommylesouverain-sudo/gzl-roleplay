local screenW, screenH = guiGetScreenSize()
local svgCache = {}

local activeProgressBar = nil

local DEFAULT_RESTRICTED_CONTROLS = {
    "fire",
    "aim_weapon",
    "jump",
    "sprint",
    "crouch",
    "next_weapon",
    "previous_weapon"
}

local function getProgressScale()
    if getScreenScale then
        return getScreenScale()
    end
    local scale = math.min(screenW / 1920, screenH / 1080)
    return math.max(0.8, scale)
end

local function getProgressBarFont(size)
    local targetSize = math.max(8, math.floor(size or 11))
    if getFont then
        return getFont("bold", targetSize)
    end
    return "default-bold"
end

local function getSegmentPillSVG(w, h, r)
    local key = string.format("prog_seg_%dx%d_r%d", w, h, r)
    if not svgCache[key] or not isElement(svgCache[key]) then
        local svgData = string.format([[
            <svg width="%d" height="%d" viewBox="0 0 %d %d" fill="none" xmlns="http://www.w3.org/2000/svg">
                <rect width="%d" height="%d" rx="%.1f" ry="%.1f" fill="#ffffff"/>
            </svg>
        ]], w, h, w, h, w, h, r, r)
        svgCache[key] = svgCreate(w, h, svgData)
    end
    return svgCache[key]
end

local function restorePlayerControls()
    for _, ctrl in ipairs(DEFAULT_RESTRICTED_CONTROLS) do
        toggleControl(ctrl, true)
    end
    if activeProgressBar and activeProgressBar.disallowedControls then
        for _, ctrl in ipairs(activeProgressBar.disallowedControls) do
            toggleControl(ctrl, true)
        end
    end
    if activeProgressBar and activeProgressBar.freeze then
        toggleAllControls(true, true, true)
    end
end

local function applyPlayerControls(pb)
    if not pb then return end
    if pb.freeze then
        toggleAllControls(false, true, false)
    else
        local list = pb.disallowedControls or DEFAULT_RESTRICTED_CONTROLS
        for _, ctrl in ipairs(list) do
            toggleControl(ctrl, false)
        end
    end
end

function isProgressBarActive()
    return activeProgressBar ~= nil and (activeProgressBar.state == "running" or activeProgressBar.state == "finishing")
end

function getProgressBarData()
    if not activeProgressBar then return nil end
    return {
        text = activeProgressBar.text,
        duration = activeProgressBar.duration,
        progress = activeProgressBar.progress or 0,
        state = activeProgressBar.state
    }
end

function cancelProgressBar(reason)
    if not activeProgressBar then return false end
    reason = reason or "cancelled"

    restorePlayerControls()

    if activeProgressBar.animation then
        setPedAnimation(localPlayer, false)
    end

    local onCancelCb = activeProgressBar.onCancel
    activeProgressBar.state = "cancelled"
    activeProgressBar.finishTick = getTickCount()

    if type(onCancelCb) == "function" then
        pcall(onCancelCb, reason)
    end

    triggerEvent("progressbar:onCancel", localPlayer, reason)
    triggerServerEvent("progressbar:serverCancel", localPlayer, reason)

    return true
end

function startProgressBar(options)
    if type(options) == "string" then
        options = { text = options }
    elseif type(options) ~= "table" then
        options = {}
    end

    if isProgressBarActive() then
        cancelProgressBar("replaced")
    end

    local text = options.text or "İşlem yapılıyor..."
    local duration = tonumber(options.duration) or tonumber(options.time) or 2500
    if duration < 100 then duration = 100 end

    local segments = tonumber(options.segments) or 6
    if segments < 1 then segments = 1 end
    if segments > 24 then segments = 24 end

    local color = options.color or { 239, 68, 68 }
    if type(color) == "string" then
        if color == "green" then
            color = { 34, 197, 94 }
        elseif color == "blue" then
            color = { 56, 189, 248 }
        elseif color == "yellow" or color == "amber" then
            color = { 245, 158, 11 }
        else
            color = { 239, 68, 68 }
        end
    end

    local now = getTickCount()
    local pb = {
        text = text,
        duration = duration,
        startTime = now,
        endTime = now + duration,
        segments = segments,
        color = color,
        bgColor = options.bgColor or { 255, 255, 255, 55 },
        freeze = options.freeze == true,
        disallowedControls = options.disallowedControls or DEFAULT_RESTRICTED_CONTROLS,
        animation = options.animation,
        canCancel = options.canCancel ~= false,
        onFinish = options.onFinish,
        onCancel = options.onCancel,
        state = "running",
        alpha = 0,
        progress = 0
    }

    applyPlayerControls(pb)

    if pb.animation and type(pb.animation) == "table" then
        local block = pb.animation.dict or pb.animation.block or "FOOD"
        local anim = pb.animation.anim or pb.animation.name or "EAT_Burger"
        local time = pb.animation.time or -1
        local loop = pb.animation.loop ~= false
        local updatePos = pb.animation.updatePos == true
        setPedAnimation(localPlayer, block, anim, time, loop, updatePos, false, false)
    end

    activeProgressBar = pb
    triggerEvent("progressbar:onStart", localPlayer, text, duration)

    return true
end

addEvent("ui:startProgressBar", true)
addEventHandler("ui:startProgressBar", root, function(options)
    startProgressBar(options)
end)

addEvent("ui:cancelProgressBar", true)
addEventHandler("ui:cancelProgressBar", root, function(reason)
    cancelProgressBar(reason)
end)

addEventHandler("onClientKey", root, function(button, press)
    if not press then return end
    if isProgressBarActive() and activeProgressBar and activeProgressBar.canCancel then
        if button == "backspace" or button == "x" then
            cancelProgressBar("user_cancel")
        end
    end
end)

addEventHandler("onClientPlayerWasted", localPlayer, function()
    if isProgressBarActive() then
        cancelProgressBar("player_died")
    end
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    if isProgressBarActive() then
        restorePlayerControls()
    end
    for _, svg in pairs(svgCache) do
        if isElement(svg) then destroyElement(svg) end
    end
    svgCache = {}
end)

addEventHandler("onClientRender", root, function()
    if not activeProgressBar then return end

    local now = getTickCount()
    local pb = activeProgressBar

    if pb.state == "running" then
        local elapsed = now - pb.startTime
        local ratio = math.max(0, math.min(1, elapsed / pb.duration))
        pb.progress = ratio

        if pb.alpha < 255 then
            pb.alpha = math.min(255, pb.alpha + 24)
        end

        if elapsed >= pb.duration then
            pb.progress = 1
            pb.state = "finishing"
            pb.finishTick = now
            restorePlayerControls()

            if pb.animation then
                setPedAnimation(localPlayer, false)
            end

            local onFinishCb = pb.onFinish
            if type(onFinishCb) == "function" then
                pcall(onFinishCb)
            end
            triggerEvent("progressbar:onFinish", localPlayer, pb.text)
            triggerServerEvent("progressbar:serverFinish", localPlayer, pb.text)
        end

    elseif pb.state == "finishing" then
        pb.progress = 1
        local postElapsed = now - pb.finishTick
        if postElapsed > 120 then
            pb.alpha = math.max(0, pb.alpha - 30)
            if pb.alpha <= 0 then
                activeProgressBar = nil
                return
            end
        end

    elseif pb.state == "cancelled" then
        pb.alpha = math.max(0, pb.alpha - 35)
        if pb.alpha <= 0 then
            activeProgressBar = nil
            return
        end
    end

    if pb.alpha <= 0 then return end

    local scale = getProgressScale()
    local alpha = math.floor(pb.alpha)
    local pct = math.floor(pb.progress * 100)

    local totalWidth = math.floor(270 * scale)
    local barHeight = math.max(6, math.floor(7 * scale))
    local segmentCount = pb.segments or 6
    local gap = math.max(4, math.floor(6 * scale))

    local totalGaps = (segmentCount - 1) * gap
    local segWidth = math.floor((totalWidth - totalGaps) / segmentCount)
    totalWidth = segWidth * segmentCount + totalGaps

    local startX = math.floor((screenW - totalWidth) / 2)
    local barY = math.floor(screenH - (64 * scale))
    local textY = math.floor(barY - (22 * scale))
    local fontSize = math.max(9, math.floor(11 * scale))
    local font = getProgressBarFont(fontSize)

    local shadowAlpha = math.floor(alpha * 0.75)
    local textAlpha = alpha

    local leftText = pb.text or ""
    local rightText = string.format("%d%%", pct)

    dxDrawText(leftText, startX + 1, textY + 1, startX + totalWidth + 1, barY + 1, tocolor(0, 0, 0, shadowAlpha), 1, font, "left", "top", false, false, true, false)
    dxDrawText(leftText, startX, textY, startX + totalWidth, barY, tocolor(255, 255, 255, textAlpha), 1, font, "left", "top", false, false, true, false)

    dxDrawText(rightText, startX + 1, textY + 1, startX + totalWidth + 1, barY + 1, tocolor(0, 0, 0, shadowAlpha), 1, font, "right", "top", false, false, true, false)
    dxDrawText(rightText, startX, textY, startX + totalWidth, barY, tocolor(255, 255, 255, textAlpha), 1, font, "right", "top", false, false, true, false)

    local segRadius = math.floor(barHeight / 2)

    local cr, cg, cb = pb.color[1] or 239, pb.color[2] or 68, pb.color[3] or 68
    local bgR = pb.bgColor[1] or 255
    local bgG = pb.bgColor[2] or 255
    local bgB = pb.bgColor[3] or 255
    local bgA = math.floor(alpha * ((pb.bgColor[4] or 55) / 255))

    for i = 1, segmentCount do
        local segX = startX + (i - 1) * (segWidth + gap)

        drawRoundedRectangle(segX, barY, segWidth, barHeight, segRadius, tocolor(bgR, bgG, bgB, bgA), true)

        local segStart = (i - 1) / segmentCount
        local segEnd = i / segmentCount

        if pb.progress >= segEnd then

            drawRoundedRectangle(segX, barY, segWidth, barHeight, segRadius, tocolor(cr, cg, cb, alpha), true)
        elseif pb.progress > segStart then

            local segRatio = (pb.progress - segStart) / (segEnd - segStart)
            local fillW = math.max(barHeight, math.floor(segWidth * segRatio))
            fillW = math.min(segWidth, fillW)
            drawRoundedRectangle(segX, barY, fillW, barHeight, segRadius, tocolor(cr, cg, cb, alpha), true)
        end
    end
end)
