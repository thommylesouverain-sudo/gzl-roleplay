
addEvent("gzl_creator:startSession", true)
addEventHandler("gzl_creator:startSession", root, function()
    local player = client or source
    if not isElement(player) then return end

    if getElementData(player, "loggedin_character") then

        setElementFrozen(player, true)
    else

        setElementDimension(player, 1337)
        setElementAlpha(player, 0)
        setElementFrozen(player, true)
    end
end)

addEvent("gzl_creator:cancelSession", true)
addEventHandler("gzl_creator:cancelSession", root, function()
    local player = client or source
    if not isElement(player) then return end
    if not getElementData(player, "loggedin_character") then
        setElementDimension(player, 0)
        setElementAlpha(player, 0)
        setElementFrozen(player, true)
    else
        setElementFrozen(player, false)
    end
end)

addEventHandler("onResourceStart", resourceRoot, function()
    for _, p in ipairs(getElementsByType("player")) do
        if getElementDimension(p) == 1337 then
            setElementDimension(p, 0)
        end
        if getElementData(p, "loggedin_character") then
            setElementAlpha(p, 255)
            setElementFrozen(p, false)
        end
    end
end)

addCommandHandler("fixkarakter", function(player)
    if not isElement(player) then return end
    setElementDimension(player, 0)
    setElementInterior(player, 0)
    setElementAlpha(player, 255)
    setElementFrozen(player, false)

    local charId = getElementData(player, "character:id") or getElementData(player, "char:id")
    local db = exports.gzl_characters and exports.gzl_characters:getCharacterDB()
    if db and charId then
        dbQuery(function(qh)
            local res = dbPoll(qh, 0)
            if res and res[1] then
                local skinId = tonumber(res[1].skin) or CreatorConfig.MaleSkinID
                setElementModel(player, skinId)
                if res[1].customization and res[1].customization ~= "" and res[1].customization ~= "{}" then
                    local cdata = fromJSON(res[1].customization)
                    if cdata then
                        setElementData(player, "char:customization", cdata, true)
                    end
                end
            end
            triggerClientEvent(player, "gzl_creator:clientRecover", player)
        end, db, "SELECT skin, customization FROM characters WHERE id = ?", charId)
    else
        local skinId = getElementData(player, "character:skin") or CreatorConfig.MaleSkinID
        setElementModel(player, skinId)
        triggerClientEvent(player, "gzl_creator:clientRecover", player)
    end
    outputChatBox("#34d399[GZL]#ffffff Karakter durumunuz ve kıyafetleriniz başarıyla sıfırlandı!", player, 255, 255, 255, true)
end)

addEvent("gzl_creator:saveCharacter", true)
addEventHandler("gzl_creator:saveCharacter", root, function(charData)
    local player = client or source
    if not isElement(player) or type(charData) ~= "table" then return end

    local gender = (charData.gender == "female") and 2 or 1
    local skinId = (gender == 2) and CreatorConfig.FemaleSkinID or CreatorConfig.MaleSkinID
    local age = tonumber(charData.age) or 24

    triggerEvent("char:create", player, charData.name, gender, age, skinId, charData)
end)

addEvent("gzl_creator:updateCharacter", true)
addEventHandler("gzl_creator:updateCharacter", root, function(charData)
    local player = client or source
    if not isElement(player) or type(charData) ~= "table" then return end

    local charId = getElementData(player, "character:id") or getElementData(player, "char:id")
    if not charId or not getElementData(player, "loggedin_character") then return end

    local gender = (charData.gender == "female") and 2 or 1
    local skinId = (gender == 2) and CreatorConfig.FemaleSkinID or CreatorConfig.MaleSkinID
    local customJson = toJSON(charData)

    local db = exports.gzl_characters and exports.gzl_characters:getCharacterDB()
    if db then
        dbExec(db, "UPDATE characters SET customization = ?, skin = ?, gender = ? WHERE id = ?", customJson, skinId, gender, charId)
    end

    setElementModel(player, skinId)
    setElementData(player, "character:skin", skinId)
    setElementData(player, "character:gender", gender)
    setElementData(player, "char:customization", charData, true)
    setElementFrozen(player, false)

    triggerClientEvent(player, "gzl_creator:saveResponse", player, true, "Kıyafetleriniz başarıyla güncellendi!")
    outputChatBox("#38bdf8[GZL]#ffffff Kıyafetleriniz ve görünümünüz başarıyla güncellendi.", player, 255, 255, 255, true)
end)

