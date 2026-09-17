local authoritativeCharacters = {}

function getAuthoritativeCharacterID(player)
    if not isElement(player) then return nil end
    local data = authoritativeCharacters[player]
    return data and data.id or nil
end

function isPlayerCharacterLoggedIn(player)
    if not isElement(player) then return false end
    return authoritativeCharacters[player] ~= nil
end

local function sendCharacterResponse(player, success, message)
    if isElement(player) then
        triggerClientEvent(player, "char:response", player, success, message)
        triggerClientEvent(player, "gzl_creator:saveResponse", player, success, message)
    end
end

local function sendCharacterList(player, accountId)
    local db = getCharacterDB()
    if not db or not accountId then return end

    dbQuery(function(qh)
        local result = dbPoll(qh, 0)
        if isElement(player) and getElementData(player, "account:id") == accountId
            and not getElementData(player, "loggedin_character") then
            triggerClientEvent(player, "char:receiveList", player, result or {})
        end
    end, db, "SELECT * FROM characters WHERE account_id = ? ORDER BY id ASC", accountId)
end

local function formatCharacterName(input)
    if not input then return nil end
    input = tostring(input):gsub("[%s_]+", "_")
    input = input:match("^_*([^_].*[^_])_*$") or input
    local parts = {}
    for part in string.gmatch(input, "[^_]+") do
        if string.len(part) >= 2 then
            local formatted = string.upper(string.sub(part, 1, 1)) .. string.lower(string.sub(part, 2))
            table.insert(parts, formatted)
        end
    end
    if #parts >= 2 then
        return table.concat(parts, "_")
    end
    return nil
end

addEvent("char:requestList", true)
addEventHandler("char:requestList", root, function()
    local player = client or source
    if not isElement(player) then return end
    local accountId = getElementData(player, "account:id")
    if not accountId then return end

    sendCharacterList(player, accountId)
end)

addEvent("char:requestListForPlayer", false)
addEventHandler("char:requestListForPlayer", root, function(accountId)
    local player = source
    if isElement(player) and accountId then
        sendCharacterList(player, accountId)
    end
end)

addEventHandler("onPlayerResourceStart", root, function(res)
    if res == getThisResource() then
        local accountId = getElementData(source, "account:id")
        if accountId and not getElementData(source, "loggedin_character") then
            sendCharacterList(source, accountId)
        end
    end
end)

addEvent("char:logout", true)
addEventHandler("char:logout", root, function()
    local player = client or source
    if not isElement(player) then return end
    if getElementData(player, "loggedin_character") then
        saveCharacter(player)
    end
    if exports.gzl_inventory and exports.gzl_inventory.unloadPlayerInventory then
        exports.gzl_inventory:unloadPlayerInventory(player)
    end
    authoritativeCharacters[player] = nil
    setElementData(player, "loggedin_character", nil, "broadcast", "deny")
    setElementData(player, "character:id", nil, "broadcast", "deny")
    setElementData(player, "char:id", nil, "broadcast", "deny")
    setElementData(player, "account:id", nil, "broadcast", "deny")
    setElementData(player, "account:username", nil, "broadcast", "deny")
    setElementData(player, "loggedin", false, "broadcast", "deny")
    setElementFrozen(player, true)
    triggerClientEvent(player, "auth:showLoginScreen", player)
end)

