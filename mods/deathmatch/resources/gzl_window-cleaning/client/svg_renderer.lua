-- AURA surfaces; job input, timing and progress stay in this resource.
function drawGlassPanel(x,y,w,h,r,bgAlpha)
    return exports.aura_ui:uiDrawSurface(x,y,w,h,{token="panel",radius=r or 12,border=true,opacity=bgAlpha or 1})
end
function drawRoundedRectangle(x,y,w,h,r,color)
    return exports.aura_ui:uiDrawRoundedRectangle(x,y,w,h,r,color)
end
function drawCircle(cx,cy,r,color)
    return exports.aura_ui:uiDrawRoundedRectangle(cx-r,cy-r,r*2,r*2,r,color)
end

function drawProgressBar(x, y, w, h, r, progress, fillColor, bgColor)
    progress = math.max(0, math.min(1, progress or 0))
    bgColor = bgColor or tocolor(30, 41, 59, 200)
    fillColor = fillColor or tocolor(56, 189, 248, 255)
    drawRoundedRectangle(x, y, w, h, r, bgColor)
    if progress > 0.01 then
        local fillW = math.max(r * 2, w * progress)
        drawRoundedRectangle(x, y, fillW, h, r, fillColor)
    end
end

function isCursorWithin(x, y, w, h)
    if not isCursorShowing() then return false end
    local cx, cy = getCursorPosition()
    if not cx or not cy then return false end
    local sw, sh = guiGetScreenSize()
    cx, cy = cx * sw, cy * sh
    return (cx >= x and cx <= x + w and cy >= y and cy <= y + h)
end