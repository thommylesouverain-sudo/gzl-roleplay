
FontManager = {}
local loadedFonts = {}

function FontManager.get(weight, size)
    weight = weight or "regular"
    size = tonumber(size) or 11
    local key = string.format("%s_%d", weight, size)

    if not loadedFonts[key] then
        local fontFile = ":aura_ui/assets/Manrope-Medium.ttf"
        local isBold = false

        if weight == "medium" then
            fontFile = ":aura_ui/assets/Manrope-Medium.ttf"
        elseif weight == "semibold" then
            fontFile = ":aura_ui/assets/Manrope-Bold.ttf"
        elseif weight == "bold" then
            fontFile = ":aura_ui/assets/Manrope-Bold.ttf"
            isBold = true
        elseif weight == "heavy" then
            fontFile = ":aura_ui/assets/Manrope-Bold.ttf"
            isBold = true
        end

        if fileExists(fontFile) then
            loadedFonts[key] = dxCreateFont(fontFile, size, isBold, "antialiased")
        end

        if not loadedFonts[key] then
            local gzlUi = getResourceFromName("gzl_ui")
            if gzlUi and getResourceState(gzlUi) == "running" then
                local f = exports.gzl_ui:getFont(weight, size)
                if f then loadedFonts[key] = f end
            end
        end

        if not loadedFonts[key] then
            loadedFonts[key] = isBold and "default-bold" or "default"
        end
    end

    return loadedFonts[key]
end

addEventHandler("onClientResourceStop", resourceRoot, function()
    for k, font in pairs(loadedFonts) do
        if isElement(font) then
            destroyElement(font)
        end
    end
    loadedFonts = {}
end)