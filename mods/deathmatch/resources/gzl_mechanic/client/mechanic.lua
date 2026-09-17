local stationMarkers = {}
local activeSoundEffects = {}
local sparkTimer = nil

local markerLogoTexture = nil

local function getNearbyStation()
    local px, py, pz = getElementPosition(localPlayer)
    for key, station in pairs(Config.Stations) do
        local dist = getDistanceBetweenPoints3D(px, py, pz, station.x, station.y, station.z)
        if dist <= station.radius + 1.0 then
            return key, station
        end
    end
    return nil, nil
end

local function renderStationMarkers()
    if isMechanicMenuOpen and isMechanicMenuOpen() then return end

    if not markerLogoTexture and fileExists("assets/images/logo.png") then
        markerLogoTexture = dxCreateTexture("assets/images/logo.png")
    end

    local px, py, pz = getElementPosition(localPlayer)
    local localVeh = getPedOccupiedVehicle(localPlayer)

    for key, station in pairs(Config.Stations) do
        local dist = getDistanceBetweenPoints3D(px, py, pz, station.x, station.y, station.z)

        if dist < 25.0 then
            local bob = math.sin(getTickCount() / 500) * 0.05
            local floatZ = station.z + 1.65 + bob
            local sx, sy = getScreenFromWorldPosition(station.x, station.y, floatZ)
            if sx and sy then
                local alpha = math.max(0, math.min(255, (25 - dist) * 18))
                local scale = math.max(0.75, math.min(1.05, 1.10 - (dist / 30)))

                local cardW = math.floor(340 * scale)
                local cardH = math.floor(66 * scale)
                local cardX = math.floor(sx - cardW / 2)
                local cardY = math.floor(sy - cardH / 2)

                local fontHeavy = getMechanicFont("heavy", math.max(8, math.floor(10.5 * scale)))
                local fontBold = getMechanicFont("bold", math.max(8, math.floor(10 * scale)))
                local fontMedium = getMechanicFont("medium", math.max(7, math.floor(9.5 * scale)))
                local fontRegular = getMechanicFont("regular", math.max(7, math.floor(9 * scale)))

                exports.aura_ui:uiDrawRectangle(cardX - 1, cardY - 1, cardW + 2, cardH + 2, tocolor(0, 0, 0, math.floor(alpha * 0.55)))
                exports.aura_ui:uiDrawRectangle(cardX, cardY, cardW, cardH, tocolor(12, 15, 22, math.floor(alpha * 0.94)))
                exports.aura_ui:uiDrawRectangle(cardX, cardY, cardW, 2, tocolor(245, 166, 35, alpha))

                local iconBoxW = math.floor(46 * scale)
                local iconBoxH = math.floor(46 * scale)
                local iconX = cardX + math.floor(10 * scale)
                local iconY = cardY + math.floor(10 * scale)
                exports.aura_ui:uiDrawRectangle(iconX, iconY, iconBoxW, iconBoxH, tocolor(245, 166, 35, math.floor(alpha * 0.15)))
                exports.aura_ui:uiDrawRectangle(iconX, iconY, iconBoxW, 1, tocolor(245, 166, 35, math.floor(alpha * 0.5)))

                if markerLogoTexture and isElement(markerLogoTexture) then
                    dxDrawImage(iconX + 3 * scale, iconY + 11 * scale, iconBoxW - 6 * scale, (iconBoxW - 6 * scale) * 0.45, markerLogoTexture, 0, 0, 0, tocolor(255, 255, 255, alpha))
                else
                    exports.aura_ui:uiDrawText("BENNY'S", iconX, iconY + 10 * scale, iconX + iconBoxW, iconY + 22 * scale, tocolor(245, 166, 35, alpha), 1.0, fontBold, "center", "center")
                    exports.aura_ui:uiDrawText("CUSTOMS", iconX, iconY + 22 * scale, iconX + iconBoxW, iconY + 34 * scale, tocolor(200, 205, 215, alpha), 1.0, fontRegular, "center", "center")
                end

                local textX = iconX + iconBoxW + math.floor(12 * scale)
                local titleY = cardY + math.floor(11 * scale)
                exports.aura_ui:uiDrawText("BENNY'S ORIGINAL MOTOR WORKS", textX, titleY, cardX + cardW - 10 * scale, titleY + 18 * scale, tocolor(245, 166, 35, alpha), 1.0, fontHeavy, "left", "center", true, false, false)

                local inRange = (dist <= station.radius + 0.5)

                if inRange then

                    local keyW = math.floor(24 * scale)
                    local keyH = math.floor(22 * scale)
                    local keyX = textX
                    local keyY = cardY + math.floor(33 * scale)

                    local keyPulse = math.sin(getTickCount() / 220) * 0.5 + 0.5
                    exports.aura_ui:uiDrawRectangle(keyX - 1, keyY - 1, keyW + 2, keyH + 2, tocolor(245, 166, 35, math.floor(alpha * keyPulse * 0.85)))
                    exports.aura_ui:uiDrawRectangle(keyX, keyY + 2, keyW, keyH, tocolor(0, 0, 0, math.floor(alpha * 0.6)))
                    exports.aura_ui:uiDrawRectangle(keyX, keyY, keyW, keyH, tocolor(245, 248, 252, alpha))
                    exports.aura_ui:uiDrawText("E", keyX, keyY, keyX + keyW, keyY + keyH, tocolor(15, 18, 26, alpha), 1.0, fontHeavy, "center", "center")

                    local actionText = localVeh and "Modifiye Menüsünü Aç" or "Atölyeyi Aç"
                    exports.aura_ui:uiDrawText(actionText, keyX + keyW + math.floor(9 * scale), keyY, cardX + cardW - 10 * scale, keyY + keyH, tocolor(255, 255, 255, alpha), 1.0, fontBold, "left", "center", true, false, false)
                else
                    exports.aura_ui:uiDrawText("Özel Araç Modifiye & Mekanik Atölyesi", textX, cardY + math.floor(34 * scale), cardX + cardW - 10 * scale, cardY + cardH - 8 * scale, tocolor(175, 185, 200, math.floor(alpha * 0.85)), 1.0, fontMedium, "left", "center", true, false, false)
                end
            end
        end
    end
