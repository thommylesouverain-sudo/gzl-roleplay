local screenW, screenH = guiGetScreenSize()
local createdPeds = {}
local createdBlips = {}
local vendingObjects = {}
local nearestShop = nil
local nearestShopType = nil
local nearestVendingType = nil
local interactionTimer = nil
local promptFonts = {}
local promptRenderTarget = nil
local promptW, promptH = 360, 118
local lastCheckX, lastCheckY, lastCheckZ = nil, nil, nil
local lastCheckRotation = nil
local lastCheckInterior, lastCheckDimension = nil, nil
local interactionDirty = true
local promptHandlerAttached = false
local renderInteractionPrompt
local setPromptRendererEnabled

local function preventShopPedDamage()
    cancelEvent()
end

local vendingModels = {
    [1775] = { type = "sprunk" },
    [1776] = { type = "sprunk" },
    [955] = { type = "sprunk" },
    [1302] = { type = "sprunk" },
    [1977] = { type = "sprunk" },
    [956] = { type = "vending_snacks" },
    [1209] = { type = "vending_snacks" }
}

local function hasUiExport(name)
    local resource = getResourceFromName("gzl_ui")
    if not resource or getResourceState(resource) ~= "running" then return false end
    return exports.gzl_ui and type(exports.gzl_ui[name]) == "function"
end

local function rounded(x, y, w, h, radius, color)
    if hasUiExport("drawRoundedRectangle") then
        exports.gzl_ui:drawRoundedRectangle(x, y, w, h, radius, color)
    end
end

local function loadPromptFonts()
    if not hasUiExport("getFont") then return end
    promptFonts.key = exports.gzl_ui:getFont("heavy", 17)
    promptFonts.title = exports.gzl_ui:getFont("bold", 16)
    promptFonts.hint = exports.gzl_ui:getFont("medium", 11)
end

local function createPromptTarget()
    if promptRenderTarget and isElement(promptRenderTarget) then
        destroyElement(promptRenderTarget)
    end
    promptRenderTarget = nil
    loadPromptFonts()
    if not promptFonts.key or not promptFonts.title or not promptFonts.hint then return false end
    promptRenderTarget = dxCreateRenderTarget(promptW, promptH, true)
    if not promptRenderTarget or not isElement(promptRenderTarget) then
        promptRenderTarget = nil
        return false
    end
    dxSetRenderTarget(promptRenderTarget, true)
    dxSetBlendMode("modulate_add")
    local keyW, keyH = 50, 42
    local keyX = (promptW - keyW) / 2
    rounded(keyX, 0, keyW, keyH, 8, tocolor(244, 255, 40, 250))
    rounded(keyX + 3, 3, keyW - 6, keyH - 6, 6, tocolor(15, 16, 18, 235))
    exports.aura_ui:uiDrawText(string.upper(Config.OpenKey or "e"), keyX, 0, keyX + keyW, keyH, tocolor(244, 255, 40, 255), 1, promptFonts.key, "center", "center")
    exports.aura_ui:uiDrawText("E Tuşuna Bas", 0, 45, promptW, 70, tocolor(250, 250, 250, 255), 1, promptFonts.title, "center", "center")
    exports.aura_ui:uiDrawText("Açmak için E tuşuna bas.", 0, 73, promptW, 96, tocolor(215, 215, 218, 245), 1, promptFonts.hint, "center", "center")
    dxSetBlendMode("blend")
    dxSetRenderTarget()
    return true
end

