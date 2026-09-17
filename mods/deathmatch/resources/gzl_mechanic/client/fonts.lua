local fontCache = {}
local fontFiles = {
    ["regular"] = ":aura_ui/assets/Manrope-Medium.ttf",
    ["medium"] = ":aura_ui/assets/Manrope-Medium.ttf",
    ["semibold"] = ":aura_ui/assets/Manrope-Bold.ttf",
    ["bold"] = ":aura_ui/assets/Manrope-Bold.ttf",
    ["heavy"] = ":aura_ui/assets/Manrope-Bold.ttf"
}

function getMechanicFont(style, size)
    style = string.lower(style or "regular")
    size = math.max(7, math.floor(tonumber(size) or 11))
    local key = style .. "_" .. size
    if fontCache[key] and isElement(fontCache[key]) then
        return fontCache[key]
    end

    local path = fontFiles[style] or fontFiles["regular"]
    if fileExists(path) then
        local f = dxCreateFont(path, size, false, "cleartype")
        if f then
            fontCache[key] = f
            return f
        end
    end

    if exports.gzl_ui and exports.gzl_ui.getFont then
        local uiFont = exports.gzl_ui:getFont(style, size)
        if uiFont and uiFont ~= "default" and uiFont ~= "default-bold" then
            return uiFont
        end
    end

    return (style == "bold" or style == "heavy" or style == "semibold") and "default-bold" or "default"
end

addEventHandler("onClientResourceStop", resourceRoot, function()
    for _, f in pairs(fontCache) do
        if isElement(f) then
            destroyElement(f)
        end
    end
    fontCache = {}
end)