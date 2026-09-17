
local screenW, screenH = guiGetScreenSize()
local isVisible = false

local charData = {
    name = "Michael_Walker",
    gender = "male",
    age = 25,
    height = 180,
    skinTone = 3,
    face = {
        eyes = 1,
        eyebrow = 1,
        beard = 1,
        lipstick = 0
    },
    hair = { id = 1, variant = 1, color = { 0.12, 0.12, 0.12, 1.0 } },
    hairVariant = 1,
    hairColorIdx = 1,
    torso = 1,
    torsoVariant = 1,
    legs = 1,
    legsVariant = 1,
    shoes = 1,
    shoesVariant = 1,
    accessories = {}
}

local currentTab = "appearance"
local currentAccCategory = "all"
local accScrollOffset = 0
local fonts = nil
local studioPed = nil
local isSubmitting = false
local previewAnimTimer = nil

local layout = {
    panelX = 35,
    panelY = 50,
    panelW = 390,
    panelH = 640,
    scale = 1.0
}

local function prepareFonts()
    if fonts or not exports.gzl_ui then return fonts ~= nil end
    local scale = math.min(screenW / 1920, screenH / 1080)
    layout.scale = math.max(0.75, math.min(1.0, scale))
    layout.panelW = math.floor(390 * layout.scale)
    layout.panelH = math.floor(640 * layout.scale)
    layout.panelX = math.floor(35 * layout.scale)
    layout.panelY = math.floor((screenH - layout.panelH) / 2)

    fonts = {
        title = exports.gzl_ui:getFont("heavy", math.max(11, math.floor(14 * layout.scale))),
        subtitle = exports.gzl_ui:getFont("medium", math.max(8, math.floor(9 * layout.scale))),
        tab = exports.gzl_ui:getFont("bold", math.max(8, math.floor(9 * layout.scale))),
        section = exports.gzl_ui:getFont("bold", math.max(8, math.floor(9 * layout.scale))),
        label = exports.gzl_ui:getFont("semibold", math.max(8, math.floor(9 * layout.scale))),
        body = exports.gzl_ui:getFont("regular", math.max(8, math.floor(9 * layout.scale))),
        button = exports.gzl_ui:getFont("bold", math.max(8, math.floor(9 * layout.scale)))
    }
    return true
end

