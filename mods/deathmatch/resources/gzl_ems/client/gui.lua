local screenW, screenH = guiGetScreenSize()
local baseW, baseH = 1920, 1080
local scale = math.max(0.85, math.min(screenW / baseW, screenH / baseH))

local svgCache = {}

-- Surfaces are rendered by AURA; ECG and medical state remain local.

local fontTitle = nil
local fontSub = nil
local fontTimer = nil
local fontsLoaded = false

local function initFonts()
    if fontsLoaded then return end
    fontsLoaded = true
    if exports.gzl_ui and exports.gzl_ui.getFont then
        fontTitle = exports.gzl_ui:getFont("bold", math.floor(11.5 * scale))
        fontSub = exports.gzl_ui:getFont("medium", math.floor(9.5 * scale))
        fontTimer = exports.gzl_ui:getFont("heavy", math.floor(18 * scale))
    end
    if not fontTitle or not isElement(fontTitle) then fontTitle = "default-bold" end
    if not fontSub or not isElement(fontSub) then fontSub = "default" end
    if not fontTimer or not isElement(fontTimer) then fontTimer = "default-bold" end
end

local function getECGValue(phase)
    local p = phase % 1.0
    if p >= 0.20 and p < 0.28 then
        return math.sin((p - 0.20) / 0.08 * math.pi) * 0.20
    elseif p >= 0.35 and p < 0.39 then
        return -math.sin((p - 0.35) / 0.04 * math.pi) * 0.16
    elseif p >= 0.39 and p < 0.46 then
        return math.sin((p - 0.39) / 0.07 * math.pi) * 1.00
    elseif p >= 0.46 and p < 0.51 then
        return -math.sin((p - 0.46) / 0.05 * math.pi) * 0.32
    elseif p >= 0.60 and p < 0.74 then
        return math.sin((p - 0.60) / 0.14 * math.pi) * 0.25
    end
    return 0
end

