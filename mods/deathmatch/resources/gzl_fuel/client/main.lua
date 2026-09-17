local screenW, screenH = guiGetScreenSize()
local scale = math.min(1, math.max(0.62, math.min(screenW / 1920, screenH / 1080)))
local panelW = math.floor(1180 * scale)
local panelH = math.floor(760 * scale)
local panelX = math.floor((screenW - panelW) / 2)
local panelY = math.floor((screenH - panelH) / 2)
local sidebarW = math.floor(214 * scale)
local staticTarget = nil
local uiResource = nil
local uiReady = false
local worldElements = {}
local fonts = {}
local hitboxes = {}
local hitboxCount = 0

local colors = {
    background = tocolor(7, 10, 16, 226),
    panel = tocolor(11, 15, 23, 248),
    card = tocolor(18, 22, 32, 232),
    cardSoft = tocolor(23, 29, 42, 205),
    border = tocolor(255, 255, 255, 18),
    borderStrong = tocolor(255, 255, 255, 32),
    text = tocolor(244, 247, 252, 255),
    muted = tocolor(144, 157, 177, 235),
    faint = tocolor(100, 113, 134, 210),
    amber = tocolor(245, 158, 11, 255),
    amberSoft = tocolor(245, 158, 11, 32),
    cyan = tocolor(56, 189, 248, 255),
    mint = tocolor(45, 212, 191, 255),
    green = tocolor(16, 185, 129, 255),
    red = tocolor(244, 63, 94, 255),
    whiteSoft = tocolor(255, 255, 255, 10)
}

local state = {
    open = false,
    loading = false,
    stationId = nil,
    nearestStationId = nil,
    data = nil,
    tab = "fuel",
    selectedLiters = 5,
    orderAmount = Config.StockOrderStep,
    withdrawAmount = 1000,
    priceDraft = Config.MinFuelPrice,
    draggingSlider = false,
    fueling = false,
    fuelingData = nil,
    sellConfirmUntil = 0
}

local tabs = {
    { id = "fuel", label = "Yakıt Dolumu", icon = "water" },
    { id = "overview", label = "İşletme", icon = "monitor" },
    { id = "operations", label = "Operasyon", icon = "wrench" },
    { id = "staff", label = "Personel", icon = "badge" }
}

local logLabels = {
    fuel_sale = "Yakıt satışı",
    wage = "Personel ödemesi",
    business_purchase = "İşletme satın alındı",
    business_sale = "İşletme devredildi",
    price_change = "Litre fiyatı değişti",
    stock_order = "Stok siparişi",
    withdraw = "Kasadan çekim",
    hire_manager = "Müdür işe alındı",
    hire_cashier = "Kasiyer işe alındı",
    employee_removed = "Personel çıkarıldı"
}

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function round(value, precision)
    local factor = 10 ^ (precision or 0)
    return math.floor(value * factor + 0.5) / factor
end

local function S(value)
    return math.floor(value * scale + 0.5)
end

local function hasUiExport(name)
    return uiReady and exports.gzl_ui and type(exports.gzl_ui[name]) == "function"
end

local function refreshUiState()
    uiResource = getResourceFromName("gzl_ui")
    uiReady = uiResource and getResourceState(uiResource) == "running" or false
    return uiReady
end

local function notify(message, kind)
    if hasUiExport("showToast") then
        exports.gzl_ui:showToast(message, kind or "info", 4500)
    else
        outputChatBox("[GZL Fuel] " .. tostring(message), kind == "error" and 244 or 235, kind == "success" and 210 or 185, 120)
    end
end

local function rounded(x, y, w, h, radius, color)
    if hasUiExport("drawRoundedRectangle") then
        exports.gzl_ui:drawRoundedRectangle(math.floor(x), math.floor(y), math.floor(w), math.floor(h), math.max(2, math.floor(radius)), color)
    end
end

local function glass(x, y, w, h, radius)
    if hasUiExport("drawGlassPanel") then
        exports.gzl_ui:drawGlassPanel(math.floor(x), math.floor(y), math.floor(w), math.floor(h), math.max(2, math.floor(radius)))
    end
end

local function circle(cx, cy, radius, color)
    if hasUiExport("drawCircle") then
        exports.gzl_ui:drawCircle(math.floor(cx), math.floor(cy), math.floor(radius), color)
    end
end

local function icon(name, x, y, size, color)
    if hasUiExport("drawIconSVG") then
        exports.gzl_ui:drawIconSVG(name, math.floor(x), math.floor(y), math.floor(size), color)
    end
end

local function loadFonts()
    if not hasUiExport("getFont") then return false end
    fonts.hero = exports.gzl_ui:getFont("heavy", math.max(15, S(24)))
    fonts.title = exports.gzl_ui:getFont("heavy", math.max(13, S(18)))
    fonts.heading = exports.gzl_ui:getFont("bold", math.max(11, S(14)))
    fonts.body = exports.gzl_ui:getFont("medium", math.max(9, S(11)))
    fonts.small = exports.gzl_ui:getFont("medium", math.max(8, S(9)))
    fonts.badge = exports.gzl_ui:getFont("bold", math.max(8, S(9)))
    fonts.metric = exports.gzl_ui:getFont("heavy", math.max(13, S(19)))
    return true
end

local function destroyStaticTarget()
    if staticTarget and isElement(staticTarget) then destroyElement(staticTarget) end
    staticTarget = nil
end

local function createStaticTarget()
    destroyStaticTarget()
    if not hasUiExport("drawGlassPanel") or not hasUiExport("drawRoundedRectangle") then return false end
    staticTarget = dxCreateRenderTarget(panelW, panelH, true)
    if not staticTarget then return false end
    dxSetRenderTarget(staticTarget, true)
    glass(0, 0, panelW, panelH, S(22))
    rounded(S(12), S(12), sidebarW - S(16), panelH - S(24), S(18), tocolor(8, 12, 19, 238))
    rounded(sidebarW + S(1), S(28), S(1), panelH - S(56), S(1), colors.border)
    dxSetRenderTarget()
    return true
end

local function clearHitboxes()
    for index = 1, hitboxCount do
        local item = hitboxes[index]
        if item then
            item.action = nil
            item.data = nil
        end
    end
    hitboxCount = 0
end

local function addHitbox(action, x, y, w, h, data, enabled)
    if enabled == false then return end
    hitboxCount = hitboxCount + 1
    local item = hitboxes[hitboxCount] or {}
    item.action = action
    item.x = x
    item.y = y
    item.w = w
    item.h = h
    item.data = data
    hitboxes[hitboxCount] = item
end

local function isInside(x, y, box)
    return x >= box.x and x <= box.x + box.w and y >= box.y and y <= box.y + box.h
end

local function formatMoney(value)
    local amount = tostring(math.floor(tonumber(value) or 0))
    while true do
        local changed
        amount, changed = string.gsub(amount, "^(-?%d+)(%d%d%d)", "%1.%2")
        if changed == 0 then break end
    end
    return "$" .. amount
end

local function formatLiters(value)
    return string.format("%.1f L", tonumber(value) or 0)
end

local function fitText(value, maximumWidth, font)
    local text = tostring(value or "")
    if exports.aura_ui:uiTextWidth(text, 1, font) <= maximumWidth then return text end
    local length = utf8 and utf8.len and utf8.len(text) or string.len(text)
    while length and length > 1 do
        local candidate = utf8 and utf8.sub and utf8.sub(text, 1, length) or string.sub(text, 1, length)
        candidate = candidate .. "..."
        if exports.aura_ui:uiTextWidth(candidate, 1, font) <= maximumWidth then return candidate end
        length = length - 1
    end
    return "..."
end

local function drawCard(x, y, w, h, radius, emphasized)
    rounded(x, y, w, h, radius, emphasized and colors.borderStrong or colors.border)
    rounded(x + 1, y + 1, w - 2, h - 2, math.max(2, radius - 1), emphasized and colors.cardSoft or colors.card)
end