local studioHistory, studioFuture, studioSnapshot = {}, {}, nil
local studioButtons = {}
local function cloneStudioState(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for k,v in pairs(value) do result[k] = cloneStudioState(v) end
    return result
end
local function captureStudioState()
    local signature = toJSON(charData, true)
    if studioSnapshot and studioSnapshot.signature ~= signature then
        studioHistory[#studioHistory+1] = studioSnapshot.data
        if #studioHistory > 60 then table.remove(studioHistory,1) end
        studioFuture = {}
    end
    studioSnapshot = { signature=signature, data=cloneStudioState(charData) }
end
local function restoreStudioState(from, target)
    if #from == 0 then return end
    target[#target+1] = cloneStudioState(charData)
    charData = table.remove(from)
    studioSnapshot = { signature=toJSON(charData,true), data=cloneStudioState(charData) }
    if isElement(studioPed) then
        setElementModel(studioPed, charData.gender == "female" and CreatorConfig.FemaleSkinID or CreatorConfig.MaleSkinID)
        applyCharacterCustomization(studioPed,charData)
    end
end
function isCreatorStudioUIAt(x,y)
    if not isVisible then return false end
    if x >= layout.panelX and x <= layout.panelX+layout.panelW and y >= layout.panelY and y <= layout.panelY+layout.panelH then return true end
    for _,b in ipairs(studioButtons) do
        if x>=b.x and x<=b.x+b.w and y>=b.y and y<=b.y+b.h then return true end
    end
    return false
end
local function renderStudioToolbar()
    captureStudioState()
    local scale=layout.scale
    local left=layout.panelX+layout.panelW+24*scale
    local available=screenW-left-24*scale
    local width=math.min(available,560*scale)
    if width<220 then studioButtons={} return end
    local x=left+(available-width)/2
    local y=screenH-112*scale
    local definitions={
        {"full","Tüm vücut"},{"head","Yüz"},{"body","Üst"},{"feet","Ayak"},{"front","Ön"},{"back","Arka"},
        {"idle","Duruş"},{"walk","Yürü"},{"run","Koş"},{"undo","Geri al"},{"redo","İleri al"},{"resetview","Sıfırla"}
    }
    exports.gzl_ui:drawRoundedRectangle(x-12*scale,y-31*scale,width+24*scale,111*scale,12*scale,tocolor(12,19,25,235))
    exports.aura_ui:uiDrawText("PROVA STÜDYOSU",x,y-25*scale,x+width,y-5*scale,tocolor(120,225,195,255),1,fonts.section,"left","center")
    studioButtons={}
    local choices=getCreatorOutfits(charData.gender)
    local current='GZL gardırop'
    for _,item in ipairs(choices) do if item.id==(charData.outfit or '') then current=item.name end end
    local oy=y-80*scale
    exports.gzl_ui:drawRoundedRectangle(x-12*scale,oy,width+24*scale,43*scale,8*scale,tocolor(19,31,38,245))
    exports.aura_ui:uiDrawText('KOMBİN  /  '..current,x+45*scale,oy,x+width-45*scale,oy+43*scale,tocolor(174,236,214,255),1,fonts.body,'center','center',true)
    for _,item in ipairs({{'outfitprev','<',x},{'outfitnext','>',x+width-36*scale}}) do
        exports.aura_ui:uiDrawText(item[2],item[3],oy,item[3]+36*scale,oy+43*scale,tocolor(230,245,240,255),1,fonts.title,'center','center')
        studioButtons[#studioButtons+1]={id=item[1],x=item[3],y=oy,w=36*scale,h=43*scale,enabled=#choices>1}
    end
    local bw=(width-5*5*scale)/6
    for i,d in ipairs(definitions) do
        local bx=x+((i-1)%6)*(bw+5*scale)
        local by=y+math.floor((i-1)/6)*36*scale
        local enabled=not (d[1]=="undo" and #studioHistory==0 or d[1]=="redo" and #studioFuture==0)
        local hover=exports.gzl_ui:isMouseInPosition(bx,by,bw,31*scale)
        exports.gzl_ui:drawRoundedRectangle(bx,by,bw,31*scale,6*scale,hover and enabled and tocolor(44,120,108,245) or tocolor(27,38,47,245))
        exports.aura_ui:uiDrawText(d[2],bx,by,bx+bw,by+31*scale,enabled and tocolor(233,242,241,255) or tocolor(111,124,132,180),1,fonts.body,"center","center",true)
        studioButtons[#studioButtons+1]={id=d[1],x=bx,y=by,w=bw,h=31*scale,enabled=enabled}
    end
end
local function studioToolbarClick(button,state,x,y)
    if not isVisible or button~="left" or state~="down" or not isElement(studioPed) then return end
    captureStudioState()
    for _,b in ipairs(studioButtons) do
        if b.enabled and x>=b.x and x<=b.x+b.w and y>=b.y and y<=b.y+b.h then
            if b.id=='outfitprev' or b.id=='outfitnext' then
                local choices=getCreatorOutfits(charData.gender);local index=1
                for i,item in ipairs(choices) do if item.id==(charData.outfit or '') then index=i end end
                index=((index-1+(b.id=='outfitnext' and 1 or -1)) % #choices)+1
                charData.outfit=choices[index].id;charData.torso=1;charData.legs=1;charData.shoes=1
                charData.torsoVariant=1;charData.legsVariant=1;charData.shoesVariant=1;charData.accessories={}
                applyCharacterCustomization(studioPed,charData)
            elseif b.id=="undo" then restoreStudioState(studioHistory,studioFuture)
            elseif b.id=="redo" then restoreStudioState(studioFuture,studioHistory)
            elseif b.id=="front" or b.id=="back" then setPedDirectRotation((CreatorConfig.Studio.ped.rot or 180)+(b.id=="back" and 180 or 0))
            elseif b.id=="resetview" then setPedDirectRotation(CreatorConfig.Studio.ped.rot or 180);setCameraView("full")
            elseif b.id=="idle" or b.id=="walk" or b.id=="run" then
                if isTimer(previewAnimTimer) then killTimer(previewAnimTimer) end
                if b.id=="idle" then setPedAnimation(studioPed,"dealer","dealer_idle",-1,true,false,false,false)
                else setPedAnimation(studioPed,"PED",b.id=="walk" and "WALK_player" or "run_player",-1,true,false,false,false) end
            else setCameraView(b.id) end
            return
        end
    end
end
addEventHandler("onClientClick",root,studioToolbarClick)

local function refreshStudioPed()
    if not isElement(studioPed) then return end
    applyCharacterCustomization(studioPed, charData)
end

local function playPreviewAnim(animType)
    if not isElement(studioPed) then return end
    if isTimer(previewAnimTimer) then killTimer(previewAnimTimer) end

    if animType == "clothes" then
        setPedAnimation(studioPed, "clothes", "CLOT_Buy", 2500, false, false, false, false)
        previewAnimTimer = setTimer(function()
            if isElement(studioPed) then
                setPedAnimation(studioPed, "dealer", "dealer_idle", -1, true, false, false, false)
            end
        end, 2500, 1)
    elseif animType == "hair" or animType == "appearance" then
        setPedAnimation(studioPed, "ped", "roadcross", 1400, false, false, false, false)
        previewAnimTimer = setTimer(function()
            if isElement(studioPed) then
                setPedAnimation(studioPed, "dealer", "dealer_idle", -1, true, false, false, false)
            end
        end, 1400, 1)
    end
end

local function getFilteredAccessories(cfg, category)
    local list = {}
    if not cfg or not cfg.accessories then return list end
    for key, data in pairs(cfg.accessories) do
        if not category or category == "all" or data.category == category then
            table.insert(list, {
                key = key,
                name = data.name or key,
                category = data.category or "head"
            })
        end
    end
    table.sort(list, function(a, b)
        local catOrder = { head = 1, face = 2, body = 3 }
        local ordA = catOrder[a.category] or 9
        local ordB = catOrder[b.category] or 9
        if ordA ~= ordB then
            return ordA < ordB
        end
        return a.name < b.name
    end)
    return list
end

local function drawSelectorRow(id, labelText, currentValueText, x, y, w, h)
    local scale = layout.scale
    exports.aura_ui:uiDrawText(labelText, x, y, x + w, y + 18 * scale, tocolor(195, 210, 230, 240), 1, fonts.label, "left", "center")

    local boxY = y + 20 * scale
    local boxH = 34 * scale
    exports.gzl_ui:drawRoundedRectangle(x, boxY, w, boxH, 8 * scale, tocolor(23, 33, 42, 220))
    exports.gzl_ui:drawRoundedBorder(x, boxY, w, boxH, 8 * scale, 1, tocolor(255, 255, 255, 18))

    local btnW = 32 * scale
    local leftHov = exports.gzl_ui:isMouseInPosition(x, boxY, btnW, boxH)
    if leftHov then
        exports.gzl_ui:drawRoundedRectangle(x, boxY, btnW, boxH, 8 * scale, tocolor(55, 177, 149, 70))
    end
    exports.aura_ui:uiDrawText("❮", x, boxY, x + btnW, boxY + boxH, leftHov and tocolor(255, 255, 255, 255) or tocolor(140, 160, 185, 220), 1, fonts.button, "center", "center")

    exports.aura_ui:uiDrawText(currentValueText, x + btnW, boxY, x + w - btnW, boxY + boxH, tocolor(240, 245, 255, 255), 1, fonts.body, "center", "center", true)

    local rightX = x + w - btnW
    local rightHov = exports.gzl_ui:isMouseInPosition(rightX, boxY, btnW, boxH)
    if rightHov then
        exports.gzl_ui:drawRoundedRectangle(rightX, boxY, btnW, boxH, 8 * scale, tocolor(55, 177, 149, 70))
    end
    exports.aura_ui:uiDrawText("❯", rightX, boxY, rightX + btnW, boxY + boxH, rightHov and tocolor(255, 255, 255, 255) or tocolor(140, 160, 185, 220), 1, fonts.button, "center", "center")

    return leftHov, rightHov
end

local function renderCreatorUI()
    if not isVisible or not prepareFonts() then return end

    local scale = layout.scale
    local px = layout.panelX
    local py = layout.panelY
    local pw = layout.panelW
    local ph = layout.panelH
    local isIngame = getElementData(localPlayer, "loggedin_character") and true or false

    renderStudioToolbar()

    exports.gzl_ui:drawRoundedRectangle(px,py,pw,ph,16*scale,tocolor(12,19,25,245))
    exports.gzl_ui:drawRoundedBorder(px,py,pw,ph,16*scale,1,tocolor(157,210,197,35))

    local titleX = px + 22 * scale
    local titleY = py + 20 * scale
    exports.gzl_ui:drawRoundedRectangle(titleX, titleY + 2 * scale, 4 * scale, 38 * scale, 2 * scale, tocolor(55, 177, 149, 255))
    exports.aura_ui:uiDrawText("GZL  /  STUDIO", titleX + 12 * scale, titleY, titleX + pw, titleY + 20 * scale, tocolor(255, 255, 255, 255), 1, fonts.title, "left", "center")

    local subTitleText = isIngame and "KIYAFET & GÖRÜNÜM MENÜSÜ" or "KARAKTERİNİ OLUŞTUR"
    exports.aura_ui:uiDrawText(subTitleText, titleX + 12 * scale, titleY + 20 * scale, titleX + pw, titleY + 38 * scale, tocolor(118, 219, 192, 220), 1, fonts.subtitle, "left", "center")

    local tabs = {}
    if isIngame then
        tabs = {
            { id = "appearance", name = "GÖRÜNÜM", cam = "head" },
            { id = "hair", name = "SAÇ", cam = "head" },
            { id = "clothes", name = "KIYAFET", cam = "body" },
            { id = "accessories", name = "AKSESUAR", cam = "full" }
        }
        if currentTab == "identity" then
            currentTab = "appearance"
        end
    else
        tabs = {
            { id = "identity", name = "KİMLİK", cam = "head" },
            { id = "appearance", name = "GÖRÜNÜM", cam = "head" },
            { id = "hair", name = "SAÇ", cam = "head" },
            { id = "clothes", name = "KIYAFET", cam = "body" },
            { id = "accessories", name = "AKSESUAR", cam = "full" }
        }
    end

    local tabY = py + 68 * scale
    local tabW = (pw - 44 * scale) / #tabs
    local tabH = 32 * scale

    for idx, tab in ipairs(tabs) do
        local tx = px + 22 * scale + (idx - 1) * tabW
        local active = currentTab == tab.id
        local hovered = exports.gzl_ui:isMouseInPosition(tx, tabY, tabW - 2, tabH)

        if active then
            exports.gzl_ui:drawRoundedRectangle(tx, tabY, tabW - 2, tabH, 6 * scale, tocolor(55, 177, 149, 180))
        elseif hovered then
            exports.gzl_ui:drawRoundedRectangle(tx, tabY, tabW - 2, tabH, 6 * scale, tocolor(255, 255, 255, 20))
        end
        exports.aura_ui:uiDrawText(tab.name, tx, tabY, tx + tabW - 2, tabY + tabH, active and tocolor(255, 255, 255, 255) or tocolor(150, 165, 185, 200), 1, fonts.tab, "center", "center")
    end

    local contentY = py + 112 * scale
    local contentW = pw - 44 * scale
    local contentX = px + 22 * scale

    if currentTab == "identity" and not isIngame then

        exports.aura_ui:uiDrawText("Cinsiyet", contentX, contentY, contentX + contentW, contentY + 16 * scale, tocolor(180, 200, 225, 240), 1, fonts.label)
        local gBtnW = (contentW - 8 * scale) / 2
        local gBtnH = 36 * scale
        local gBtnY = contentY + 20 * scale

        local maleActive = charData.gender == "male"
        exports.gzl_ui:drawRoundedRectangle(contentX, gBtnY, gBtnW, gBtnH, 8 * scale, maleActive and tocolor(37, 99, 235, 220) or tocolor(20, 28, 42, 200))
        exports.aura_ui:uiDrawText("♂ Erkek", contentX, gBtnY, contentX + gBtnW, gBtnY + gBtnH, tocolor(255, 255, 255, 255), 1, fonts.button, "center", "center")

        local femaleActive = charData.gender == "female"
        local femaleX = contentX + gBtnW + 8 * scale
        exports.gzl_ui:drawRoundedRectangle(femaleX, gBtnY, gBtnW, gBtnH, 8 * scale, femaleActive and tocolor(219, 39, 119, 220) or tocolor(20, 28, 42, 200))
        exports.aura_ui:uiDrawText("♀ Kadın", femaleX, gBtnY, femaleX + gBtnW, gBtnY + gBtnH, tocolor(255, 255, 255, 255), 1, fonts.button, "center", "center")

        local nameY = gBtnY + 50 * scale
        exports.aura_ui:uiDrawText("Karakter Adı & Soyadı", contentX, nameY, contentX + contentW, nameY + 16 * scale, tocolor(180, 200, 225, 240), 1, fonts.label)
        exports.gzl_ui:drawGlassEditBox("creator_char_name", contentX, nameY + 20 * scale, contentW, 36 * scale, { placeholder = "Ad_Soyad", text = charData.name, font = fonts.body })

        local ageY = nameY + 70 * scale
        drawSelectorRow("char_age", "Karakter Yaşı", tostring(charData.age) .. " Yaş", contentX, ageY, contentW, 36 * scale)

    elseif currentTab == "appearance" then
        local toneCfg = CreatorConfig.SkinTones[charData.skinTone] or CreatorConfig.SkinTones[3]
        drawSelectorRow("skin_tone", "Ten Rengi Tonu", toneCfg.name .. " (#" .. charData.skinTone .. ")", contentX, contentY, contentW, 36 * scale)

        local dotY = contentY + 62 * scale
        local dotGap = contentW / #CreatorConfig.SkinTones
        for i, t in ipairs(CreatorConfig.SkinTones) do
            local dotX = contentX + (i - 0.5) * dotGap
            local selected = charData.skinTone == i
            exports.gzl_ui:drawCircle(dotX, dotY, selected and (12 * scale) or (8 * scale), tocolor(t.color[1]*255, t.color[2]*255, t.color[3]*255, 255))
            if selected then
                exports.gzl_ui:drawCircle(dotX, dotY, 4 * scale, tocolor(255, 255, 255, 255))
            end
        end

        local eyeY = dotY + 22 * scale
        local eyeName = CreatorConfig.EyeColors[charData.face.eyes] or ("Göz Rengi #" .. tostring(charData.face.eyes))
        drawSelectorRow("eye_color", "Göz Rengi", eyeName, contentX, eyeY, contentW, 36 * scale)

        local ebY = eyeY + 64 * scale
        local ebName = CreatorConfig.Eyebrows[charData.face.eyebrow] or ("Kaş Stili #" .. tostring(charData.face.eyebrow))
        drawSelectorRow("eyebrow", "Kaş Şekli", ebName, contentX, ebY, contentW, 36 * scale)

        local extraY = ebY + 64 * scale
        if charData.gender == "male" then
            local beardName = CreatorConfig.Male.beards[charData.face.beard] or ("Sakal Stili #" .. tostring(charData.face.beard))
            drawSelectorRow("beard", "Sakal & Bıyık", beardName, contentX, extraY, contentW, 36 * scale)
        else
            local lipName = CreatorConfig.Female.lipsticks[charData.face.lipstick] or ("Ruj Tonu #" .. tostring(charData.face.lipstick))
            drawSelectorRow("lipstick", "Ruj Tonu", lipName, contentX, extraY, contentW, 36 * scale)
        end

    elseif currentTab == "hair" then
        local cfg = resolveCreatorConfig(charData)
        local hairItem = cfg.hairs[charData.hair.id] or cfg.hairs[1] or { name = "Kel / Saçsız", variants = 0 }
        drawSelectorRow("hair_model", "Saç Kesimi", hairItem.name, contentX, contentY, contentW, 36 * scale)

        if charData.hair.id > 0 and (hairItem.variants or 0) > 0 then

            local varY = contentY + 64 * scale
            local maxVars = hairItem.variants or 1
            local curVar = charData.hairVariant or 1
            local varText = "Varyant / Stil #" .. tostring(curVar) .. " / " .. tostring(maxVars)
            drawSelectorRow("hair_variant", "Saç Stili / Deseni", varText, contentX, varY, contentW, 36 * scale)

            local colorY = varY + 64 * scale
            local colorCfg = CreatorConfig.HairColors[charData.hairColorIdx] or CreatorConfig.HairColors[1]
            drawSelectorRow("hair_color", "Saç Rengi Tonu", colorCfg.name, contentX, colorY, contentW, 36 * scale)

            local dotY = colorY + 64 * scale
            local dotGap = contentW / #CreatorConfig.HairColors
            for i, c in ipairs(CreatorConfig.HairColors) do
                local dotX = contentX + (i - 0.5) * dotGap
                local selected = charData.hairColorIdx == i
                exports.gzl_ui:drawCircle(dotX, dotY, selected and (11 * scale) or (7 * scale), tocolor(c.color[1]*255, c.color[2]*255, c.color[3]*255, 255))
                if selected then
                    exports.gzl_ui:drawCircle(dotX, dotY, 4 * scale, tocolor(255, 255, 255, 255))
                end
            end
        else

            local infoY = contentY + 68 * scale
            exports.gzl_ui:drawRoundedRectangle(contentX, infoY, contentW, 52 * scale, 8 * scale, tocolor(23, 33, 42, 180))
            exports.gzl_ui:drawRoundedBorder(contentX, infoY, contentW, 52 * scale, 8 * scale, 1, tocolor(255, 255, 255, 12))
            exports.aura_ui:uiDrawText("Kel / Saçsız stil seçildi.\nRenk ve varyant seçenekleri devre dışıdır.", contentX, infoY, contentX + contentW, infoY + 52 * scale, tocolor(140, 160, 185, 220), 1, fonts.subtitle, "center", "center")
        end

    elseif currentTab == "clothes" then
        local cfg = resolveCreatorConfig(charData)

        local torsoItem = cfg.torso[charData.torso] or cfg.torso[1]
        drawSelectorRow("cloth_torso", "Üst Kıyafet Modeli", torsoItem.name, contentX, contentY, contentW, 36 * scale)

        local tVarY = contentY + 60 * scale
        local tMaxVars = torsoItem.variants or 1
        local tVarText = tMaxVars > 0 and ("Desen #" .. tostring(charData.torsoVariant) .. " / " .. tostring(tMaxVars)) or "Standart"
        drawSelectorRow("cloth_torso_var", "Üst Kıyafet Rengi/Deseni", tVarText, contentX, tVarY, contentW, 36 * scale)

        local legsY = tVarY + 60 * scale
        local legsItem = cfg.legs[charData.legs] or cfg.legs[1]
        drawSelectorRow("cloth_legs", "Alt Kıyafet (Pantolon)", legsItem.name, contentX, legsY, contentW, 36 * scale)

        local lVarY = legsY + 60 * scale
        local lMaxVars = legsItem.variants or 1
        local lVarText = lMaxVars > 0 and ("Renk #" .. tostring(charData.legsVariant) .. " / " .. tostring(lMaxVars)) or "Standart"
        drawSelectorRow("cloth_legs_var", "Alt Kıyafet Rengi/Deseni", lVarText, contentX, lVarY, contentW, 36 * scale)

        local shoesY = lVarY + 60 * scale
        local shoesItem = cfg.shoes[charData.shoes] or cfg.shoes[1]
        drawSelectorRow("cloth_shoes", "Ayakkabı", shoesItem.name, contentX, shoesY, contentW, 36 * scale)

        local sVarY = shoesY + 60 * scale
        local sMaxVars = shoesItem.variants or 1
        local sVarText = sMaxVars > 0 and ("Renk #" .. tostring(charData.shoesVariant) .. " / " .. tostring(sMaxVars)) or "Standart"
        drawSelectorRow("cloth_shoes_var", "Ayakkabı Rengi", sVarText, contentX, sVarY, contentW, 36 * scale)

    elseif currentTab == "accessories" then
        local cfg = resolveCreatorConfig(charData)
        local categories = {
            { id = "all", name = "TÜMÜ" },
            { id = "head", name = "ŞAPKA" },
            { id = "face", name = "YÜZ" },
            { id = "body", name = "EKİPMAN" }
        }

        local catW = (contentW - 9 * scale) / #categories
        local catH = 28 * scale
        for i, cat in ipairs(categories) do
            local cx = contentX + (i - 1) * (catW + 3 * scale)
            local isSel = currentAccCategory == cat.id
            local isHov = exports.gzl_ui:isMouseInPosition(cx, contentY, catW, catH)

            if isSel then
                exports.gzl_ui:drawRoundedRectangle(cx, contentY, catW, catH, 6 * scale, tocolor(55, 177, 149, 200))
            elseif isHov then
                exports.gzl_ui:drawRoundedRectangle(cx, contentY, catW, catH, 6 * scale, tocolor(255, 255, 255, 25))
            else
                exports.gzl_ui:drawRoundedRectangle(cx, contentY, catW, catH, 6 * scale, tocolor(23, 33, 42, 180))
            end
            exports.aura_ui:uiDrawText(cat.name, cx, contentY, cx + catW, contentY + catH, isSel and tocolor(255, 255, 255, 255) or tocolor(150, 165, 185, 220), 1, fonts.tab, "center", "center")
        end

        local filtered = getFilteredAccessories(cfg, currentAccCategory)
        local listY = contentY + 36 * scale
        local itemH = 38 * scale
        local itemGap = 6 * scale
        local maxVisible = 7
        local maxScroll = math.max(0, #filtered - maxVisible)
        accScrollOffset = math.min(accScrollOffset, maxScroll)

        local fromIdx = accScrollOffset + 1
        local toIdx = math.min(#filtered, accScrollOffset + maxVisible)

        local cardW = contentW - (maxScroll > 0 and (8 * scale) or 0)

        for i = fromIdx, toIdx do
            local item = filtered[i]
            local relIdx = i - fromIdx
            local ay = listY + relIdx * (itemH + itemGap)
            local isEquipped = charData.accessories[item.key] == true
            local hovered = exports.gzl_ui:isMouseInPosition(contentX, ay, cardW, itemH)

            if isEquipped then
                exports.gzl_ui:drawRoundedRectangle(contentX, ay, cardW, itemH, 8 * scale, tocolor(37, 99, 235, 110))
                exports.gzl_ui:drawRoundedBorder(contentX, ay, cardW, itemH, 8 * scale, 1, tocolor(55, 177, 149, 220))
            else
                exports.gzl_ui:drawRoundedRectangle(contentX, ay, cardW, itemH, 8 * scale, hovered and tocolor(25, 35, 52, 220) or tocolor(23, 33, 42, 190))
                exports.gzl_ui:drawRoundedBorder(contentX, ay, cardW, itemH, 8 * scale, 1, hovered and tocolor(255, 255, 255, 30) or tocolor(255, 255, 255, 12))
            end

            local dotSize = 7 * scale
            local dotX = contentX + 14 * scale
            local dotY = ay + (itemH - dotSize) / 2
            exports.gzl_ui:drawRoundedRectangle(dotX, dotY, dotSize, dotSize, 2 * scale, isEquipped and tocolor(55, 177, 149, 255) or tocolor(140, 160, 185, 180))

            exports.aura_ui:uiDrawText(item.name, dotX + dotSize + 10 * scale, ay, contentX + cardW - 142 * scale, ay + itemH, tocolor(240, 245, 255, 255), 1, fonts.body, "left", "center", true)

            local variants=cfg.accessories[item.key].variants or 1
            if variants>1 then
                local vx=contentX+cardW-137*scale
                exports.gzl_ui:drawRoundedRectangle(vx,ay+7*scale,55*scale,24*scale,5*scale,tocolor(34,58,65,245))
                exports.aura_ui:uiDrawText(tostring(charData.accessoryVariants and charData.accessoryVariants[item.key] or 1)..'/'..variants..' >',vx,ay,vx+55*scale,ay+itemH,tocolor(171,235,213,255),1,fonts.body,'center','center')
            end

            local badgeW = 66 * scale
            local badgeH = 24 * scale
            local badgeX = contentX + cardW - badgeW - 8 * scale
            local badgeY = ay + (itemH - badgeH) / 2

            if isEquipped then
                exports.gzl_ui:drawRoundedRectangle(badgeX, badgeY, badgeW, badgeH, 6 * scale, tocolor(16, 185, 129, 220))
                exports.aura_ui:uiDrawText("✓ TAKILI", badgeX, badgeY, badgeX + badgeW, badgeY + badgeH, tocolor(255, 255, 255, 255), 1, fonts.button, "center", "center")
            else
                exports.gzl_ui:drawRoundedRectangle(badgeX, badgeY, badgeW, badgeH, 6 * scale, tocolor(30, 41, 59, 220))
                exports.gzl_ui:drawRoundedBorder(badgeX, badgeY, badgeW, badgeH, 6 * scale, 1, tocolor(255, 255, 255, 20))
                exports.aura_ui:uiDrawText("+ TAK", badgeX, badgeY, badgeX + badgeW, badgeY + badgeH, tocolor(160, 175, 195, 220), 1, fonts.label, "center", "center")
            end
        end

        if maxScroll > 0 then
            local trackX = contentX + contentW - 4 * scale
            local trackH = maxVisible * (itemH + itemGap) - itemGap
            exports.gzl_ui:drawRoundedRectangle(trackX, listY, 3 * scale, trackH, 2 * scale, tocolor(255, 255, 255, 20))

            local thumbH = math.max(16 * scale, trackH * (maxVisible / #filtered))
            local thumbY = listY + (trackH - thumbH) * (accScrollOffset / maxScroll)
            exports.gzl_ui:drawRoundedRectangle(trackX, thumbY, 3 * scale, thumbH, 2 * scale, tocolor(55, 177, 149, 220))
        end

        local row1Y = py + ph - 88 * scale
        exports.aura_ui:uiDrawText("💡 Fare tekerleği ile kaydırabilirsiniz", contentX, row1Y - 20 * scale, contentX + contentW, row1Y - 4 * scale, tocolor(140, 160, 185, 160), 1, fonts.subtitle, "center", "center")
    end

    local row1Y = py + ph - 88 * scale
    local row2Y = py + ph - 46 * scale

    if isIngame then

        exports.gzl_ui:drawGlassButton("btn_back", "❮ VAZGEÇ & KAPAT", contentX, row1Y, contentW, 36 * scale, { theme = "danger", font = fonts.button })
        local saveText = isSubmitting and "KAYDEDİLİYOR..." or "✓ GÜNCELLE & KAYDET"
        exports.gzl_ui:drawGlassButton("btn_save", saveText, contentX, row2Y, contentW, 40 * scale, { theme = "green", font = fonts.button, disabled = isSubmitting })
    else

        local halfBtnW = (contentW - 8 * scale) / 2
        exports.gzl_ui:drawGlassButton("btn_back", "❮ SEÇİME DÖN", contentX, row1Y, halfBtnW, 34 * scale, { theme = "blue", font = fonts.button })
        exports.gzl_ui:drawGlassButton("btn_random", "🎲 RASTGELE", contentX + halfBtnW + 8 * scale, row1Y, halfBtnW, 34 * scale, { theme = "blue", font = fonts.button })
        local saveText = isSubmitting and "OLUŞTURULUYOR..." or "✓ ONAYLA & BAŞLA"
        exports.gzl_ui:drawGlassButton("btn_save", saveText, contentX, row2Y, contentW, 40 * scale, { theme = "green", font = fonts.button, disabled = isSubmitting })
    end

    local camBarW = 340 * scale
    local camBarH = 36 * scale
    local camBarX = (screenW - camBarW) / 2
    local camBarY = 20 * scale

    exports.gzl_ui:drawGlassPanel(camBarX, camBarY, camBarW, camBarH, 10 * scale)
    local camViews = {
        { id = "head", name = "YÜZ" },
        { id = "body", name = "GÖVDE" },
        { id = "feet", name = "AYAK" },
        { id = "full", name = "TAM BOY" }
    }
    local cbW = camBarW / #camViews
    for i, cv in ipairs(camViews) do
        local bx = camBarX + (i - 1) * cbW
        local hovered = exports.gzl_ui:isMouseInPosition(bx, camBarY, cbW, camBarH)
        if hovered then
            exports.gzl_ui:drawRoundedRectangle(bx + 2, camBarY + 2, cbW - 4, camBarH - 4, 6 * scale, tocolor(55, 177, 149, 60))
        end
        exports.aura_ui:uiDrawText(cv.name, bx, camBarY, bx + cbW, camBarY + camBarH, hovered and tocolor(255, 255, 255, 255) or tocolor(180, 200, 225, 220), 1, fonts.button, "center", "center")
    end

    exports.aura_ui:uiDrawText("💡 Karakteri döndürmek için sağ tarafa tıklayıp sürükleyin", screenW - 360 * scale, screenH - 30 * scale, screenW - 20 * scale, screenH, tocolor(160, 180, 205, 180), 1, fonts.subtitle, "right", "center")
end

local function handleCreatorClick(button, state)
    if button ~= "left" or state ~= "down" or not isVisible then return end

    local scale = layout.scale
    local px = layout.panelX
    local py = layout.panelY
    local pw = layout.panelW
    local ph = layout.panelH
    local contentW = pw - 44 * scale
    local contentX = px + 22 * scale
    local contentY = py + 112 * scale
    local isIngame = getElementData(localPlayer, "loggedin_character") and true or false

    local camBarW = 340 * scale
    local camBarH = 36 * scale
    local camBarX = (screenW - camBarW) / 2
    local camBarY = 20 * scale
    if exports.gzl_ui:isMouseInPosition(camBarX, camBarY, camBarW, camBarH) then
        local camViews = { "head", "body", "feet", "full" }
        local cbW = camBarW / #camViews
        for i, cv in ipairs(camViews) do
            local bx = camBarX + (i - 1) * cbW
            if exports.gzl_ui:isMouseInPosition(bx, camBarY, cbW, camBarH) then
                setCameraView(cv)
                return
            end
        end
    end

    local tabs = {}
    if isIngame then
        tabs = {
            { id = "appearance", cam = "head" },
            { id = "hair", cam = "head" },
            { id = "clothes", cam = "body" },
            { id = "accessories", cam = "full" }
        }
    else
        tabs = {
            { id = "identity", cam = "head" },
            { id = "appearance", cam = "head" },
            { id = "hair", cam = "head" },
            { id = "clothes", cam = "body" },
            { id = "accessories", cam = "full" }
        }
    end

    local tabY = py + 68 * scale
    local tabW = (pw - 44 * scale) / #tabs
    local tabH = 32 * scale
    for idx, t in ipairs(tabs) do
        local tx = px + 22 * scale + (idx - 1) * tabW
        if exports.gzl_ui:isMouseInPosition(tx, tabY, tabW - 2, tabH) then
            if currentTab ~= t.id then
                currentTab = t.id
                if t.cam then setCameraView(t.cam) end
                playPreviewAnim(t.id)
            end
            return
        end
    end

    local btnW = 32 * scale

    if currentTab == "identity" and not isIngame then
        local gBtnW = (contentW - 8 * scale) / 2
        local gBtnH = 36 * scale
        local gBtnY = contentY + 20 * scale
        if exports.gzl_ui:isMouseInPosition(contentX, gBtnY, gBtnW, gBtnH) then
            charData.gender = "male"
            if isElement(studioPed) then setElementModel(studioPed, CreatorConfig.MaleSkinID) end
            refreshStudioPed()
            return
        elseif exports.gzl_ui:isMouseInPosition(contentX + gBtnW + 8 * scale, gBtnY, gBtnW, gBtnH) then
            charData.gender = "female"
            if isElement(studioPed) then setElementModel(studioPed, CreatorConfig.FemaleSkinID) end
            refreshStudioPed()
            return
        end

        local ageY = gBtnY + 120 * scale
        if exports.gzl_ui:isMouseInPosition(contentX, ageY + 20 * scale, btnW, 34 * scale) then
            charData.age = math.max(18, charData.age - 1)
        elseif exports.gzl_ui:isMouseInPosition(contentX + contentW - btnW, ageY + 20 * scale, btnW, 34 * scale) then
            charData.age = math.min(80, charData.age + 1)
        end

    elseif currentTab == "appearance" then

        if exports.gzl_ui:isMouseInPosition(contentX, contentY + 20 * scale, btnW, 34 * scale) then
            charData.skinTone = charData.skinTone > 1 and (charData.skinTone - 1) or #CreatorConfig.SkinTones
            refreshStudioPed()
        elseif exports.gzl_ui:isMouseInPosition(contentX + contentW - btnW, contentY + 20 * scale, btnW, 34 * scale) then
            charData.skinTone = charData.skinTone < #CreatorConfig.SkinTones and (charData.skinTone + 1) or 1
            refreshStudioPed()
        end

        local dotY = contentY + 62 * scale
        local dotGap = contentW / #CreatorConfig.SkinTones
        for i = 1, #CreatorConfig.SkinTones do
            local dotX = contentX + (i - 0.5) * dotGap
            if exports.gzl_ui:isMouseInPosition(dotX - 14 * scale, dotY - 14 * scale, 28 * scale, 28 * scale) then
                charData.skinTone = i
                refreshStudioPed()
                return
            end
        end

        local eyeY = dotY + 22 * scale
        local maxEyes = #CreatorConfig.EyeColors
        if exports.gzl_ui:isMouseInPosition(contentX, eyeY + 20 * scale, btnW, 34 * scale) then
            charData.face.eyes = charData.face.eyes > 1 and (charData.face.eyes - 1) or maxEyes
            refreshStudioPed()
        elseif exports.gzl_ui:isMouseInPosition(contentX + contentW - btnW, eyeY + 20 * scale, btnW, 34 * scale) then
            charData.face.eyes = charData.face.eyes < maxEyes and (charData.face.eyes + 1) or 1
            refreshStudioPed()
        end

        local ebY = eyeY + 64 * scale
        local maxEyebrows = #CreatorConfig.Eyebrows
        if exports.gzl_ui:isMouseInPosition(contentX, ebY + 20 * scale, btnW, 34 * scale) then
            charData.face.eyebrow = charData.face.eyebrow > 1 and (charData.face.eyebrow - 1) or maxEyebrows
            refreshStudioPed()
        elseif exports.gzl_ui:isMouseInPosition(contentX + contentW - btnW, ebY + 20 * scale, btnW, 34 * scale) then
            charData.face.eyebrow = charData.face.eyebrow < maxEyebrows and (charData.face.eyebrow + 1) or 1
            refreshStudioPed()
        end

        local extraY = ebY + 64 * scale
        if charData.gender == "male" then
            local maxBeards = #CreatorConfig.Male.beards
            if exports.gzl_ui:isMouseInPosition(contentX, extraY + 20 * scale, btnW, 34 * scale) then
                charData.face.beard = charData.face.beard > 0 and (charData.face.beard - 1) or maxBeards
                refreshStudioPed()
            elseif exports.gzl_ui:isMouseInPosition(contentX + contentW - btnW, extraY + 20 * scale, btnW, 34 * scale) then
                charData.face.beard = charData.face.beard < maxBeards and (charData.face.beard + 1) or 0
                refreshStudioPed()
            end
        else
            local maxLips = #CreatorConfig.Female.lipsticks
            if exports.gzl_ui:isMouseInPosition(contentX, extraY + 20 * scale, btnW, 34 * scale) then
                charData.face.lipstick = charData.face.lipstick > 0 and (charData.face.lipstick - 1) or maxLips
                refreshStudioPed()
            elseif exports.gzl_ui:isMouseInPosition(contentX + contentW - btnW, extraY + 20 * scale, btnW, 34 * scale) then
                charData.face.lipstick = charData.face.lipstick < maxLips and (charData.face.lipstick + 1) or 0
                refreshStudioPed()
            end
        end

    elseif currentTab == "hair" then
        local cfg = resolveCreatorConfig(charData)
        local maxHairs = #cfg.hairs

        if exports.gzl_ui:isMouseInPosition(contentX, contentY + 20 * scale, btnW, 34 * scale) then
            charData.hair.id = (charData.hair.id or 1) > 0 and (charData.hair.id - 1) or maxHairs
            charData.hairVariant = 1
            charData.hair.variant = 1
            refreshStudioPed()
            return
        elseif exports.gzl_ui:isMouseInPosition(contentX + contentW - btnW, contentY + 20 * scale, btnW, 34 * scale) then
            charData.hair.id = (charData.hair.id or 1) < maxHairs and (charData.hair.id + 1) or 0
            charData.hairVariant = 1
            charData.hair.variant = 1
            refreshStudioPed()
            return
        end

        local hairItem = cfg.hairs[charData.hair.id]
        if charData.hair.id > 0 and hairItem and (hairItem.variants or 0) > 0 then
            local maxVars = hairItem.variants or 1
            local varY = contentY + 64 * scale

            if exports.gzl_ui:isMouseInPosition(contentX, varY + 20 * scale, btnW, 34 * scale) then
                charData.hairVariant = (charData.hairVariant or 1) > 1 and (charData.hairVariant - 1) or maxVars
                charData.hair.variant = charData.hairVariant
                refreshStudioPed()
                return
            elseif exports.gzl_ui:isMouseInPosition(contentX + contentW - btnW, varY + 20 * scale, btnW, 34 * scale) then
                charData.hairVariant = (charData.hairVariant or 1) < maxVars and (charData.hairVariant + 1) or 1
                charData.hair.variant = charData.hairVariant
                refreshStudioPed()
                return
            end

            local colorY = varY + 64 * scale
            if exports.gzl_ui:isMouseInPosition(contentX, colorY + 20 * scale, btnW, 34 * scale) then
                charData.hairColorIdx = charData.hairColorIdx > 1 and (charData.hairColorIdx - 1) or #CreatorConfig.HairColors
                charData.hair.color = CreatorConfig.HairColors[charData.hairColorIdx].color
                refreshStudioPed()
                return
            elseif exports.gzl_ui:isMouseInPosition(contentX + contentW - btnW, colorY + 20 * scale, btnW, 34 * scale) then
                charData.hairColorIdx = charData.hairColorIdx < #CreatorConfig.HairColors and (charData.hairColorIdx + 1) or 1
                charData.hair.color = CreatorConfig.HairColors[charData.hairColorIdx].color
                refreshStudioPed()
                return
            end

            local dotY = colorY + 64 * scale
            local dotGap = contentW / #CreatorConfig.HairColors
            for i = 1, #CreatorConfig.HairColors do
                local dotX = contentX + (i - 0.5) * dotGap
                if exports.gzl_ui:isMouseInPosition(dotX - 12 * scale, dotY - 12 * scale, 24 * scale, 24 * scale) then
                    charData.hairColorIdx = i
                    charData.hair.color = CreatorConfig.HairColors[i].color

                    if maxVars >= i then
                        charData.hairVariant = i
                        charData.hair.variant = i
                    end
                    refreshStudioPed()
                    return
                end
            end
        end

    elseif currentTab == "clothes" then
        local cfg = resolveCreatorConfig(charData)

        if exports.gzl_ui:isMouseInPosition(contentX, contentY + 20 * scale, btnW, 34 * scale) then
            charData.torso = charData.torso > 1 and (charData.torso - 1) or #cfg.torso
            charData.torsoVariant = 1
            refreshStudioPed()
            playPreviewAnim("clothes")
            return
        elseif exports.gzl_ui:isMouseInPosition(contentX + contentW - btnW, contentY + 20 * scale, btnW, 34 * scale) then
            charData.torso = charData.torso < #cfg.torso and (charData.torso + 1) or 1
            charData.torsoVariant = 1
            refreshStudioPed()
            playPreviewAnim("clothes")
            return
        end

        local tVarY = contentY + 60 * scale
        local torsoItem = cfg.torso[charData.torso] or cfg.torso[1]
        local tMaxVars = torsoItem.variants or 1
        if tMaxVars > 1 then
            if exports.gzl_ui:isMouseInPosition(contentX, tVarY + 20 * scale, btnW, 34 * scale) then
                charData.torsoVariant = charData.torsoVariant > 1 and (charData.torsoVariant - 1) or tMaxVars
                refreshStudioPed()
                playPreviewAnim("clothes")
                return
            elseif exports.gzl_ui:isMouseInPosition(contentX + contentW - btnW, tVarY + 20 * scale, btnW, 34 * scale) then
                charData.torsoVariant = charData.torsoVariant < tMaxVars and (charData.torsoVariant + 1) or 1
                refreshStudioPed()
                playPreviewAnim("clothes")
                return
            end
        end

        local legsY = tVarY + 60 * scale
        if exports.gzl_ui:isMouseInPosition(contentX, legsY + 20 * scale, btnW, 34 * scale) then
            charData.legs = charData.legs > 1 and (charData.legs - 1) or #cfg.legs
            charData.legsVariant = 1
            refreshStudioPed()
            playPreviewAnim("clothes")
            return
        elseif exports.gzl_ui:isMouseInPosition(contentX + contentW - btnW, legsY + 20 * scale, btnW, 34 * scale) then
            charData.legs = charData.legs < #cfg.legs and (charData.legs + 1) or 1
            charData.legsVariant = 1
            refreshStudioPed()
            playPreviewAnim("clothes")
            return
        end

        local lVarY = legsY + 60 * scale
        local legsItem = cfg.legs[charData.legs] or cfg.legs[1]
        local lMaxVars = legsItem.variants or 1
        if lMaxVars > 1 then
            if exports.gzl_ui:isMouseInPosition(contentX, lVarY + 20 * scale, btnW, 34 * scale) then
                charData.legsVariant = charData.legsVariant > 1 and (charData.legsVariant - 1) or lMaxVars
                refreshStudioPed()
                playPreviewAnim("clothes")
                return
            elseif exports.gzl_ui:isMouseInPosition(contentX + contentW - btnW, lVarY + 20 * scale, btnW, 34 * scale) then
                charData.legsVariant = charData.legsVariant < lMaxVars and (charData.legsVariant + 1) or 1
                refreshStudioPed()
                playPreviewAnim("clothes")
                return
            end
        end

        local shoesY = lVarY + 60 * scale
        if exports.gzl_ui:isMouseInPosition(contentX, shoesY + 20 * scale, btnW, 34 * scale) then
            charData.shoes = charData.shoes > 1 and (charData.shoes - 1) or #cfg.shoes
            charData.shoesVariant = 1
            refreshStudioPed()
            return
        elseif exports.gzl_ui:isMouseInPosition(contentX + contentW - btnW, shoesY + 20 * scale, btnW, 34 * scale) then
            charData.shoes = charData.shoes < #cfg.shoes and (charData.shoes + 1) or 1
            charData.shoesVariant = 1
            refreshStudioPed()
            return
        end

        local sVarY = shoesY + 60 * scale
        local shoesItem = cfg.shoes[charData.shoes] or cfg.shoes[1]
        local sMaxVars = shoesItem.variants or 1
        if sMaxVars > 1 then
            if exports.gzl_ui:isMouseInPosition(contentX, sVarY + 20 * scale, btnW, 34 * scale) then
                charData.shoesVariant = charData.shoesVariant > 1 and (charData.shoesVariant - 1) or sMaxVars
                refreshStudioPed()
                return
            elseif exports.gzl_ui:isMouseInPosition(contentX + contentW - btnW, sVarY + 20 * scale, btnW, 34 * scale) then
                charData.shoesVariant = charData.shoesVariant < sMaxVars and (charData.shoesVariant + 1) or 1
                refreshStudioPed()
                return
            end
        end

    elseif currentTab == "accessories" then
        local cfg = resolveCreatorConfig(charData)
        local categories = {
            { id = "all", name = "TÜMÜ" },
            { id = "head", name = "ŞAPKA" },
            { id = "face", name = "YÜZ" },
            { id = "body", name = "EKİPMAN" }
        }

        local catW = (contentW - 9 * scale) / #categories
        local catH = 28 * scale
        for i, cat in ipairs(categories) do
            local cx = contentX + (i - 1) * (catW + 3 * scale)
            if exports.gzl_ui:isMouseInPosition(cx, contentY, catW, catH) then
                if currentAccCategory ~= cat.id then
                    currentAccCategory = cat.id
                    accScrollOffset = 0
                end
                return
            end
        end

        local filtered = getFilteredAccessories(cfg, currentAccCategory)
        local listY = contentY + 36 * scale
        local itemH = 38 * scale
        local itemGap = 6 * scale
        local maxVisible = 7
        local maxScroll = math.max(0, #filtered - maxVisible)
        local cardW = contentW - (maxScroll > 0 and (8 * scale) or 0)

        local fromIdx = accScrollOffset + 1
        local toIdx = math.min(#filtered, accScrollOffset + maxVisible)

        for i = fromIdx, toIdx do
            local item = filtered[i]
            local relIdx = i - fromIdx
            local ay = listY + relIdx * (itemH + itemGap)
            if exports.gzl_ui:isMouseInPosition(contentX, ay, cardW, itemH) then
                local variants=cfg.accessories[item.key].variants or 1
                if variants>1 and exports.gzl_ui:isMouseInPosition(contentX+cardW-137*scale,ay,55*scale,itemH) then
                    charData.accessoryVariants=charData.accessoryVariants or {}
                    charData.accessoryVariants[item.key]=(charData.accessoryVariants[item.key] or 1)%variants+1
                    charData.accessories[item.key]=true
                else
                    charData.accessories[item.key] = not charData.accessories[item.key]
                end
                refreshStudioPed()
                return
            end
        end
    end

    local row1Y = py + ph - 88 * scale
    local row2Y = py + ph - 46 * scale

    if isIngame then

        if exports.gzl_ui:isMouseInPosition(contentX, row1Y, contentW, 36 * scale) and not isSubmitting then
            setCreatorVisible(false)
            return
        end

        if exports.gzl_ui:isMouseInPosition(contentX, row2Y, contentW, 40 * scale) and not isSubmitting then
            isSubmitting = true
            triggerServerEvent("gzl_creator:updateCharacter", localPlayer, charData)
            return
        end
    else

        local halfBtnW = (contentW - 8 * scale) / 2

        if exports.gzl_ui:isMouseInPosition(contentX, row1Y, halfBtnW, 34 * scale) and not isSubmitting then
            setCreatorVisible(false)
            triggerServerEvent("char:requestList", localPlayer)
            return
        end

        if exports.gzl_ui:isMouseInPosition(contentX + halfBtnW + 8 * scale, row1Y, halfBtnW, 34 * scale) and not isSubmitting then
            local cfg = resolveCreatorConfig(charData)
            charData.skinTone = math.random(1, #CreatorConfig.SkinTones)
            charData.hair.id = math.random(0, #cfg.hairs)
            local hairItem = cfg.hairs[charData.hair.id]
            local maxVars = (hairItem and hairItem.variants) or 1
            charData.hairVariant = math.random(1, math.max(1, maxVars))
            charData.hair.variant = charData.hairVariant
            charData.hairColorIdx = math.random(1, #CreatorConfig.HairColors)
            charData.hair.color = CreatorConfig.HairColors[charData.hairColorIdx].color
            charData.face.eyes = math.random(1, #CreatorConfig.EyeColors)
            charData.face.eyebrow = math.random(1, #CreatorConfig.Eyebrows)
            if charData.gender == "male" then
                charData.face.beard = math.random(0, #CreatorConfig.Male.beards)
            else
                charData.face.lipstick = math.random(0, #CreatorConfig.Female.lipsticks)
            end
            charData.torso = math.random(1, #cfg.torso)
            charData.torsoVariant = 1
            charData.legs = math.random(1, #cfg.legs)
            charData.legsVariant = 1
            charData.shoes = math.random(1, #cfg.shoes)
            charData.shoesVariant = 1
            refreshStudioPed()
            return
        end

        if exports.gzl_ui:isMouseInPosition(contentX, row2Y, contentW, 40 * scale) and not isSubmitting then
            local inputName = exports.gzl_ui:getEditBoxText("creator_char_name")
            if inputName and inputName ~= "" then
                charData.name = inputName
            end
            if not charData.name or string.len(charData.name) < 4 then
                if exports.gzl_ui and exports.gzl_ui.showNotification then
                    exports.gzl_ui:showNotification("HATA", "Lütfen geçerli bir Ad ve Soyad girin! (örn: Michael_Walker)", "error")
                end
                return
            end
            isSubmitting = true
            triggerServerEvent("gzl_creator:saveCharacter", localPlayer, charData)
            return
        end
    end
end

local function copyTable(t)
    if type(t) ~= "table" then return t end
    local res = {}
    for k, v in pairs(t) do
        res[k] = (type(v) == "table") and copyTable(v) or v
    end
    return res
end

local hudComponents = {"all", "radar", "area_name", "vehicle_name", "breath", "clock", "money", "health", "armour", "weapon", "ammo"}
local originalCustomization = nil
local originalModel = nil
local originalRot = nil
local wasSaved = false

function setCreatorVisible(visible)
    studioHistory,studioFuture,studioSnapshot,studioButtons={},{},nil,{}
    if isVisible == visible then return end
    isVisible = visible
    isSubmitting = false

    local isIngame = getElementData(localPlayer, "loggedin_character") and true or false

    if isVisible then
        wasSaved = false

        if loadCreatorModels then
            loadCreatorModels()
        end

        for _, comp in ipairs(hudComponents) do
            setPlayerHudComponentVisible(comp, false)
        end
        showChat(false)
        triggerServerEvent("gzl_creator:startSession", localPlayer)

        if isIngame then
            originalCustomization = copyTable(charData)
            originalModel = getElementModel(localPlayer)
            originalRot = getPedCurrentRotation() or select(3, getElementRotation(localPlayer))
            studioPed = localPlayer

            local skin = charData.gender == "female" and CreatorConfig.FemaleSkinID or CreatorConfig.MaleSkinID
            setElementModel(studioPed, skin)
            setPedAnimation(studioPed, "dealer", "dealer_idle", -1, true, false, false, false)
        else
            local studioCfg = CreatorConfig.Studio.ped
            local skin = charData.gender == "female" and CreatorConfig.FemaleSkinID or CreatorConfig.MaleSkinID

            if not isElement(studioPed) or studioPed == localPlayer then
                studioPed = createPed(skin, studioCfg.x, studioCfg.y, studioCfg.z, studioCfg.rot)
                if isElement(studioPed) then
                    setElementInterior(studioPed, 0)
                    setElementDimension(studioPed, 1337)
                    setElementFrozen(studioPed, true)
                    setTimer(function()
                        if isElement(studioPed) then
                            setPedAnimation(studioPed, "dealer", "dealer_idle", -1, true, false, false, false)
                        end
                    end, 80, 1)
                end
            else
                setElementModel(studioPed, skin)
                setElementPosition(studioPed, studioCfg.x, studioCfg.y, studioCfg.z)
                setElementInterior(studioPed, 0)
                setElementDimension(studioPed, 1337)
                setPedAnimation(studioPed, "dealer", "dealer_idle", -1, true, false, false, false)
            end
        end

        setStudioPed(studioPed)
        refreshStudioPed()
        setTimer(refreshStudioPed, 50, 1)
        setTimer(refreshStudioPed, 200, 1)
        startStudioCamera(studioPed)

        if isIngame then
            setCameraView("body", true)
        end

        addEventHandler("onClientRender", root, renderCreatorUI)
        addEventHandler("onClientClick", root, handleCreatorClick)
    else
        stopStudioCamera()
        -- Release the session before optional appearance cleanup can throw.
        removeEventHandler("onClientRender", root, renderCreatorUI)
        removeEventHandler("onClientClick", root, handleCreatorClick)
        triggerServerEvent("gzl_creator:cancelSession", localPlayer)
        if isElement(studioPed) then
            if studioPed ~= localPlayer then
                resetPedShaders(studioPed)
                destroyElement(studioPed)
            else

                setPedAnimation(studioPed, false)

                if not wasSaved then
                    if originalCustomization then
                        for k, v in pairs(originalCustomization) do
                            if type(v) == "table" then
                                charData[k] = copyTable(v)
                            else
                                charData[k] = v
                            end
                        end
                        applyCharacterCustomization(localPlayer, charData)
                    end
                    if originalModel then
                        setElementModel(localPlayer, originalModel)
                    end
                    if originalRot then
                        setElementRotation(localPlayer, 0, 0, originalRot)
                    end
                end
            end
            studioPed = nil
        end

        if isIngame then
            setPlayerHudComponentVisible("all", false)
            setPlayerHudComponentVisible("crosshair", true)
            showChat(true)
        end

    end
end

addEvent("gzl_creator:saveResponse", true)
addEventHandler("gzl_creator:saveResponse", root, function(success, message)
    isSubmitting = false
    if success then
        wasSaved = true
        setCreatorVisible(false)
    end
    if exports.gzl_ui and exports.gzl_ui.showNotification then
        exports.gzl_ui:showNotification(success and "BAŞARILI" or "HATA", message, success and "success" or "error")
    end
end)

addEventHandler("onClientKey", root, function(button, press)
    if not press or not isVisible then return end
    local isIngame = getElementData(localPlayer, "loggedin_character") and true or false

    if button == "escape" and not isSubmitting then
        setCreatorVisible(false)
        if not isIngame then
            triggerServerEvent("char:requestList", localPlayer)
        end
        cancelEvent()
    elseif button == "enter" and not isSubmitting and currentTab == "identity" and not isIngame then
        local inputName = exports.gzl_ui:getEditBoxText("creator_char_name")
        if inputName and inputName ~= "" then
            charData.name = inputName
        end
        if not charData.name or string.len(charData.name) < 4 then
            if exports.gzl_ui and exports.gzl_ui.showNotification then
                exports.gzl_ui:showNotification("HATA", "Lütfen geçerli bir Ad ve Soyad girin! (örn: Michael_Walker)", "error")
            end
            return
        end
        isSubmitting = true
        triggerServerEvent("gzl_creator:saveCharacter", localPlayer, charData)
        cancelEvent()
    elseif button == "mouse_wheel_up" and currentTab == "accessories" then
        if accScrollOffset > 0 then
            accScrollOffset = accScrollOffset - 1
            cancelEvent()
        end
    elseif button == "mouse_wheel_down" and currentTab == "accessories" then
        local cfg = resolveCreatorConfig(charData)
        local filtered = getFilteredAccessories(cfg, currentAccCategory)
        local maxVisible = 7
        local maxScroll = math.max(0, #filtered - maxVisible)
        if accScrollOffset < maxScroll then
            accScrollOffset = accScrollOffset + 1
            cancelEvent()
        end
    end
end)

addEvent("gzl_creator:openSkinMenu", true)
addEventHandler("gzl_creator:openSkinMenu", root, function()
    local existingData = getElementData(localPlayer, "char:customization")
    if type(existingData) == "table" then
        if existingData[1] and type(existingData[1]) == "table" then
            existingData = existingData[1]
        end
        for k, v in pairs(existingData) do
            if type(v) == "table" then
                charData[k] = copyTable(v)
            else
                charData[k] = v
            end
        end
    end
    local cName = getElementData(localPlayer, "char:name") or getElementData(localPlayer, "character:name")
    if cName and cName ~= "" then
        charData.name = cName
    end
    local cAge = getElementData(localPlayer, "character:age")
    if cAge then
        charData.age = tonumber(cAge) or charData.age
    end
    local cGender = getElementData(localPlayer, "character:gender")
    if cGender then
        charData.gender = (tonumber(cGender) == 2) and "female" or "male"
    end

    if type(charData.face) ~= "table" then
        charData.face = { eyes = 1, eyebrow = 1, beard = 1, lipstick = 0 }
    else
        charData.face.eyes = tonumber(charData.face.eyes) or 1
        charData.face.eyebrow = tonumber(charData.face.eyebrow) or 1
        charData.face.beard = tonumber(charData.face.beard) or 0
        charData.face.lipstick = tonumber(charData.face.lipstick) or 0
    end

    charData.hair = charData.hair or { id = 1, variant = 1 }
    charData.hairVariant = charData.hairVariant or charData.hair.variant or 1
    charData.accessories = charData.accessories or {}

    currentTab = "clothes"
    currentAccCategory = "all"
    accScrollOffset = 0
    setCreatorVisible(true)
end)

addCommandHandler("creator", function()
    setCreatorVisible(not isVisible)
end)

addEvent("gzl_creator:open", true)
addEventHandler("gzl_creator:open", root, function()
    currentTab = "identity"
    currentAccCategory = "all"
    accScrollOffset = 0
    setCreatorVisible(true)
end)

addEvent("gzl_creator:clientRecover", true)
addEventHandler("gzl_creator:clientRecover", root, function()
    if isVisible then
        setCreatorVisible(false)
    end
    stopStudioCamera()
    setCameraTarget(localPlayer)
    showChat(true)
    setPlayerHudComponentVisible("all", false)
    setPlayerHudComponentVisible("crosshair", true)
    local cdata = getElementData(localPlayer, "char:customization")
    if cdata then
        resetPedShaders(localPlayer)
        applyCharacterCustomization(localPlayer, cdata)
    end
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    if getElementData(localPlayer, "loggedin_character") then
        setCameraTarget(localPlayer)
        showChat(true)
        setPlayerHudComponentVisible("all", false)
        setPlayerHudComponentVisible("crosshair", true)
    end
end)