addEvent("char:create", true)
addEventHandler("char:create", root, function(rawName, gender, age, skin, customization)
    local player = client or source
    if not isElement(player) then return end

    local accountId = getElementData(player, "account:id")
    if not accountId then
        sendCharacterResponse(player, false, "Oturum bilgisi bulunamadı!")
        return
    end

    local name = formatCharacterName(rawName)
    if not name or string.len(name) < 4 or string.len(name) > 26 then
        sendCharacterResponse(player, false, "Lütfen geçerli bir Ad ve Soyad girin! (örn. Thommy Souverain)")
        return
    end

    gender = tonumber(gender) or 1
    age = tonumber(age) or 24
    skin = tonumber(skin) or (gender == 1 and 0 or 9)

    if age < CharConfig.MinAge or age > CharConfig.MaxAge then
        sendCharacterResponse(player, false, "Yaş " .. CharConfig.MinAge .. " ile " .. CharConfig.MaxAge .. " arasında olmalıdır!")
        return
    end

    local validSkin = false
    local skinList = (gender == 1) and CharConfig.MaleSkins or CharConfig.FemaleSkins
    for _, s in ipairs(skinList) do
        if s == skin then
            validSkin = true
            break
        end
    end

    if not validSkin then
        skin = (gender == 1) and CharConfig.MaleSkins[1] or CharConfig.FemaleSkins[1]
    end

    local db = getCharacterDB()
    if not db then
        sendCharacterResponse(player, false, "Veritabanına bağlanılamadı!")
        return
    end

    dbQuery(function(countQh)
        local countRes = dbPoll(countQh, 0)
        if not countRes then
            sendCharacterResponse(player, false, "Veritabanı hatası oluştu!")
            return
        end
        if #countRes >= CharConfig.MaxCharactersPerAccount then
            sendCharacterResponse(player, false, "Maksimum karakter sınırına ulaştınız (" .. CharConfig.MaxCharactersPerAccount .. ")!")
            return
        end

        dbQuery(function(nameQh)
            local nameRes = dbPoll(nameQh, 0)
            if not nameRes then
                sendCharacterResponse(player, false, "Veritabanı hatası oluştu!")
                return
            end
            if #nameRes > 0 then
                sendCharacterResponse(player, false, "Bu karakter adı zaten kullanılmaktadır!")
                return
            end

            local spawn = CharConfig.DefaultSpawn
            local isCustom = type(customization) == "table"
            local customJson = isCustom and toJSON(customization) or "{}"
            if isCustom then
                skin = (gender == 2 or customization.gender == "female") and 171 or 170
            end

            local q = [[
                INSERT INTO characters 
                (account_id, name, gender, age, skin, money, bank_money, pos_x, pos_y, pos_z, rot_z, interior, dimension, customization)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ]]

            dbExec(db, q, accountId, name, gender, age, skin, CharConfig.DefaultCash, CharConfig.DefaultBank, spawn.x, spawn.y, spawn.z, spawn.rot, spawn.interior, spawn.dimension, customJson)

            if isCustom then
                dbQuery(function(insertQh)
                    local insertedRows = dbPoll(insertQh, 0)
                    if insertedRows and #insertedRows > 0 then
                        local newChar = insertedRows[1]
                        if not isElement(player) then return end
                        if getElementData(player, "account:id") ~= accountId then return end
                        if not spawnPlayer(player, spawn.x, spawn.y, spawn.z, spawn.rot, skin, spawn.interior, spawn.dimension) then
                            sendCharacterResponse(player, false, "Karakter kaydedildi ancak oyun dünyasına yerleştirilemedi. Lütfen tekrar seçin.")
                            sendCharacterList(player, accountId)
                            return
                        end

                        setElementData(player, "character:id", newChar.id, "broadcast", "deny")
                        setElementData(player, "character:name", newChar.name)
                        setElementData(player, "character:gender", tonumber(newChar.gender) or 1)
                        setElementData(player, "character:age", tonumber(newChar.age) or 24)
                        setElementData(player, "character:money", tonumber(newChar.money) or CharConfig.DefaultCash, "broadcast", "deny")
                        setElementData(player, "character:bank", tonumber(newChar.bank_money) or CharConfig.DefaultBank, "broadcast", "deny")
                        setElementData(player, "character:skin", tonumber(newChar.skin) or skin)
                        setElementData(player, "character:hunger", 100)
                        setElementData(player, "character:thirst", 100)

                        setElementData(player, "char:id", newChar.id, "broadcast", "deny")
                        setElementData(player, "char:name", newChar.name)
                        setElementData(player, "char:money", tonumber(newChar.money) or CharConfig.DefaultCash, "broadcast", "deny")
                        setElementData(player, "char:bank_money", tonumber(newChar.bank_money) or CharConfig.DefaultBank)
                        setElementData(player, "char:bank", tonumber(newChar.bank_money) or CharConfig.DefaultBank, "broadcast", "deny")
                        setElementData(player, "char:hunger", 100)
                        setElementData(player, "char:thirst", 100)
                        setElementData(player, "char:customization", customization, true)
                        setElementData(player, "loggedin_character", true, "broadcast", "deny")

                        setPlayerMoney(player, tonumber(newChar.money) or CharConfig.DefaultCash)

                        setElementDimension(player, spawn.dimension)
                        setElementInterior(player, spawn.interior)
                        setElementAlpha(player, 255)
                        setElementFrozen(player, false)
                        setElementHealth(player, 100)
                        setPedArmor(player, 0)
                        setCameraTarget(player, player)
                        setCameraInterior(player, spawn.interior)
                        fadeCamera(player, true, 1.5)

                        authoritativeCharacters[player] = { id = newChar.id, name = newChar.name, accountId = accountId }
                        triggerClientEvent(player, "char:spawnSuccess", player, newChar)
                        triggerEvent("char:spawnSuccess", player, newChar)
                        triggerClientEvent(player, "gzl_creator:saveResponse", player, true, "Karakteriniz başarıyla oluşturuldu!")
                    else
                        sendCharacterResponse(player, false, "Karakter veritabanına kaydedilemedi!")
                        sendCharacterList(player, accountId)
                    end
                end, db, "SELECT * FROM characters WHERE id = last_insert_rowid()")
            else
                sendCharacterResponse(player, true, "Karakter başarıyla oluşturuldu!")
                sendCharacterList(player, accountId)
            end
        end, db, "SELECT id FROM characters WHERE LOWER(name) = LOWER(?)", name)

    end, db, "SELECT id FROM characters WHERE account_id = ?", accountId)
end)

