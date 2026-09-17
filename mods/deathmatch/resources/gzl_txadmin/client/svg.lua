local svgCache = {}

local function createBasicFillSVG(w, h, r)
    w = math.max(1, math.floor(w))
    h = math.max(1, math.floor(h))
    local scale = (w <= 80 or h <= 80) and 4 or (w <= 512 and 2 or 1)
    if (w * scale > 4096) or (h * scale > 4096) then
        scale = 1
    end
    local sw = math.min(4096, math.max(1, math.floor(w * scale)))
    local sh = math.min(4096, math.max(1, math.floor(h * scale)))
    local sr = math.min(r * scale, math.min(sw, sh) * 0.5)
    local svgData = string.format([[
        <svg width="%d" height="%d" viewBox="0 0 %d %d" fill="none" xmlns="http://www.w3.org/2000/svg">
            <rect width="%d" height="%d" rx="%.1f" ry="%.1f" fill="white"/>
        </svg>
    ]], sw, sh, sw, sh, sw, sh, sr, sr)
    return svgCreate(sw, sh, svgData)
end

local function createCircleSVG(sd)
    sd = math.min(4096, math.max(1, math.floor(sd)))
    local center = sd * 0.5
    local r = math.max(1, (sd * 0.5) - 0.5)
    local svgData = string.format([[
        <svg width="%d" height="%d" viewBox="0 0 %d %d" fill="none" xmlns="http://www.w3.org/2000/svg">
            <circle cx="%.2f" cy="%.2f" r="%.2f" fill="white"/>
        </svg>
    ]], sd, sd, sd, sd, center, center, r)
    return svgCreate(sd, sd, svgData)
end

function drawCircle(cx,cy,r,color,postGUI)
    return exports.aura_ui:uiDrawRoundedRectangle(cx-r,cy-r,r*2,r*2,r,color,postGUI)
end

function drawRoundedRectangle(x,y,w,h,r,color,postGUI)
    return exports.aura_ui:uiDrawRoundedRectangle(x,y,w,h,r,color,postGUI)
end

local function createBorderSVG(w, h, r, stroke)
    w = math.max(1, math.floor(w))
    h = math.max(1, math.floor(h))
    stroke = stroke or 1.2
    local inset = stroke * 0.5
    local bw = math.max(1, w - stroke)
    local bh = math.max(1, h - stroke)
    local br = math.max(0, r - inset)
    local svgData = string.format([[
        <svg width="%d" height="%d" viewBox="0 0 %d %d" fill="none" xmlns="http://www.w3.org/2000/svg">
            <rect x="%.2f" y="%.2f" width="%.2f" height="%.2f" rx="%.2f" ry="%.2f" fill="none" stroke="white" stroke-width="%.2f"/>
        </svg>
    ]], w, h, w, h, inset, inset, bw, bh, br, br, stroke)
    return svgCreate(w, h, svgData)
end

function drawRoundedBorder(x,y,w,h,r,color,stroke,postGUI)
    return exports.aura_ui:uiDrawBorder(x,y,w,h,r,stroke,color,postGUI)
end

local function createCardSVG(w, h, r)
    local strokeW = 1.0
    local innerW = w - strokeW
    local innerH = h - strokeW
    local svgData = string.format([[
        <svg width="%d" height="%d" viewBox="0 0 %d %d" fill="none" xmlns="http://www.w3.org/2000/svg">
            <defs>
                <linearGradient id="txBg" x1="0%%" y1="0%%" x2="0%%" y2="100%%">
                    <stop offset="0%%" stop-color="#141923" stop-opacity="0.97"/>
                    <stop offset="100%%" stop-color="#0d1118" stop-opacity="0.98"/>
                </linearGradient>
                <linearGradient id="txBorder" x1="0%%" y1="0%%" x2="100%%" y2="100%%">
                    <stop offset="0%%" stop-color="#ffffff" stop-opacity="0.16"/>
                    <stop offset="50%%" stop-color="#38bdf8" stop-opacity="0.08"/>
                    <stop offset="100%%" stop-color="#ffffff" stop-opacity="0.03"/>
                </linearGradient>
            </defs>
            <rect x="0.5" y="0.5" width="%.2f" height="%.2f" rx="%.1f" ry="%.1f" fill="url(#txBg)" stroke="url(#txBorder)" stroke-width="1.0"/>
        </svg>
    ]], w, h, w, h, innerW, innerH, r, r)
    return svgCreate(w, h, svgData)
end

function drawTxAdminCard(x,y,w,h,r,postGUI)
    return exports.aura_ui:uiDrawPanel(x,y,w,h,r,postGUI)
end

