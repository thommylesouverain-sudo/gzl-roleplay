-- AURA DX loading. Static composition is rebuilt only on layout changes.
local active,preview=false,false
local ready,finishAt=false,nil
local loaded,total,progress=0,0,0
local started,timer,target,background=0,nil,nil,nil
local sw,sh=0,0
local fonts={}
local visualReady,retryAt=false,0
local oldMode,oldChat
local percent,status=0,"Sunucuya bağlanılıyor"
local tips={
    "Karakterinin bildikleriyle hareket et; oyuncu bilgisini role taşıma.",
    "Eşyalarını ve taşıma kapasiteni envanterinden takip edebilirsin.",
    "Diğer oyunculara hikâyeye katılmaları için fırsat ver.",
    "Bir sorun yaşarsan destek ekibine durumu açıkça anlat."
}
local function character() return getElementData(localPlayer,"char:id") or getElementData(localPlayer,"character:id") or getElementData(localPlayer,"loggedin_character") end
local function running(name) local r=getResourceFromName(name); return r and getResourceState(r)=="running" end
local function suppress()
    if preview or not active or character() then return end
    showChat(false); setPlayerHudComponentVisible("all",false)
    if running("gzl_hud") then exports.gzl_hud:setHUDVisible(false) end
    if running("gzl_chat") then exports.gzl_chat:setChatVisible(false) end
    if running("gzl_radar") then exports.gzl_radar:setRadarVisible(false) end
end
local function font(size,bold)
    size=math.max(6,math.floor(size+0.5)); local key=size..tostring(bold)
    if not isElement(fonts[key]) then fonts[key]=dxCreateFont(":aura_ui/assets/Manrope-"..(bold and "Bold" or "Medium")..".ttf",size,false,"cleartype") end
    if not isElement(fonts[key]) then visualReady=false end
    return fonts[key] or "default"
end
local function text(value,x,y,w,h,size,color,bold,align,wrap)
    dxDrawText(value,x,y,x+w,y+h,tocolor(unpack(color)),1,font(size,bold),align or "left","center",not wrap,wrap==true,false)
end
local function surface(x,y,w,h,color,r,border)
    local ok,result=false,false
    if running("aura_ui") then
        ok,result=pcall(function() return exports.aura_ui:uiDrawSurface(x,y,w,h,{color=color,radius=r or 0,borderColor=border},false) end)
    end
    if not ok or not result then
        visualReady=false
        dxDrawRectangle(x,y,w,h,tocolor(unpack(color)),false)
    end
end
local function geometry() local s=math.min(sw/1600,sh/900); return s,(sw-1440*s)/2,(sh-740*s)/2 end
local function drawStatic()
    local s,x,y=geometry()
    dxDrawRectangle(0,0,sw,sh,tocolor(15,17,20))
    if isElement(background) then
        local bw,bh=dxGetMaterialSize(background); local scale=math.max(sw/bw,sh/bh)
        dxDrawImage((sw-bw*scale)/2,(sh-bh*scale)/2,bw*scale,bh*scale,background,0,0,0,tocolor(255,255,255,180))
    end
    -- A baked gradient leaves the scene visible and keeps the loading area legible.
    for i=0,63 do
        local t=i/63
        dxDrawRectangle(0,sh*i/64,sw,sh/64+1,tocolor(15,17,20,math.floor(35+215*t*t)))
    end
    surface(x+40*s,y+28*s,4*s,38*s,{201,244,111},2*s)
    text("GZL ROLEPLAY",x+60*s,y+25*s,420*s,30*s,17*s,{239,242,244},true)
    text("LOS SANTOS",x+60*s,y+57*s,420*s,20*s,9*s,{143,153,164})
    if preview then
        text("ÖNİZLEME  /  ESC İLE KAPAT",x+900*s,y+28*s,500*s,32*s,10*s,{201,244,111},false,"right")
    end
    text("ŞEHRE HOŞ GELDİN",x+60*s,y+464*s,800*s,26*s,10*s,{201,244,111},true)
    text("Hikâyen birazdan başlıyor.",x+60*s,y+497*s,1260*s,70*s,34*s,{239,242,244},true)
    surface(x+60*s,y+590*s,1320*s,s,{48,54,61})
    text("İPUCU",x+60*s,y+691*s,65*s,28*s,9*s,{201,244,111},true)
end
local function rebuild()
    visualReady=true; retryAt=getTickCount()+1000
    -- Allocate fonts before binding the target; never cache the initial fallback
    -- permanently when the dependency is still downloading/starting.
    local s=geometry()
    for _,size in ipairs({9,10,12,17,20,34}) do font(size*s,false); font(size*s,true) end
    if isElement(target) then destroyElement(target) end
    target=dxCreateRenderTarget(sw,sh,false)
    if target and dxSetRenderTarget(target,true) then
        dxSetBlendMode("blend"); drawStatic(); dxSetRenderTarget(); dxSetBlendMode("blend")
    else if isElement(target) then destroyElement(target) end; target=nil; visualReady=false end
