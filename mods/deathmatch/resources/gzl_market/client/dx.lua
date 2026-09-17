local screenW, screenH = guiGetScreenSize()
local panelW, panelH = 1496, 890
local imageRoot = "web/assets/images/"
local productColumns = 4
local productRows = 2
local cartRows = 7
local renderTarget = nil
local backdropTexture = nil
local textureCache = {}
local failedTextures = {}
local hitboxes = {}
local hitboxCount = 0
local fonts = {}
local checkoutTimer = nil
local handlersAttached = false

local state = {
    open = false,
    shopType = "market",
    shop = nil,
    category = 1,
    categoryOffset = 0,
    productRow = 0,
    cartScroll = 0,
    cart = {},
    quantities = {},
    hovered = nil,
    dirty = true,
    purchasing = false
}

local renderMarket
local handleMarketClick
local handleMarketKey
local handleMarketCursorMove

local function hasUiExport(name)
    local resource = getResourceFromName("gzl_ui")
    if not resource or getResourceState(resource) ~= "running" then return false end
    return exports.gzl_ui and type(exports.gzl_ui[name]) == "function"
end

local function notify(message, kind)
    if hasUiExport("showToast") then
        exports.gzl_ui:showToast(message, kind or "info")
    else
        outputChatBox("[Market] " .. message, kind == "error" and 244 or 45, kind == "error" and 63 or 212, kind == "error" and 94 or 191)
    end
end

local function rounded(x, y, w, h, radius, color)
    return exports.aura_ui:uiDrawSurface(x,y,w,h,{color=color,radius=radius},false)
end

local function glass(x, y, w, h, radius)
    if hasUiExport("drawGlassPanel") then
        exports.gzl_ui:drawGlassPanel(x, y, w, h, radius)
    end
end

local function icon(name, x, y, size, color)
    if hasUiExport("drawIconSVG") then
        exports.gzl_ui:drawIconSVG(name, x, y, size, color)
    end
end

local function loadFonts()
    if not hasUiExport("getFont") then return false end
    fonts.title = exports.gzl_ui:getFont("heavy", 24)
    fonts.heading = exports.gzl_ui:getFont("heavy", 21)
    fonts.card = exports.gzl_ui:getFont("bold", 12)
    fonts.button = exports.gzl_ui:getFont("bold", 10)
    fonts.body = exports.gzl_ui:getFont("medium", 9)
    fonts.small = exports.gzl_ui:getFont("medium", 8)
    fonts.badge = exports.gzl_ui:getFont("bold", 9)
    return true
end

local function destroyRenderTarget()
    if renderTarget and isElement(renderTarget) then
        destroyElement(renderTarget)
    end
    renderTarget = nil
    if backdropTexture and isElement(backdropTexture) then
        destroyElement(backdropTexture)
    end
    backdropTexture = nil
end

local function destroyTextures()
    for _, texture in pairs(textureCache) do
        if isElement(texture) then
            destroyElement(texture)
        end
    end
    textureCache = {}
    failedTextures = {}
end

local function createMarketTarget()
    destroyRenderTarget()
    renderTarget = dxCreateRenderTarget(panelW, panelH, true)
    backdropTexture = svgCreate(32, 32, '<svg width="32" height="32" viewBox="0 0 32 32" xmlns="http://www.w3.org/2000/svg"><rect width="32" height="32" rx="1" fill="#03060a" fill-opacity="0.10"/></svg>')
    if not renderTarget or not isElement(renderTarget) then
        destroyRenderTarget()
        return false
    end
    return true
end

local function createImageMaterial(filename)
    local path = imageRoot .. filename
    if not fileExists(path) then return false end
    if string.lower(string.sub(filename, -4)) == ".svg" then
        return svgCreate(256, 256, path)
    end
    return dxCreateTexture(path, "argb", false, "clamp")
end

local function markTexture(required, filename)
    if type(filename) == "string" and filename ~= "" then
        required[filename] = true
    end
end