local function createSelectedPillSVG(w, h, r)
    local strokeW = 1.0
    local innerW = w - strokeW
    local innerH = h - strokeW
    local svgData = string.format([[
        <svg width="%d" height="%d" viewBox="0 0 %d %d" fill="none" xmlns="http://www.w3.org/2000/svg">
            <defs>
                <linearGradient id="pillBg" x1="0%%" y1="0%%" x2="100%%" y2="0%%">
                    <stop offset="0%%" stop-color="#242c3b" stop-opacity="0.95"/>
                    <stop offset="100%%" stop-color="#1c2331" stop-opacity="0.95"/>
                </linearGradient>
            </defs>
            <rect x="0.5" y="0.5" width="%.2f" height="%.2f" rx="%.1f" ry="%.1f" fill="url(#pillBg)" stroke="#ffffff" stroke-opacity="0.08" stroke-width="1.0"/>
        </svg>
    ]], w, h, w, h, innerW, innerH, r, r)
    return svgCreate(w, h, svgData)
end

function drawSelectedPill(x,y,w,h,r,postGUI)
    return exports.aura_ui:uiDrawSurface(x,y,w,h,{token="surface",radius=r or 10,border=true},postGUI)
end

local iconPaths = {
    ["warning"] = '<path d="M1 21h22L12 2 1 21zm12-3h-2v-2h2v2zm0-4h-2v-4h2v4z" fill="white"/>',
    ["noclip"] = '<circle cx="12" cy="12" r="2.8" fill="white"/><path d="M12 2l-3.2 3.2h2.2v3.6h2V5.2h2.2L12 2zm0 20l3.2-3.2h-2.2v-3.6h-2v3.6H8.8L12 22zm-10-10l3.2 3.2v-2.2h3.6v-2H5.2V8.8L2 12zm20 0l-3.2-3.2v2.2h-3.6v2h3.6v2.2l3.2-3.2z" fill="white"/>',
    ["teleport"] = '<path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5a2.5 2.5 0 0 1 0-5 2.5 2.5 0 0 1 0 5z" fill="white"/>',
    ["vehicle"] = '<path d="M18.92 6.01C18.72 5.42 18.16 5 17.5 5h-11c-.66 0-1.21.42-1.42 1.01L3 12v8c0 .55.45 1 1 1h1c.55 0 1-.45 1-1v-1h12v1c0 .55.45 1 1 1h1c.55 0 1-.45 1-1v-8l-2.08-5.99zM6.5 16c-.83 0-1.5-.67-1.5-1.5S5.67 13 6.5 13s1.5.67 1.5 1.5S7.33 16 6.5 16zm11 0c-.83 0-1.5-.67-1.5-1.5s.67-1.5 1.5-1.5 1.5.67 1.5 1.5-.67 1.5-1.5 1.5zM5 11l1.5-4.5h11L19 11H5z" fill="white"/>',
    ["heal"] = '<path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z" fill="white"/>',
    ["announcement"] = '<path d="M20 2H4c-1.1 0-2 .9-2 2v18l4-4h14c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zm-7 12h-2v-2h2v2zm0-4h-2V6h2v4z" fill="white"/>',
    ["reset_world"] = '<path d="M4 8V4h4V2H2v6h2zm16-4h-4V2h6v6h-2V4zM4 16v4h4v2H2v-6h2zm16 4h-4v2h6v-6h-2v4zm-8-9c-1.66 0-3 1.34-3 3s1.34 3 3 3 3-1.34 3-3-1.34-3-3-3zm0 4.5c-.83 0-1.5-.67-1.5-1.5s.67-1.5 1.5-1.5 1.5.67 1.5 1.5-.67 1.5-1.5 1.5z" fill="white"/>',
    ["player_ids"] = '<path d="M16 11c1.66 0 2.99-1.34 2.99-3S17.66 5 16 5c-1.66 0-3 1.34-3 3s1.34 3 3 3zm-8 0c1.66 0 2.99-1.34 2.99-3S9.66 5 8 5C6.34 5 5 6.34 5 8s1.34 3 3 3zm0 2c-2.33 0-7 1.17-7 3.5V19h14v-2.5c0-2.33-4.67-3.5-7-3.5zm8 0c-.29 0-.62.02-.97.05 1.16.84 1.97 1.97 1.97 3.45V19h6v-2.5c0-2.33-4.67-3.5-7-3.5z" fill="white"/>',
    ["chevron_down"] = '<path d="M7.41 8.59L12 13.17l4.59-4.58L18 10l-6 6-6-6 1.41-1.41z" fill="white"/>',
    ["chevron_up"] = '<path d="M7.41 15.41L12 10.83l4.59 4.58L18 14l-6-6-6 6 1.41 1.41z" fill="white"/>',
    ["arrow_left"] = '<path d="M15.41 16.59L10.83 12l4.58-4.59L14 6l-6 6 6 6 1.41-1.41z" fill="white"/>',
    ["arrow_right"] = '<path d="M8.59 16.59L13.17 12 8.59 7.41 10 6l6 6-6 6-1.41-1.41z" fill="white"/>',
    ["search"] = '<path d="M15.5 14h-.79l-.28-.27C15.41 12.59 16 11.11 16 9.5 16 5.91 13.09 3 9.5 3S3 5.91 3 9.5 5.91 16 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z" fill="white"/>',
    ["user"] = '<path d="M12 12c2.7 0 4.8-2.1 4.8-4.8S14.7 2.4 12 2.4 7.2 4.5 7.2 7.2 9.3 12 12 12zm0 2.4c-3.2 0-9.6 1.6-9.6 4.8v2.4h19.2v-2.4c0-3.2-6.4-4.8-9.6-4.8z" fill="white"/>',
    ["server"] = '<path d="M4 3h16a2 2 0 0 1 2 2v3a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2zm0 8h16a2 2 0 0 1 2 2v3a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2v-3a2 2 0 0 1 2-2zm0 8h16a2 2 0 0 1 2 2v0a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2v0a2 2 0 0 1 2-2z" fill="white"/>',
    ["check"] = '<path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z" fill="white"/>',
    ["cross"] = '<path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z" fill="white"/>',
    ["pencil"] = '<path d="M3 17.25V21h3.75L17.81 9.94l-3.75-3.75L3 17.25zM20.71 7.04c.39-.39.39-1.02 0-1.41l-2.34-2.34c-.39-.39-1.02-.39-1.41 0l-1.83 1.83 3.75 3.75 1.83-1.83z" fill="white"/>',
    ["copy"] = '<path d="M16 1H4c-1.1 0-2 .9-2 2v14h2V3h12V1zm3 4H8c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h11c1.1 0 2-.9 2-2V7c0-1.1-.9-2-2-2zm0 16H8V7h11v14z" fill="white"/>',
    ["bolt"] = '<path d="M11 21h-1l1-7H7.5c-.58 0-.57-.32-.38-.66.19-.34.05-.08.07-.12C8.48 10.94 10.42 7.54 13 3h1l-1 7h3.5c.49 0 .56.33.47.51l-.07.15C14.9 14.66 12.96 18.06 11 21z" fill="white"/>',
    ["info"] = '<path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-6h2v6zm0-8h-2V7h2v2z" fill="white"/>',
    ["list"] = '<path d="M3 13h2v-2H3v2zm0 4h2v-2H3v2zm0-8h2V7H3v2zm4 4h14v-2H7v2zm0 4h14v-2H7v2zM7 7v2h14V7H7z" fill="white"/>',
    ["history"] = '<path d="M13 3a9 9 0 0 0-9 9H1l3.89 3.89.07.14L9 12H6c0-3.87 3.13-7 7-7s7 3.13 7 7-3.13 7-7 7c-1.93 0-3.68-.79-4.94-2.06l-1.42 1.42A8.954 8.954 0 0 0 13 21a9 9 0 0 0 0-18zm-1 5v5l4.28 2.54.72-1.21-3.5-2.08V8H12z" fill="white"/>',
    ["ban"] = '<path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.42 0-8-3.58-8-8 0-1.85.63-3.55 1.69-4.9L16.9 18.31C15.55 19.37 13.85 20 12 20zm6.31-3.1L7.1 5.69C8.45 4.63 10.15 4 12 4c4.42 0 8 3.58 8 8 0 1.85-.63 3.55-1.69 4.9z" fill="white"/>',
    ["ped_walk"] = '<path d="M13.5 5.5c1.1 0 2-.9 2-2s-.9-2-2-2-2 .9-2 2 .9 2 2 2zM9.8 8.9L7 23h2.1l1.8-8 2.1 2v6h2v-7.5l-2.1-2 .6-3C14.8 12 16.8 13 19 13v-2c-1.9 0-3.5-1-4.3-2.4l-1-1.6c-.4-.6-1-1-1.7-1-.3 0-.5.1-.8.1L6 8.3V13h2V9.6l1.8-.7" fill="white"/>'
}

function drawIconSVG(name, x, y, size, color, postGUI)
    size = math.max(8, math.floor(size or 18))
    local key = "icon_" .. name .. "_" .. size
    if not svgCache[key] or not isElement(svgCache[key]) then
        local pathXml = iconPaths[name] or iconPaths["user"]
        local svgData = string.format([[
            <svg width="%d" height="%d" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                %s
            </svg>
        ]], size, size, pathXml)
        svgCache[key] = svgCreate(size, size, svgData)
    end
    if svgCache[key] then
        dxDrawImage(math.floor(x), math.floor(y), size, size, svgCache[key], 0, 0, 0, color or tocolor(255, 255, 255, 255), postGUI or false)
    end
end

addEventHandler("onClientResourceStop", resourceRoot, function()
    for _, elem in pairs(svgCache) do
        if isElement(elem) then
            destroyElement(elem)
        end
    end
    svgCache = {}
end)