local function isPlayerAdmin(player)
    if not isElement(player) then return false end

    local adminLevel = tonumber(getElementData(player, "character:admin") or getElementData(player, "admin_level") or getElementData(player, "admin"))
    if adminLevel and adminLevel > 0 then return true end

    local acc = getPlayerAccount(player)
    if acc and not isGuestAccount(acc) then
        local accName = getAccountName(acc)
        local adminGroup = aclGetGroup("Admin")
        if adminGroup and isObjectInACLGroup("user." .. accName, adminGroup) then
            return true
        end
        local superAdminGroup = aclGetGroup("SuperAdmin")
        if superAdminGroup and isObjectInACLGroup("user." .. accName, superAdminGroup) then
            return true
        end
    end

    return hasObjectPermissionTo(player, "command.kick", false)
end

local function findTargetPlayer(query)
    if not query or query == "" then return nil end
    local numId = tonumber(query)

    if numId then
        for _, p in ipairs(getElementsByType("player")) do
            local pCharId = tonumber(getElementData(p, "character:id") or getElementData(p, "char:id") or getElementData(p, "playerid"))
            if pCharId == numId then
                return p
            end
        end
    end

    local qLower = string.lower(query)
    for _, p in ipairs(getElementsByType("player")) do
        local pName = string.lower(getPlayerName(p))
        local cName = string.lower(tostring(getElementData(p, "char:name") or getElementData(p, "character:name") or ""))
        if string.find(pName, qLower, 1, true) or string.find(cName, qLower, 1, true) then
            return p
        end
    end

    if numId then
        local all = getElementsByType("player")
        if all[numId] then
            return all[numId]
        end
    end

    return nil
end

addCommandHandler("skinmenu", function(player)
    if not isElement(player) then return end
    if not isPlayerAdmin(player) then
        outputChatBox("#ef4444[HATA]#ffffff Bu komutu kullanmak için yetkiniz bulunmamaktadır.", player, 255, 255, 255, true)
        return
    end

    if not getElementData(player, "loggedin_character") then
        outputChatBox("#ef4444[HATA]#ffffff Önce bir karaktere giriş yapmalısınız.", player, 255, 255, 255, true)
        return
    end

    if isPedInVehicle(player) then
        outputChatBox("#ef4444[HATA]#ffffff Araçtayken kıyafet menüsünü açamazsınız! Lütfen araçtan inin.", player, 255, 255, 255, true)
        return
    end

    triggerClientEvent(player, "gzl_creator:openSkinMenu", player)
    outputChatBox("#38bdf8[GZL-ADMIN]#ffffff Kıyafet ve görünüm menüsü açıldı.", player, 255, 255, 255, true)
end)

addCommandHandler("giveskinmenu", function(player, cmd, targetQuery)
    if not isElement(player) then return end
    if not isPlayerAdmin(player) then
        outputChatBox("#ef4444[HATA]#ffffff Bu komutu kullanmak için yetkiniz bulunmamaktadır.", player, 255, 255, 255, true)
        return
    end

    if not targetQuery or targetQuery == "" then
        outputChatBox("#38bdf8[KULLANIM]#ffffff /giveskinmenu [Oyuncu ID / İsim]", player, 255, 255, 255, true)
        return
    end

    local target = findTargetPlayer(targetQuery)
    if not target or not isElement(target) then
        outputChatBox("#ef4444[HATA]#ffffff Belirtilen oyuncu bulunamadı!", player, 255, 255, 255, true)
        return
    end

    if not getElementData(target, "loggedin_character") then
        outputChatBox("#ef4444[HATA]#ffffff Bu oyuncu henüz bir karaktere giriş yapmamış!", player, 255, 255, 255, true)
        return
    end

    if isPedInVehicle(target) then
        outputChatBox("#ef4444[HATA]#ffffff Belirtilen oyuncu araçta! Menünün açılması için araçtan inmesi gerekiyor.", player, 255, 255, 255, true)
        return
    end

    local targetName = tostring(getElementData(target, "char:name") or getPlayerName(target)):gsub("_", " ")
    local adminName = tostring(getElementData(player, "char:name") or getPlayerName(player)):gsub("_", " ")

    triggerClientEvent(target, "gzl_creator:openSkinMenu", target)
    outputChatBox("#38bdf8[GZL-ADMIN]#ffffff " .. targetName .. " adlı oyuncuya kıyafet menüsü açıldı.", player, 255, 255, 255, true)
    outputChatBox("#38bdf8[GZL]#ffffff Yetkili (" .. adminName .. ") size kıyafet / görünüm menüsü verdi.", target, 255, 255, 255, true)
end)

addCommandHandler("karakter", function(player)
    triggerClientEvent(player, "gzl_creator:open", player)
end)