Equipment = {}

local hasEquipment = false
local jobVehicle = nil
local isNearTrunk = false

function Equipment.hasEquipment()
    return hasEquipment
end

function Equipment.setVehicle(veh)
    jobVehicle = veh
end

function Equipment.clear()
    hasEquipment = false
    jobVehicle = nil
    isNearTrunk = false
end

local function getVehicleTrunkPosition(veh)
    if not isElement(veh) then return nil end
    local vx, vy, vz = getElementPosition(veh)
    local rx, ry, rz = getElementRotation(veh)
    local radZ = math.rad(rz)
    -- Araç arkası ofseti (yaklaşık 2.8 metre gerisi)
    local tx = vx - math.sin(-radZ) * 2.8
    local ty = vy - math.cos(-radZ) * 2.8
    local tz = vz + 0.3
    return tx, ty, tz
end

function Equipment.isNearTrunk()
    return isNearTrunk
end

function Equipment.toggleEquipment()
    if not isElement(jobVehicle) or not isNearTrunk then return end

    hasEquipment = not hasEquipment
    triggerServerEvent("windowCleaning:serverToggleEquipment", localPlayer, hasEquipment)

    if hasEquipment then
        Audio.playButtonClick()
        exports.aura_ui:uiToast("Ekipman Alındı", "Cam silme fırçası ve ekipmanlar hazır. Vitrinlere ilerleyin!", "info", 4000)
    else
        Audio.playButtonClick()
        exports.aura_ui:uiToast("Ekipman Bırakıldı", "Temizlik malzemeleri araca yerleştirildi.", "info", 3500)
    end
end

function Equipment.render()
    local jobData = JobHUD.getJobData()
    if not jobData or not isElement(jobVehicle) then
        isNearTrunk = false
        return
    end

    local tx, ty, tz = getVehicleTrunkPosition(jobVehicle)
    if not tx then return end

    local px, py, pz = getElementPosition(localPlayer)
    local dist = getDistanceBetweenPoints3D(px, py, pz, tx, ty, tz)

    if dist <= Config.Equipment.trunkDistance then
        isNearTrunk = true
        local sx, sy = getScreenFromWorldPosition(tx, ty, tz + 0.5)
        if sx and sy then
            local cardW = 200
            local cardH = 44
            local cardX = sx - cardW / 2
            local cardY = sy - cardH / 2

            drawGlassPanel(cardX, cardY, cardW, cardH, 8, 0.92)
            local statusText = hasEquipment and "Ekipmanları Bırak" or "Ekipmanları Al"
            local colorBar = hasEquipment and tocolor(30,34,39,245) or tocolor(30,34,39,245)
            drawRoundedRectangle(cardX + 2, cardY + 2, cardW - 4, cardH - 4, 6, colorBar)

            exports.aura_ui:uiDrawText("[ E ] " .. statusText, cardX, cardY, cardX + cardW, cardY + cardH, tocolor(255, 255, 255, 255), 0.95, "default-bold", "center", "center")
        end
    else
        isNearTrunk = false
    end
end