local function createWorldShops()
    for shopType, shopData in pairs(ShopsData) do
        if shopData.locations then
            for _, loc in ipairs(shopData.locations) do
                local ped = createPed(loc.pedModel or 172, loc.x, loc.y, loc.z, loc.pedHeading or 0)
                if isElement(ped) then
                    setElementInterior(ped, loc.interior or 0)
                    setElementDimension(ped, loc.dimension or 0)
                    setElementFrozen(ped, true)
                    setElementCollisionsEnabled(ped, false)
                    setElementAlpha(ped, 255)
                    addEventHandler("onClientPedDamage", ped, preventShopPedDamage, false)
                    createdPeds[#createdPeds + 1] = { element = ped, shopType = shopType }
                end
                if Config.UseBlips then
                    local blip = createBlip(loc.x, loc.y, loc.z, Config.BlipId, 2, 255, 255, 255, 255, 0, 300)
                    if isElement(blip) then
                        setElementInterior(blip, loc.interior or 0)
                        setElementDimension(blip, loc.dimension or 0)
                        setElementData(blip, "blip:name", shopData.name, false)
                        createdBlips[#createdBlips + 1] = blip
                    end
                end
            end
        end
    end
end

local function cacheInitialVendingObjects()
    for _, object in ipairs(getElementsByType("object", root, true)) do
        local model = getElementModel(object)
        if vendingModels[model] then
            vendingObjects[object] = model
        end
    end
end

local function clearNearestInteraction()
    nearestShop = nil
    nearestShopType = nil
    nearestVendingType = nil
    if setPromptRendererEnabled then
        setPromptRendererEnabled(false)
    end
end

local function updateNearestInteraction()
    if not isElement(localPlayer) then return end
    if isMarketOpen() then
        clearNearestInteraction()
        return
    end
    if isPedInVehicle(localPlayer) then
        clearNearestInteraction()
        lastCheckX = nil
        interactionDirty = true
        return
    end
    local px, py, pz = getElementPosition(localPlayer)
    local pInt = getElementInterior(localPlayer)
    local pDim = getElementDimension(localPlayer)
    local _, _, pRot = getElementRotation(localPlayer)
    if lastCheckX and not interactionDirty and pInt == lastCheckInterior and pDim == lastCheckDimension then
        local moveX, moveY, moveZ = px - lastCheckX, py - lastCheckY, pz - lastCheckZ
        local rotationDelta = math.abs(((pRot - lastCheckRotation + 180) % 360) - 180)
        if moveX * moveX + moveY * moveY + moveZ * moveZ < 0.0025 and rotationDelta < 2 then
            return
        end
    end
    lastCheckX, lastCheckY, lastCheckZ = px, py, pz
    lastCheckRotation = pRot
    lastCheckInterior, lastCheckDimension = pInt, pDim
    interactionDirty = false
    nearestShop = nil
    nearestShopType = nil
    nearestVendingType = nil
    local nearestDistance = Config.InteractionDistance + 0.01

    for _, entry in ipairs(createdPeds) do
        local ped = entry.element
        if isElement(ped) and getElementInterior(ped) == pInt and getElementDimension(ped) == pDim then
            local x, y, z = getElementPosition(ped)
            local distance = getDistanceBetweenPoints3D(px, py, pz, x, y, z)
            if distance < nearestDistance then
                nearestDistance = distance
                nearestShop = ped
                nearestShopType = entry.shopType
            end
        end
    end

    if nearestShopType then
        setPromptRendererEnabled(true)
        return
    end

    local rad = math.rad(-pRot)
    local lookX = px + math.sin(rad) * 2.8
    local lookY = py + math.cos(rad) * 2.8
    local hit, _, _, _, hitElement, _, _, _, _, _, _, worldModelID, worldModelX, worldModelY, worldModelZ = processLineOfSight(px, py, pz + 0.3, lookX, lookY, pz + 0.3, true, true, false, true, true, false, false, false, localPlayer, true)
    local targetModel = nil
    local targetX, targetY, targetZ = nil, nil, nil

    if hit then
        if isElement(hitElement) and getElementType(hitElement) == "object" then
            local model = getElementModel(hitElement)
            if vendingModels[model] then
                targetModel = model
                targetX, targetY, targetZ = getElementPosition(hitElement)
            end
        elseif worldModelID and vendingModels[worldModelID] then
            targetModel = worldModelID
            targetX, targetY, targetZ = worldModelX, worldModelY, worldModelZ
        end
    end

    if not targetModel then
        local closestObjectDistance = 2.21
        for object, model in pairs(vendingObjects) do
            if isElement(object) and getElementInterior(object) == pInt and getElementDimension(object) == pDim then
                local ox, oy, oz = getElementPosition(object)
                local distance = getDistanceBetweenPoints3D(px, py, pz, ox, oy, oz)
                if distance < closestObjectDistance then
                    closestObjectDistance = distance
                    targetModel = model
                    targetX, targetY, targetZ = ox, oy, oz
                end
            elseif not isElement(object) then
                vendingObjects[object] = nil
            end
        end
    end

    if targetModel and targetX then
        local distance = getDistanceBetweenPoints3D(px, py, pz, targetX, targetY, targetZ)
        if distance <= 2.5 and distance < nearestDistance then
            nearestShop = nil
            nearestShopType = nil
            nearestVendingType = vendingModels[targetModel].type
        end
    end
    setPromptRendererEnabled(nearestVendingType ~= nil or nearestShopType ~= nil)
end

local function drawInteractionPrompt()
    if isMarketOpen and isMarketOpen() then return end
    if not nearestVendingType and not nearestShopType then return end
    if not promptRenderTarget or not isElement(promptRenderTarget) then return end
    local scale = math.min(screenW / 1920, screenH / 1080)
    local width, height = promptW * scale, promptH * scale
    dxDrawImage((screenW - width) / 2, screenH - 121 * scale, width, height, promptRenderTarget)
end

renderInteractionPrompt = function()
    drawInteractionPrompt()
end

setPromptRendererEnabled = function(enabled)
    if enabled and not promptHandlerAttached then
        addEventHandler("onClientRender", root, renderInteractionPrompt, true, "low-10")
        promptHandlerAttached = true
    elseif not enabled and promptHandlerAttached then
        removeEventHandler("onClientRender", root, renderInteractionPrompt)
        promptHandlerAttached = false
    end
end

bindKey(Config.OpenKey, "down", function()
    if isMarketOpen() then
        toggleMarketUI(false)
        interactionDirty = true
        return
    end
    if nearestVendingType then
        local vType = nearestVendingType
        clearNearestInteraction()
        toggleMarketUI(true, vType)
        return
    end
    if nearestShop and isElement(nearestShop) and nearestShopType then
        local sType = nearestShopType
        clearNearestInteraction()
        toggleMarketUI(true, sType)
    end
end)

addEventHandler("onClientPlayerDrink", localPlayer, function()
    cancelEvent()
    toggleMarketUI(true, "sprunk")
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    createPromptTarget()
    createWorldShops()
    cacheInitialVendingObjects()
    updateNearestInteraction()
    interactionTimer = setTimer(updateNearestInteraction, 250, 0)
end)

addEventHandler("onClientRestore", root, function()
    screenW, screenH = guiGetScreenSize()
    setTimer(createPromptTarget, 100, 1)
end)

addEventHandler("onClientElementStreamIn", root, function()
    if getElementType(source) ~= "object" then return end
    local model = getElementModel(source)
    if not vendingModels[model] then return end
    vendingObjects[source] = model
    interactionDirty = true
end)

addEventHandler("onClientElementStreamOut", root, function()
    if not vendingObjects[source] then return end
    vendingObjects[source] = nil
    interactionDirty = true
end)

addEventHandler("onClientElementDestroy", root, function()
    if not vendingObjects[source] then return end
    vendingObjects[source] = nil
    interactionDirty = true
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    if interactionTimer and isTimer(interactionTimer) then
        killTimer(interactionTimer)
    end
    setPromptRendererEnabled(false)
    if promptRenderTarget and isElement(promptRenderTarget) then
        destroyElement(promptRenderTarget)
    end
    promptRenderTarget = nil
    for _, entry in ipairs(createdPeds) do
        if isElement(entry.element) then
            destroyElement(entry.element)
        end
    end
    for _, blip in ipairs(createdBlips) do
        if isElement(blip) then
            destroyElement(blip)
        end
    end
    createdPeds = {}
    createdBlips = {}
    vendingObjects = {}
end)