-- AURA: all coordinates are logical pixels; children inherit the root scale.
Aura = { nodes = {}, order = {}, theme = {
    background = {15,17,20}, panel = {22,25,29}, surface = {30,34,39},
    border = {48,54,61}, text = {239,242,244}, muted = {143,153,164},
    accent = {201,244,111}, ink = {24,32,17}, danger = {248,119,133},
    success = {111,220,170}, warning = {244,194,109}, info = {132,181,255}
} }
local A = Aura
A.renderers,A.interactive = {},{}
local kinds = {panel=true,label=true,button=true,badge=true,edit=true,checkbox=true,
    switch=true,slider=true,progress=true,tabs=true,select=true,divider=true}
local fonts, shader, focused, pressed, dropdown, oldInputMode = {}, nil, nil, nil, nil, nil
local toasts, hits, lastTick = {}, {}, getTickCount()
local drawCount = 0
local postGUI = false
local ox,oy,target,clip = 0,0,nil,nil
local topModal
local scrolls={}
local function clamp(n,a,b) return math.max(a,math.min(b,n)) end
local function copy(t) local r={} for k,v in pairs(t) do r[k]=type(v)=="table" and copy(v) or v end return r end
local function color(c,alpha) return tocolor(c[1],c[2],c[3],(c[4] or 255)*(alpha or 1)) end
local function mix(a,b,t) return {a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t,a[3]+(b[3]-a[3])*t} end
local function rgba(c,a) return c[1]/255,c[2]/255,c[3]/255,(c[4] or 255)/255*(a or 1) end
local function font(size,bold)
    size=clamp(math.floor(size+0.5),6,96)
    local key=size..tostring(bold)
    if not isElement(fonts[key]) then fonts[key]=dxCreateFont("assets/Manrope-"..(bold and "Bold" or "Medium")..".ttf",size,false,"cleartype") end
    return fonts[key] or "default"
end
local function rect(x,y,w,h,c,alpha)
    dxDrawRectangle(x-ox,y-oy,w,h,color(c,alpha),postGUI and not target)
end
local function line(x,y,x2,y2,c,width,alpha)
    dxDrawLine(x-ox,y-oy,x2-ox,y2-oy,color(c,alpha),width or 1,postGUI and not target)
end
local styleIds={solid=0,outline=1,glass=2,gradient=3,modern=4,glow=5,dashed=6}
local function box(x,y,w,h,c,r,edge,gradient,alpha,options)
    if w<=0 or h<=0 then return end
    options=options or {}
    local style=options.style or "solid"
    local intensity=clamp(tonumber(options.intensity) or 0.7,0,1)
    if style=="outline" then edge=options.borderColor or edge or c; c={c[1],c[2],c[3],options.fillAlpha or 22} end
    if style=="gradient" and not gradient then gradient=mix(c,{6,9,15},0.6) end
    if style=="glass" or style=="modern" or style=="glow" then
        edge=options.borderColor or edge or mix(c,{255,255,255},0.3)
        gradient=gradient or mix(c,{6,9,15},0.4)
    end
    if style=="dashed" then edge=options.borderColor or edge or c end
    if options.sharp then r=0 end
    drawCount=drawCount+1
    if shader then
        dxSetShaderValue(shader,"size",w,h)
        dxSetShaderValue(shader,"radius",math.min(r or 10,w/2,h/2))
        dxSetShaderValue(shader,"borderWidth",edge and (options.borderWidth or 1) or 0)
        dxSetShaderValue(shader,"fillColor",rgba(c,alpha))
        dxSetShaderValue(shader,"endColor",rgba(gradient or c,alpha))
        dxSetShaderValue(shader,"edgeColor",rgba(edge or c,alpha))
        dxSetShaderValue(shader,"style",styleIds[style] or 0)
        dxSetShaderValue(shader,"direction",options.direction=="horizontal" and 1 or 0)
        dxSetShaderValue(shader,"dashLength",math.max(1,options.dashLength or 8))
        dxSetShaderValue(shader,"dashGap",math.max(1,options.dashGap or 5))
        dxSetShaderValue(shader,"intensity",intensity)
        dxDrawImage(x-ox,y-oy,w,h,shader,0,0,0,tocolor(255,255,255,255),postGUI and not target)
    else
        rect(x,y,w,h,c,alpha)
        if edge then
            if style=="dashed" then
                local length,gap=math.max(1,options.dashLength or 8),math.max(1,options.dashGap or 5)
                for px=0,w,length+gap do rect(x+px,y,math.min(length,w-px),1,edge,alpha); rect(x+px,y+h-1,math.min(length,w-px),1,edge,alpha) end
                for py=0,h,length+gap do rect(x,y+py,1,math.min(length,h-py),edge,alpha); rect(x+w-1,y+py,1,math.min(length,h-py),edge,alpha) end
            else
                rect(x,y,w,1,edge,alpha); rect(x,y+h-1,w,1,edge,alpha)
                rect(x,y,1,h,edge,alpha); rect(x+w-1,y,1,h,edge,alpha)
            end
        end
    end
