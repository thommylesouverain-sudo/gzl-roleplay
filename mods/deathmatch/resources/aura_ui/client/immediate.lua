-- Stateless DX drawing API. Caller retains hitboxes, events and render targets.
local U=Aura.util
local function unpackColor(value,default)
    if type(value)=="table" then return value end
    if type(value)~="number" then return default or Aura.theme.surface end
    value=value%4294967296
    return {math.floor(value/65536)%256,math.floor(value/256)%256,value%256,math.floor(value/16777216)%256}
end
local function neutral(value)
    local c=unpackColor(value)
    -- Keep semantic/brand colors and opacity. Normalize only dark blue-gray fills.
    if c[1]>0 and c[3]<85 and c[3]>=c[1] and c[3]-c[1]<48 then
        local t=c[3]<25 and Aura.theme.background or (c[3]<46 and Aura.theme.panel or Aura.theme.surface)
        return {t[1],t[2],t[3],c[4] or 255}
    end
    return c
end
function uiDrawSurface(x,y,w,h,options,postGUI)
    if type(x)~="number" or type(y)~="number" or type(w)~="number" or type(h)~="number" or w<=0 or h<=0 then return false end
    local p=U.copy(options or {})
    local fill=p.color and unpackColor(p.color) or Aura.theme[p.token or "panel"] or Aura.theme.panel
    local edge=p.borderColor and unpackColor(p.borderColor) or (p.border and Aura.theme.border)
    local gradient=p.gradient and unpackColor(p.gradient)
    p.borderColor=edge
    if (p.radius or 10)==0 and not edge and not gradient and (not p.style or p.style=="solid") then
        return Aura.immediate(U.rect,postGUI,x,y,w,h,fill,p.opacity)
    end
    return Aura.immediate(U.box,postGUI,x,y,w,h,fill,p.radius or 10,edge,gradient,p.opacity,p)
end
function uiDrawRectangle(x,y,w,h,c,postGUI,subPixel)
    return uiDrawSurface(x,y,w,h,{color=neutral(c or tocolor(255,255,255)),radius=0},postGUI)
end
function uiDrawRoundedRectangle(x,y,w,h,r,c,postGUI)
    return uiDrawSurface(x,y,w,h,{color=neutral(c),radius=r or 10},postGUI)
end
function uiDrawBorder(x,y,w,h,r,width,c,postGUI)
    return uiDrawSurface(x,y,w,h,{color={0,0,0,0},radius=r or 10,borderColor=unpackColor(c,Aura.theme.border),borderWidth=width or 1},postGUI)
end
function uiDrawPanel(x,y,w,h,r,cOrPost,postGUI)
    local tint=type(cOrPost)=="number" and unpackColor(cOrPost) or {255,255,255,255}
    if type(cOrPost)=="boolean" then postGUI=cOrPost end
    local c=Aura.theme.panel
    return uiDrawSurface(x,y,w,h,{color={c[1]*tint[1]/255,c[2]*tint[2]/255,c[3]*tint[3]/255,tint[4]},radius=r or 14,border=true},postGUI)
end
local tones={blue="info",green="success",mint="success",red="danger",error="danger",danger="danger",warning="warning",amber="warning"}
function uiDrawButtonSurface(x,y,w,h,r,tone,state,postGUI)
    local accent=Aura.theme[tones[tone] or tone or "accent"] or Aura.theme.accent
    local fill=U.mix(Aura.theme.panel,accent,state=="hover" and 0.32 or 0.2)
    return uiDrawSurface(x,y,w,h,{color=fill,radius=r or 10,borderColor=U.mix(Aura.theme.border,accent,0.5)},postGUI)
end
function uiDrawEditSurface(x,y,w,h,r,state,postGUI)
    return uiDrawSurface(x,y,w,h,{token="surface",radius=r or 10,borderColor=state=="active" and Aura.theme.accent or (state=="hover" and Aura.theme.muted or Aura.theme.border)},postGUI)
end
function uiDrawTabsSurface(x,y,w,h,r,active,postGUI)
    uiDrawSurface(x,y,w,h,{token="background",radius=r or 10,border=true},postGUI)
    local left=active=="login" or active==1
    return uiDrawSurface(x+4+(left and 0 or w/2),y+4,w/2-8,h-8,{token="surface",radius=math.max(0,(r or 10)-3)},postGUI)
end
function uiDrawNotificationSurface(x,y,w,h,r,tone,postGUI,alpha)
    uiDrawSurface(x,y,w,h,{token="panel",radius=r or 12,border=true,opacity=(alpha or 255)/255},postGUI)
    return uiDrawSurface(x+12,y+12,3,math.max(1,h-24),{token=tones[tone] or tone or "info",radius=1,opacity=(alpha or 255)/255},postGUI)
end
function uiGetFont(weight,size)
    local bold=weight=="bold" or weight=="heavy" or weight=="semibold" or weight=="default-bold"
    return U.font(tonumber(size) or 11,bold)
end
local function textFont(scale,font)
    if font==nil or font=="default" or font=="default-bold" or font=="clear" then
        -- Fixed 9pt base retains existing scale and measurement relationships.
        return scale or 1,uiGetFont(font,9)
    end
    return scale or 1,font
end
function uiDrawText(value,x,y,right,bottom,c,scale,font,...)
    scale,font=textFont(scale,font)
    return dxDrawText(value,x,y,right,bottom,c,scale,font,...)
end
function uiTextWidth(value,scale,font,colorCoded)
    scale,font=textFont(scale,font)
    return dxGetTextWidth(value,scale,font,colorCoded)
end
function uiFontHeight(scale,font)
    scale,font=textFont(scale,font)
    return dxGetFontHeight(scale,font)
end