end
local close
local function update()
    if not active then return end
    if not visualReady and getTickCount()>=retryAt then rebuild() end
    local elapsed=getTickCount()-started
    if preview then
        percent=math.min(100,math.floor(elapsed/120)); status=percent==100 and "Önizleme hazır · /loadingtest veya Esc ile kapat" or "AURA önizlemesi hazırlanıyor"
        return
    end
    local complete=ready and not isTransferBoxActive()
    -- Server startup progress is not a download percentage. Unknown phases
    -- use an indeterminate bar instead of a fabricated timed percentage.
    percent=complete and 100 or ((not isTransferBoxActive() and total>0 and not ready) and math.min(99,math.floor(progress/total*100)) or nil)
    status=complete and "Oyun hazır" or (isTransferBoxActive() and "Oyun dosyaları indiriliyor" or "Şehir hazırlanıyor")
    if complete then finishAt=finishAt or getTickCount()+1400 else finishAt=nil end
    if finishAt and getTickCount()>=finishAt then close() end
end
local function render()
    if not active then return end
    local w,h=guiGetScreenSize(); if w~=sw or h~=sh then sw,sh=w,h; rebuild() end
    if isElement(target) then dxDrawImage(0,0,sw,sh,target,0,0,0,tocolor(255,255,255),true) else drawStatic() end
    local s,x,y=geometry()
    dxDrawText(status,x+60*s,y+608*s,x+1190*s,y+643*s,tocolor(239,242,244),1,font(12*s),"left","center",false,false,true)
    local counter=percent and (tostring(percent).."%") or "YÜKLENİYOR"
    dxDrawText(counter,x+1190*s,y+608*s,x+1380*s,y+643*s,tocolor(201,244,111),1,font(12*s,true),"right","center",false,false,true)
    dxDrawRectangle(x+60*s,y+657*s,1320*s,4*s,tocolor(48,54,61),true)
    if percent then
        dxDrawRectangle(x+60*s,y+657*s,1320*s*percent/100,4*s,tocolor(201,244,111),true)
    else
        local travel=(math.sin((getTickCount()-started)/750)+1)/2
        dxDrawRectangle(x+(60+1100*travel)*s,y+657*s,220*s,4*s,tocolor(201,244,111),true)
    end
    local tip=tips[math.floor((getTickCount()-started)/8000)%#tips+1]
    dxDrawText(tip,x+135*s,y+691*s,x+1380*s,y+719*s,tocolor(143,153,164),1,font(10*s),"left","center",true,false,true)

end
close=function()
    if not active then return end
    local wasTest=preview; active=false; preview=false; finishAt=nil
    removeEventHandler("onClientRender",root,render)
    if isTimer(timer) then killTimer(timer) end; timer=nil
    if isElement(target) then destroyElement(target) end; target=nil
    if isElement(background) then destroyElement(background) end; background=nil
    for _,f in pairs(fonts) do if isElement(f) then destroyElement(f) end end; fonts={}
    showCursor(false)
    if not wasTest then
        guiSetInputMode(oldMode or "allow_binds"); fadeCamera(true,1.2)
        if character() then
            showChat(oldChat); setPlayerHudComponentVisible("crosshair",true)
            if running("gzl_hud") then exports.gzl_hud:setHUDVisible(true) end
            if running("gzl_radar") then exports.gzl_radar:setRadarVisible(true) end
        else showChat(false); setPlayerHudComponentVisible("all",false) end
    end
end
local function open(test)
    if active then return end
    active=true; preview=test==true; started=getTickCount(); finishAt=nil; percent=0
    sw,sh=guiGetScreenSize(); background=dxCreateTexture("assets/background.png","argb",false,"clamp")
    if not preview then oldChat=isChatVisible(); oldMode=guiGetInputMode(); suppress(); guiSetInputMode("no_binds_when_editing"); triggerServerEvent("gzl_loading:requestStatus",resourceRoot) end
    showCursor(true); rebuild(); update()
    addEventHandler("onClientRender",root,render,false,"low-10000")
    timer=setTimer(update,250,0)
end
addCommandHandler("loadingtest",function()
    if active and not preview then outputChatBox("[AURA] Gerçek yükleme devam ediyor; test modu yükleme bittikten sonra açılabilir.",201,244,111); return end
    if active then close() else open(true) end
end)
addEventHandler("onClientKey",root,function(key,press) if active and preview and press and key=="escape" then cancelEvent(); close() end end)
addEvent("gzl_loading:status",true)
addEventHandler("gzl_loading:status",resourceRoot,function(p,t,busy,serverReady)
    progress=math.max(0,tonumber(p) or 0); total=math.max(0,tonumber(t) or 0); ready=serverReady==true and busy~=true
    if not preview then update() end
end)
addEvent("char:spawnSuccess",true)
addEventHandler("char:spawnSuccess",root,function() if not preview then close() end end)
addEventHandler("onClientPlayerSpawn",localPlayer,function() if character() and not preview then close() end end)
addEventHandler("onClientResourceStart",root,function(startedResource)
    if active and startedResource and startedResource==getResourceFromName("aura_ui") then visualReady=false; retryAt=0 end
    if source==resourceRoot then if not character() then open(false) end
    elseif active and not preview then loaded=loaded+1; suppress() end
end)
addEventHandler("onClientRestore",root,function(cleared) if active and cleared then rebuild() end end)
addEventHandler("onClientResourceStop",resourceRoot,close)
