-- AURA surfaces, native DX item textures. No browser or HTML runtime.
InventoryDX={visible=false,hotbar=false,scroll={0,0},amount="0",textures={},fonts={},textureOrder={},weights={0,0},textureSizes={}}
local D=InventoryDX
local hits,drag,selected,menu,hover,hoverTick={},nil,nil,nil,nil,0
local amountFocus=false
local attached=false
local frameMouseX,frameMouseY
-- Match AURA's established graphite/Manrope/lime visual language.
local T={background={15,17,20},panel={22,25,29},surface={30,34,39},border={48,54,61},
    text={239,242,244},muted={143,153,164},accent={201,244,111},ink={24,32,17}}
local function surface(x,y,w,h,color,r,border)
    return InventorySurface.draw(x,y,w,h,color,r,border)
end
local function font(size,bold)
    size=math.max(6,math.min(96,math.floor(size+0.5)))
    local key=size..tostring(bold)
    if not isElement(D.fonts[key]) then D.fonts[key]=dxCreateFont(":aura_ui/assets/Manrope-"..(bold and "Bold" or "Medium")..".ttf",size,false,"cleartype") end
    return D.fonts[key] or "default"
end
local function text(value,x,y,w,h,size,color,align,bold)
    dxDrawText(tostring(value or ""),x,y,x+w,y+h,tocolor(unpack(color or T.text)),1,font(size,bold),align or "left","center",true,false,true)
