JobServer = {}

local activeJobs = {}
local playerJobMap = {}
local cleaningSessions = {}
local playerEquipProps = {}
local playerOrigCustom = {}

local function deepCopyTable(src)
    if type(src) ~= "table" then return src end
    local jsonStr = toJSON(src)
    if jsonStr then
        local copy = fromJSON(jsonStr)
        if copy then return copy end
    end
    local res = {}
    for k, v in pairs(src) do
        res[k] = (type(v) == "table") and deepCopyTable(v) or v
    end
    return res
end

local function nearPoint(player, point, radius)
    if not isElement(player) or getElementType(player) ~= "player" then return false end
    if getElementDimension(player) ~= 0 or getElementInterior(player) ~= 0 then return false end
    local x, y, z = getElementPosition(player)
    return getDistanceBetweenPoints3D(x, y, z, point.x, point.y, point.z) <= radius
end

local function findBuildingById(bId)
    for _, b in ipairs(Config.Buildings) do
        if b.id == bId then
            return b
        end
    end
    return nil
end

function JobServer.getJob(player)
    local jobId = playerJobMap[player]
    return jobId and activeJobs[jobId] or nil
end

function JobServer.detachEquipment(player)
    local prop = playerEquipProps[player]
    if isElement(prop) then
        local boneRes = getResourceFromName("bone_attach")
        if boneRes and getResourceState(boneRes) == "running" then
            pcall(function() exports.bone_attach:detachElementFromBone(prop) end)
        end
        destroyElement(prop)
    end
    playerEquipProps[player] = nil
end

function JobServer.attachEquipment(player)
    JobServer.detachEquipment(player)
    if not isElement(player) then return end

    local cfg = Config.Equipment or {}
    local modelId = cfg.propModel or 2712
    local prop = createObject(modelId, 0, 0, 0)
    if not isElement(prop) then
        -- Fallback: Sprey kutusu (365)
        modelId = 365
        prop = createObject(modelId, 0, 0, 0)
    end

    if isElement(prop) then
        setElementCollisionsEnabled(prop, false)
        local attached = false
        local boneRes = getResourceFromName("bone_attach")
        if boneRes and getResourceState(boneRes) == "running" then
            local bone = cfg.propBone or 12
            local off = cfg.propOffset or { x = 0.05, y = 0.02, z = 0.08, rx = 0, ry = 180, rz = 0 }
            local ok, res = pcall(function()
                return exports.bone_attach:attachElementToBone(prop, player, bone, off.x, off.y, off.z, off.rx, off.ry, off.rz)
            end)
            if ok and res then
                attached = true
            end
        end

        if not attached then
            -- Bone attach aktif değilse sağ kalçaya/bele as
            attachElements(prop, player, 0.25, 0.0, -0.15, 0, 0, 0)
        end
        playerEquipProps[player] = prop
    end
end

local function applyWorkerOutfit(player)
    if not isElement(player) then return end
    local custom = getElementData(player, "char:customization")
    if type(custom) == "table" then
        -- Orijinal sivil kıyafetleri derin kopya ile sakla
        local savedOrig = deepCopyTable(custom)
        playerOrigCustom[player] = savedOrig
        setElementData(player, "window_cleaning:origCustom", savedOrig, false)

        local workCustom = deepCopyTable(custom)
        local target = workCustom
        if workCustom[1] and type(workCustom[1]) == "table" then
            target = workCustom[1]
        end

        local isFemale = (target.gender == "female")
        -- Özel GZL Temizlik Reflektörlü İş Tişörtü (Erkek: 77, Kadın: 20)
        target.torso = 1
        target.torsoVariant = isFemale and 20 or 77

        -- Bol Kargo İş Pantolonu
        target.legs = 2
        target.legsVariant = 1

        -- Ağır İş Botu
        target.shoes = isFemale and 2 or 3
        target.shoesVariant = 1

        setElementData(player, "char:customization", workCustom, true)
    end
    setElementAlpha(player, 255)
end