addEventHandler("onClientRender", root, function()
    if not isPlayerInComa() then return end

    initFonts()

    local now = getTickCount()
    local remSec = getDeathTimeRemaining()
    local holdProg = getHoldProgress()
    local cooldownSec = getDistressCooldownRemaining()

    exports.aura_ui:uiDrawRectangle(0, 0, screenW, screenH, tocolor(5, 8, 14, 160))

    local pulseRaw = math.sin(now / ((remSec > 0) and 400 or 800))
    local pulseAlpha = math.floor(math.max(0, pulseRaw) * 28)
    if pulseAlpha > 0 then
        exports.aura_ui:uiDrawRectangle(0, 0, screenW, screenH, tocolor(180, 20, 20, pulseAlpha))
    end

    local panelW = math.floor(540 * scale)
    local panelH = math.floor(155 * scale)
    local panelX = math.floor((screenW - panelW) / 2)
    local panelY = math.floor(screenH - panelH - (50 * scale))

    exports.aura_ui:uiDrawPanel(panelX,panelY,panelW,panelH,12)

    local heartScale = 1.0 + (math.max(0, pulseRaw) * 0.15)
    local heartColor = (remSec > 0) and tocolor(239, 68, 68, 255) or tocolor(148, 163, 184, 180)
    local heartX = panelX + math.floor(20 * scale)
    local heartY = panelY + math.floor(16 * scale)

    exports.aura_ui:uiDrawText("♥", heartX, heartY, heartX + 22, heartY + 22, heartColor, 1.5 * scale * heartScale, "default-bold", "center", "center")

    local titleX = panelX + math.floor(50 * scale)
    local titleY = panelY + math.floor(14 * scale)
    local titleText = (remSec > 0) and "AĞIR YARALI / BİLİNÇ KAYBI" or "BİLİNÇ TAMAMEN KAPANDI"
    local subText = (remSec > 0) and "Nabız zayıf, kan kaybı devam ediyor... Tıbbi yardım bekleyin." or "Hayatta kalma süresi tükendi. Hastaneye sevk olabilirsiniz."
    local titleColor = (remSec > 0) and tocolor(248, 250, 252, 255) or tocolor(248, 113, 113, 255)

    exports.aura_ui:uiDrawText(titleText, titleX, titleY, panelX + panelW - 120, titleY + 18, titleColor, 1.0, fontTitle, "left", "center")
    exports.aura_ui:uiDrawText(subText, titleX, titleY + 18, panelX + panelW - 120, titleY + 34, tocolor(148, 163, 184, 210), 1.0, fontSub, "left", "center")

    local minutes = math.floor(remSec / 60)
    local seconds = remSec % 60
    local timerStr = string.format("%02d:%02d", minutes, seconds)
    local timerColor = (remSec > 30) and tocolor(56, 189, 248, 255) or ((remSec > 0) and tocolor(239, 68, 68, 255) or tocolor(148, 163, 184, 200))
    local timerX = panelX + panelW - math.floor(95 * scale)
    local timerY = panelY + math.floor(14 * scale)

    exports.aura_ui:uiDrawText(timerStr, timerX, timerY, timerX + math.floor(75 * scale), timerY + math.floor(32 * scale), timerColor, 1.0, fontTimer, "right", "center")

    local ecgW = panelW - math.floor(40 * scale)
    local ecgH = math.floor(24 * scale)
    local ecgX = panelX + math.floor(20 * scale)
    local ecgMidY = panelY + math.floor(68 * scale)

    exports.aura_ui:uiDrawRectangle(ecgX, ecgMidY, ecgW, 1, tocolor(255, 255, 255, 25))

    if remSec > 0 then
        local step = 6
        local timeOffset = now * 0.00065
        local waveColor = tocolor(239, 68, 68, 230)

        for i = 0, ecgW - step, step do
            local phase1 = (i / ecgW) + timeOffset
            local phase2 = ((i + step) / ecgW) + timeOffset

            local v1 = getECGValue(phase1)
            local v2 = getECGValue(phase2)

            if v1 ~= 0 or v2 ~= 0 then
                local y1 = ecgMidY - (v1 * (ecgH * 0.55))
                local y2 = ecgMidY - (v2 * (ecgH * 0.55))
                dxDrawLine(ecgX + i, y1, ecgX + i + step, y2, waveColor, 1.8)
            end
        end
    else

        exports.aura_ui:uiDrawRectangle(ecgX, ecgMidY, ecgW, 1, tocolor(239, 68, 68, 160))
    end

    local btnW = math.floor((panelW - math.floor(48 * scale)) / 2)
    local btnH = math.floor(36 * scale)
    local btnY = panelY + panelH - btnH - math.floor(14 * scale)

    local btnGX = panelX + math.floor(20 * scale)
    local gText = (cooldownSec > 0) and string.format("[G] SİNYAL GÖNDERİLDİ (%ds)", cooldownSec) or "[G] ACİL YARDIM ÇAĞIR (EMS)"
    local gBg1 = (cooldownSec > 0) and "#161e2e" or "#0e2439"
    local gBg2 = (cooldownSec > 0) and "#0f1624" or "#091724"
    local gStroke = (cooldownSec > 0) and "#334155" or "#0284c7"
    local gTextColor = (cooldownSec > 0) and tocolor(148, 163, 184, 190) or tocolor(56, 189, 248, 255)

    exports.aura_ui:uiDrawButtonSurface(btnGX,btnY,btnW,btnH,8,"info",cooldownSec > 0 and "normal" or "hover")
    exports.aura_ui:uiDrawText(gText, btnGX, btnY, btnGX + btnW, btnY + btnH, gTextColor, 1.0, fontSub, "center", "center")

    local btnEX = btnGX + btnW + math.floor(8 * scale)
    local eText, eBg1, eBg2, eStroke, eTextColor

    if remSec > 0 then
        eText = string.format("YENİDEN DOĞMA: %02d:%02d", minutes, seconds)
        eBg1 = "#121824"
        eBg2 = "#090d16"
        eStroke = "#1e293b"
        eTextColor = tocolor(100, 116, 139, 180)
    else
        if holdProg > 0 then
            eText = string.format("[E] HAZIRLANIYOR... %%%d", math.floor(holdProg * 100))
            eBg1 = "#14532d"
            eBg2 = "#052e16"
            eStroke = "#22c55e"
            eTextColor = tocolor(74, 222, 128, 255)
        else
            eText = "[E] BASILI TUT — HASTANE ($150)"
            eBg1 = "#27272a"
            eBg2 = "#18181b"
            eStroke = "#eab308"
            eTextColor = tocolor(250, 204, 21, 255)
        end
    end

    exports.aura_ui:uiDrawButtonSurface(btnEX,btnY,btnW,btnH,8,"danger","normal")

    if holdProg > 0 then
        local fillW = math.floor((btnW - 4) * holdProg)
        exports.aura_ui:uiDrawRectangle(btnEX + 2, btnY + 2, fillW, btnH - 4, tocolor(34, 197, 94, 160))
    end

    exports.aura_ui:uiDrawText(eText, btnEX, btnY, btnEX + btnW, btnY + btnH, eTextColor, 1.0, fontSub, "center", "center")
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    for _, svg in pairs(svgCache) do
        if isElement(svg) then
            destroyElement(svg)
        end
    end
    svgCache = {}
end)