addEvent("char:select", true)
addEventHandler("char:select", root, function(characterId)
    local player = client or source
    if not isElement(player) then return end

    if getElementData(player, "loggedin_character") then
        saveCharacter(player)
    end

    local accountId = getElementData(player, "account:id")
    characterId = tonumber(characterId)
    if not accountId or not characterId then return end

    local db = getCharacterDB()
    if not db then return end

    dbQuery(function(qh)
        local result = dbPoll(qh, 0)
        if result and #result > 0 then
            local row = result[1]
            if not isElement(player) then return end
            if getElementData(player, "account:id") ~= accountId then return end

            local customData = nil
            if row.customization and row.customization ~= "" and row.customization ~= "{}" then
                customData = fromJSON(row.customization)
                if type(customData) == "table" and customData[1] and type(customData[1]) == "table" then
                    customData = customData[1]
                end
            end

            local px = tonumber(row.pos_x) or CharConfig.DefaultSpawn.x
            local py = tonumber(row.pos_y) or CharConfig.DefaultSpawn.y
            local pz = tonumber(row.pos_z) or CharConfig.DefaultSpawn.z
            local prot = tonumber(row.rot_z) or CharConfig.DefaultSpawn.rot
            local pskin = tonumber(row.skin) or 0
            if type(customData) == "table" then
                pskin = (customData.gender == "female") and 171 or 170
            end
            local pint = tonumber(row.interior) or 0
            local pdim = tonumber(row.dimension) or 0
            if pdim == 1337 or pdim >= 60000 then pdim = 0 end

            -- Never publish a logged-in character or open its HUD after a failed spawn.
            if not spawnPlayer(player, px, py, pz, prot, pskin, pint, pdim) then
                outputDebugString("[GZL Characters] Spawn failed for character " .. tostring(row.id), 1)
                sendCharacterResponse(player, false, "Karakter oyun dünyasına yerleştirilemedi. Lütfen yetkiliye bildirin.")
                return
            end

            if type(customData) == "table" then
                setElementData(player, "char:customization", customData, true)
            else
                setElementData(player, "char:customization", nil, true)
            end

            setElementData(player, "character:id", row.id, "broadcast", "deny")
            setElementData(player, "character:name", row.name)
            setElementData(player, "character:gender", tonumber(row.gender) or 1)
            setElementData(player, "character:age", tonumber(row.age) or 24)
            setElementData(player, "character:money", tonumber(row.money) or 0, "broadcast", "deny")
            setElementData(player, "character:bank", tonumber(row.bank_money) or 0, "broadcast", "deny")
            setElementData(player, "character:skin", tonumber(row.skin) or 0)
            setElementData(player, "character:hunger", tonumber(row.hunger) or 100)
            setElementData(player, "character:thirst", tonumber(row.thirst) or 100)

            setElementData(player, "char:id", row.id, "broadcast", "deny")
            setElementData(player, "char:name", row.name)
            setElementData(player, "char:money", tonumber(row.money) or 0, "broadcast", "deny")
            setElementData(player, "char:bank_money", tonumber(row.bank_money) or 0)
            setElementData(player, "char:bank", tonumber(row.bank_money) or 0, "broadcast", "deny")
            setElementData(player, "char:hunger", tonumber(row.hunger) or 100)
            setElementData(player, "char:thirst", tonumber(row.thirst) or 100)
            setElementData(player, "loggedin_character", true, "broadcast", "deny")

            setPlayerMoney(player, tonumber(row.money) or 0)

            dbExec(db, "UPDATE characters SET last_active = CURRENT_TIMESTAMP WHERE id = ?", row.id)

            setElementDimension(player, pdim)
            setElementInterior(player, pint)
            setElementAlpha(player, 255)
            setPedArmor(player, tonumber(row.armor) or 0)
            setCameraTarget(player, player)
            setCameraInterior(player, pint)
            fadeCamera(player, true, 1.5)

            local isDead = tonumber(row.is_dead) or 0
            local deathRemaining = tonumber(row.death_time_remaining) or 0

            if isDead == 1 then
                setElementHealth(player, 100)
                setElementFrozen(player, true)
                setElementData(player, "character:is_dead", 1)
                setElementData(player, "ems:isDead", true, true)
                setElementData(player, "character:death_time_remaining", deathRemaining)

                setTimer(function()
                    if isElement(player) then
                        local remSec = (deathRemaining and deathRemaining >= 0) and deathRemaining or 120
                        if exports.gzl_ems and exports.gzl_ems.restorePlayerComa then
                            exports.gzl_ems:restorePlayerComa(player, remSec)
                        else
                            setElementFrozen(player, true)
                            setPedAnimation(player, "CRACK", "crckdeth2", -1, true, false, false, true)
                            triggerClientEvent(player, "gzl_ems:onClientEnterComa", player, remSec)
                        end
                        outputChatBox("#ef4444[DURUM]#ffffff Önceki oturumda ağır yaralı/koma durumundayken ayrıldığınız tespit edildi! Koma haliniz devam ediyor.", player, 255, 255, 255, true)
                    end
                end, 400, 1)
            else
                setElementFrozen(player, false)
                setElementHealth(player, math.max(20, tonumber(row.health) or 100))
                setElementData(player, "character:is_dead", 0)
                setElementData(player, "ems:isDead", false, true)
            end

            authoritativeCharacters[player] = { id = row.id, name = row.name, accountId = accountId }
            triggerClientEvent(player, "char:spawnSuccess", player, row)
            triggerEvent("char:spawnSuccess", player, row)
        else
            sendCharacterResponse(player, false, "Karakter verisi bulunamadı!")
        end
    end, db, "SELECT * FROM characters WHERE id = ? AND account_id = ?", characterId, accountId)
end)