local function drawProgress(x, y, w, h, progress, accent)
    progress = clamp(tonumber(progress) or 0, 0, 1)
    rounded(x, y, w, h, h / 2, tocolor(255, 255, 255, 14))
    if progress > 0 then
        rounded(x, y, math.max(h, w * progress), h, h / 2, accent or colors.amber)
    end
end

local function drawButton(action, label, x, y, w, h, theme, buttonIcon, enabled, data)
    enabled = enabled ~= false
    if hasUiExport("drawGlassButton") then
        exports.gzl_ui:drawGlassButton("fuel_" .. tostring(action) .. "_" .. tostring(data or ""), label, x, y, w, h, {
            radius = S(10),
            font = fonts.badge,
            theme = theme or "blue",
            icon = buttonIcon,
            iconSize = S(15),
            disabled = not enabled
        })
    else
        drawCard(x, y, w, h, S(10), enabled)
        exports.aura_ui:uiDrawText(label, x, y, x + w, y + h, enabled and colors.text or colors.faint, 1, fonts.badge or "default-bold", "center", "center")
    end
    addHitbox(action, x, y, w, h, data, enabled)
end

local function drawPill(label, x, y, w, color, pillIcon)
    rounded(x, y, w, S(28), S(14), tocolor(255, 255, 255, 10))
    if pillIcon then icon(pillIcon, x + S(9), y + S(7), S(14), color) end
    exports.aura_ui:uiDrawText(label, x + (pillIcon and S(29) or S(10)), y, x + w - S(9), y + S(28), color, 1, fonts.badge, "left", "center", true)
end

local function getStationConfig(stationId)
    return getFuelStationConfig(stationId)
end

local function isTabAvailable(tabId)
    if tabId == "fuel" or tabId == "overview" then return true end
    if not state.data or not state.data.access then return false end
    if tabId == "operations" then return state.data.access.canManage end
    if tabId == "staff" then return state.data.access.canViewBusiness end
    return false
end

local function validateActiveTab()
    if not isTabAvailable(state.tab) then state.tab = "fuel" end
end

local function updateLiveVehicle()
    local data = state.data
    if not data or not data.vehicle or not isElement(data.vehicle.element) then return end
    local vehicle = data.vehicle.element
    local fuel = tonumber(getElementData(vehicle, Config.FuelElementData)) or data.vehicle.fuel or 0
    data.vehicle.fuel = clamp(fuel, 0, 100)
    data.vehicle.liters = data.vehicle.capacity * data.vehicle.fuel / 100
    data.vehicle.missingLiters = data.vehicle.capacity * (100 - data.vehicle.fuel) / 100
    data.vehicle.engineOn = getVehicleEngineState(vehicle)
    if not state.fueling then
        state.selectedLiters = clamp(state.selectedLiters, 0, math.max(0, data.vehicle.missingLiters))
    end
end

local function requestContext()
    if not state.stationId then return end
    state.loading = true
    triggerServerEvent("gzl_fuel:requestContext", resourceRoot, state.stationId)
end

function openFuelPanel(stationId)
    local config = getStationConfig(stationId)
    if not config then return false end
    refreshUiState()
    if not loadFonts() then
        notify("GZL UI kaynağı çalışmıyor.", "error")
        return false
    end
    if not staticTarget or not isElement(staticTarget) then createStaticTarget() end
    state.open = true
    state.loading = true
    state.stationId = config.id
    state.tab = "fuel"
    state.data = nil
    state.fueling = false
    state.fuelingData = nil
    state.sellConfirmUntil = 0
    setElementData(localPlayer, "gzl_fuel:isOpen", true, false)
    showCursor(true)
    pcall(guiSetInputMode, "no_binds_when_editing")
    requestContext()
    return true
end

function closeFuelPanel(stopFueling)
    if not state.open then return false end
    if stopFueling and state.fueling then
        triggerServerEvent("gzl_fuel:stopFueling", resourceRoot)
    end
    state.open = false
    state.loading = false
    state.draggingSlider = false
    state.data = nil
    state.stationId = nil
    state.fueling = false
    state.fuelingData = nil
    setElementData(localPlayer, "gzl_fuel:isOpen", false, false)
    setElementData(localPlayer, "gzl_fuel:lastClosedTick", getTickCount(), false)
    showCursor(false)
    if hasUiExport("setActiveEditBox") then exports.gzl_ui:setActiveEditBox(nil) end
    pcall(guiSetInputMode, "allow_binds")
    return true
end

function isFuelPanelOpen()
    return state.open
end

local function drawSidebar()
    local x = panelX + S(30)
    local y = panelY + S(34)
    circle(x + S(22), y + S(22), S(22), colors.amberSoft)
    icon("water", x + S(12), y + S(12), S(20), colors.amber)
    exports.aura_ui:uiDrawText("GZL", x + S(56), y - S(1), x + sidebarW - S(36), y + S(21), colors.text, 1, fonts.heading, "left", "center")
    exports.aura_ui:uiDrawText("FUEL OPERATIONS", x + S(56), y + S(19), x + sidebarW - S(36), y + S(40), colors.amber, 1, fonts.small, "left", "center")

    local itemY = panelY + S(116)
    for _, tab in ipairs(tabs) do
        if isTabAvailable(tab.id) then
            local active = state.tab == tab.id
            if active then
                rounded(panelX + S(24), itemY, sidebarW - S(38), S(48), S(12), tocolor(245, 158, 11, 26))
                rounded(panelX + S(24), itemY + S(8), S(3), S(32), S(2), colors.amber)
            end
            icon(tab.icon, panelX + S(42), itemY + S(15), S(18), active and colors.amber or colors.muted)
            exports.aura_ui:uiDrawText(tab.label, panelX + S(72), itemY, panelX + sidebarW - S(28), itemY + S(48), active and colors.text or colors.muted, 1, fonts.body, "left", "center")
            addHitbox("tab", panelX + S(24), itemY, sidebarW - S(38), S(48), tab.id, true)
            itemY = itemY + S(58)
        end
    end

    local statusY = panelY + panelH - S(115)
    rounded(panelX + S(28), statusY, sidebarW - S(46), S(56), S(12), tocolor(255, 255, 255, 8))
    circle(panelX + S(48), statusY + S(28), S(5), state.loading and colors.amber or colors.green)
    exports.aura_ui:uiDrawText(state.loading and "VERİLER ALINIYOR" or "SİSTEM ÇEVRİMİÇİ", panelX + S(62), statusY + S(7), panelX + sidebarW - S(28), statusY + S(28), state.loading and colors.amber or colors.green, 1, fonts.small, "left", "center")
    exports.aura_ui:uiDrawText("ESC  Kapat", panelX + S(62), statusY + S(27), panelX + sidebarW - S(28), statusY + S(48), colors.faint, 1, fonts.small, "left", "center")
end

local function drawHeader()
    local contentX = panelX + sidebarW + S(32)
    local contentW = panelW - sidebarW - S(56)
    local actionSize = S(40)
    local actionGap = S(9)
    local refreshW = S(92)
    local closeX = panelX + panelW - S(20) - actionSize
    local refreshX = closeX - actionGap - refreshW
    local stockW = S(124)
    local priceW = S(130)
    local stockX = refreshX - S(16) - stockW
    local priceX = stockX - S(10) - priceW
    local actionY = panelY + S(23)
    local pillY = panelY + S(29)
    local data = state.data
    local station = data and data.station or nil
    local config = getStationConfig(state.stationId)
    local title = station and station.name or config and config.name or "Benzin İstasyonu"
    local district = station and station.district or config and config.district or "Veriler hazırlanıyor"
    exports.aura_ui:uiDrawText(title, contentX, panelY + S(29), priceX - S(16), panelY + S(56), colors.text, 1, fonts.title, "left", "center", true)
    exports.aura_ui:uiDrawText(district, contentX, panelY + S(57), priceX - S(16), panelY + S(78), colors.muted, 1, fonts.small, "left", "center", true)
    if station then
        drawPill(string.format("$%.2f / L", station.price), priceX, pillY, priceW, colors.amber, "water")
        local stockColor = station.stock / station.maxStock <= 0.15 and colors.red or colors.mint
        drawPill(string.format("%%%d STOK", math.floor(station.stock / station.maxStock * 100)), stockX, pillY, stockW, stockColor, "cube")
    end
    drawButton("refresh", "Yenile", refreshX, actionY, refreshW, actionSize, "blue", "swap", true)
    drawButton("close_panel", "", closeX, actionY, actionSize, actionSize, "danger", "cross", true)