local function refreshTextures()
    local required = {}
    markTexture(required, "box.png")
    markTexture(required, "risk_logo.png")
    markTexture(required, "cart_basket.png")

    if state.shop then
        for _, category in ipairs(state.shop.categories) do
            markTexture(required, category.tabImage)
        end

        local category = state.shop.categories[state.category]
        if category and category.items then
            local first = state.productRow * productColumns + 1
            local last = math.min(#category.items, first + productColumns * productRows - 1)
            for index = first, last do
                markTexture(required, category.items[index].image)
            end
        end

        local cartFirst = state.cartScroll + 1
        local cartLast = math.min(#state.cart, cartFirst + cartRows - 1)
        for index = cartFirst, cartLast do
            markTexture(required, state.cart[index].item.image)
        end
    end

    for filename, texture in pairs(textureCache) do
        if not required[filename] then
            if isElement(texture) then
                destroyElement(texture)
            end
            textureCache[filename] = nil
            failedTextures[filename] = nil
        end
    end

    for filename in pairs(required) do
        if (not textureCache[filename] or not isElement(textureCache[filename])) and not failedTextures[filename] then
            local material = createImageMaterial(filename)
            if material and isElement(material) then
                textureCache[filename] = material
            else
                failedTextures[filename] = true
            end
        end
    end
end

local function getTexture(filename)
    local texture = textureCache[filename or ""]
    if texture and isElement(texture) then return texture end
    texture = textureCache["box.png"]
    if texture and isElement(texture) then return texture end
    return nil
end

local function parseThemeColor(value)
    if type(value) ~= "string" or not string.match(value, "^#%x%x%x%x%x%x$") then
        return 45, 212, 191
    end
    return tonumber(string.sub(value, 2, 3), 16), tonumber(string.sub(value, 4, 5), 16), tonumber(string.sub(value, 6, 7), 16)
end

local function formatMoney(value)
    local amount = tostring(math.floor(tonumber(value) or 0))
    while true do
        local changed
        amount, changed = string.gsub(amount, "^(-?%d+)(%d%d%d)", "%1,%2")
        if changed == 0 then break end
    end
    return "$ " .. amount
end

local marketCategoryOrder = {
    snacks = 1,
    beverages = 2,
    tools = 3,
    electronics = 4,
    general = 5,
    fashion = 6,
    souvenirs = 7,
    office = 8
}

local function prepareShop(shopType, shop)
    if shopType == "market" then
        table.sort(shop.categories, function(a, b)
            return (marketCategoryOrder[a.id] or 99) < (marketCategoryOrder[b.id] or 99)
        end)
    end
end

local function getDefaultCategoryIndex(shop)
    for index, category in ipairs(shop.categories) do
        if category.id == shop.defaultCategory then
            return index
        end
    end
    return 1
end

local function fitText(text, maxWidth, font)
    text = tostring(text or "")
    if exports.aura_ui:uiTextWidth(text, 1, font) <= maxWidth then return text end
    local length = utf8.len(text) or string.len(text)
    while length > 1 do
        local candidate = utf8.sub(text, 1, length) .. "..."
        if exports.aura_ui:uiTextWidth(candidate, 1, font) <= maxWidth then return candidate end
        length = length - 1
    end
    return "..."
end

local function clearHitboxes()
    for index = 1, hitboxCount do
        hitboxes[index] = nil
    end
    hitboxCount = 0
end

local function addHitbox(id, action, x, y, w, h, data)
    hitboxCount = hitboxCount + 1
    hitboxes[hitboxCount] = {
        id = id,
        action = action,
        x = x,
        y = y,
        w = w,
        h = h,
        data = data
    }
end

local function drawButton(id, label, x, y, w, h, theme, buttonIcon, disabled)
    local hovered = state.hovered == id and not disabled
    local color
    if disabled then
        color = tocolor(30, 34, 39, 255)
    elseif theme == "danger" then
        color = hovered and tocolor(62, 38, 43, 255) or tocolor(30, 34, 39, 255)
    elseif theme == "accent" then
        color = hovered and tocolor(216, 250, 153, 255) or tocolor(201, 244, 111, 255)
    else
        color = hovered and tocolor(42, 48, 55, 255) or tocolor(30, 34, 39, 255)
    end
    rounded(x, y, w, h, 8, color)
    local textColor = disabled and tocolor(119, 129, 143, 180) or tocolor(244, 247, 250, 250)
    if theme == "accent" and not disabled then textColor=tocolor(24,32,17,255) end
    if buttonIcon then
        local size = 16
        if label == "" then
            icon(buttonIcon, x + (w - size) / 2, y + (h - size) / 2, size, textColor)
        else
            local textWidth = exports.aura_ui:uiTextWidth(label, 1, fonts.button)
            local totalWidth = size + 7 + textWidth
            local startX = x + (w - totalWidth) / 2
            icon(buttonIcon, startX, y + (h - size) / 2, size, textColor)
            exports.aura_ui:uiDrawText(label, startX + size + 7, y, x + w, y + h, textColor, 1, fonts.button, "left", "center")
        end
    else
        exports.aura_ui:uiDrawText(label, x, y, x + w, y + h, textColor, 1, fonts.button, "center", "center")
    end
end

local function drawBackdropDetail(r, g, b)
    rounded(1028, 28, 440, 840, 12, tocolor(22,25,29,255))
    dxDrawLine(40,120,998,120,tocolor(48,54,61,255),1)
end

local function drawCategories(accent)
    local categories = state.shop.categories
    local count = #categories
    if count == 0 then return end
    local areaX, areaRight = 40, 1014
    local gap = 14
    local categoryW = 130
    local startX = areaX
    local y, h = 150, 126
    local first = state.categoryOffset + 1
    local last = math.min(count, first + 6)

    for index = first, last do
        local category = categories[index]
        local x = startX + (index - first) * (categoryW + gap)
        local visibleW = math.min(categoryW, areaRight - x)
        if visibleW > 0 then
        local selected = index == state.category
        local hovered = state.hovered == "category:" .. index
        local color = selected and tocolor(38, 46, 34, 255) or hovered and tocolor(30, 34, 39, 255) or tocolor(22, 25, 29, 255)
        rounded(x, y, visibleW, h, 7, color)
        rounded(x + 1, y + 1, visibleW - 2, h - 2, 7, tocolor(255, 255, 255, selected and 5 or 2))
        if selected then
            local accentW = math.min(categoryW * 0.44, visibleW - categoryW * 0.28)
            rounded(x + categoryW * 0.28, y, accentW, 4, 2, accent)
        end
        local texture = getTexture(category.tabImage)
        local iconSize = 52
        local centerX = x + categoryW / 2
        if texture then
            dxDrawImage(centerX - iconSize / 2, y + 20, iconSize, iconSize, texture, 0, 0, 0, selected and tocolor(255, 255, 255, 255) or tocolor(190, 190, 190, 165))
        end
        exports.aura_ui:uiDrawText(fitText(category.label, visibleW - 12, fonts.button), x + 6, y + 83, x + visibleW - 6, y + 116, selected and tocolor(250, 250, 247, 255) or tocolor(142, 142, 144, 205), 1, fonts.button, "center", "center", true)
        addHitbox("category:" .. index, "category", x, y, visibleW, h, index)
        end
    end
end

local function drawProductCard(item, index, x, y, w, h, accent)
    exports.aura_ui:uiDrawSurface(x,y,w,h,{color={22,25,29},radius=10,borderColor={48,54,61}},false)
    rounded(x + 10, y + 10, w - 20, 145, 8, tocolor(30,34,39,255))
    local texture = getTexture(item.image)
    local imageSize = 125
    local centerX = x + w / 2
    if texture then
        dxDrawImage(centerX - imageSize / 2, y + 20, imageSize, imageSize, texture)
    end

    local priceLabel = formatMoney(item.price)
    local priceW = math.max(45, exports.aura_ui:uiTextWidth(priceLabel, 1, fonts.badge) + 12)
    local priceX = x + w - priceW - 12
    exports.aura_ui:uiDrawText(fitText(item.name, priceX - x - 20, fonts.card), x + 12, y + 162, priceX - 6, y + 186, tocolor(247, 248, 250, 255), 1, fonts.card, "left", "center", true)
    rounded(priceX, y + 164, priceW, 20, 3, tocolor(38, 46, 34, 255))
    exports.aura_ui:uiDrawText(priceLabel, priceX + 2, y + 164, priceX + priceW - 2, y + 184, tocolor(201, 244, 111, 255), 1, fonts.badge, "center", "center", true)
    exports.aura_ui:uiDrawText(item.desc or "", x + 12, y + 188, x + w - 12, y + 224, tocolor(139, 139, 143, 220), 1, fonts.small, "left", "top", true, true)

    local quantity = state.quantities[item.id] or 1
    local controlsY = y + h - 38
    rounded(x + 12, controlsY, 54, 30, 5, tocolor(35, 36, 38, 238))
    exports.aura_ui:uiDrawText(tostring(quantity), x + 20, controlsY, x + 54, controlsY + 30, tocolor(140, 140, 143, 230), 1, fonts.button, "left", "center")
    drawButton("product-buy:" .. item.id, "Sepete Ekle", x + 72, controlsY, w - 84, 30, "accent")
    addHitbox("product-buy:" .. item.id, "product-buy", x + 72, controlsY, w - 84, 30, item)
end

local function drawProducts(accent)
    local category = state.shop.categories[state.category]
    if not category or not category.items then return end
    local areaX, areaY, areaW = 40, 309, 958
    local gapX, gapY = 14, 12
    local cardW = (areaW - gapX * (productColumns - 1)) / productColumns
    local cardH = 270
    local first = state.productRow * productColumns + 1
    local last = math.min(#category.items, first + productColumns * productRows - 1)

    for index = first, last do
        local visibleIndex = index - first
        local column = visibleIndex % productColumns
        local row = math.floor(visibleIndex / productColumns)
        local x = areaX + column * (cardW + gapX)
        local y = areaY + row * (cardH + gapY)
        drawProductCard(category.items[index], index, x, y, cardW, cardH, accent)
    end

    local totalRows = math.ceil(#category.items / productColumns)
    if totalRows > 1 then
        local trackX = areaX + areaW + 13
        local trackY = areaY
        local trackH = panelH - areaY - 20
        rounded(trackX, trackY, 2, trackH, 1, tocolor(255, 255, 255, 18))
        local thumbH = math.max(48, trackH / totalRows)
        local maxRow = totalRows - 1
        local thumbY = trackY + (trackH - thumbH) * state.productRow / maxRow
        rounded(trackX, thumbY, 2, thumbH, 1, accent)
    end
end

local function drawCartItem(entry, index, x, y, w, h, accent)
    local item = entry.item
    rounded(x, y, 72, 72, 7, tocolor(27, 28, 30, 235))
    rounded(x + 1, y + 1, 70, 70, 7, tocolor(255, 255, 255, 6))
    local texture = getTexture(item.image)
    if texture then
        dxDrawImage(x + 8, y + 8, 56, 56, texture)
    end
    exports.aura_ui:uiDrawText(fitText(item.name, 145, fonts.card), x + 86, y + 5, x + 231, y + 28, tocolor(245, 247, 250, 255), 1, fonts.card, "left", "center", true)
    rounded(x + 235, y + 7, 42, 18, 3, tocolor(38, 46, 34, 255))
    exports.aura_ui:uiDrawText(formatMoney(item.price), x + 237, y + 7, x + 275, y + 25, tocolor(201, 244, 111, 255), 1, fonts.badge, "center", "center", true)
    exports.aura_ui:uiDrawText(item.desc or "", x + 86, y + 30, x + 245, y + 68, tocolor(134, 134, 138, 220), 1, fonts.small, "left", "top", true, true)
    local controlY = y + 22
    drawButton("cart-delete:" .. item.id, "", x + w - 126, controlY, 28, 30, "danger", "cross")
    drawButton("cart-minus:" .. item.id, "<", x + w - 92, controlY, 28, 30, "neutral")
    exports.aura_ui:uiDrawText(tostring(entry.quantity), x + w - 61, controlY, x + w - 33, controlY + 30, tocolor(235, 237, 240, 245), 1, fonts.badge, "center", "center")
    drawButton("cart-plus:" .. item.id, ">", x + w - 28, controlY, 28, 30, "neutral")
    addHitbox("cart-delete:" .. item.id, "cart-delete", x + w - 126, controlY, 28, 30, index)
    addHitbox("cart-minus:" .. item.id, "cart-minus", x + w - 92, controlY, 28, 30, index)
    addHitbox("cart-plus:" .. item.id, "cart-plus", x + w - 28, controlY, 28, 30, index)
end

local function getCartTotal()
    local total = 0
    for _, entry in ipairs(state.cart) do
        total = total + entry.item.price * entry.quantity
    end
    return total
end

local function drawCart(accent)
    local x, w = 1038, 396
    exports.aura_ui:uiDrawText("Sepet", x, 48, x + w - 64, 82, tocolor(247, 248, 250, 255), 1, fonts.heading, "left", "center")
    exports.aura_ui:uiDrawText("Sepetinizi yönetin ve ürünlerinizi inceleyin.", x, 86, x + w - 62, 106, tocolor(112, 112, 116, 220), 1, fonts.small, "left", "center", true)
    drawButton("close", "", x + w - 46, 60, 46, 46, "danger", "cross")
    addHitbox("close", "close", x + w - 46, 60, 46, 46)

    if #state.cart == 0 then
        local basket = getTexture("cart_basket.png")
        if basket then
            dxDrawImage(x + w / 2 - 50, 298, 100, 100, basket, 0, 0, 0, tocolor(255, 255, 255, 145))
        end
        exports.aura_ui:uiDrawText("Sepetiniz boş.", x, 423, x + w, 451, tocolor(118, 118, 122, 230), 1, fonts.body, "center", "center")
    else
        local first = state.cartScroll + 1
        local last = math.min(#state.cart, first + cartRows - 1)
        local rowH, gap = 72, 11
        for index = first, last do
            drawCartItem(state.cart[index], index, x, 150 + (index - first) * (rowH + gap), w, rowH, accent)
        end

        if #state.cart > cartRows then
            local trackH = 572
            rounded(x + w + 8, 150, 2, trackH, 1, tocolor(255, 255, 255, 18))
            local thumbH = math.max(55, trackH * cartRows / #state.cart)
            local thumbY = 150 + (trackH - thumbH) * state.cartScroll / (#state.cart - cartRows)
            rounded(x + w + 8, thumbY, 2, thumbH, 1, accent)
        end
    end

    dxDrawLine(x, 749, x + w, 749, tocolor(255, 255, 255, 34), 1)
    rounded(x - 2, 747, 4, 4, 2, tocolor(255, 255, 255, 230))
    rounded(x + w - 2, 747, 4, 4, 2, tocolor(255, 255, 255, 230))
    exports.aura_ui:uiDrawText("Toplam", x, 763, x + 150, 801, tocolor(246, 248, 250, 255), 1, fonts.heading, "left", "center")
    exports.aura_ui:uiDrawText(formatMoney(getCartTotal()), x + 150, 763, x + w, 801, tocolor(201, 244, 111, 255), 1, fonts.heading, "right", "center")
    drawButton("checkout:cash", "Nakit", x, 815, 187, 42, "accent", nil, state.purchasing or #state.cart == 0)
    drawButton("checkout:card", "Kart", x + 205, 815, 191, 42, "neutral", nil, state.purchasing or #state.cart == 0)
    if not state.purchasing and #state.cart > 0 then
        addHitbox("checkout:cash", "checkout", x, 815, 187, 42, "cash")
        addHitbox("checkout:card", "checkout", x + 205, 815, 191, 42, "card")
    end
end

local function rebuildTarget()
    if not renderTarget or not isElement(renderTarget) or not state.shop then return false end
    clearHitboxes()

    local r, g, b = 201,244,111
    local accent = tocolor(r, g, b, 255)
    dxSetRenderTarget(renderTarget, true)
    dxSetBlendMode("modulate_add")
    exports.aura_ui:uiDrawSurface(0,0,panelW,panelH,{color={15,17,20},radius=16,borderColor={48,54,61}},false)
    drawBackdropDetail(r, g, b)
    exports.aura_ui:uiDrawText("aura",40,32,142,84,tocolor(239,242,244),1,fonts.title,"left","center")
    local marketTitleX=40+dxGetTextWidth("aura",1,fonts.title)+12
    exports.aura_ui:uiDrawText("MARKET",marketTitleX,43,310,75,tocolor(143,153,164),1,fonts.button,"left","center")
    exports.aura_ui:uiDrawText(state.shop.name or "Market",40,87,998,111,tocolor(143,153,164),1,fonts.body,"left","center",true)
    drawCategories(accent)
    rounded(40, 284, 958, 1, 0, tocolor(48,54,61))
    drawProducts(accent)
    drawCart(accent)

    dxSetBlendMode("blend")
    dxSetRenderTarget()
    state.dirty = false
    return true
end

local function getPanelGeometry()
    local scale = math.min((screenW - 40) / panelW, (screenH - 40) / panelH, 1)
    local width = panelW * scale
    local height = panelH * scale
    return (screenW - width) / 2, (screenH - height) / 2, width, height, scale
end

local function getHoveredHitbox()
    if not isCursorShowing() then return nil, nil end
    local cx, cy = getCursorPosition()
    if not cx or not cy then return nil, nil end
    local panelX, panelY, _, _, scale = getPanelGeometry()
    local x = (cx * screenW - panelX) / scale
    local y = (cy * screenH - panelY) / scale
    for index = hitboxCount, 1, -1 do
        local box = hitboxes[index]
        if x >= box.x and x <= box.x + box.w and y >= box.y and y <= box.y + box.h then
            return box.id, box
        end
    end
    return nil, nil
end

local function findCartEntry(itemId)
    for index, entry in ipairs(state.cart) do
        if entry.item.id == itemId then return entry, index end
    end
    return nil, nil
end

local function clampProductScroll()
    local category = state.shop and state.shop.categories[state.category]
    local totalRows = category and category.items and math.ceil(#category.items / productColumns) or 0
    state.productRow = math.max(0, math.min(state.productRow, math.max(0, totalRows - 1)))
end

local function clampCartScroll()
    state.cartScroll = math.max(0, math.min(state.cartScroll, math.max(0, #state.cart - cartRows)))
end

local function setDirty(refresh)
    state.dirty = true
    if refresh then
        refreshTextures()
    end
    if state.open and renderTarget and isElement(renderTarget) then
        rebuildTarget()
    end
end

local function addToCart(item)
    local quantity = state.quantities[item.id] or 1
    local entry = findCartEntry(item.id)
    if entry then
        entry.quantity = math.min(99, entry.quantity + quantity)
    else
        state.cart[#state.cart + 1] = { item = item, quantity = quantity }
    end
    clampCartScroll()
    playSoundFrontEnd(1)
    setDirty(true)
end

local function changeProductQuantity(item, delta)
    local current = state.quantities[item.id] or 1
    state.quantities[item.id] = math.max(1, math.min(99, current + delta))
    playSoundFrontEnd(1)
    setDirty(false)
end

local function changeCartQuantity(index, delta)
    local entry = state.cart[index]
    if not entry then return end
    entry.quantity = math.max(1, math.min(99, entry.quantity + delta))
    playSoundFrontEnd(1)
    setDirty(false)
end

local function removeCartEntry(index)
    if not state.cart[index] then return end
    table.remove(state.cart, index)
    clampCartScroll()
    playSoundFrontEnd(1)
    setDirty(true)
end

local function resetCheckoutState()
    if checkoutTimer and isTimer(checkoutTimer) then
        killTimer(checkoutTimer)
    end
    checkoutTimer = nil
    state.purchasing = false
    setDirty(false)
end

local function checkout(method)
    if state.purchasing or #state.cart == 0 then return end
    if not Config.PaymentMethods[method] then return end
    local items = {}
    for index, entry in ipairs(state.cart) do
        items[index] = { id = entry.item.id, quantity = entry.quantity }
    end
    state.purchasing = true
    setDirty(false)
    triggerServerEvent("gzl_market:serverPurchase", localPlayer, {
        shopType = state.shopType,
        method = method,
        items = items
    })
    checkoutTimer = setTimer(function()
        checkoutTimer = nil
        if not state.purchasing then return end
        state.purchasing = false
        setDirty(false)
        notify("Sunucudan satın alma yanıtı alınamadı.", "error")
    end, 7000, 1)
end

local function setControlsEnabled(enabled)
    toggleControl("forwards", enabled)
    toggleControl("backwards", enabled)
    toggleControl("left", enabled)
    toggleControl("right", enabled)
    toggleControl("fire", enabled)
    toggleControl("next_weapon", enabled)
    toggleControl("previous_weapon", enabled)
    toggleControl("aim_weapon", enabled)
    toggleControl("jump", enabled)
    toggleControl("sprint", enabled)
end

local function attachHandlers()
    if handlersAttached then return end
    addEventHandler("onClientRender", root, renderMarket, true, "low")
    addEventHandler("onClientClick", root, handleMarketClick)
    addEventHandler("onClientKey", root, handleMarketKey)
    addEventHandler("onClientCursorMove", root, handleMarketCursorMove)
    handlersAttached = true
end

local function detachHandlers()
    if not handlersAttached then return end
    removeEventHandler("onClientRender", root, renderMarket)
    removeEventHandler("onClientClick", root, handleMarketClick)
    removeEventHandler("onClientKey", root, handleMarketKey)
    removeEventHandler("onClientCursorMove", root, handleMarketCursorMove)
    handlersAttached = false
end

function toggleMarketUI(open, shopType)
    if open == state.open then return end
    if open then
        shopType = type(shopType) == "string" and shopType or "market"
        local shop = ShopsData[shopType] or ShopsData.market
        if not shop or not shop.categories or #shop.categories == 0 then
            notify("Mağaza verisi bulunamadı.", "error")
            return
        end
        prepareShop(shopType, shop)
        if not loadFonts() then
            notify("gzl_ui çalışmadığı için market açılamadı.", "error")
            return
        end
        if not createMarketTarget() then
            notify("DX render target oluşturulamadı.", "error")
            return
        end
        state.open = true
        state.shopType = ShopsData[shopType] and shopType or "market"
        state.shop = shop
        state.category = getDefaultCategoryIndex(shop)
        state.categoryOffset = 0
        state.productRow = 0
        state.cartScroll = 0
        state.cart = {}
        state.quantities = {}
        state.hovered = nil
        state.purchasing = false
        state.dirty = true
        refreshTextures()
        rebuildTarget()
        showCursor(true, true)
        setControlsEnabled(false)
        guiSetInputMode("no_binds")
        guiSetInputEnabled(true)
        attachHandlers()
        playSoundFrontEnd(11)
    else
        state.open = false
        resetCheckoutState()
        detachHandlers()
        showCursor(false)
        setControlsEnabled(true)
        guiSetInputMode("allow_binds")
        guiSetInputEnabled(false)
        destroyRenderTarget()
        state.shop = nil
        state.cart = {}
        state.quantities = {}
        state.hovered = nil
        playSoundFrontEnd(12)
    end
end

function isMarketOpen()
    return state.open
end

renderMarket = function()
    if not state.open then return end
    if not renderTarget or not isElement(renderTarget) then return end
    local x, y, w, h = getPanelGeometry()
    exports.aura_ui:uiDrawRectangle(0, 0, screenW, screenH, tocolor(0, 0, 0, 195))
    if backdropTexture and isElement(backdropTexture) then
        dxDrawImage(0, 0, screenW, screenH, backdropTexture)
    end
    dxDrawImage(x, y, w, h, renderTarget)
end

handleMarketCursorMove = function()
    if not state.open then return end
    local hovered = getHoveredHitbox()
    if hovered == state.hovered then return end
    state.hovered = hovered
    state.dirty = true
    rebuildTarget()
end

handleMarketClick = function(button, clickState)
    if not state.open or button ~= "left" or clickState ~= "up" then return end
    local _, box = getHoveredHitbox()
    if not box then return end

    if box.action == "close" then
        toggleMarketUI(false)
    elseif box.action == "category" then
        state.category = box.data
        state.productRow = 0
        playSoundFrontEnd(1)
        setDirty(true)
    elseif box.action == "product-minus" then
        changeProductQuantity(box.data, -1)
    elseif box.action == "product-plus" then
        changeProductQuantity(box.data, 1)
    elseif box.action == "product-buy" then
        addToCart(box.data)
    elseif box.action == "cart-minus" then
        changeCartQuantity(box.data, -1)
    elseif box.action == "cart-plus" then
        changeCartQuantity(box.data, 1)
    elseif box.action == "cart-delete" then
        removeCartEntry(box.data)
    elseif box.action == "checkout" then
        checkout(box.data)
    end
end

handleMarketKey = function(button, press)
    if not state.open or not press then return end
    if button == "escape" then
        cancelEvent()
        toggleMarketUI(false)
        return
    end
    if button ~= "mouse_wheel_up" and button ~= "mouse_wheel_down" then return end
    local direction = button == "mouse_wheel_up" and -1 or 1
    local cx, cy = getCursorPosition()
    if not cx then return end
    local panelX, panelY, panelWidth, _, scale = getPanelGeometry()
    local absoluteX = cx * screenW
    local localX = (absoluteX - panelX) / scale
    local localY = (cy * screenH - panelY) / scale
    if localX >= 40 and localX <= 1014 and localY >= 140 and localY <= 288 then
        local before = state.categoryOffset
        state.categoryOffset = math.max(0, math.min(state.categoryOffset + direction, math.max(0, #state.shop.categories - 7)))
        if before ~= state.categoryOffset then
            setDirty(false)
        end
        cancelEvent()
        return
    end
    if absoluteX >= panelX + panelWidth * 0.70 then
        local before = state.cartScroll
        state.cartScroll = state.cartScroll + direction
        clampCartScroll()
        if before ~= state.cartScroll then
            setDirty(true)
        end
    else
        local before = state.productRow
        state.productRow = state.productRow + direction
        clampProductScroll()
        if before ~= state.productRow then
            setDirty(true)
        end
    end
    cancelEvent()
end

addEvent("gzl_market:open", true)
addEventHandler("gzl_market:open", root, function(shopType)
    toggleMarketUI(true, shopType)
end)

addEvent("gzl_market:purchaseSuccess", true)
addEventHandler("gzl_market:purchaseSuccess", root, function(data)
    if source ~= localPlayer or type(data) ~= "table" then return end
    resetCheckoutState()
    if state.open then
        state.cart = {}
        state.cartScroll = 0
        setDirty(true)
    end
    notify("Satın alma başarılı: " .. formatMoney(data.totalCost), "success")
end)

addEvent("gzl_market:purchaseError", true)
addEventHandler("gzl_market:purchaseError", root, function(data)
    if source ~= localPlayer or type(data) ~= "table" then return end
    resetCheckoutState()
    notify(data.message or "İşlem başarısız.", "error")
end)

addEventHandler("onClientRestore", root, function()
    screenW, screenH = guiGetScreenSize()
    if state.open then
        setDirty(false)
    end
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    if checkoutTimer and isTimer(checkoutTimer) then
        killTimer(checkoutTimer)
    end
    detachHandlers()
    if state.open then
        showCursor(false)
        setControlsEnabled(true)
        guiSetInputMode("allow_binds")
        guiSetInputEnabled(false)
    end
    destroyRenderTarget()
    destroyTextures()
end)
