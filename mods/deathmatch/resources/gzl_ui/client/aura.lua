-- Compatibility facade: existing input IDs, events and timers stay in gzl_ui.
-- All shared panel/button/edit drawing and fonts now come from AURA.
local nativeFont=getFont
local ownedFonts={}
local function ready()
    local r=getResourceFromName("aura_ui")
    return r and getResourceState(r)=="running"
end
local function bridge(name,exportName)
    local fallback=_G[name]
    _G[name]=function(...)
        if ready() then return exports.aura_ui[exportName](exports.aura_ui,...) end
        if fallback then return fallback(...) end
        return false
    end
end
bridge("drawRoundedRectangle","uiDrawRoundedRectangle")
bridge("drawRoundedBorder","uiDrawBorder")
bridge("drawGlassPanel","uiDrawPanel")
bridge("drawLiquidButtonSVG","uiDrawButtonSurface")
bridge("drawEditBoxSVG","uiDrawEditSurface")
bridge("drawDiagonalTabBarSVG","uiDrawTabsSurface")
bridge("drawNotificationCardSVG","uiDrawNotificationSurface")
function getFont(weight,size)
    size=math.max(6,math.min(96,math.floor((tonumber(size) or 11)+0.5)))
    local bold=weight=="bold" or weight=="heavy" or weight=="semibold" or weight=="default-bold"
    local key=size..tostring(bold)
    if not isElement(ownedFonts[key]) then
        ownedFonts[key]=dxCreateFont(":aura_ui/assets/Manrope-"..(bold and "Bold" or "Medium")..".ttf",size,false,"cleartype")
    end
    return ownedFonts[key] or nativeFont(weight,size)
end
addEventHandler("onClientResourceStop",resourceRoot,function()
    for _,font in pairs(ownedFonts) do if isElement(font) then destroyElement(font) end end
    ownedFonts={}
end)
local nativeCircle=drawCircle
function drawCircle(cx,cy,r,c,postGUI)
    if ready() then return exports.aura_ui:uiDrawRoundedRectangle(cx-r,cy-r,r*2,r*2,r,c,postGUI) end
    return nativeCircle(cx,cy,r,c,postGUI)
end