end

local function drawMetricCard(x, y, w, h, label, value, detail, metricIcon, accent)
    drawCard(x, y, w, h, S(14), false)
    circle(x + S(29), y + S(29), S(16), tocolor(255, 255, 255, 9))
    icon(metricIcon, x + S(20), y + S(20), S(18), accent)
    exports.aura_ui:uiDrawText(label, x + S(54), y + S(12), x + w - S(14), y + S(32), colors.muted, 1, fonts.small, "left", "center", true)
    exports.aura_ui:uiDrawText(value, x + S(18), y + S(46), x + w - S(18), y + S(78), colors.text, 1, fonts.metric, "left", "center", true)
    exports.aura_ui:uiDrawText(detail or "", x + S(18), y + S(80), x + w - S(18), y + h - S(10), accent, 1, fonts.small, "left", "center", true)
end

local function drawNoVehicle(x, y, w, h)
    drawCard(x, y, w, h, S(18), true)
    circle(x + w / 2, y + S(92), S(38), tocolor(56, 189, 248, 20))
    icon("car", x + w / 2 - S(18), y + S(74), S(36), colors.cyan)
    exports.aura_ui:uiDrawText("Araç algılanmadı", x + S(30), y + S(145), x + w - S(30), y + S(176), colors.text, 1, fonts.heading, "center", "center")
    exports.aura_ui:uiDrawText("Aracınızı pompa alanına yanaştırın ve sürücü koltuğundayken E tuşuna basın.", x + S(70), y + S(184), x + w - S(70), y + S(235), colors.muted, 1, fonts.body, "center", "top", true, true)
    drawPill("Sürücü koltuğu gerekli", x + w / 2 - S(98), y + S(258), S(196), colors.amber, "alert")
end

local function drawFuelingPanel(x, y, w, h)
    local progressData = state.fuelingData or {}
    local delivered = tonumber(progressData.delivered) or 0
    local target = math.max(0.1, tonumber(progressData.target) or state.selectedLiters)
    local paid = tonumber(progressData.paid) or 0
    drawCard(x, y, w, h, S(18), true)
    circle(x + S(52), y + S(54), S(27), tocolor(245, 158, 11, 25))
    icon("water", x + S(38), y + S(40), S(28), colors.amber)
    exports.aura_ui:uiDrawText("DOLUM DEVAM EDİYOR", x + S(94), y + S(24), x + w - S(30), y + S(53), colors.amber, 1, fonts.small, "left", "center")
    exports.aura_ui:uiDrawText(formatLiters(delivered) .. " / " .. formatLiters(target), x + S(94), y + S(48), x + w - S(30), y + S(82), colors.text, 1, fonts.hero, "left", "center")
    drawProgress(x + S(30), y + S(112), w - S(60), S(12), delivered / target, colors.amber)
    local percent = math.floor(clamp(delivered / target, 0, 1) * 100)
    exports.aura_ui:uiDrawText("%" .. tostring(percent), x + S(30), y + S(132), x + S(100), y + S(158), colors.muted, 1, fonts.badge, "left", "center")
    exports.aura_ui:uiDrawText("Ödenen " .. formatMoney(paid), x + S(100), y + S(132), x + w - S(30), y + S(158), colors.green, 1, fonts.badge, "right", "center")
    if progressData.attendant then
        drawPill("Görevli: " .. progressData.attendant, x + S(30), y + S(175), w - S(60), colors.cyan, "badge")
    else
        drawPill("Otomatik pompa hizmeti", x + S(30), y + S(175), w - S(60), colors.muted, "monitor")
    end
    drawButton("stop_fueling", "Dolumu Durdur", x + S(30), y + h - S(72), w - S(60), S(46), "danger", "cross", true)
end

local function getFuelMaximum()
    if not state.data or not state.data.vehicle then return 0 end
    return math.max(0, math.min(state.data.vehicle.missingLiters or 0, state.data.station.stock or 0))
end

local function setSelectedLiters(value)
    local maximum = getFuelMaximum()
    if maximum < 0.1 then
        state.selectedLiters = 0
    else
        state.selectedLiters = round(clamp(tonumber(value) or 0, math.min(1, maximum), maximum), 1)
    end
end