end

local function handleInteractionKey(button, press)
    if button == "e" and press then
        if isMechanicMenuOpen and isMechanicMenuOpen() then
            return
        end

        local key, station = getNearbyStation()
        if key and station then
            local veh = getPedOccupiedVehicle(localPlayer)
            if not veh then

                local px, py, pz = getElementPosition(localPlayer)
                for _, v in ipairs(getElementsByType("vehicle", root, true)) do
                    local vx, vy, vz = getElementPosition(v)
                    if getDistanceBetweenPoints3D(px, py, pz, vx, vy, vz) <= 4.0 then
                        veh = v
                        break
                    end
                end
            end

            if veh then
                openMechanicMenu(veh, key)
            else
                if exports.gzl_ui and exports.gzl_ui.showToast then
                    exports.gzl_ui:showToast("Bu istasyonu kullanmak icin bir arac gereklidir!", "warning")
                else
                    outputChatBox("[Benny's] Islem yapabilmek icin aracınızla istasyona girin.", 240, 160, 20)
                end
            end
        end
    end
end

addEvent("mechanic:clientPlayRepairSequence", true)
addEventHandler("mechanic:clientPlayRepairSequence", root, function(targetVeh, serviceType, duration)
    if not isElement(targetVeh) then return end

    local vx, vy, vz = getElementPosition(targetVeh)
    local isLocalVehicle = (getPedOccupiedVehicle(localPlayer) == targetVeh)

    if serviceType == "repairEngine" or serviceType == "fullOverhaul" then
        setVehicleDoorOpenRatio(targetVeh, 0, 1, 1000)

        if fileExists("assets/sounds/impact_wrench.wav") then
            local sound = playSound3D("assets/sounds/impact_wrench.wav", vx, vy, vz)
            if sound then
                setSoundMaxDistance(sound, 30)
                setSoundVolume(sound, 0.9)
            end
        end

        if isTimer(sparkTimer) then killTimer(sparkTimer) end
        local sparkCount = 0
        sparkTimer = setTimer(function()
            if isElement(targetVeh) then
                local bx, by, bz = getPositionFromElementOffset(targetVeh, 0.0, 1.8, 0.5)
                fxAddSparks(bx, by, bz, 0, 0, 1, 2, 4, 0, 0, 0, true, 2, 1)
                sparkCount = sparkCount + 1
                if sparkCount >= 10 then
                    killTimer(sparkTimer)
                end
            end
        end, 250, 10)

        if isLocalVehicle and exports.gzl_ui and exports.gzl_ui.startProgressBar then
            exports.gzl_ui:startProgressBar({
                text = "Motor bloğu ve mekanik aksam onarılıyor...",
                duration = duration or 3500
            })
        end

        setTimer(function()
            if isElement(targetVeh) then
                setVehicleDoorOpenRatio(targetVeh, 0, 0, 1000)
            end
        end, duration or 3500, 1)

    elseif serviceType == "repairBody" then

        if fileExists("assets/sounds/metal_hammer.wav") then
            local sound = playSound3D("assets/sounds/metal_hammer.wav", vx, vy, vz)
            if sound then
                setSoundMaxDistance(sound, 30)
                setSoundVolume(sound, 0.9)
            end
        end

        if isLocalVehicle and exports.gzl_ui and exports.gzl_ui.startProgressBar then
            exports.gzl_ui:startProgressBar({
                text = "Kaporta ve gövde panelleri düzeltiliyor...",
                duration = duration or 3000
            })
        end

    elseif serviceType == "repairTires" then
        if fileExists("assets/sounds/impact_wrench.wav") then
            local sound = playSound3D("assets/sounds/impact_wrench.wav", vx, vy, vz)
            if sound then
                setSoundMaxDistance(sound, 30)
                setSoundVolume(sound, 0.9)
            end
        end

        if isLocalVehicle and exports.gzl_ui and exports.gzl_ui.startProgressBar then
            exports.gzl_ui:startProgressBar({
                text = "Tekerlekler sökülüyor ve yeni lastikler takılıyor...",
                duration = duration or 2500
            })
        end

    elseif serviceType == "paint" then
        if fileExists("assets/sounds/spray.wav") then
            local sound = playSound3D("assets/sounds/spray.wav", vx, vy, vz)
            if sound then
                setSoundMaxDistance(sound, 30)
                setSoundVolume(sound, 0.9)
            end
        end

        fxAddTyreBurst(vx, vy, vz + 0.5, 0, 0, 0.2)

        if isLocalVehicle and exports.gzl_ui and exports.gzl_ui.startProgressBar then
            exports.gzl_ui:startProgressBar({
                text = "Fırınlı boya ve vernik katmanı uygulanıyor...",
                duration = duration or 3000
            })
        end
    end
end)

function getPositionFromElementOffset(element, offX, offY, offZ)
    local m = getElementMatrix(element)
    local x = offX * m[1][1] + offY * m[2][1] + offZ * m[3][1] + m[4][1]
    local y = offX * m[1][2] + offY * m[2][2] + offZ * m[3][2] + m[4][2]
    local z = offX * m[1][3] + offY * m[2][3] + offZ * m[3][3] + m[4][3]
    return x, y, z
end

local function initMarkers()
    for key, station in pairs(Config.Stations) do
        local m = createMarker(station.x, station.y, station.z - 0.9, station.type, station.radius, station.color[1], station.color[2], station.color[3], station.color[4])
        stationMarkers[key] = m
    end
    addEventHandler("onClientRender", root, renderStationMarkers)
    addEventHandler("onClientKey", root, handleInteractionKey)
end

addEventHandler("onClientResourceStart", resourceRoot, initMarkers)

addEventHandler("onClientResourceStop", resourceRoot, function()
    if isElement(markerLogoTexture) then destroyElement(markerLogoTexture) end
end)