local function restoreOriginalOutfit(player)
    if not isElement(player) then return end
    local origCustom = playerOrigCustom[player] or getElementData(player, "window_cleaning:origCustom")

    -- Eğer hafızada bulunamazsa veritabanından orijinal sivil kıyafeti çek
    if not origCustom then
        local charId = getElementData(player, "character:id") or getElementData(player, "char:id")
        local db = exports.gzl_characters and exports.gzl_characters:getCharacterDB()
        if db and charId then
            local qh = dbQuery(db, "SELECT customization FROM characters WHERE id = ?", charId)
            local res = dbPoll(qh, 500)
            if res and res[1] and res[1].customization and res[1].customization ~= "" and res[1].customization ~= "{}" then
                origCustom = fromJSON(res[1].customization)
            end
        end
    end

    if origCustom then
        local restored = deepCopyTable(origCustom)
        local target = restored
        if restored[1] and type(restored[1]) == "table" then
            target = restored[1]
        end
        if target.torsoVariant == 77 then
            target.torsoVariant = 7
        elseif target.torsoVariant == 20 and target.gender == "female" then
            target.torsoVariant = 1
        end

        setElementData(player, "char:customization", restored, true)
        removeElementData(player, "window_cleaning:origCustom")
        playerOrigCustom[player] = nil

        -- DB'ye de orijinal sivil kıyafeti kaydet
        local charId = getElementData(player, "character:id") or getElementData(player, "char:id")
        local db = exports.gzl_characters and exports.gzl_characters:getCharacterDB()
        if db and charId then
            local customJson = toJSON(restored)
            if customJson then
                dbExec(db, "UPDATE characters SET customization = ? WHERE id = ?", customJson, charId)
            end
        end

        -- İstemci shader'larını anında yenile
        triggerClientEvent(player, "gzl_creator:clientRecover", player)
    else
        local curCustom = getElementData(player, "char:customization")
        if type(curCustom) == "table" then
            local restored = deepCopyTable(curCustom)
            local target = restored
            if restored[1] and type(restored[1]) == "table" then
                target = restored[1]
            end
            if target.torsoVariant == 77 then
                target.torsoVariant = 7
            elseif target.torsoVariant == 20 and target.gender == "female" then
                target.torsoVariant = 1
            end
            setElementData(player, "char:customization", restored, true)
            local charId = getElementData(player, "character:id") or getElementData(player, "char:id")
            local db = exports.gzl_characters and exports.gzl_characters:getCharacterDB()
            if db and charId then
                dbExec(db, "UPDATE characters SET customization = ? WHERE id = ?", toJSON(restored), charId)
            end
            triggerClientEvent(player, "gzl_creator:clientRecover", player)
        end
    end
    setElementAlpha(player, 255)
end