local function drawFuelTab(contentX, contentY, contentW, contentH)
    local data = state.data
    if not data or not data.vehicle then
        drawNoVehicle(contentX, contentY, contentW, contentH)
        return
    end
    updateLiveVehicle()
    local vehicle = data.vehicle
    local station = data.station
    local gap = S(12)
    local totalW = contentW
    local colW = (totalW - gap * 2) / 3
    local startX = contentX + (contentW - totalW) / 2
    local centerOne = startX + colW / 2
    local centerTwo = startX + colW + gap + colW / 2
    local centerThree = startX + (colW + gap) * 2 + colW / 2
    drawMetricCard(centerOne - colW / 2, contentY, colW, S(112), "MEVCUT YAKIT", "%" .. tostring(math.floor(vehicle.fuel)), formatLiters(vehicle.liters) .. " depoda", "water", vehicle.fuel <= 15 and colors.red or colors.amber)
    drawMetricCard(centerTwo - colW / 2, contentY, colW, S(112), "DEPO KAPASİTESİ", formatLiters(vehicle.capacity), vehicle.name, "car", colors.cyan)
    drawMetricCard(centerThree - colW / 2, contentY, colW, S(112), "LİTRE FİYATI", string.format("$%.2f", station.price), formatLiters(station.stock) .. " istasyon stoğu", "wallet", colors.green)

    local bodyY = contentY + S(128)
    local leftW = math.floor(contentW * 0.61)
    local rightX = contentX + leftW + gap
    local rightW = contentW - leftW - gap
    if state.fueling then
        drawFuelingPanel(contentX, bodyY, contentW, contentH - S(128))
        return
    end

    drawCard(contentX, bodyY, leftW, contentH - S(128), S(16), false)
    exports.aura_ui:uiDrawText("Dolum miktarı", contentX + S(24), bodyY + S(18), contentX + leftW - S(24), bodyY + S(46), colors.text, 1, fonts.heading, "left", "center")
    exports.aura_ui:uiDrawText("İhtiyacınız olan litreyi seçin", contentX + S(24), bodyY + S(46), contentX + leftW - S(24), bodyY + S(67), colors.muted, 1, fonts.small, "left", "center")
    exports.aura_ui:uiDrawText(formatLiters(state.selectedLiters), contentX + S(24), bodyY + S(86), contentX + leftW - S(24), bodyY + S(126), colors.amber, 1, fonts.hero, "left", "center")

    local sliderX = contentX + S(24)
    local sliderY = bodyY + S(143)
    local sliderW = leftW - S(48)
    local maximum = getFuelMaximum()
    local sliderProgress = maximum > 0 and state.selectedLiters / maximum or 0
    drawProgress(sliderX, sliderY, sliderW, S(10), sliderProgress, colors.amber)
    circle(sliderX + sliderW * sliderProgress, sliderY + S(5), S(9), colors.text)
    circle(sliderX + sliderW * sliderProgress, sliderY + S(5), S(5), colors.amber)
    addHitbox("fuel_slider", sliderX, sliderY - S(14), sliderW, S(38), nil, maximum > 0)
    exports.aura_ui:uiDrawText("1 L", sliderX, sliderY + S(20), sliderX + S(60), sliderY + S(42), colors.faint, 1, fonts.small, "left", "center")
    exports.aura_ui:uiDrawText(formatLiters(maximum), sliderX + sliderW - S(100), sliderY + S(20), sliderX + sliderW, sliderY + S(42), colors.faint, 1, fonts.small, "right", "center")

    local presetY = bodyY + S(211)
    local presetGap = S(9)
    local presetW = (sliderW - presetGap * 3) / 4
    drawButton("fuel_preset", "+5 L", sliderX, presetY, presetW, S(42), "blue", nil, maximum >= 1, 5)
    drawButton("fuel_preset", "+10 L", sliderX + (presetW + presetGap), presetY, presetW, S(42), "blue", nil, maximum >= 1, 10)
    drawButton("fuel_preset", "+25 L", sliderX + (presetW + presetGap) * 2, presetY, presetW, S(42), "blue", nil, maximum >= 1, 25)
    drawButton("fuel_full", "Doldur", sliderX + (presetW + presetGap) * 3, presetY, presetW, S(42), "green", nil, maximum >= 1)

    rounded(sliderX, bodyY + S(279), sliderW, S(1), S(1), colors.border)
    drawPill(vehicle.engineOn and "Motor açık" or "Motor kapalı", sliderX, bodyY + S(302), S(155), vehicle.engineOn and colors.red or colors.green, vehicle.engineOn and "alert" or "check")
    drawPill("Nakit " .. formatMoney(data.player.cash), sliderX + S(166), bodyY + S(302), sliderW - S(166), colors.mint, "wallet")

    drawCard(rightX, bodyY, rightW, contentH - S(128), S(16), true)
    exports.aura_ui:uiDrawText("İşlem Özeti", rightX + S(22), bodyY + S(18), rightX + rightW - S(22), bodyY + S(47), colors.text, 1, fonts.heading, "left", "center")
    local summaryY = bodyY + S(75)
    local labels = { "Seçilen yakıt", "Tahmini tutar", "Dolum sonrası", "Ödeme" }
    local values = {
        formatLiters(state.selectedLiters),
        formatMoney(math.ceil(state.selectedLiters * station.price)),
        "%" .. tostring(math.floor(clamp(vehicle.fuel + state.selectedLiters / vehicle.capacity * 100, 0, 100))),
        "Nakit"
    }
    for index = 1, #labels do
        local rowY = summaryY + (index - 1) * S(43)
        exports.aura_ui:uiDrawText(labels[index], rightX + S(22), rowY, rightX + rightW * 0.58, rowY + S(28), colors.muted, 1, fonts.small, "left", "center")
        exports.aura_ui:uiDrawText(values[index], rightX + rightW * 0.48, rowY, rightX + rightW - S(22), rowY + S(28), index == 2 and colors.amber or colors.text, 1, fonts.badge, "right", "center")
        if index < #labels then rounded(rightX + S(22), rowY + S(35), rightW - S(44), S(1), S(1), colors.border) end
    end
    local canFuel = state.selectedLiters >= 0.1 and not vehicle.engineOn and station.stock >= 0.1 and data.player.cash >= math.ceil(state.selectedLiters * station.price)
    local helper = vehicle.engineOn and "Dolum için motoru kapatın" or data.player.cash < math.ceil(state.selectedLiters * station.price) and "Yetersiz nakit bakiye" or station.stock < 0.1 and "İstasyon stoğu boş" or "Doluma hazır"
    exports.aura_ui:uiDrawText(helper, rightX + S(22), bodyY + contentH - S(226), rightX + rightW - S(22), bodyY + contentH - S(198), canFuel and colors.green or colors.red, 1, fonts.small, "center", "center")
    drawButton("start_fueling", "Dolumu Başlat", rightX + S(22), bodyY + contentH - S(190), rightW - S(44), S(48), "green", "water", canFuel)
end

local function drawPurchaseOverview(contentX, contentY, contentW, contentH)
    local data = state.data
    local station = data.station
    local owned = station.ownerId and station.ownerId > 0
    drawCard(contentX, contentY, contentW, contentH, S(18), true)
    circle(contentX + S(70), contentY + S(70), S(38), owned and tocolor(56, 189, 248, 20) or tocolor(245, 158, 11, 22))
    icon(owned and "shield" or "garage", contentX + S(50), contentY + S(50), S(40), owned and colors.cyan or colors.amber)
    exports.aura_ui:uiDrawText(owned and "Özel işletme" or "Yatırım fırsatı", contentX + S(126), contentY + S(30), contentX + contentW - S(36), contentY + S(62), owned and colors.cyan or colors.amber, 1, fonts.small, "left", "center")
    exports.aura_ui:uiDrawText(owned and station.ownerName or station.name, contentX + S(126), contentY + S(60), contentX + contentW - S(36), contentY + S(102), colors.text, 1, fonts.hero, "left", "center", true)
    exports.aura_ui:uiDrawText(owned and "Bu istasyonun yönetim ekranı yalnızca işletme sahibi ve yetkili personeline açıktır." or "İstasyonu satın alarak pompa fiyatını, yakıt stoğunu, işletme kasasını ve personeli yönetin.", contentX + S(126), contentY + S(106), contentX + contentW - S(50), contentY + S(160), colors.muted, 1, fonts.body, "left", "top", true, true)

    local cardsY = contentY + S(190)
    local gap = S(12)
    local totalW = contentW - S(48)
    local cardW = (totalW - gap * 2) / 3
    local startX = contentX + (contentW - totalW) / 2
    local centerOne = startX + (0 + 0.5) * (cardW + gap)
    local centerTwo = startX + (1 + 0.5) * (cardW + gap)
    local centerThree = startX + (2 + 0.5) * (cardW + gap)
    drawMetricCard(centerOne - cardW / 2, cardsY, cardW, S(120), "İŞLETME DEĞERİ", formatMoney(station.purchasePrice), "Tek seferlik satın alma", "bank", colors.amber)
    drawMetricCard(centerTwo - cardW / 2, cardsY, cardW, S(120), "MEVCUT STOK", formatLiters(station.stock), "%" .. tostring(math.floor(station.stock / station.maxStock * 100)) .. " kapasite", "cube", colors.mint)
    drawMetricCard(centerThree - cardW / 2, cardsY, cardW, S(120), "LİTRE FİYATI", string.format("$%.2f", station.price), "Aktif pompa tarifesi", "water", colors.cyan)

    if not owned then
        drawPill("Banka bakiyesi " .. formatMoney(data.player.bank), contentX + S(24), contentY + contentH - S(116), contentW - S(48), data.player.bank >= station.purchasePrice and colors.green or colors.red, "bank")
        drawButton("purchase_station", "İşletmeyi Satın Al", contentX + S(24), contentY + contentH - S(74), contentW - S(48), S(50), "green", "key", data.player.bank >= station.purchasePrice)
    else
        drawPill("İşletme sahibi: " .. station.ownerName, contentX + S(24), contentY + contentH - S(74), contentW - S(48), colors.cyan, "user")
    end
end

