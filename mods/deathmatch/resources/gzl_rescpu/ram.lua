local opened, timer = false, nil
local rows, summary, filter, page = {}, {}, "", 1
local cpuRows = {}
local perPage = 12
local function pageCount()
    return math.max(1, math.ceil(math.max(#rows, #cpuRows) / perPage))
end
local fonts, fontScale = {}, nil
local panelTarget, targetScale = nil, nil
local panelDirty = true
local targetAttempted = false
local sampleJob, nextSample = nil, 0
local function stage() coroutine.yield() end
local function timedStats(category)
    local started = getTickCount()
    local ok, columns, data = pcall(getPerformanceStats, category)
    PerfProbe.record(category, getTickCount() - started)
    stage()
    return ok, columns, data
end

local function memoryBytes(value)
    if type(value) == "number" then return value end
    local raw = tostring(value or ""):gsub(",", "")
    local number, unit = raw:match("^%s*([%+%-]?[%d%.]+)%s*([%a]*)")
    number = tonumber(number)
    local units = { b = 1, kb = 1024, kib = 1024, mb = 1024^2,
        mib = 1024^2, gb = 1024^3, gib = 1024^3 }
    local multiplier = units[(unit or ""):lower()]
    if not number or not multiplier then return nil end
    return number * multiplier
end

local function mib(value)
    return type(value) == "number" and string.format("%.2f MiB", value / 1024^2) or "N/A"
end

local function sampleCPU()
    cpuRows = {}
    local ok, columns, data = timedStats("Lua timing")
    if not ok or type(columns) ~= "table" or type(data) ~= "table" then
        summary.cpu = "N/A"
        return
    end
    local indexes = {}
    for i, name in ipairs(columns) do indexes[tostring(name):lower():gsub("%s", "")] = i end
    local total, measured = 0, false
    for _, row in ipairs(data) do
        local name = tostring(row[indexes.name or 1] or "")
        if getResourceFromName(name) then
            local raw = tostring(row[indexes["5s.cpu"] or 2] or "")
            local value = tonumber(raw:match("([%d%.]+)"))
            if value then total = total + value; measured = true end
            if filter == "" or name:lower():find(filter, 1, true) then
                cpuRows[#cpuRows + 1] = {name = name, value = value,
                    current = value and string.format("%.2f %%", value) or "N/A",
                    time = tostring(row[indexes["5s.time"] or 3] or "N/A")}
            end
        end
    end
    stage()
    local sortStart = getTickCount()
    table.sort(cpuRows, function(a, b)
        if (a.value or -1) == (b.value or -1) then return a.name < b.name end
        return (a.value or -1) > (b.value or -1)
    end)
    PerfProbe.record("CPU sort", getTickCount() - sortStart)
    stage()
    summary.cpu = measured and string.format("%.2f %%", total) or "N/A"
end

local function sample()
    if not isMTAWindowFocused() then return end
    local ok, columns, data = timedStats("Lua memory")
    rows, summary = {}, {}
    if not ok or type(columns) ~= "table" or type(data) ~= "table" then
        summary.error = "Lua bellek olcumu alinamadi."
        sampleCPU()
        return
    end
    local indexes = {}
    for i, name in ipairs(columns) do
        indexes[tostring(name):lower():gsub("[^%a]", "")] = i
    end
    local function cell(row, key)
        local index = indexes[key]
        return index and row[index] or nil
    end
    local total = 0
    for _, row in ipairs(data) do
        local name = tostring(cell(row, "name") or "")
        if getResourceFromName(name) then
            local bytes = memoryBytes(cell(row, "current"))
            total = total + (bytes or 0)
            if filter == "" or name:lower():find(filter, 1, true) then
                rows[#rows + 1] = { name = name, bytes = bytes,
                    current = tostring(cell(row, "current") or "N/A"),
                    change = tostring(cell(row, "change") or "N/A"),
                    peak = tostring(cell(row, "max") or "N/A"),
                    browsers = tostring(cell(row, "webbrowsers") or "N/A"),
                    textures = tostring(cell(row, "textures") or "N/A"),
                    shaders = tostring(cell(row, "shaders") or "N/A"),
                    targets = tostring(cell(row, "rendertargets") or "N/A") }
            end
        end
    end
    stage()
    local sortStart = getTickCount()
    table.sort(rows, function(a, b)
        if (a.bytes or -1) == (b.bytes or -1) then return a.name < b.name end
        return (a.bytes or -1) > (b.bytes or -1)
    end)
    PerfProbe.record("RAM sort", getTickCount() - sortStart)
    stage()
    summary.lua = mib(total)
    if type(getProcessMemoryStats) == "function" then
        local success, memory = pcall(getProcessMemoryStats)
        if success and type(memory) == "table" then summary.process = mib(memory.resident) end
    end
    local success, status = pcall(dxGetStatus)
    if success and type(status) == "table" then
        summary.graphics = string.format("Texture: %s MB | RT: %s MB | Font: %s MB",
            tostring(status.VideoMemoryUsedByTextures or "N/A"),
            tostring(status.VideoMemoryUsedByRenderTargets or "N/A"),
            tostring(status.VideoMemoryUsedByFonts or "N/A"))
    end
    sampleCPU()
    page = math.min(page, pageCount())
    panelDirty = true
end

local function releaseFonts()
    for _, font in pairs(fonts) do
        if isElement(font) then destroyElement(font) end
    end
    fonts, fontScale = {}, nil
end

local function prepareFonts(scale)
    if fontScale == scale then return end
    releaseFonts()
    fontScale = scale
    local started = getTickCount()
    local sizes = {small = 9, body = 11, strong = 11, title = 24, metric = 25}
    for key, size in pairs(sizes) do
        local file = (key == "small" or key == "body") and "Regular" or "Semibold"
        fonts[key] = dxCreateFont(":aura_ui/assets/Manrope-" .. (file == "Regular" and "Medium" or "Bold") .. ".ttf", math.max(7, math.floor(size * scale)), false, "cleartype") or "default"
    end
    PerfProbe.record("fonts", getTickCount() - started)
end

local function drawPanel(x, y, scale, postGUI)
    local white, muted = tocolor(235, 241, 251), tocolor(135, 151, 173)
    local accent, green = tocolor(117, 154, 255), tocolor(80, 218, 178)
    local function rect(left, top, width, height, color)
        exports.aura_ui:uiDrawRectangle(x + left * scale, y + top * scale, width * scale, height * scale, color, postGUI)
    end
    local function label(text, left, top, width, color, font, align, height)
        exports.aura_ui:uiDrawText(text, x + left * scale, y + top * scale,
            x + (left + width) * scale, y + (top + (height or 25)) * scale,
            color or white, 1, fonts[font or "body"], align or "left", "center", true, false, postGUI)
    end
    rect(-6, -6, 1112, 792, tocolor(0, 0, 0, 65))
    rect(0, 0, 1100, 780, tocolor(12, 17, 27, 252))
    rect(0, 0, 1100, 2, accent)
    rect(28, 25, 43, 32, tocolor(36, 49, 79))
    label("GZL", 28, 28, 43, accent, "strong", "center")
    label("DEVELOPER TOOLS", 83, 29, 260, muted, "small")
    label("Performans monitörü", 28, 66, 730, white, "title", "left", 40)
    label("İstemci kaynakları / Canlı performans görünümü", 30, 111, 750, muted)
    rect(925, 33, 147, 30, tocolor(22, 48, 43))
    label("CANLI / 2 SN", 931, 36, 135, green, "small", "center")

    local function card(left, title, value, detail, color)
        rect(left, 155, 340, 109, tocolor(21, 29, 43))
        rect(left, 155, 3, 109, color)
        label(title, left + 19, 167, 300, muted, "small")
        label(value, left + 19, 191, 303, color, "metric", "left", 39)
        label(detail, left + 19, 234, 303, muted, "small")
    end
    card(28, "OYUN SÜRECİ / RAM", summary.process or "N/A", "İşletim sisteminin bildirdiği yerleşik bellek", white)
    card(380, "KAYNAKLAR / LUA", summary.lua or "N/A", "Tüm istemci kaynaklarının Lua toplamı", accent)
    card(732, "KAYNAKLAR / CPU", summary.cpu or "N/A", "Lua işlem yükü / son 5 saniye", green)
    label(summary.graphics or "Grafik belleği: N/A", 30, 277, 1040, muted, "small")

    label("RAM / LUA BELLEĞİ", 30, 311, 500, accent, "strong")
    label("CPU / LUA İŞLEM YÜKÜ", 574, 311, 500, green, "strong")
    rect(549, 316, 1, 366, tocolor(41, 52, 70))
    local function section(left, list, cpu)
        local tint = cpu and green or accent
        rect(left, 344, 500, 29, tocolor(26, 35, 51))
        label("KAYNAK", left + 12, 346, 230, muted, "small")
        label(cpu and "CPU / 5 SN" or "LUA RAM", left + 252, 346, 112, muted, "small")
        label(cpu and "SÜRE / 5 SN" or "FARK / 5 SN", left + 375, 346, 115, muted, "small")
        local maximum = list[1] and (cpu and list[1].value or list[1].bytes) or 0
        for slot = 1, perPage do
            local row = list[(page - 1) * perPage + slot]
            if not row then break end
            local top = 378 + (slot - 1) * 25
            rect(left, top, 500, 24, slot % 2 == 1 and tocolor(19, 26, 39) or tocolor(15, 22, 33))
            label(row.name, left + 12, top, 233, white, "strong")
            label(row.current, left + 252, top - 2, 112, tint, "strong")
            rect(left + 252, top + 21, 105, 2, tocolor(37, 48, 66))
            local value = cpu and row.value or row.bytes
            if maximum > 0 then rect(left + 252, top + 21, 105 * math.min(1, (value or 0) / maximum), 2, tint) end
            local detail = cpu and row.time or row.change
            local change = not cpu and memoryBytes(detail)
            local color = change and (change < 0 and green or change > 0 and tocolor(242, 185, 112)) or muted
            label((detail and detail ~= "") and detail or "—", left + 375, top, 115, color)
        end
        if not list[(page - 1) * perPage + 1] then
            label("Bu sayfada veri yok.", left + 12, 395, 470, muted)
        end
    end
    section(28, rows, false)
    section(572, cpuRows, true)
    rect(28, 689, 1044, 1, tocolor(41, 52, 70))
    label("Lua, kaynakların toplam RAM'i değildir. CEF / model / grafik belleği bu sütuna dahil değildir.", 30, 697, 1040, muted, "small")
    label("CPU, MTA Lua zamanlamasıdır; bilgisayarın toplam CPU yüzdesi değildir. Her bölüm ayrı sıralanır.", 30, 717, 1040, muted, "small")
    label("/ram kapat  ·  /ram yenile  ·  /ram <kaynak> filtrele  ·  /ram next / prev", 30, 748, 800, muted, "small")
    label(string.format("SAYFA %02d / %02d", page, pageCount()), 895, 748, 175, accent, "small", "right")
end

local function releaseTarget()
    if isElement(panelTarget) then destroyElement(panelTarget) end
    panelTarget, targetScale, targetAttempted = nil, nil, false
    panelDirty = true
end

local function render()
    if not isMTAWindowFocused() then return end
    local sw, sh = guiGetScreenSize()
    local scale = math.min(1, sw / 1180, sh / 850)
    if not sampleJob and getTickCount() >= nextSample then
        sampleJob = coroutine.create(sample)
    end
    if sampleJob then
        local ok, err = coroutine.resume(sampleJob)
        if not ok then
            outputDebugString("[RAM] " .. tostring(err), 1)
            sampleJob = nil
            nextSample = getTickCount() + 2000
        elseif coroutine.status(sampleJob) == "dead" then
            sampleJob = nil
            nextSample = getTickCount() + 2000
        end
        if isElement(panelTarget) then
            exports.aura_ui:uiDrawRectangle(0, 0, sw, sh, tocolor(3, 7, 14, 110), true)
            dxDrawImage((sw - 1100 * scale) / 2 - 6 * scale, (sh - 780 * scale) / 2 - 6 * scale,
                math.ceil(1112 * scale), math.ceil(792 * scale), panelTarget, 0, 0, 0, tocolor(255,255,255), true)
        end
        return
    end
    if fontScale ~= scale then prepareFonts(scale); return end
    if targetScale ~= scale then
        releaseTarget()
        targetScale = scale
    end
    local width, height = math.ceil(1112 * scale), math.ceil(792 * scale)
    if not targetAttempted then
        targetAttempted = true
        panelTarget = dxCreateRenderTarget(width, height, false)
    end
    local x, y = (sw - 1100 * scale) / 2, (sh - 780 * scale) / 2
    if isElement(panelTarget) and panelDirty then
        if dxSetRenderTarget(panelTarget, true) then
            local previousBlend = dxGetBlendMode()
            dxSetBlendMode("blend")
            local started = getTickCount()
            drawPanel(6 * scale, 6 * scale, scale, false)
            PerfProbe.record("panel rebuild", getTickCount() - started)
            dxSetRenderTarget()
            dxSetBlendMode(previousBlend)
            panelDirty = false
        end
    end
    exports.aura_ui:uiDrawRectangle(0, 0, sw, sh, tocolor(3, 7, 14, 110), true)
    if isElement(panelTarget) and not panelDirty then
        local previousBlend = dxGetBlendMode()
        dxSetBlendMode("blend")
        dxDrawImage(x - 6 * scale, y - 6 * scale, width, height, panelTarget, 0, 0, 0, tocolor(255, 255, 255), true)
        dxSetBlendMode(previousBlend)
    else
        drawPanel(x, y, scale, true)
    end
end

addEventHandler("onClientRestore", root, function()
    panelDirty = true
end)

local function close()
    if isTimer(timer) then killTimer(timer) end
    timer = nil
    sampleJob, nextSample = nil, 0
    removeEventHandler("onClientRender", root, render)
    releaseTarget()
    releaseFonts()
    rows, cpuRows, summary, opened = {}, {}, {}, false
end

addCommandHandler("ram", function(_, query)
    query = tostring(query or ""):lower()
    if opened and query == "" then close(); return end
    if opened and query == "next" then
        page = math.min(page + 1, pageCount())
        panelDirty = true
        return
    elseif opened and query == "prev" then
        page = math.max(1, page - 1)
        panelDirty = true
        return
    elseif query ~= "yenile" then
        filter, page = query == "all" and "" or query, 1
    end
    if not opened then
        opened = true
        addEventHandler("onClientRender", root, render)
    end
    sampleJob = nil
    nextSample = 0
end)

addEventHandler("onClientResourceStop", resourceRoot, close)