function saveCharacter(player)
    if not isElement(player) then return false end
    local charId = getElementData(player, "character:id") or getElementData(player, "char:id")
    if not charId or not getElementData(player, "loggedin_character") then return false end

    local x, y, z = getElementPosition(player)
    local _, _, rot = getElementRotation(player)
    local interior = getElementInterior(player)
    local dimension = getElementDimension(player)
    if dimension == 1337 then dimension = 0 end
    local health = getElementHealth(player)
    local armor = getPedArmor(player)
    local money = tonumber(getElementData(player, "character:money") or getElementData(player, "char:money") or getPlayerMoney(player)) or 0
    local bank = tonumber(getElementData(player, "character:bank") or getElementData(player, "char:bank_money") or getElementData(player, "char:bank")) or 0
    local hunger = tonumber(getElementData(player, "character:hunger") or getElementData(player, "char:hunger")) or 100
    local thirst = tonumber(getElementData(player, "character:thirst") or getElementData(player, "char:thirst")) or 100

    local isDead = (getElementData(player, "ems:isDead") == true or getElementData(player, "character:is_dead") == 1 or isPedDead(player)) and 1 or 0
    local deathRemaining = 0
    if isDead == 1 then
        local foundRem = false
        pcall(function()
            if exports.gzl_ems and exports.gzl_ems.getRemainingDeathTime then
                local rem = exports.gzl_ems:getRemainingDeathTime(player)
                if tonumber(rem) ~= nil then
                    deathRemaining = math.max(0, math.floor(tonumber(rem)))
                    foundRem = true
                end
            end
        end)
        if not foundRem then
            local deathTick = getElementData(player, "ems:deathTick")
            if deathTick then
                local elapsed = (getTickCount() - deathTick) / 1000
                deathRemaining = math.max(0, math.floor(180 - elapsed))
            else
                local storedRem = tonumber(getElementData(player, "character:death_time_remaining"))
                deathRemaining = storedRem or 120
            end
        end
    end

    local customData = getElementData(player, "window_cleaning:origCustom") or getElementData(player, "char:customization")
    local customJson = (type(customData) == "table") and toJSON(customData) or nil

    local db = getCharacterDB()
    if db then
        if customJson then
            local q = [[
                UPDATE characters
                SET pos_x = ?, pos_y = ?, pos_z = ?, rot_z = ?,
                    interior = ?, dimension = ?, health = ?, armor = ?,
                    money = ?, bank_money = ?, hunger = ?, thirst = ?,
                    customization = ?, is_dead = ?, death_time_remaining = ?,
                    last_active = CURRENT_TIMESTAMP
                WHERE id = ?
            ]]
            dbExec(db, q, x, y, z, rot, interior, dimension, health, armor, money, bank, hunger, thirst, customJson, isDead, deathRemaining, charId)
        else
            local q = [[
                UPDATE characters
                SET pos_x = ?, pos_y = ?, pos_z = ?, rot_z = ?,
                    interior = ?, dimension = ?, health = ?, armor = ?,
                    money = ?, bank_money = ?, hunger = ?, thirst = ?,
                    is_dead = ?, death_time_remaining = ?,
                    last_active = CURRENT_TIMESTAMP
                WHERE id = ?
            ]]
            dbExec(db, q, x, y, z, rot, interior, dimension, health, armor, money, bank, hunger, thirst, isDead, deathRemaining, charId)
        end
        return true
    end
    return false