function JobServer.startJob(leader, buildingId)
    if playerJobMap[leader] or not nearPoint(leader, Config.DepotLocation.marker, 8.0) then return end
    local building = findBuildingById(buildingId)
    if not building then return end

    local team = LobbyServer.getTeam(leader)
    if team and team.leader ~= leader then return end

    local members = {}
    local seen = {}
    for _, member in ipairs(team and team.members or { leader }) do
        if not seen[member] and not playerJobMap[member] and nearPoint(member, Config.DepotLocation.marker, 35.0) then
            seen[member] = true
            table.insert(members, member)
        end
    end
    if #members == 0 or #members > Config.MaxGroupMembers then return end

    local jobId = "job_" .. tostring(getTickCount()) .. "_" .. tostring(math.random(1000, 9999))

    local vSpawn = Config.DepotLocation.vehicleSpawn
    local veh = createVehicle(Config.JobVehicleModel, vSpawn.x, vSpawn.y, vSpawn.z, 0, 0, vSpawn.rot)
    if isElement(veh) then
        setElementData(veh, "window_cleaning:jobId", jobId)
        setElementData(veh, "window_cleaning:isJobVehicle", true, true)
        setVehiclePlateText(veh, "GZL-TEMIZ")
        setVehicleColor(veh, 245, 95, 20, 240, 240, 240, 245, 95, 20, 240, 240, 240)
    end

    local windowsCopy = {}
    for _, w in ipairs(building.windows) do
        table.insert(windowsCopy, {
            id = w.id,
            label = w.label,
            x = w.x,
            y = w.y,
            z = w.z,
            isCleaned = false
        })
    end

    local jobData = {
        id = jobId,
        buildingId = building.id,
        buildingName = building.name,
        leader = leader,
        members = members,
        vehicle = veh,
        windows = windowsCopy,
        totalWindows = #windowsCopy,
        cleanedWindows = 0,
        parkingPos = building.vehicleParking
    }

    activeJobs[jobId] = jobData

    for _, member in ipairs(members) do
        if isElement(member) then
            playerJobMap[member] = jobId

            -- GZL Creator ile gerçekçi temizlik üniformasını giydir
            applyWorkerOutfit(member)
            setElementData(member, "char:job", "Cam Temizlik Görevlisi")

            triggerClientEvent(member, "windowCleaning:clientJobStarted", member, {
                buildingId = building.id,
                buildingName = building.name,
                totalWindows = #windowsCopy,
                cleanedWindows = 0,
                parkingPos = building.vehicleParking,
                windows = windowsCopy
            }, veh)
        end
    end
end

function JobServer.finishJob(player)
    local job = JobServer.getJob(player)
    if not job then return end
    if job.finishing or job.cleanedWindows < job.totalWindows then return end
    if not nearPoint(player, Config.DepotLocation.vehicleReturn, 16.0) then return end
    job.finishing = true

    local memberCount = #job.members
    local groupBonusMultiplier = 1.0 + (math.max(0, memberCount - 1) * Config.Economy.groupMultiplierPerMember)
    local baseTotal = (job.totalWindows * Config.Economy.basePayPerWindow) + Config.Economy.completionBonus
    local finalSalary = math.floor(baseTotal * groupBonusMultiplier)

    for _, member in ipairs(job.members) do
        if isElement(member) then
            JobServer.detachEquipment(member)
            restoreOriginalOutfit(member)

            local currentMoney = tonumber(getElementData(member, "character:money") or getPlayerMoney(member)) or 0
            local newMoney = currentMoney + finalSalary
            setElementData(member, "character:money", newMoney, "broadcast", "deny")
            setElementData(member, "char:money", newMoney, "broadcast", "deny")
            setPlayerMoney(member, newMoney)

            if exports.gzl_characters and exports.gzl_characters.saveCharacter then
                exports.gzl_characters:saveCharacter(member)
            end

            cleaningSessions[member] = nil
            playerJobMap[member] = nil
            triggerClientEvent(member, "windowCleaning:clientJobFinished", member, finalSalary)
        end
    end

    if isElement(job.vehicle) then
        destroyElement(job.vehicle)
    end
    activeJobs[job.id] = nil
end

function JobServer.cancelJob(leaderOrSolo)
    local job = JobServer.getJob(leaderOrSolo)
    if not job then return end
    if job.leader ~= leaderOrSolo and #job.members > 1 then return end

    for _, member in ipairs(job.members) do
        if isElement(member) then
            JobServer.detachEquipment(member)
            restoreOriginalOutfit(member)

            cleaningSessions[member] = nil
            playerJobMap[member] = nil
            triggerClientEvent(member, "windowCleaning:clientJobCancelled", member, "Görev lider tarafından iptal edildi.")
        end
    end

    if isElement(job.vehicle) then
        destroyElement(job.vehicle)
    end
    activeJobs[job.id] = nil
end

function JobServer.handlePlayerDisconnect(player)
    JobServer.detachEquipment(player)
    restoreOriginalOutfit(player)
    cleaningSessions[player] = nil
    local job = JobServer.getJob(player)
    if not job then return end

    playerJobMap[player] = nil
    for idx, m in ipairs(job.members) do
        if m == player then
            table.remove(job.members, idx)
            break
        end
    end

    if #job.members == 0 then
        if isElement(job.vehicle) then destroyElement(job.vehicle) end
        activeJobs[job.id] = nil
    end