end
local function inside(x,y,b) return x and x>=b.x and y>=b.y and x<b.x+b.w and y<b.y+b.h end
local function cursor() local x,y=getCursorPosition(); local w,h=guiGetScreenSize(); if x then return x*w,y*h end end
local function hit(x,y,w,h,kind,side,slot)
    local b={x=x,y=y,w=w,h=h,kind=kind,side=side,slot=slot}; hits[#hits+1]=b; return b
end
local function find(x,y) for i=#hits,1,-1 do if inside(x,y,hits[i]) then return hits[i] end end end
local function inv(side) return side==1 and D.left or D.right end
local function itemAt(side,slot)
    local v=inv(side); return v and v.items and (v.items[slot] or v.items[tostring(slot)])
end
local function label(item) local def=ItemsList[item.name] or {}; return (item.metadata or {}).label or item.label or def.label or item.name end
local function picture(item)
    local def=ItemsList[item.name] or ItemsList[item.name:lower()] or {}
    local name=(item.metadata or {}).image or (def.client or {}).image or def.image or item.name..".png"
    name=tostring(name):gsub("^images/","")
    if not name:match("%.[%w]+$") then name=name..".png" end
    -- Only packaged assets are loaded; missing/remote artwork gets a label fallback.
    if name:find("..",1,true) or name:find(":",1,true) or name:find("\\",1,true) then return nil end
    local path="web/build/images/"..name
    local cached=D.textures[path]
    if cached==false then return nil end
    if not isElement(cached) then
        if #D.textureOrder>=64 then
            local oldest=table.remove(D.textureOrder,1)
            if isElement(D.textures[oldest]) then destroyElement(D.textures[oldest]) end
            D.textureSizes[D.textures[oldest]]=nil
            D.textures[oldest]=nil
        end
        cached=fileExists(path) and dxCreateTexture(path,"argb",false,"clamp") or false
        D.textures[path]=cached
        D.textureOrder[#D.textureOrder+1]=path
    end
    return cached or nil
end
local function image(item,x,y,size,alpha)
    local tex=picture(item)
    if tex then
        local dimensions=D.textureSizes[tex]
        if not dimensions then local w,h=dxGetMaterialSize(tex); dimensions={w,h}; D.textureSizes[tex]=dimensions end
        local w,h=dimensions[1],dimensions[2]; local ratio=math.min(size/w,size/h)
        dxDrawImage(x+(size-w*ratio)/2,y+(size-h*ratio)/2,w*ratio,h*ratio,tex,0,0,0,tocolor(255,255,255,alpha or 255),true)
    else text("?",x,y,size,size,22,{143,153,164},"center") end
end
local function cleanTextures()
    for _,t in pairs(D.textures) do if isElement(t) then destroyElement(t) end end
    D.textures={}; D.textureOrder={}; D.textureSizes={}
end
local function count(item,transfer)
    local n=math.max(1,tonumber(item.count) or 1)
    if transfer and (getKeyState("lshift") or getKeyState("rshift")) and n>1 then return math.floor(n/2) end
    local requested=tonumber(D.amount) or 0
    return math.min(n,requested>0 and requested or (transfer and n or 1))
end
local function sameMetadata(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~="table" then return a==b end
    for k,v in pairs(a) do if not sameMetadata(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
local function action(kind,ref,target)
    if kind=="close" then D.action("closeInventory",{}); return end
    local item=ref and itemAt(ref.side,ref.slot)
    if not item or not item.name then return end
    if kind=="transfer" then
        target=target or {side=ref.side==1 and 2 or 1}
        local destination=inv(target.side); if not destination then return end
        if not target.slot then
            local empty
            for slot=1,destination.slots or 40 do
                local existing=itemAt(target.side,slot)
                if not existing and not empty then empty=slot end
                if existing and existing.name==item.name and item.stack~=false and (ItemsList[item.name] or {}).stack~=false and sameMetadata(existing.metadata or {},item.metadata or {}) then target.slot=slot; break end
            end
            target.slot=target.slot or empty
        end
        if not target.slot or (ref.side==target.side and ref.slot==target.slot) then return end
        D.action("swapItems",{fromSlot=ref.slot,toSlot=target.slot,fromType=inv(ref.side).type,toType=destination.type,count=count(item,true)})
    elseif ref.side==1 then
        D.action(kind,{slot=ref.slot,count=count(item,false)})
    end
end
local function cell(side,slot,x,y,w,h,s,interactive)
    local item=itemAt(side,slot)
    local mx,my=frameMouseX,frameMouseY; local b={x=x,y=y,w=w,h=h}
    local over=interactive and inside(mx,my,b)
    local chosen=selected and selected.side==side and selected.slot==slot
    surface(x,y,w,h,(over or chosen) and {38,46,34} or (item and T.surface or T.panel),10*s,(over or chosen) and T.accent or T.border)
    if interactive then hit(x,y,w,h,"slot",side,slot) end
    if item and item.name then
        local weight=tonumber(item.weight) or 0
        if weight>0 then text(weight>=1000 and string.format("%.1f kg",weight/1000) or weight.." g",x+10*s,y+6*s,w*.55,22*s,math.max(7,9*s),T.muted) end
        text(tostring(item.count or 1).." x",x+w*.4,y+6*s,w*.6-10*s,22*s,math.max(7,10*s),T.accent,"right",true)
        local z=math.min(w*.56,h*.54)
        image(item,x+(w-z)/2,y+(h-z)/2,z,drag and drag.side==side and drag.slot==slot and 100 or 255)
        text(label(item),x+10*s,y+h-29*s,w-20*s,23*s,math.max(7,10*s),nil,"left",true)
        local durability=tonumber(item.durability or (item.metadata or {}).durability)
        if durability and durability<=100 then surface(x,y+h-2*s,w*math.max(0,durability)/100,2*s,{201,244,111},0) end
    else text(string.format("%02d",slot),x+10*s,y+7*s,w-20*s,20*s,math.max(7,9*s),{68,77,86}) end
end
function D.layout()
    local w,h=guiGetScreenSize(); local s=math.min(w/1920,h/1080)
    return {s=s,x=(w-1536*s)/2,y=(h-690*s)/2,w=648*s,h=638*s,cell=123.2*s,gap=8*s,rows=5,right=(w-1536*s)/2+888*s,center=w/2}
end
local function panel(side,x,l)
    local v=inv(side); local s=l.s
    local title=v and v.label or (side==1 and "Yükleniyor…" or "Dünya")
    local titleWidth=l.w-240*s
    surface(x,l.y,l.w,48*s,T.panel,10*s,T.border)
    surface(x+12*s,l.y+12*s,24*s,24*s,T.accent,6*s)
    surface(x+18*s,l.y+20*s,12*s,11*s,{22,25,29},2*s)
    dxDrawLine(x+21*s,l.y+20*s,x+21*s,l.y+17*s,tocolor(22,25,29),s,true)
    dxDrawLine(x+21*s,l.y+17*s,x+27*s,l.y+17*s,tocolor(22,25,29),s,true)
    dxDrawLine(x+27*s,l.y+17*s,x+27*s,l.y+20*s,tocolor(22,25,29),s,true)
    text(title,x+50*s,l.y,titleWidth-58*s,48*s,math.max(8,12*s),nil,"left",true)
    local weight,max=D.weights[side],v and tonumber(v.maxWeight) or 0
    text(string.format("%.2f/%g kg",weight/1000,max/1000),x+l.w-146*s,l.y,132*s,48*s,math.max(8,11*s),nil,"right")
    surface(x+l.w-234*s,l.y+21*s,84*s,6*s,T.background,3*s)
    surface(x+l.w-234*s,l.y+21*s,84*s*(max>0 and math.min(1,weight/max) or 0),6*s,T.accent,3*s)
    local slots=v and v.slots or 40
    D.scroll[side]=math.min(D.scroll[side],math.max(0,math.ceil(slots/5)-l.rows))
    for row=0,l.rows-1 do for col=0,4 do
        local slot=(row+D.scroll[side])*5+col+1
        if slot<=slots then cell(side,slot,x+col*(l.cell+l.gap),l.y+56*s+row*(l.cell+l.gap),l.cell,l.cell,s,true) end
    end end
    local total=math.ceil(slots/5)
    if total>l.rows then
        local track=l.rows*(l.cell+l.gap)-l.gap; local thumb=track*l.rows/total
        surface(x+l.w+6*s,l.y+56*s,3*s,track,{48,54,61,150},1)
        surface(x+l.w+6*s,l.y+56*s+(track-thumb)*D.scroll[side]/(total-l.rows),3*s,thumb,{143,153,164,190},1)
    end
end
local function render()
    if not D.visible and not D.hotbar then return end
    if isMTAWindowFocused and not isMTAWindowFocused() then return end
    hits={}; local l=D.layout(); local s=l.s; local w,h=guiGetScreenSize()
    frameMouseX,frameMouseY=cursor()
    if not D.visible then
        for slot=1,5 do cell(1,slot,w/2-260*s+(slot-1)*105*s,h-130*s,100*s,100*s,s,false) end
        return
    end
    dxDrawRectangle(0,0,w,h,tocolor(8,10,12,175),true)
    surface(l.x-32*s,l.y-110*s,1600*s,890*s,T.background,18*s,T.border)
    text("aura",l.x,l.y-96*s,130*s,56*s,math.max(16,32*s),T.text)
    text("ENVANTER",l.x+104*s,l.y-84*s,300*s,32*s,math.max(8,11*s),T.muted)
    text("Eşyaların. Kontrol sende.",l.x+840*s,l.y-85*s,696*s,34*s,math.max(8,12*s),T.muted,"right")
    surface(l.x,l.y-30*s,1536*s,1*s,T.border,0)
    text("KİŞİSEL",l.x,l.y-26*s,250*s,22*s,math.max(7,9*s),T.muted)
    text("YAKIN ÇEVRE",l.right,l.y-26*s,250*s,22*s,math.max(7,9*s),T.muted)
    panel(1,l.x,l); panel(2,l.right,l)
    local ax,ay=l.center-56*s,l.y+224*s
    surface(ax-24*s,ay-70*s,160*s,396*s,T.panel,14*s,T.border)
    text("İŞLEMLER",ax-12*s,ay-55*s,136*s,25*s,math.max(7,9*s),T.muted,"center")
    text("Miktar",ax,ay-27*s,112*s,22*s,math.max(7,10*s),T.muted)
    surface(ax,ay,112*s,46*s,T.background,8*s,amountFocus and T.accent or T.border)
    text(D.amount..(amountFocus and getTickCount()%1000<500 and "|" or ""),ax,ay,112*s,46*s,math.max(9,14*s),nil,"center")
    hit(ax,ay,112*s,46*s,"amount")
    local buttons={{"useItem","Kullan",T.ink},{"giveItem","Ver",T.text},{"close","Kapat",T.muted}}
    for i,b in ipairs(buttons) do
        local y=ay+78*s+(i-1)*76*s
        local mx,my=frameMouseX,frameMouseY; local over=inside(mx,my,{x=ax+8*s,y=y,w=96*s,h=60*s})
        surface(ax+8*s,y,96*s,60*s,i==1 and (over and {216,250,153} or T.accent) or (over and {42,48,55} or T.surface),9*s,i~=1 and T.border or nil)
        text(b[2],ax+8*s,y,96*s,60*s,math.max(8,12*s),b[3],"center",true)
        hit(ax+8*s,y,96*s,60*s,b[1])
    end
    surface(l.x,l.y+718*s,1536*s,1*s,T.border,0)
    text("Çift tık: kullan   ·   Ctrl: aktar   ·   Shift: yarısını taşı   ·   Sağ tık: işlemler",l.x,l.y+734*s,1320*s,26*s,math.max(7,10*s),T.muted)
    text("AURA / DX",l.x+1320*s,l.y+734*s,216*s,26*s,math.max(7,10*s),T.accent,"right")
    local mx,my=frameMouseX,frameMouseY; local under=find(mx,my)
    local key=under and under.kind=="slot" and (under.side..":"..under.slot)
    if key~=hover then hover=key; hoverTick=getTickCount() end
    if under and key and not drag and not menu and getTickCount()-hoverTick>450 then
        local item=itemAt(under.side,under.slot)
        if item and item.name then
            local tx=math.min(mx+18*s,w-300*s); local ty=math.min(my+18*s,h-120*s)
            surface(tx,ty,284*s,104*s,{22,25,29,250},8*s,{48,54,61})
            text(label(item),tx+14*s,ty+6*s,256*s,28*s,math.max(8,12*s),nil,nil,true)
            text(item.description or (ItemsList[item.name] or {}).description or "",tx+14*s,ty+37*s,256*s,28*s,math.max(7,10*s),{160,171,182})
            text("Adet: "..tostring(item.count or 1)..((item.metadata or {}).serial and "  ·  "..tostring(item.metadata.serial) or ""),tx+14*s,ty+68*s,256*s,25*s,math.max(7,10*s),{201,244,111})
        end
    end
    if drag and mx and ((mx-drag.x)^2+(my-drag.y)^2)>25 then
        local item=itemAt(drag.side,drag.slot); if item then image(item,mx-38*s,my-38*s,76*s,210) end
    end
    if menu then
        local entries=menu.side==1 and {{"useItem","Kullan"},{"giveItem","Yakındaki oyuncuya ver"},{"dropItem","Yere bırak"},{"transfer","Diğer envantere aktar"}} or {{"transfer","Envantere al"}}
        local it=itemAt(menu.side,menu.slot)
        if it and (it.metadata or {}).serial then entries[#entries+1]={"copy","Seri numarasını kopyala"} end
        surface(menu.x,menu.y,230*s,#entries*36*s+8*s,{22,25,29,255},7*s,{48,54,61})
        for i,e in ipairs(entries) do text(e[2],menu.x+12*s,menu.y+4*s+(i-1)*36*s,208*s,36*s,math.max(8,11*s)); hit(menu.x,menu.y+4*s+(i-1)*36*s,230*s,36*s,e[1],menu.side,menu.slot) end
    end
end
local lastClick,lastTick=nil,0
local function click(button,state,x,y)
    if not D.visible then return end
    local b=find(x,y)
    if button=="right" and state=="down" then
        drag=nil; menu=nil
        if b and b.kind=="slot" and itemAt(b.side,b.slot) then
            local w,h=guiGetScreenSize(); local s=D.layout().s
            menu={side=b.side,slot=b.slot,x=math.min(x,w-232*s),y=math.min(y,h-190*s)}
        end
        return
    end
    if button~="left" then return end
    if state=="down" then
        amountFocus=b and b.kind=="amount" or false
        if b and b.kind=="slot" and itemAt(b.side,b.slot) then
            selected={side=b.side,slot=b.slot}; drag={side=b.side,slot=b.slot,x=x,y=y}
        elseif b and b.kind~="amount" then
            if b.kind=="copy" then local it=itemAt(b.side,b.slot); if it then setClipboard(tostring((it.metadata or {}).serial or "")) end
            else action(b.kind,b.side and b or selected) end
        end
        menu=nil
    elseif state=="up" and drag then
        local ref=drag; drag=nil
        if ((x-ref.x)^2+(y-ref.y)^2)>25 then
            if b and b.kind=="slot" then action("transfer",ref,b)
            elseif b and (b.kind=="useItem" or b.kind=="giveItem") then action(b.kind,ref) end
        elseif b and b.kind=="slot" then
            local key=ref.side..":"..ref.slot
            if getKeyState("lctrl") or getKeyState("rctrl") then action("transfer",ref)
            elseif getKeyState("lalt") or getKeyState("ralt") or (lastClick==key and getTickCount()-lastTick<300) then action("useItem",ref); key=nil end
            lastClick,lastTick=key,getTickCount()
        end
    end
end
local function key(button,press)
    if not D.visible or not press then return end
    if button=="escape" then cancelEvent(); if menu then menu=nil elseif amountFocus then amountFocus=false else action("close") end
    elseif button=="mouse_wheel_up" or button=="mouse_wheel_down" then
        local x,y=cursor(); local l=D.layout(); local side=x and x>=l.right and 2 or 1
        if inside(x,y,{x=side==1 and l.x or l.right,y=l.y,w=l.w,h=720*l.s}) then
            D.scroll[side]=math.max(0,math.min(math.max(0,math.ceil(((inv(side) or {}).slots or 40)/5)-l.rows),D.scroll[side]+(button=="mouse_wheel_up" and -1 or 1)))
            drag=nil; menu=nil; cancelEvent()
        end
    elseif amountFocus then
        cancelEvent()
        if button=="backspace" then D.amount=D.amount:sub(1,-2)
        elseif button=="enter" or button=="tab" then amountFocus=false
        elseif button=="a" and (getKeyState("lctrl") or getKeyState("rctrl")) then D.amount="" end
    end
end
local function character(c) if D.visible and amountFocus and c:match("^%d$") and #D.amount<8 then D.amount=(D.amount=="0" and "" or D.amount)..c end end
local function updateHandlers()
    local wanted=D.visible or D.hotbar
    if wanted==attached then return end
    attached=wanted
    if wanted then addEventHandler("onClientRender",root,render,false,"low-9000")
    else removeEventHandler("onClientRender",root,render); cleanTextures(); InventorySurface.clear() end
end
function D.setData(left,right)
    if D.right and right and D.right.id~=right.id then D.scroll[2]=0 end
    D.left,D.right=left,right
    for side=1,2 do
        local total=0
        for _,item in pairs((inv(side) or {}).items or {}) do total=total+(tonumber(item.weight) or 0)*(tonumber(item.count) or 1) end
        D.weights[side]=total
    end
    drag=nil; menu=nil; selected=nil
    if not D.visible and not D.hotbar then cleanTextures() end
end
function D.setVisible(value)
    D.visible=value; drag=nil; menu=nil; selected=nil; amountFocus=false; hits={}
    if value then D.scroll={0,0}; D.amount="0" end
    updateHandlers()
end
function D.setHotbar(value) D.hotbar=value; updateHandlers() end
addEventHandler("onClientClick",root,click)
addEventHandler("onClientKey",root,key)
addEventHandler("onClientCharacter",root,character)
addEventHandler("onClientResourceStop",resourceRoot,function()
    cleanTextures(); for _,f in pairs(D.fonts) do if isElement(f) then destroyElement(f) end end
end)