end

function saveAllCharacters()
    for _, player in ipairs(getElementsByType("player")) do
        if getElementData(player, "loggedin_character") then
            saveCharacter(player)
        end
    end
end

function getPlayerCash(player)
    if not isElement(player) then return 0 end
    return tonumber(getElementData(player, "character:money") or getElementData(player, "char:money") or getPlayerMoney(player)) or 0
end

function setPlayerCash(player, amount)
    if not isElement(player) then return false end
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    setElementData(player, "character:money", amount, "broadcast", "deny")
    setElementData(player, "char:money", amount, "broadcast", "deny")
    setPlayerMoney(player, amount)
    saveCharacter(player)
    return true
end

function givePlayerCash(player, amount)
    if not isElement(player) then return false end
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false end
    local cur = getPlayerCash(player)
    local ok = setPlayerCash(player, cur + amount)
    if ok and exports.gzl_logs and exports.gzl_logs.logMoney then
        pcall(function() exports.gzl_logs:logMoney("SYSTEM", player, amount, "give_cash", "Nakit para verildi") end)
    end
    return ok
end

function takePlayerCash(player, amount)
    if not isElement(player) then return false end
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false end
    local cur = getPlayerCash(player)
    if cur < amount then return false end
    local ok = setPlayerCash(player, cur - amount)
    if ok and exports.gzl_logs and exports.gzl_logs.logMoney then
        pcall(function() exports.gzl_logs:logMoney(player, "SYSTEM", amount, "take_cash", "Nakit para alındı") end)
    end
    return ok
