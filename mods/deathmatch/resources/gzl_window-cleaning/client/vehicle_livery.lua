VehicleLivery = {}

local logoShader = nil
local logoTexture = nil

local function getShader()
    if not isElement(logoShader) then
        logoShader = dxCreateShader("assets/shaders/tex_replace.fx")
        logoTexture = dxCreateTexture("assets/textures/utility_logo.png", "argb")
        if isElement(logoShader) and isElement(logoTexture) then
            dxSetShaderValue(logoShader, "gTexture", logoTexture)
        else
            outputDebugString("[GZL-LIVERY ERROR] Failed to create shader or texture! Shader: " .. tostring(isElement(logoShader)) .. " Tex: " .. tostring(isElement(logoTexture)), 1)
        end
    end
    return logoShader
end

local function isCleaningVehicle(veh)
    if not isElement(veh) or getElementType(veh) ~= "vehicle" then return false end
    if getElementData(veh, "window_cleaning:isJobVehicle") then return true end
    if getElementData(veh, "window_cleaning:jobId") then return true end
    if Equipment and Equipment.getVehicle and Equipment.getVehicle() == veh then return true end
    return false
end

function VehicleLivery.apply(veh)
    if not isElement(veh) or getElementType(veh) ~= "vehicle" then return false end
    local sh = getShader()
    if not isElement(sh) then
        outputDebugString("[GZL-LIVERY] Shader could not be created!", 1)
        return false
    end

    local texNames = engineGetModelTextureNames(getElementModel(veh)) or {}
    outputDebugString("[GZL-VEH-TEXTURES] Model: " .. tostring(getElementModel(veh)) .. " Textures: " .. toJSON(texNames), 3)

    local matched = false
    for _, tex in ipairs(texNames) do
        local lower = string.lower(tex)
        if string.find(lower, "logo") or string.find(lower, "sanit") or string.find(lower, "andreas") or string.find(lower, "badge") or string.find(lower, "sign") or string.find(lower, "decal") or string.find(lower, "decay") then
            engineApplyShaderToWorldTexture(sh, tex, veh)
            outputDebugString("[GZL-LIVERY] Applied shader to texture: " .. tex, 3)
            matched = true
        end
    end

    -- Always apply to standard wildcards as well
    engineApplyShaderToWorldTexture(sh, "utility92logo*", veh)
    engineApplyShaderToWorldTexture(sh, "*logo*", veh)
    engineApplyShaderToWorldTexture(sh, "*sanit*", veh)

    return true
end

function VehicleLivery.remove(veh)
    if not isElement(veh) or not isElement(logoShader) then return end
    engineRemoveShaderFromWorldTexture(logoShader, "*", veh)
end

-- Stream-in & Data Watchers
addEventHandler("onClientElementStreamIn", root, function()
    if isCleaningVehicle(source) then
        VehicleLivery.apply(source)
    end
end)

addEventHandler("onClientElementDataChange", root, function(dataName)
    if (dataName == "window_cleaning:isJobVehicle" or dataName == "window_cleaning:jobId") and getElementType(source) == "vehicle" then
        if isCleaningVehicle(source) then
            if isElementStreamedIn(source) then
                VehicleLivery.apply(source)
            end
        else
            VehicleLivery.remove(source)
        end
    end
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    for _, veh in ipairs(getElementsByType("vehicle")) do
        if isCleaningVehicle(veh) and isElementStreamedIn(veh) then
            VehicleLivery.apply(veh)
        end
    end
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    if isElement(logoShader) then destroyElement(logoShader) end
    if isElement(logoTexture) then destroyElement(logoTexture) end
    logoShader = nil
    logoTexture = nil
end)