end

-- Network Events
addEvent("windowCleaning:startJob", true)
addEventHandler("windowCleaning:startJob", root, function(buildingId)
    local ply = client or source
    JobServer.startJob(ply, buildingId)
end)

addEvent("windowCleaning:finishJob", true)
addEventHandler("windowCleaning:finishJob", root, function()
    local ply = client or source
    JobServer.finishJob(ply)
end)

addEvent("windowCleaning:requestCancelJob", true)
addEventHandler("windowCleaning:requestCancelJob", root, function()
    local ply = client or source
    JobServer.cancelJob(ply)
end)

addEvent("windowCleaning:leaveOutfit", true)
addEventHandler("windowCleaning:leaveOutfit", root, function()
    local ply = client or source
    if not isElement(ply) then return end

    if playerJobMap[ply] then
        JobServer.cancelJob(ply, "Kıyafet bırakıldığı için mevcut görev sonlandırıldı.")
    else
        restoreOriginalOutfit(ply)
        removePlayerEquipmentProp(ply)
    end
end)

addEvent("windowCleaning:serverToggleEquipment", true)
addEventHandler("windowCleaning:serverToggleEquipment", root, function(hasEquipment)
    local ply = client or source
    if not isElement(ply) then return end

    if hasEquipment then
        JobServer.attachEquipment(ply)
    else
        JobServer.detachEquipment(ply)
    end
end)

addEvent("windowCleaning:startAnimation", true)
addEventHandler("windowCleaning:startAnimation", root, function(windowId)
    local ply = client or source
    if not isElement(ply) or isPedDead(ply) or isPedInVehicle(ply) then return end
    local job = JobServer.getJob(ply)
    if not job then return end

    local targetId = tonumber(windowId)
    for _, window in ipairs(job.windows) do
        if tonumber(window.id) == targetId and not window.isCleaned and nearPoint(ply, window, 8.0) then
            cleaningSessions[ply] = {
                job = job.id,
                window = targetId,
                started = getTickCount()
            }
            return
        end
    end
end)

addEvent("windowCleaning:stopAnimation", true)
addEventHandler("windowCleaning:stopAnimation", root, function()
    local ply = client or source
    if isElement(ply) then
        cleaningSessions[ply] = nil
    end
end)

addEvent("windowCleaning:submitCleanWindow", true)
addEventHandler("windowCleaning:submitCleanWindow", root, function(windowId)
    local ply = client or source
    if not isElement(ply) then return end
    local job = JobServer.getJob(ply)
    if not job then return end

    local targetId = tonumber(windowId)
    local targetWin = nil
    for _, w in ipairs(job.windows) do
        if tonumber(w.id) == targetId and not w.isCleaned then
            targetWin = w
            break
        end
    end
    if not targetWin then return end

    local session = cleaningSessions[ply]
    if session then
        if tonumber(session.window) ~= targetId or session.job ~= job.id then return end
        local elapsed = getTickCount() - session.started
        if elapsed < 1500 then return end
    end
    if not nearPoint(ply, targetWin, 8.0) then return end
    cleaningSessions[ply] = nil

    targetWin.isCleaned = true
    job.cleanedWindows = job.cleanedWindows + 1

    -- Canlı Takım Senkronizasyonu
    for _, member in ipairs(job.members) do
        if isElement(member) then
            triggerClientEvent(member, "windowCleaning:clientSyncWindowCleaned", member, targetId, job.cleanedWindows)
        end
    end
end)

addEventHandler("onResourceStart", resourceRoot, function()
    local boneRes = getResourceFromName("bone_attach")
    if boneRes and getResourceState(boneRes) ~= "running" then
        pcall(function() startResource(boneRes) end)
    end
    for _, player in ipairs(getElementsByType("player")) do
        restoreOriginalOutfit(player)
    end
end)