end

function getPlayerBank(player)
    if not isElement(player) then return 0 end
    return tonumber(getElementData(player, "character:bank") or getElementData(player, "char:bank_money") or getElementData(player, "char:bank")) or 0
end

function setPlayerBank(player, amount)
    if not isElement(player) then return false end
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    setElementData(player, "character:bank", amount, "broadcast", "deny")
    setElementData(player, "char:bank_money", amount)
    setElementData(player, "char:bank", amount, "broadcast", "deny")
    saveCharacter(player)
    return true
end

function givePlayerBank(player, amount)
    if not isElement(player) then return false end
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false end
    local cur = getPlayerBank(player)
    local ok = setPlayerBank(player, cur + amount)
    if ok and exports.gzl_logs and exports.gzl_logs.logMoney then
        pcall(function() exports.gzl_logs:logMoney("BANK_SYSTEM", player, amount, "give_bank", "Banka hesabı para girişi") end)
    end
    return ok
end

function takePlayerBank(player, amount)
    if not isElement(player) then return false end
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false end
    local cur = getPlayerBank(player)
    if cur < amount then return false end
    local ok = setPlayerBank(player, cur - amount)
    if ok and exports.gzl_logs and exports.gzl_logs.logMoney then
        pcall(function() exports.gzl_logs:logMoney(player, "BANK_SYSTEM", amount, "take_bank", "Banka hesabı para çıkışı") end)
    end
    return ok
end

addEventHandler("onPlayerQuit", root, function()
    local isComa = (getElementData(source, "ems:isDead") == true or getElementData(source, "character:is_dead") == 1 or isPedDead(source))
    if isComa then
        setElementData(source, "character:is_dead", 1)
    end
    saveCharacter(source)
    authoritativeCharacters[source] = nil
end)

addEventHandler("onResourceStart", resourceRoot, function()
    for _, player in ipairs(getElementsByType("player")) do
        if getElementData(player, "loggedin_character") then
            local cid = tonumber(getElementData(player, "character:id") or getElementData(player, "char:id"))
            if cid then
                authoritativeCharacters[player] = {
                    id = cid,
                    name = getElementData(player, "character:name") or getElementData(player, "char:name"),
                    accountId = getElementData(player, "account:id")
                }
            end
        end
    end
end)

addEventHandler("onResourceStop", resourceRoot, function()
    saveAllCharacters()
end)

setTimer(saveAllCharacters, 120000, 0)

addEventHandler("onElementDataChange", root, function(dataName, oldValue)
    if getElementType(source) ~= "player" or not getElementData(source, "loggedin_character") then return end
    if dataName == "character:money" then
        local v = tonumber(getElementData(source, dataName)) or 0
        if getElementData(source, "char:money") ~= v then
            setElementData(source, "char:money", v, "broadcast", "deny")
        end
        if getPlayerMoney(source) ~= v then
            setPlayerMoney(source, v)
        end
    elseif dataName == "char:money" then
        local v = tonumber(getElementData(source, dataName)) or 0
        if getElementData(source, "character:money") ~= v then
            setElementData(source, "character:money", v, "broadcast", "deny")
        end
        if getPlayerMoney(source) ~= v then
            setPlayerMoney(source, v)
        end
    elseif dataName == "character:bank" then
        local v = tonumber(getElementData(source, dataName)) or 0
        if getElementData(source, "char:bank_money") ~= v then
            setElementData(source, "char:bank_money", v)
        end
        if getElementData(source, "char:bank") ~= v then
            setElementData(source, "char:bank", v, "broadcast", "deny")
        end
    elseif dataName == "char:bank_money" then
        local v = tonumber(getElementData(source, dataName)) or 0
        if getElementData(source, "character:bank") ~= v then
            setElementData(source, "character:bank", v, "broadcast", "deny")
        end
        if getElementData(source, "char:bank") ~= v then
            setElementData(source, "char:bank", v, "broadcast", "deny")
        end
    end
end)