end
local function text(s,x,y,w,h,c,size,bold,align,alpha)
    drawCount=drawCount+1
    dxDrawText(tostring(s or ""),x-ox,y-oy,x+w-ox,y+h-oy,color(c,alpha),1,font(size or 10,bold),align or "left","center",true,false,postGUI and not target,false,true)
end
A.box,A.text,A.color = box,text,color
-- Immediate-mode consumers draw in their own render callback/target. Never
-- inherit the showroom's postGUI flag or a retained viewport's coordinate origin.
function A.immediate(callback,drawPostGUI,...)
    local savedX,savedY,savedTarget,savedClip,savedPost=ox,oy,target,clip,postGUI
    ox,oy,target,clip,postGUI=0,0,nil,nil,drawPostGUI==true
    local ok,result=pcall(callback,...)
    ox,oy,target,clip,postGUI=savedX,savedY,savedTarget,savedClip,savedPost
    if not ok then outputDebugString("[AURA immediate] "..tostring(result),1); return false end
    return result~=false
end
local function active(n)
    if not n or not n.p.visible then return false end
    if n.parent then return active(A.nodes[n.parent]) end
    return true
end
local function enabled(n)
    if not n or n.p.disabled then return false end
    return not n.parent or enabled(A.nodes[n.parent])
end
local function geometry(n)
    local p=n.p
    if n.parent then
        local x,y,_,_,s=geometry(A.nodes[n.parent])
        local parent=A.nodes[n.parent]
        return x+p.x*s,y+(p.y-(parent.kind=="scroll" and (parent.p.scrollY or 0) or 0))*s,p.w*s,p.h*s,s
    end
    local sw,sh=guiGetScreenSize()
    local s=p.autoScale and math.min(1.35,sw/(p.w+48),sh/(p.h+48)) or (p.scale or 1)
    return p.centered and (sw-p.w*s)/2 or p.x*s,p.centered and (sh-p.h*s)/2 or p.y*s,p.w*s,p.h*s,s
end
local function inside(x,y,w,h,mx,my) return mx and mx>=x and my>=y and mx<=x+w and my<=y+h end
local function cursor() local x,y=getCursorPosition(); local w,h=guiGetScreenSize(); if x then return x*w,y*h end end
local function emit(n,event,...) if n and isElement(n.el) then triggerEvent(event,n.el,...) end end
for _,e in ipairs({"onAuraClick","onAuraChange","onAuraSubmit","onAuraFocus","onAuraContext","onAuraClose"}) do addEvent(e,false) end
local function descendant(el,ancestor)
    while el do if el==ancestor then return true end; el=A.nodes[el] and A.nodes[el].parent end
    return false
end
local function modal()
    for i=#A.order,1,-1 do local n=A.nodes[A.order[i]]; if active(n) and n.p.modal then return n.el end end
end
local function scope(el) local m=modal(); return not m or descendant(el,m) end
local function intersection(a,b)
    if not a then return b end
    local x,y=math.max(a.x,b.x),math.max(a.y,b.y)
    return {x=x,y=y,w=math.max(0,math.min(a.x+a.w,b.x+b.w)-x),h=math.max(0,math.min(a.y+a.h,b.y+b.h)-y)}
