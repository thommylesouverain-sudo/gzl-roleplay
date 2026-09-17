
PDRender = {}

function PDRender.draw()

    if PDClient.panicAlert then
        local now = getTickCount()
        if (now - PDClient.panicAlert.startTick) < 15000 then
            local sw, sh = PDGeometry.screenW, PDGeometry.screenH
            local boxW = 340
            local boxH = 64
            local boxX = sw - boxW - 24
            local boxY = sh - boxH - 24

            local alpha = (math.floor(now / 400) % 2 == 0) and 255 or 180
            exports.aura_ui:uiDrawRectangle(boxX, boxY, boxW, boxH, tocolor(220, 38, 38, alpha))
            exports.aura_ui:uiDrawText("⚠ 10-99 ACİL DESTEK ÇAĞRISI ⚠", boxX, boxY + 8, boxX + boxW, boxY + 28, tocolor(255, 255, 255, 255), 1.0, "default-bold", "center", "center")
            exports.aura_ui:uiDrawText("Memur: " .. PDClient.panicAlert.officerName .. " (GPS İşaretlendi)", boxX, boxY + 30, boxX + boxW, boxY + 54, tocolor(255, 255, 255, 255), 0.9, "default-bold", "center", "center")
        else
            PDClient.panicAlert = nil
        end
    end

    if not PDClient.isOpen then return end

    local t = PDGeometry.tablet
    local colors = PDTheme.colors
    local fontScale = PDGeometry.scale

    exports.aura_ui:uiDrawRectangle(t.x - 2, t.y - 2, t.w + 4, t.h + 4, colors.tabletBorder)
    exports.aura_ui:uiDrawRectangle(t.x, t.y, t.w, t.h, colors.tabletBg)

    local hd = t.header
    exports.aura_ui:uiDrawRectangle(hd.x, hd.y, hd.w, hd.h, colors.headerBg)
    exports.aura_ui:uiDrawRectangle(hd.x, hd.y + hd.h - 1, hd.w, 1, colors.separator)

    exports.aura_ui:uiDrawText("★ LOS SANTOS POLICE DEPARTMENT - MDC V2.0", hd.x + 20, hd.y, hd.x + 400, hd.y + hd.h, colors.textPrimary, fontScale * 1.05, "default-bold", "left", "center")

    local offInfo = (PDClient.officer.name or "Memur") .. " | " .. (PDClient.officer.status or "10-8")
    local offStatusCol = (PDClient.officer.status == "10-8" and colors.accentGreen) or (PDClient.officer.status == "10-99" and colors.accentRed or colors.accentOrange)
    exports.aura_ui:uiDrawText(offInfo, hd.x + hd.w - 300, hd.y, hd.x + hd.w - 50, hd.y + hd.h, offStatusCol, fontScale * 0.95, "default-bold", "right", "center")

    local isCloseHover = PDGeometry.isCursorIn(hd.x + hd.w - 36, hd.y + 16, 24, 24)
    local closeCol = isCloseHover and colors.accentRed or colors.textDim
    exports.aura_ui:uiDrawText("✕", hd.x + hd.w - 36, hd.y + 16, hd.x + hd.w - 12, hd.y + 40, closeCol, fontScale * 1.1, "default-bold", "center", "center")

    local sb = t.sidebar
    exports.aura_ui:uiDrawRectangle(sb.x, sb.y, sb.w, sb.h, colors.sidebarBg)
    exports.aura_ui:uiDrawRectangle(sb.x + sb.w - 1, sb.y, 1, sb.h, colors.separator)

    local tabH = 48
    local curTabY = sb.y + 16

    local tabs = {
        { id = "dashboard", icon = "📊", label = "Genel Durum" },
        { id = "citizen", icon = "👤", label = "Vatandaş & Sicil" },
        { id = "vehicle", icon = "🚗", label = "Plaka & BOLO" },
        { id = "penal", icon = "⚖", label = "Ceza Kanunu" }
    }

    for _, tab in ipairs(tabs) do
        local isActive = (PDClient.activeTab == tab.id)
        local isHover = Components.drawTabButton(sb.x, curTabY, sb.w - 1, tabH, tab.icon, tab.label, isActive, fontScale)
        if isHover and getKeyState("mouse1") and not PDClient.clickDebounce then
            PDClient.activeTab = tab.id
            PDClient.scrollOffset = 0
            PDClient.clickDebounce = true
            setTimer(function() PDClient.clickDebounce = false end, 180, 1)
        end
        curTabY = curTabY + tabH + 4
    end

    local panicY = sb.y + sb.h - 58
    local isPanicHover = PDGeometry.isCursorIn(sb.x + 14, panicY, sb.w - 28, 44)
    local panicBg = isPanicHover and colors.panicBtnHover or colors.panicBtn
    exports.aura_ui:uiDrawRectangle(sb.x + 14, panicY, sb.w - 28, 44, panicBg)
    exports.aura_ui:uiDrawText("🚨 10-99 PANİK BUTONU", sb.x + 14, panicY, sb.x + sb.w - 14, panicY + 44, colors.textPrimary, fontScale * 0.9, "default-bold", "center", "center")

    if isPanicHover and getKeyState("mouse1") and not PDClient.clickDebounce then
        PDClient.triggerPanic()
        PDClient.clickDebounce = true
        setTimer(function() PDClient.clickDebounce = false end, 1000, 1)
    end

    local ct = t.content
    exports.aura_ui:uiDrawRectangle(ct.x, ct.y, ct.w, ct.h, colors.contentBg)

    if PDClient.activeTab == "dashboard" then
        Views.drawDashboard(ct.x, ct.y, ct.w, ct.h, PDClient, fontScale)
    elseif PDClient.activeTab == "citizen" then
        Views.drawCitizenQuery(ct.x, ct.y, ct.w, ct.h, PDClient, fontScale)
    elseif PDClient.activeTab == "vehicle" then
        Views.drawVehicleQuery(ct.x, ct.y, ct.w, ct.h, PDClient, fontScale)
    elseif PDClient.activeTab == "penal" then
        Views.drawPenalCode(ct.x, ct.y, ct.w, ct.h, PDClient, fontScale)
    end
end

addEventHandler("onClientRender", root, PDRender.draw)

addEventHandler("onClientResourceStart", resourceRoot, function()
    PDGeometry.updateMetrics()
end)

addEventHandler("onClientRestore", root, function()
    PDGeometry.updateMetrics()
end)