local function drawActivityList(x, y, w, h, logs)
    drawCard(x, y, w, h, S(16), false)
    exports.aura_ui:uiDrawText("Son Hareketler", x + S(20), y + S(14), x + w - S(20), y + S(42), colors.text, 1, fonts.heading, "left", "center")
    if not logs or #logs == 0 then
        exports.aura_ui:uiDrawText("Henüz işlem kaydı yok.", x + S(20), y + S(62), x + w - S(20), y + h - S(20), colors.muted, 1, fonts.body, "center", "center")
        return
    end
    local rowY = y + S(56)
    local rowH = S(48)
    local visible = math.min(#logs, 7)
    for index = 1, visible do
        local item = logs[index]
        local label = logLabels[item.event_type] or item.event_type or "İşlem"
        local accent = item.event_type == "fuel_sale" and colors.green or item.event_type == "withdraw" and colors.red or colors.cyan
        circle(x + S(30), rowY + rowH / 2, S(5), accent)
        exports.aura_ui:uiDrawText(fitText(label, w * 0.45, fonts.badge), x + S(46), rowY + S(3), x + w * 0.58, rowY + S(24), colors.text, 1, fonts.badge, "left", "center", true)
        exports.aura_ui:uiDrawText(fitText(item.actor_name or "Sistem", w * 0.45, fonts.small), x + S(46), rowY + S(23), x + w * 0.58, rowY + S(43), colors.muted, 1, fonts.small, "left", "center", true)
        local value = tonumber(item.liters) and tonumber(item.liters) > 0 and formatLiters(item.liters) or tonumber(item.amount) and tonumber(item.amount) > 0 and formatMoney(item.amount) or ""
        exports.aura_ui:uiDrawText(value, x + w * 0.58, rowY, x + w - S(18), rowY + rowH, accent, 1, fonts.badge, "right", "center")
        if index < visible then rounded(x + S(20), rowY + rowH - 1, w - S(40), S(1), S(1), colors.border) end
        rowY = rowY + rowH
    end
end

local function drawBusinessOverview(contentX, contentY, contentW, contentH)
    local data = state.data
    local station = data.station
    if not data.access.canViewBusiness then
        drawPurchaseOverview(contentX, contentY, contentW, contentH)
        return
    end
    local gap = S(12)
    local totalW = contentW
    local cardW = (totalW - gap * 3) / 4
    local startX = contentX + (contentW - totalW) / 2
    local metrics = {
        { "İŞLETME KASASI", formatMoney(station.balance), "Kullanılabilir", "wallet", colors.green },
        { "TOPLAM CİRO", formatMoney(station.totalRevenue), "Tüm zamanlar", "bank", colors.cyan },
        { "SATILAN YAKIT", formatLiters(station.totalLiters), "Tüm zamanlar", "water", colors.amber },
        { "MÜŞTERİ", tostring(station.totalCustomers), "Tamamlanan dolum", "user", colors.mint }
    }
    for index = 1, 4 do
        local centerX = startX + (index - 1) * (cardW + gap) + cardW / 2
        local metric = metrics[index]
        drawMetricCard(centerX - cardW / 2, contentY, cardW, S(112), metric[1], metric[2], metric[3], metric[4], metric[5])
    end
    local bodyY = contentY + S(128)
    local leftW = math.floor(contentW * 0.63)
    drawActivityList(contentX, bodyY, leftW, contentH - S(128), data.logs)
    local rightX = contentX + leftW + gap
    local rightW = contentW - leftW - gap
    drawCard(rightX, bodyY, rightW, contentH - S(128), S(16), true)
    exports.aura_ui:uiDrawText("Operasyon Durumu", rightX + S(20), bodyY + S(14), rightX + rightW - S(20), bodyY + S(42), colors.text, 1, fonts.heading, "left", "center")
    local stockRatio = station.stock / station.maxStock
    exports.aura_ui:uiDrawText("Yakıt stoğu", rightX + S(20), bodyY + S(66), rightX + rightW - S(20), bodyY + S(88), colors.muted, 1, fonts.small, "left", "center")
    exports.aura_ui:uiDrawText("%" .. tostring(math.floor(stockRatio * 100)), rightX + S(20), bodyY + S(66), rightX + rightW - S(20), bodyY + S(88), stockRatio <= 0.15 and colors.red or colors.amber, 1, fonts.badge, "right", "center")
    drawProgress(rightX + S(20), bodyY + S(98), rightW - S(40), S(9), stockRatio, stockRatio <= 0.15 and colors.red or colors.amber)
    exports.aura_ui:uiDrawText(formatLiters(station.stock) .. " / " .. formatLiters(station.maxStock), rightX + S(20), bodyY + S(116), rightX + rightW - S(20), bodyY + S(139), colors.faint, 1, fonts.small, "left", "center")
    rounded(rightX + S(20), bodyY + S(153), rightW - S(40), S(1), S(1), colors.border)
    drawPill(data.access.role == "owner" and "İşletme sahibi" or data.access.role == "manager" and "İstasyon müdürü" or "Pompa görevlisi", rightX + S(20), bodyY + S(174), rightW - S(40), colors.cyan, "badge")
    if data.access.canDuty then
        drawPill(data.player.duty and "Mesai aktif" or "Mesai kapalı", rightX + S(20), bodyY + S(215), rightW - S(40), data.player.duty and colors.green or colors.muted, data.player.duty and "check" or "clock")
        drawButton("toggle_duty", data.player.duty and "Mesaiyi Bitir" or "Mesaiye Başla", rightX + S(20), bodyY + S(260), rightW - S(40), S(45), data.player.duty and "danger" or "green", data.player.duty and "cross" or "clock", true)
        exports.aura_ui:uiDrawText("Aktif görevli, müşteri dolumlarından litre başına ödeme kazanır.", rightX + S(20), bodyY + S(318), rightX + rightW - S(20), bodyY + S(365), colors.muted, 1, fonts.small, "center", "top", true, true)
    else
        exports.aura_ui:uiDrawText("Fiyat, stok ve kasa işlemleri için Operasyon sekmesini kullanın.", rightX + S(24), bodyY + S(225), rightX + rightW - S(24), bodyY + S(285), colors.muted, 1, fonts.body, "center", "center", true, true)
    end
end

local function drawStepper(label, value, detail, x, y, w, actionMinus, actionPlus, valueColor)
    drawCard(x, y, w, S(94), S(14), false)
    exports.aura_ui:uiDrawText(label, x + S(18), y + S(12), x + w - S(18), y + S(34), colors.muted, 1, fonts.small, "left", "center")
    exports.aura_ui:uiDrawText(value, x + S(18), y + S(34), x + w - S(104), y + S(67), valueColor or colors.text, 1, fonts.heading, "left", "center", true)
    exports.aura_ui:uiDrawText(detail or "", x + S(18), y + S(66), x + w - S(104), y + S(86), colors.faint, 1, fonts.small, "left", "center", true)
    drawButton(actionMinus, "−", x + w - S(92), y + S(26), S(34), S(42), "blue", nil, true)
    drawButton(actionPlus, "+", x + w - S(50), y + S(26), S(34), S(42), "blue", nil, true)
end

local function drawOperationsTab(contentX, contentY, contentW, contentH)
    local data = state.data
    local station = data.station
    local gap = S(14)
    local colW = (contentW - gap) / 2
    local leftX = contentX
    local rightX = contentX + colW + gap
    drawCard(leftX, contentY, colW, contentH, S(18), true)
    exports.aura_ui:uiDrawText("Pompa Tarifesi", leftX + S(22), contentY + S(18), leftX + colW - S(22), contentY + S(48), colors.text, 1, fonts.heading, "left", "center")
    exports.aura_ui:uiDrawText("Kâr marjınızı koruyarak litre fiyatını belirleyin.", leftX + S(22), contentY + S(50), leftX + colW - S(22), contentY + S(82), colors.muted, 1, fonts.small, "left", "top", true, true)
    drawStepper("YENİ LİTRE FİYATI", string.format("$%.2f", state.priceDraft), string.format("Sınır $%.2f - $%.2f", Config.MinFuelPrice, Config.MaxFuelPrice), leftX + S(22), contentY + S(103), colW - S(44), "price_minus", "price_plus", colors.amber)
    local margin = state.priceDraft - station.wholesalePrice
    drawPill(string.format("Tahmini brüt marj $%.2f / L", margin), leftX + S(22), contentY + S(211), colW - S(44), margin > 0 and colors.green or colors.red, "signal")
    drawButton("save_price", "Fiyatı Güncelle", leftX + S(22), contentY + S(254), colW - S(44), S(46), "green", "check", true)
    rounded(leftX + S(22), contentY + S(322), colW - S(44), S(1), S(1), colors.border)
    exports.aura_ui:uiDrawText("İşletme Devri", leftX + S(22), contentY + S(344), leftX + colW - S(22), contentY + S(374), colors.text, 1, fonts.heading, "left", "center")
    local saleValue = math.floor(station.purchasePrice * Config.BusinessSaleRate + station.balance)
    exports.aura_ui:uiDrawText("Devlet geri alım bedeli ve mevcut kasa toplamı hesabınıza yatırılır.", leftX + S(22), contentY + S(378), leftX + colW - S(22), contentY + S(426), colors.muted, 1, fonts.small, "left", "top", true, true)
    drawPill("Net ödeme " .. formatMoney(saleValue), leftX + S(22), contentY + S(438), colW - S(44), colors.amber, "bank")
    if data.access.isOwner then
        local confirming = getTickCount() < state.sellConfirmUntil
        drawButton("sell_station", confirming and "Tekrar Bas: Devri Onayla" or "İşletmeyi Devret", leftX + S(22), contentY + contentH - S(68), colW - S(44), S(46), "danger", "logout", true)
    end

    drawCard(rightX, contentY, colW, contentH, S(18), true)
    exports.aura_ui:uiDrawText("Tedarik & Kasa", rightX + S(22), contentY + S(18), rightX + colW - S(22), contentY + S(48), colors.text, 1, fonts.heading, "left", "center")
    local freeStock = math.max(0, station.maxStock - station.stock)
    drawStepper("SİPARİŞ MİKTARI", formatLiters(state.orderAmount), formatLiters(freeStock) .. " boş kapasite", rightX + S(22), contentY + S(72), colW - S(44), "order_minus", "order_plus", colors.cyan)
    local orderCost = math.ceil(state.orderAmount * station.wholesalePrice)
    drawPill("Tedarik maliyeti " .. formatMoney(orderCost), rightX + S(22), contentY + S(180), colW - S(44), colors.amber, "cube")
    local canOrder = freeStock >= Config.StockOrderStep
    drawButton("order_balance", "Kasadan Sipariş", rightX + S(22), contentY + S(223), (colW - S(53)) / 2, S(46), "blue", "wallet", canOrder and station.balance >= orderCost)
    drawButton("order_bank", "Bankadan Sipariş", rightX + S(31) + (colW - S(53)) / 2, contentY + S(223), (colW - S(53)) / 2, S(46), "green", "bank", canOrder and data.access.isOwner and data.player.bank >= orderCost)
    rounded(rightX + S(22), contentY + S(291), colW - S(44), S(1), S(1), colors.border)
    drawStepper("KASADAN ÇEKİM", formatMoney(state.withdrawAmount), "Kasa " .. formatMoney(station.balance), rightX + S(22), contentY + S(314), colW - S(44), "withdraw_minus", "withdraw_plus", colors.green)
    drawButton("withdraw_all", "Tümünü Seç", rightX + S(22), contentY + S(422), S(112), S(42), "blue", nil, data.access.isOwner and station.balance >= 1)
    drawButton("withdraw", "Bankaya Aktar", rightX + S(144), contentY + S(422), colW - S(166), S(42), "green", "bank", data.access.isOwner and state.withdrawAmount >= 1 and state.withdrawAmount <= station.balance)
end

local function drawStaffTab(contentX, contentY, contentW, contentH)
    local data = state.data
    local employees = data.employees or {}
    local gap = S(14)
    local listW = math.floor(contentW * 0.58)
    local formX = contentX + listW + gap
    local formW = contentW - listW - gap
    drawCard(contentX, contentY, listW, contentH, S(18), false)
    exports.aura_ui:uiDrawText("Personel Kadrosu", contentX + S(22), contentY + S(16), contentX + listW - S(80), contentY + S(46), colors.text, 1, fonts.heading, "left", "center")
    drawPill(tostring(#employees) .. " / " .. tostring(Config.MaxEmployees), contentX + listW - S(76), contentY + S(17), S(54), colors.cyan)
    local rowY = contentY + S(62)
    local rowH = S(52)
    if #employees == 0 then
        exports.aura_ui:uiDrawText("İstasyonda kayıtlı personel yok.", contentX + S(22), rowY, contentX + listW - S(22), contentY + contentH - S(22), colors.muted, 1, fonts.body, "center", "center")
    else
        for index = 1, math.min(#employees, Config.MaxEmployees) do
            local employee = employees[index]
            rounded(contentX + S(18), rowY, listW - S(36), rowH, S(12), index % 2 == 0 and tocolor(255, 255, 255, 8) or tocolor(255, 255, 255, 5))
            circle(contentX + S(44), rowY + rowH / 2, S(14), employee.role == "manager" and tocolor(56, 189, 248, 22) or tocolor(45, 212, 191, 20))
            icon(employee.role == "manager" and "shield" or "user", contentX + S(36), rowY + rowH / 2 - S(8), S(16), employee.role == "manager" and colors.cyan or colors.mint)
            exports.aura_ui:uiDrawText(fitText(employee.name, listW - S(190), fonts.badge), contentX + S(66), rowY + S(5), contentX + listW - S(118), rowY + S(27), colors.text, 1, fonts.badge, "left", "center", true)
            exports.aura_ui:uiDrawText("ID " .. tostring(employee.characterId) .. " · " .. (employee.role == "manager" and "Müdür" or "Kasiyer"), contentX + S(66), rowY + S(27), contentX + listW - S(118), rowY + S(47), colors.muted, 1, fonts.small, "left", "center", true)
            if data.access.canStaff then
                drawButton("remove_employee", "Çıkar", contentX + listW - S(102), rowY + S(8), S(72), S(36), "danger", nil, true, employee.characterId)
            end
            rowY = rowY + rowH + S(6)
        end
    end

    drawCard(formX, contentY, formW, contentH, S(18), true)
    if data.access.canStaff then
        exports.aura_ui:uiDrawText("Personel Ekle", formX + S(22), contentY + S(18), formX + formW - S(22), contentY + S(48), colors.text, 1, fonts.heading, "left", "center")
        exports.aura_ui:uiDrawText("Çevrimiçi karakter ID'si ile rol atayın.", formX + S(22), contentY + S(49), formX + formW - S(22), contentY + S(79), colors.muted, 1, fonts.small, "left", "top", true, true)
        if hasUiExport("drawGlassEditBox") then
            exports.gzl_ui:drawGlassEditBox("gzl_fuel_employee_id", formX + S(22), contentY + S(98), formW - S(44), S(48), {
                placeholder = "Karakter ID",
                maxChars = 7,
                font = fonts.body,
                radius = S(10),
                icon = "user"
            })
        end
        drawButton("hire_cashier", "Kasiyer Ekle", formX + S(22), contentY + S(162), formW - S(44), S(44), "green", "user", #employees < Config.MaxEmployees)
        drawButton("hire_manager", "Müdür Ekle", formX + S(22), contentY + S(216), formW - S(44), S(44), "blue", "shield", #employees < Config.MaxEmployees)
        rounded(formX + S(22), contentY + S(284), formW - S(44), S(1), S(1), colors.border)
        exports.aura_ui:uiDrawText("Rol Yetkileri", formX + S(22), contentY + S(306), formX + formW - S(22), contentY + S(334), colors.text, 1, fonts.heading, "left", "center")
        drawPill("Müdür: fiyat ve stok", formX + S(22), contentY + S(350), formW - S(44), colors.cyan, "shield")
        drawPill("Kasiyer: mesai ve kazanç", formX + S(22), contentY + S(392), formW - S(44), colors.mint, "badge")
    else
        circle(formX + formW / 2, contentY + S(100), S(34), tocolor(45, 212, 191, 20))
        icon("clock", formX + formW / 2 - S(17), contentY + S(83), S(34), colors.mint)
        exports.aura_ui:uiDrawText("Pompa Görevlisi", formX + S(22), contentY + S(150), formX + formW - S(22), contentY + S(184), colors.text, 1, fonts.heading, "center", "center")
        exports.aura_ui:uiDrawText("Mesai açıkken bu istasyonda tamamlanan müşteri dolumlarından litre başına ödeme kazanırsınız.", formX + S(26), contentY + S(194), formX + formW - S(26), contentY + S(270), colors.muted, 1, fonts.body, "center", "top", true, true)
        drawPill(data.player.duty and "Mesai aktif" or "Mesai kapalı", formX + S(22), contentY + S(302), formW - S(44), data.player.duty and colors.green or colors.muted, data.player.duty and "check" or "clock")
        drawButton("toggle_duty", data.player.duty and "Mesaiyi Bitir" or "Mesaiye Başla", formX + S(22), contentY + S(350), formW - S(44), S(48), data.player.duty and "danger" or "green", data.player.duty and "cross" or "clock", true)
    end
end

local function drawLoading(contentX, contentY, contentW, contentH)
    drawCard(contentX, contentY, contentW, contentH, S(18), false)
    local pulse = (math.sin(getTickCount() / 260) + 1) / 2
    circle(contentX + contentW / 2, contentY + contentH / 2 - S(42), S(28), tocolor(245, 158, 11, math.floor(25 + pulse * 35)))
    icon("water", contentX + contentW / 2 - S(14), contentY + contentH / 2 - S(56), S(28), colors.amber)
    exports.aura_ui:uiDrawText("İstasyon verileri hazırlanıyor", contentX + S(30), contentY + contentH / 2 + S(5), contentX + contentW - S(30), contentY + contentH / 2 + S(38), colors.text, 1, fonts.heading, "center", "center")
end

local function renderPanel()
    if not state.open then return end
    if not staticTarget or not isElement(staticTarget) then
        if not createStaticTarget() then return end
    end
    clearHitboxes()
    rounded(0, 0, screenW, screenH, S(2), colors.background)
    dxDrawImage(panelX, panelY, panelW, panelH, staticTarget)
    drawSidebar()
    drawHeader()
    local contentX = panelX + sidebarW + S(32)
    local contentY = panelY + S(101)
    local contentW = panelW - sidebarW - S(56)
    local contentH = panelH - S(124)
    if state.loading and not state.data then
        drawLoading(contentX, contentY, contentW, contentH)
        return
    end
    if not state.data then return end
    validateActiveTab()
    state.data.player.cash = tonumber(getElementData(localPlayer, "character:money") or getPlayerMoney(localPlayer)) or state.data.player.cash
    state.data.player.bank = tonumber(getElementData(localPlayer, "character:bank") or state.data.player.bank) or 0
    if state.tab == "fuel" then
        drawFuelTab(contentX, contentY, contentW, contentH)
    elseif state.tab == "overview" then
        drawBusinessOverview(contentX, contentY, contentW, contentH)
    elseif state.tab == "operations" then
        drawOperationsTab(contentX, contentY, contentW, contentH)
    elseif state.tab == "staff" then
        drawStaffTab(contentX, contentY, contentW, contentH)
    end
end

local function renderWorldPrompt()
    if state.open or not state.nearestStationId then return end
    local config = getStationConfig(state.nearestStationId)
    if not config then return end
    local w = S(370)
    local h = S(72)
    local x = (screenW - w) / 2
    local y = screenH - S(150)
    glass(x, y, w, h, S(16))
    circle(x + S(38), y + h / 2, S(20), colors.amberSoft)
    icon("water", x + S(28), y + h / 2 - S(10), S(20), colors.amber)
    exports.aura_ui:uiDrawText(config.name, x + S(68), y + S(10), x + w - S(62), y + S(35), colors.text, 1, fonts.body or "default-bold", "left", "center", true)
    exports.aura_ui:uiDrawText("Yakıt ve işletme paneli", x + S(68), y + S(34), x + w - S(62), y + S(59), colors.muted, 1, fonts.small or "default", "left", "center", true)
    rounded(x + w - S(50), y + S(20), S(30), S(32), S(8), tocolor(245, 158, 11, 28))
    exports.aura_ui:uiDrawText("E", x + w - S(50), y + S(20), x + w - S(20), y + S(52), colors.amber, 1, fonts.badge or "default-bold", "center", "center")
end

addEventHandler("onClientRender", root, function()
    renderWorldPrompt()
    renderPanel()
end)

local function updateSliderFromCursor(cursorX)
    local maximum = getFuelMaximum()
    if maximum <= 0 then return end
    for index = 1, hitboxCount do
        local box = hitboxes[index]
        if box.action == "fuel_slider" then
            local progress = clamp((cursorX - box.x) / box.w, 0, 1)
            setSelectedLiters(maximum * progress)
            return
        end
    end
end

local function performAction(action, data)
    if action == "tab" then
        if isTabAvailable(data) then state.tab = data end
    elseif action == "close_panel" then
        closeFuelPanel(true)
    elseif action == "refresh" then
        requestContext()
    elseif action == "fuel_slider" then
        local cx = getCursorPosition()
        if cx then updateSliderFromCursor(cx * screenW) end
        state.draggingSlider = true
    elseif action == "fuel_preset" then
        setSelectedLiters(data)
    elseif action == "fuel_full" then
        setSelectedLiters(getFuelMaximum())
    elseif action == "start_fueling" then
        triggerServerEvent("gzl_fuel:startFueling", resourceRoot, state.stationId, state.selectedLiters)
    elseif action == "stop_fueling" then
        triggerServerEvent("gzl_fuel:stopFueling", resourceRoot)
    elseif action == "purchase_station" then
        triggerServerEvent("gzl_fuel:purchaseStation", resourceRoot, state.stationId)
    elseif action == "price_minus" then
        state.priceDraft = round(clamp(state.priceDraft - Config.PriceStep, Config.MinFuelPrice, Config.MaxFuelPrice), 2)
    elseif action == "price_plus" then
        state.priceDraft = round(clamp(state.priceDraft + Config.PriceStep, Config.MinFuelPrice, Config.MaxFuelPrice), 2)
    elseif action == "save_price" then
        triggerServerEvent("gzl_fuel:setPrice", resourceRoot, state.stationId, state.priceDraft)
    elseif action == "order_minus" then
        state.orderAmount = math.max(Config.StockOrderStep, state.orderAmount - Config.StockOrderStep)
    elseif action == "order_plus" then
        local freeStock = state.data.station.maxStock - state.data.station.stock
        state.orderAmount = math.min(Config.MaxStockOrder, math.floor(freeStock / Config.StockOrderStep) * Config.StockOrderStep, state.orderAmount + Config.StockOrderStep)
        state.orderAmount = math.max(Config.StockOrderStep, state.orderAmount)
    elseif action == "order_balance" or action == "order_bank" then
        triggerServerEvent("gzl_fuel:orderStock", resourceRoot, state.stationId, state.orderAmount, action == "order_balance" and "balance" or "bank")
    elseif action == "withdraw_minus" then
        state.withdrawAmount = math.max(0, state.withdrawAmount - 1000)
    elseif action == "withdraw_plus" then
        state.withdrawAmount = math.min(math.floor(state.data.station.balance), state.withdrawAmount + 1000)
    elseif action == "withdraw_all" then
        state.withdrawAmount = math.floor(state.data.station.balance)
    elseif action == "withdraw" then
        triggerServerEvent("gzl_fuel:withdrawBalance", resourceRoot, state.stationId, state.withdrawAmount)
    elseif action == "hire_cashier" or action == "hire_manager" then
        local employeeId = hasUiExport("getEditBoxText") and exports.gzl_ui:getEditBoxText("gzl_fuel_employee_id") or ""
        triggerServerEvent("gzl_fuel:addEmployee", resourceRoot, state.stationId, tonumber(employeeId), action == "hire_manager" and "manager" or "cashier")
    elseif action == "remove_employee" then
        triggerServerEvent("gzl_fuel:removeEmployee", resourceRoot, state.stationId, data)
    elseif action == "toggle_duty" then
        triggerServerEvent("gzl_fuel:toggleDuty", resourceRoot, state.stationId)
    elseif action == "sell_station" then
        if getTickCount() < state.sellConfirmUntil then
            triggerServerEvent("gzl_fuel:sellStation", resourceRoot, state.stationId)
            state.sellConfirmUntil = 0
        else
            state.sellConfirmUntil = getTickCount() + 5000
            notify("Devir işlemini onaylamak için düğmeye tekrar basın.", "warning")
        end
    end
end

addEventHandler("onClientClick", root, function(button, clickState, absoluteX, absoluteY)
    if not state.open or button ~= "left" then return end
    if clickState == "down" then
        for index = hitboxCount, 1, -1 do
            local box = hitboxes[index]
            if box and isInside(absoluteX, absoluteY, box) then
                performAction(box.action, box.data)
                playSoundFrontEnd(6)
                return
            end
        end
    elseif clickState == "up" then
        state.draggingSlider = false
    end
end)

addEventHandler("onClientCursorMove", root, function(_, _, absoluteX)
    if state.open and state.draggingSlider then updateSliderFromCursor(absoluteX) end
end)

addEventHandler("onClientKey", root, function(button, press)
    if not state.open or not press then return end
    if button == "escape" then
        cancelEvent()
        closeFuelPanel(true)
        return
    end
    if (exports.gzl_core and exports.gzl_core.isPlayerTyping and exports.gzl_core:isPlayerTyping()) or guiGetInputEnabled() or isChatBoxInputActive() or isConsoleActive() then
        return
    end
    local activeEdit = hasUiExport("getActiveEditBox") and exports.gzl_ui:getActiveEditBox() or nil
    if activeEdit then return end
    if button == "arrow_l" and state.tab == "fuel" and not state.fueling then
        setSelectedLiters(state.selectedLiters - 1)
        cancelEvent()
    elseif button == "arrow_r" and state.tab == "fuel" and not state.fueling then
        setSelectedLiters(state.selectedLiters + 1)
        cancelEvent()
    elseif button == "enter" and state.tab == "fuel" and not state.fueling and state.selectedLiters >= 0.1 then
        triggerServerEvent("gzl_fuel:startFueling", resourceRoot, state.stationId, state.selectedLiters)
        cancelEvent()
    elseif button == "1" then
        state.tab = "fuel"
        cancelEvent()
    elseif button == "2" then
        state.tab = "overview"
        cancelEvent()
    elseif button == "3" and isTabAvailable("operations") then
        state.tab = "operations"
        cancelEvent()
    elseif button == "4" and isTabAvailable("staff") then
        state.tab = "staff"
        cancelEvent()
    end
end)

bindKey("e", "down", function()
    if isCursorShowing() then return end
    if (exports.gzl_core and exports.gzl_core.isPlayerTyping and exports.gzl_core:isPlayerTyping()) or isChatBoxInputActive() or isConsoleActive() then return end
    if state.open or not state.nearestStationId then return end
    openFuelPanel(state.nearestStationId)
end)

setTimer(function()
    local nearestId = nil
    local nearestDistance = Config.InteractionDistance + 0.01
    if getElementInterior(localPlayer) == 0 and getElementDimension(localPlayer) == 0 and (getElementData(localPlayer, "character:id") or getElementData(localPlayer, "char:id") or getElementData(localPlayer, "loggedin_character")) then
        local x, y, z = getElementPosition(localPlayer)
        for _, station in ipairs(Config.Stations) do
            local distance = getDistanceBetweenPoints3D(x, y, z, station.x, station.y, station.z)
            if distance < nearestDistance then
                nearestId = station.id
                nearestDistance = distance
            end
        end
    end
    state.nearestStationId = nearestId
    if state.open then
        local config = getStationConfig(state.stationId)
        local currentX, currentY, currentZ = getElementPosition(localPlayer)
        local tooFar = not config or getElementInterior(localPlayer) ~= 0 or getElementDimension(localPlayer) ~= 0 or getDistanceBetweenPoints3D(currentX, currentY, currentZ, config.x, config.y, config.z) > Config.InteractionDistance + 2
        if tooFar then
            closeFuelPanel(true)
            notify("İstasyondan uzaklaştığınız için panel kapatıldı.", "warning")
        end
    end
end, 300, 0)

addEvent("gzl_fuel:receiveContext", true)
addEventHandler("gzl_fuel:receiveContext", resourceRoot, function(payload)
    if not state.open or type(payload) ~= "table" or type(payload.station) ~= "table" or payload.station.id ~= state.stationId then return end
    state.data = payload
    state.loading = false
    state.priceDraft = tonumber(payload.station.price) or Config.MinFuelPrice
    local freeStock = math.max(0, payload.station.maxStock - payload.station.stock)
    state.orderAmount = math.max(Config.StockOrderStep, math.min(Config.MaxStockOrder, math.floor(freeStock / Config.StockOrderStep) * Config.StockOrderStep))
    state.withdrawAmount = math.min(math.floor(payload.station.balance), math.max(0, state.withdrawAmount))
    if payload.vehicle then
        setSelectedLiters(math.min(5, payload.vehicle.missingLiters or 0))
    else
        state.selectedLiters = 0
    end
    validateActiveTab()
end)

addEvent("gzl_fuel:actionResult", true)
addEventHandler("gzl_fuel:actionResult", resourceRoot, function(success, message)
    if not state.data then state.loading = false end
    notify(message, success and "success" or "error")
end)

addEvent("gzl_fuel:fuelingStarted", true)
addEventHandler("gzl_fuel:fuelingStarted", resourceRoot, function(payload)
    if not state.open or type(payload) ~= "table" then return end
    state.fueling = true
    state.fuelingData = {
        delivered = 0,
        target = payload.target,
        paid = 0,
        attendant = payload.attendant
    }
    notify(payload.attendant and payload.attendant .. " pompa hizmetini üstlendi." or "Yakıt dolumu başladı.", "success")
end)

addEvent("gzl_fuel:fuelingProgress", true)
addEventHandler("gzl_fuel:fuelingProgress", resourceRoot, function(payload)
    if not state.open or type(payload) ~= "table" then return end
    local attendant = state.fuelingData and state.fuelingData.attendant or nil
    state.fuelingData = payload
    state.fuelingData.attendant = attendant
    if state.data and state.data.station then state.data.station.stock = payload.stock or state.data.station.stock end
end)

addEvent("gzl_fuel:fuelingEnded", true)
addEventHandler("gzl_fuel:fuelingEnded", resourceRoot, function(payload)
    if type(payload) ~= "table" then return end
    state.fueling = false
    state.fuelingData = nil
    notify(payload.message .. " " .. formatLiters(payload.delivered) .. " · " .. formatMoney(payload.paid), payload.completed and "success" or "warning")
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    setElementData(localPlayer, "gzl_fuel:isOpen", false, false)
    setElementData(localPlayer, "gzl_fuel:lastClosedTick", 0, false)
    refreshUiState()
    loadFonts()
    createStaticTarget()
    for _, station in ipairs(Config.Stations) do
        local marker = createMarker(station.x, station.y, station.z - 1.05, "cylinder", 4, 245, 158, 11, 95)
        local blip = createBlip(station.x, station.y, station.z, 55, 1, 245, 158, 11, 255, 0, 350)
        worldElements[#worldElements + 1] = marker
        worldElements[#worldElements + 1] = blip
    end
end)

addEventHandler("onClientResourceStart", root, function(resource)
    if getResourceName(resource) == "gzl_ui" then
        setTimer(function()
            refreshUiState()
            loadFonts()
            createStaticTarget()
        end, 300, 1)
    end
end)

addEventHandler("onClientResourceStop", root, function(resource)
    if getResourceName(resource) == "gzl_ui" then
        uiReady = false
        uiResource = nil
        destroyStaticTarget()
        if state.open then closeFuelPanel(true) end
    end
end)

addEventHandler("onClientRestore", root, function()
    setTimer(createStaticTarget, 100, 1)
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    if state.open then
        showCursor(false)
        pcall(guiSetInputMode, "allow_binds")
    end
    setElementData(localPlayer, "gzl_fuel:isOpen", false, false)
    setElementData(localPlayer, "gzl_fuel:lastClosedTick", getTickCount(), false)
    destroyStaticTarget()
    for _, element in ipairs(worldElements) do
        if isElement(element) then destroyElement(element) end
    end
    worldElements = {}
end)