end
local function addHit(n,x,y,w,h,extra)
    local bounds=intersection(clip,{x=x,y=y,w=w,h=h})
    if bounds.w<=0 or bounds.h<=0 or not scope(n.el) then return end
    local entry=extra or {}; entry.el=n.el; entry.x,entry.y,entry.w,entry.h=bounds.x,bounds.y,bounds.w,bounds.h
    entry.enabled=enabled(n); hits[#hits+1]=entry
end
local function beginClip(n,x,y,w,h,bg)
    local rw,rh=math.max(1,math.ceil(w)),math.max(1,math.ceil(h))
    if n.rt and (n.rw~=rw or n.rh~=rh) then destroyElement(n.rt); n.rt=nil; n.rtRetry=nil end
    if not n.rt and (not n.rtRetry or getTickCount()>n.rtRetry) then
        n.rt=dxCreateRenderTarget(rw,rh,false); n.rw,n.rh=rw,rh; n.rtRetry=getTickCount()+2000
    end
    if not n.rt then return false end
    local saved={ox=ox,oy=oy,target=target,clip=clip,x=x,y=y,w=w,h=h}
    if not dxSetRenderTarget(n.rt,true) then return false end
    ox,oy,target=x,y,n.rt
    clip=intersection(clip,{x=x,y=y,w=w,h=h})
    dxSetBlendMode("blend")
    rect(x,y,rw,rh,bg or A.theme.panel)
    return saved
end
local function endClip(n,saved)
    ox,oy,target,clip=saved.ox,saved.oy,saved.target,saved.clip
    if target then dxSetRenderTarget(target) else dxSetRenderTarget() end
    dxSetBlendMode("blend")
    dxDrawImage(saved.x-ox,saved.y-oy,n.rw,n.rh,n.rt,0,0,0,tocolor(255,255,255,255),postGUI and not target)
end
A.util={box=box,text=text,rect=rect,line=line,font=font,clamp=clamp,mix=mix,copy=copy,
    geometry=geometry,active=active,enabled=enabled,inside=inside,cursor=cursor,emit=emit,
    addHit=addHit,beginClip=beginClip,endClip=endClip,scope=scope,modal=modal,
    focused=function() return focused end, pressed=function() return pressed end,
    invalidate=function() hits={}; pressed=nil; dropdown=nil end}

function uiCreate(kind,properties,parent)
    if not (kinds[kind] or A.renderers[kind]) or (parent and not A.nodes[parent]) or (properties and type(properties)~="table") then return false end
    local p=copy(properties or {})
    p.x,p.y,p.w,p.h=tonumber(p.x) or 0,tonumber(p.y) or 0,tonumber(p.w) or 160,tonumber(p.h) or 40
    p.visible=p.visible~=false
    if p.w<0 or p.h<0 then return false end
    p.text=tostring(p.text or "")
    p.value=p.value or ((kind=="tabs" or kind=="select") and 1 or 0)
    local el=createElement("aura:"..kind)
    if not el then return false end
    setElementParent(el,parent or resourceRoot)
    A.nodes[el]={el=el,kind=kind,p=p,parent=parent,children={},owner=sourceResource or getThisResource(),hover=0}
    local list=parent and A.nodes[parent].children or A.order
    list[#list+1]=el
    return el
end
function uiGet(el,key) local n=A.nodes[el]; if not n then return false end; local v=n.p[key]; return type(v)=="table" and copy(v) or v end
function uiFocus(el)
    if el and (not A.nodes[el] or not active(A.nodes[el]) or not enabled(A.nodes[el]) or not scope(el)) then return false end
    if focused==el then return true end
    if el then triggerEvent("onAuraInputClaim",resourceRoot) end
    local previous=focused
    focused=el
    if previous then emit(A.nodes[previous],"onAuraFocus",false) end
    if oldInputMode then guiSetInputMode(oldInputMode); oldInputMode=nil end
    if el and (A.nodes[el].kind=="edit" or A.nodes[el].kind=="memo") then
        oldInputMode=guiGetInputMode(); guiSetInputMode("no_binds")
        if A.editor then A.editor.init(A.nodes[el]) end
    end
    if el then emit(A.nodes[el],"onAuraFocus",true) end
    return true
end
-- Local DX input ownership only; no remote events or CEF integration.
addEvent("onAuraInputClaim",false)
addEventHandler("onAuraInputClaim",root,function()
    if source~=resourceRoot then uiFocus(nil) end
end)
function uiSet(el,key,value)
    local n=A.nodes[el]
    if not n or type(key)~="string" then return false end
    if key=="x" or key=="y" or key=="w" or key=="h" or key=="scale" then
        if type(value)~="number" or value~=value or math.abs(value)==math.huge then return false end
        if (key=="w" or key=="h" or key=="scale") and value<=0 then return false end
    end
    n.p[key]=type(value)=="table" and copy(value) or value
    if key=="text" and A.editor and (n.kind=="edit" or n.kind=="memo") then A.editor.reset(n) end
    if A.changed then A.changed(n,key) end
    if focused and (not active(A.nodes[focused]) or not enabled(A.nodes[focused])) then uiFocus(nil) end
    if dropdown and (not active(A.nodes[dropdown]) or not enabled(A.nodes[dropdown])) then dropdown=nil end
    return true
end
local function forget(el)
    local n=A.nodes[el]; if not n then return end
    if n.forgetting then return end
    n.forgetting=true
    if focused==el then uiFocus(nil) end
    if pressed==el then pressed=nil end
    if dropdown==el then dropdown=nil end
    if A.forget then A.forget(n) end
    if n.rt and isElement(n.rt) then destroyElement(n.rt) end
    local children=copy(n.children)
    for _,child in ipairs(children) do uiDestroy(child) end
    local list=n.parent and A.nodes[n.parent] and A.nodes[n.parent].children or A.order
    for i=#list,1,-1 do if list[i]==el then table.remove(list,i) end end
    A.nodes[el]=nil
end
function uiDestroy(el) if not A.nodes[el] then return false end; forget(el); if isElement(el) then destroyElement(el) end; return true end
function uiSetTheme(values)
    if type(values)~="table" then return false end
    for k,v in pairs(values) do
        if not A.theme[k] or type(v)~="table" or #v<3 then return false end
        for i=1,#v do if type(v[i])~="number" or v[i]<0 or v[i]>255 then return false end end
    end
    for k,v in pairs(values) do A.theme[k]=copy(v) end
    return true
end
function uiToast(title,message,tone,duration)
    toasts[#toasts+1]={title=tostring(title),message=tostring(message or ""),tone=tone or "success",start=getTickCount(),duration=clamp(tonumber(duration) or 3500,500,15000)}
    if #toasts>4 then table.remove(toasts,1) end
    return true
end
function uiStats() local count=0; for _ in pairs(A.nodes) do count=count+1 end; return {elements=count,drawCalls=drawCount,shader=not not shader} end
local function value(n,v)
    if n.p.value==v then return end
    n.p.value=v; emit(n,"onAuraChange",v)
end
local function slider(n,mx)
    local x,_,w=geometry(n); local lo,hi=n.p.min or 0,n.p.max or 100
    if hi<=lo then return end
    local step=math.max(0.001,n.p.step or 1)
    value(n,clamp(lo+math.floor((clamp((mx-x)/w,0,1)*(hi-lo))/step+0.5)*step,lo,hi))
end
local function renderNode(el,dt,mx,my)
    local n=A.nodes[el]; if not active(n) then return end
    local p,t=n.p,A.theme
    local x,y,w,h,s=geometry(n)
    if clip then local bounds=intersection(clip,{x=x,y=y,w=w,h=h}); if bounds.w<=0 or bounds.h<=0 then return end end
    local interactive=A.interactive[n.kind] or n.kind=="button" or n.kind=="edit" or n.kind=="checkbox" or n.kind=="switch" or n.kind=="slider" or n.kind=="tabs" or n.kind=="select"
    local isEnabled=enabled(n)
    local hover=isEnabled and scope(el) and inside(x,y,w,h,mx,my) and (not clip or inside(clip.x,clip.y,clip.w,clip.h,mx,my))
    n.hover=n.hover+((hover and 1 or 0)-n.hover)*(1-math.exp(-dt/85))
    local alpha=isEnabled and (p.opacity or 1) or 0.38
    local accent=t[p.tone or "accent"] or t.accent
    local bg=p.color or t.surface
    local fg=p.textColor or t.text
    local r=(p.radius or 10)*s
    local f=(p.size or 10)*s
    if interactive then addHit(n,x,y,w,h) end
    if A.renderers[n.kind] then
        A.renderers[n.kind](n,x,y,w,h,s,dt,mx,my,alpha)
    elseif n.kind=="panel" then
        local border
        if p.border~=false then border=t.border end
        box(x,y,w,h,p.color or (p.tone and mix(t.panel,accent,0.25)) or t.panel,r,p.borderColor or border,p.gradient,alpha,p)
    elseif n.kind=="label" then text(p.text,x,y,w,h,p.textColor or t.text,f,p.bold,p.align,alpha)
    elseif n.kind=="divider" then rect(x,y,w,math.max(1,h),t.border,alpha)
    elseif n.kind=="button" then
        local primary=p.variant=="primary"
        local c=primary and accent or (p.variant=="ghost" and t.panel or bg)
        c=mix(c,primary and {229,255,180} or {58,64,71},n.hover*0.65)
        if pressed==el then c=mix(c,t.background,0.18) end
        box(x,y,w,h,c,r,p.borderColor or (p.variant=="outline" and accent or t.border),p.gradient,alpha,p)
        text(p.text,x+10*s,y,w-20*s,h,primary and t.ink or fg,f,true,"center",alpha)
    elseif n.kind=="badge" then
        box(x,y,w,h,mix(t.panel,accent,0.12),h/2,mix(t.panel,accent,0.30),nil,alpha)
        text(p.text,x,y,w,h,accent,f,true,"center",alpha)
    elseif n.kind=="edit" then
        if A.editor then A.editor.draw(n,x,y,w,h,s,alpha) else
        box(x,y,w,h,bg,r,focused==el and accent or mix(t.border,t.muted,n.hover*0.5),nil,alpha)
        local content=p.password and string.rep("*",utf8.len(p.text)) or p.text
        local display=content
        while dxGetTextWidth(display,1,font(f,false))>w-32*s and utf8.len(display)>0 do display=utf8.sub(display,2) end
        text(display~="" and display or (p.placeholder or ""),x+14*s,y,w-28*s,h,content~="" and fg or t.muted,f,false,nil,alpha)
        if focused==el and getTickCount()%1000<500 then
            local cw=dxGetTextWidth(display,1,font(f,false))
            rect(x+14*s+cw,y+12*s,1,h-24*s,accent)
        end
        end
    elseif n.kind=="checkbox" or n.kind=="switch" then
        local on=p.value==true or p.value==1
        n.check=(n.check or (on and 1 or 0))+((on and 1 or 0)-(n.check or (on and 1 or 0)))*(1-math.exp(-dt/100))
        local bw,bh=(n.kind=="switch" and 38 or 22)*s,22*s
        box(x,y+(h-bh)/2,bw,bh,mix(bg,accent,n.check),n.kind=="switch" and bh/2 or 6*s,on and nil or t.border,nil,alpha)
        if n.kind=="switch" then
            box(x+3*s+n.check*16*s,y+(h-16*s)/2,16*s,16*s,on and t.ink or t.muted,8*s,nil,nil,alpha)
        elseif on then
            local cy=y+h/2
            line(x+6*s,cy,x+10*s,cy+4*s,t.ink,2*s,alpha)
            line(x+10*s,cy+4*s,x+17*s,cy-4*s,t.ink,2*s,alpha)
        end
        text(p.text,x+bw+12*s,y,w-bw-12*s,h,fg,f,false,nil,alpha)
    elseif n.kind=="progress" or n.kind=="slider" then
        local lo,hi=p.min or 0,p.max or 100
        local v=clamp(((tonumber(p.value) or 0)-lo)/math.max(0.001,hi-lo),0,1)
        local bh=(n.kind=="slider" and 5 or 7)*s
        box(x,y+(h-bh)/2,w,bh,t.surface,bh/2,nil,nil,alpha)
        if v>0 then box(x,y+(h-bh)/2,w*v,bh,accent,bh/2,nil,nil,alpha) end
        if n.kind=="slider" then box(x+v*(w-16*s),y+(h-16*s)/2,16*s,16*s,t.text,8*s,nil,nil,alpha) end
    elseif n.kind=="tabs" then
        box(x,y,w,h,t.background,r,t.border,nil,alpha)
        local items=p.items or {}; local iw=(w-8*s)/math.max(1,#items)
        for i,label in ipairs(items) do
            local ix=x+4*s+(i-1)*iw
            if p.value==i then box(ix,y+4*s,iw,h-8*s,t.surface,7*s,nil,nil,alpha) end
            text(label,ix,y,iw,h,p.value==i and t.text or t.muted,f,p.value==i,"center",alpha)
        end
    elseif n.kind=="select" then
        box(x,y,w,h,bg,r,dropdown==el and accent or t.border,nil,alpha)
        text((p.items or {})[p.value] or p.placeholder or "Seçiniz",x+14*s,y,w-44*s,h,fg,f,false,nil,alpha)
        text(dropdown==el and "−" or "+",x+w-32*s,y,22*s,h,t.muted,14*s,false,"center",alpha)
    end
    if focused==el and n.kind~="edit" and interactive then
        line(x+8*s,y+h-2*s,x+w-8*s,y+h-2*s,accent,2*s,alpha)
    end
    if n.kind=="scroll" then
        local maxY=math.max(0,(p.contentHeight or p.h)-p.h)
        p.scrollY=clamp(p.scrollY or 0,0,maxY)
        if scope(el) then scrolls[#scrolls+1]={n=n,bounds=intersection(clip,{x=x,y=y,w=w,h=h})} end
        local saved=beginClip(n,x,y,w-10*s,h,p.color or t.panel)
        if saved then
            for _,child in ipairs(n.children) do renderNode(child,dt,mx,my) end
            endClip(n,saved)
        else text("Çizim belleği yetersiz",x+12*s,y,w-24*s,h,t.muted,9*s) end
        if maxY>0 then
            local thumb=math.max(24*s,h*p.h/(p.contentHeight or p.h))
            box(x+w-6*s,y+(h-thumb)*p.scrollY/maxY,4*s,thumb,t.muted,2*s)
            addHit(n,x+w-12*s,y,12*s,h,{scrollbar=true})
        end
    else for _,child in ipairs(n.children) do renderNode(child,dt,mx,my) end end
end
local function draw()
    local now=getTickCount(); local dt=math.min(now-lastTick,100); lastTick=now; drawCount=0; hits={}; scrolls={}
    topModal=modal()
    if focused and not scope(focused) then uiFocus(nil) end
    postGUI=false
    for _,el in ipairs(A.order) do
        local n=A.nodes[el]
        if active(n) and n.p.fullscreenBackdrop then postGUI=true; break end
    end
    if postGUI then
        local sw,sh=guiGetScreenSize()
        local bg=A.theme.background
        dxDrawRectangle(0,0,sw,sh,tocolor(bg[1],bg[2],bg[3],255),true)
        drawCount=drawCount+1
    end
    local mx,my=cursor()
    if A.update then A.update(dt,mx,my) end
    if pressed and A.nodes[pressed] and active(A.nodes[pressed]) and enabled(A.nodes[pressed]) and A.nodes[pressed].kind=="slider" and mx then slider(A.nodes[pressed],mx) end
    for _,el in ipairs(A.order) do if not A.nodes[el].p.modal then renderNode(el,dt,mx,my) end end
    for _,el in ipairs(A.order) do
        if A.nodes[el].p.modal and active(A.nodes[el]) then
            local sw,sh=guiGetScreenSize(); rect(0,0,sw,sh,{0,0,0,190})
            renderNode(el,dt,mx,my)
        end
    end
    if dropdown and A.nodes[dropdown] and active(A.nodes[dropdown]) then
        local n=A.nodes[dropdown]; local x,y,w,h,s=geometry(n)
        local items=n.p.items or {}; local dh=#items*36*s+8*s
        local _,sh=guiGetScreenSize(); y=y+h+6*s
        if y+dh>sh then local _,ny=geometry(n); y=ny-dh-6*s end
        box(x,y,w,dh,A.theme.panel,10*s,A.theme.border)
        for i,label in ipairs(items) do
            local iy=y+4*s+(i-1)*36*s
            if inside(x,iy,w,36*s,mx,my) then box(x+4*s,iy,w-8*s,36*s,A.theme.surface,6*s) end
            text(label,x+14*s,iy,w-28*s,36*s,A.theme.text,10*s)
            hits[#hits+1]={el=dropdown,x=x,y=iy,w=w,h=36*s,enabled=true,option=i}
        end
    end
    local sw,sh=guiGetScreenSize(); local s=math.min(1,sw/600)
    for i=#toasts,1,-1 do
        local toast=toasts[i]; local age=now-toast.start
        if age>toast.duration then table.remove(toasts,i) else
            local a=math.min(1,age/180,(toast.duration-age)/250)
            local w,h=340*s,76*s; local x,y=sw-w-28*s,sh-28*s-(#toasts-i+1)*(h+10*s)+(1-a)*12*s
            box(x,y,w,h,A.theme.panel,12*s,A.theme.border,nil,a)
            box(x+14*s,y+19*s,4*s,38*s,A.theme[toast.tone] or A.theme.accent,2*s,nil,nil,a)
            text(toast.title,x+32*s,y+10*s,w-46*s,26*s,A.theme.text,11*s,true,nil,a)
            text(toast.message,x+32*s,y+36*s,w-46*s,24*s,A.theme.muted,9*s,false,nil,a)
        end
    end
    if A.overlay then A.overlay(dt,mx,my,hits) end
end
local function hit(mx,my)
    for i=#hits,1,-1 do local h=hits[i]; if A.nodes[h.el] and scope(h.el) and inside(h.x,h.y,h.w,h.h,mx,my) then return h end end
end
local function activate(n,h,mx)
    if A.activate and A.activate(n,h,mx) then return end
    if n.kind=="checkbox" or n.kind=="switch" then value(n,not (n.p.value==true or n.p.value==1))
    elseif n.kind=="tabs" then local x,_,w,_,s=geometry(n); value(n,clamp(math.floor((mx-x-4*s)/((w-8*s)/math.max(1,#(n.p.items or {}))))+1,1,math.max(1,#(n.p.items or {}))))
    elseif n.kind=="select" then
        if h and h.option then value(n,h.option); dropdown=nil else dropdown=dropdown~=n.el and n.el or nil end
    end
    emit(n,"onAuraClick")
end
addEventHandler("onClientClick",root,function(button,state,mx,my)
    if A.click and A.click(button,state,mx,my) then return end
    if button=="right" and state=="down" then
        local h=hit(mx,my); local n=h and A.nodes[h.el]
        if n and h.enabled then emit(n,"onAuraContext",mx,my); if n.p.contextItems and A.context then A.context(n,mx,my) end end
        return
    end
    if button~="left" then return end
    local h=hit(mx,my); local n=h and A.nodes[h.el]
    if state=="down" then
        if dropdown and (not h or h.el~=dropdown) then dropdown=nil end
        if n and h.enabled and active(n) and enabled(n) then
            pressed=h.el; uiFocus(h.el)
            if n.kind=="slider" then slider(n,mx) end
            if A.pointer then A.pointer(n,h,mx,my) end
        else pressed=nil; uiFocus(nil) end
    else
        local old=pressed; pressed=nil
        if n and h.enabled and active(n) and enabled(n) and old==h.el then activate(n,h,mx) end
    end
end)
addEventHandler("onClientCharacter",root,function(character)
    local n=focused and A.nodes[focused]
    if n and A.editor and (n.kind=="edit" or n.kind=="memo") then A.editor.insert(n,character); return end
    if n and n.kind=="edit" and utf8.len(n.p.text)<(n.p.maxLength or 128) then n.p.text=n.p.text..character; emit(n,"onAuraChange",n.p.text) end
end)
addEventHandler("onClientPaste",root,function(content)
    local n=focused and A.nodes[focused]
    if n and A.editor and (n.kind=="edit" or n.kind=="memo") then A.editor.insert(n,content); return end
    if n and n.kind=="edit" then n.p.text=utf8.sub(n.p.text..content:gsub("[\r\n]"," "),1,n.p.maxLength or 128); emit(n,"onAuraChange",n.p.text) end
end)
addEventHandler("onClientKey",root,function(key,down)
    if not down then return end
    if A.key and A.key(key) then cancelEvent(); return end
    if key=="mouse_wheel_up" or key=="mouse_wheel_down" then
        local mx,my=cursor()
        for i=#scrolls,1,-1 do
            local entry=scrolls[i]; local b=entry.bounds; local n=entry.n
            if enabled(n) and inside(b.x,b.y,b.w,b.h,mx,my) then
                uiSet(n.el,"scrollY",clamp((n.p.scrollY or 0)+(key=="mouse_wheel_up" and -1 or 1)*(n.p.scrollStep or 40),0,math.max(0,(n.p.contentHeight or n.p.h)-n.p.h)))
                cancelEvent(); return
            end
        end
    end
    if key=="escape" and modal() then uiDestroy(modal()); cancelEvent(); return end
    if not focused then return end
    local n=A.nodes[focused]; if not n then return end
    if key=="escape" then dropdown=nil; uiFocus(nil); cancelEvent(); return end
    if key=="tab" then
        local list={}; local index=0
        local seen={}
        for _,h in ipairs(hits) do if h.enabled and not h.option and not seen[h.el] and A.nodes[h.el] and scope(h.el) then
            seen[h.el]=true; list[#list+1]=h.el; if h.el==focused then index=#list end
        end end
        if #list>0 then uiFocus(list[(index-1+(getKeyState("lshift") and -1 or 1))%#list+1]) end
        cancelEvent()
    elseif (n.kind=="edit" or n.kind=="memo") and A.editor then
        if A.editor.key(n,key) then cancelEvent() end
    elseif n.kind=="edit" then
        if key=="backspace" then n.p.text=utf8.sub(n.p.text,1,math.max(0,utf8.len(n.p.text)-1)); emit(n,"onAuraChange",n.p.text); cancelEvent()
        elseif key=="enter" then emit(n,"onAuraSubmit",n.p.text); cancelEvent() end
    elseif (n.kind=="slider" or n.kind=="tabs" or n.kind=="select") and (key=="arrow_l" or key=="arrow_r" or key=="arrow_u" or key=="arrow_d") then
        local direction=(key=="arrow_l" or key=="arrow_u") and -1 or 1
        value(n,clamp(n.p.value+direction*(n.kind=="slider" and (n.p.step or 1) or 1),n.kind=="slider" and (n.p.min or 0) or 1,n.kind=="slider" and (n.p.max or 100) or math.max(1,#(n.p.items or {}))))
        cancelEvent()
    elseif key=="enter" or key=="space" then
        if n.kind=="button" or n.kind=="checkbox" or n.kind=="switch" or n.kind=="select" then activate(n); cancelEvent() end
    end
end)
addEventHandler("onClientElementDestroy",root,function() if A.nodes[source] then forget(source) end end)
addEventHandler("onClientResourceStart",resourceRoot,function()
    shader=dxCreateShader("assets/surface.fx")
    if not shader then outputDebugString("[AURA] Shader unavailable; using rectangular DX fallback.",2) end
end)
addEventHandler("onClientResourceStop",root,function(stopped)
    if stopped==getThisResource() then
        uiFocus(nil)
        for _,f in pairs(fonts) do if isElement(f) then destroyElement(f) end end
        if isElement(shader) then destroyElement(shader) end
    else
        local remove={}; for el,n in pairs(A.nodes) do if n.owner==stopped then remove[#remove+1]=el end end
        for _,el in ipairs(remove) do uiDestroy(el) end
    end
end)
addEventHandler("onClientRender",root,draw,false,"low-9999")
