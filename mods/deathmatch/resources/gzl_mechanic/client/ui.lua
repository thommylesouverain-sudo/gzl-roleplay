
local screenW, screenH = guiGetScreenSize()
local isMenuOpen = false
local currentVehicle = nil
local logoTexture = nil
local renderNativeBennyMenu = nil

local menuW = 430
local logoH = 106
local subheadH = 30
local itemH = 35
local maxVisibleItems = 10
local directionH = 24
local statusH = 34

local menuX = screenW - menuW - 35
local menuY = 30

local currentMenu = "mainMenu"
local menuStack = {}
local selectedIndex = 1
local scrollOffset = 1
local statusMessage = nil
local statusTimer = nil

local originalState = {
    color1 = { r = 255, g = 255, b = 255 },
    color2 = { r = 255, g = 255, b = 255 },
    headlights = { r = 255, g = 255, b = 255 },
    upgrades = {}
}

local function safeGetHeadlight(veh)
    if not isElement(veh) then return 255, 255, 255 end
    if getVehicleHeadLightColor then
        return getVehicleHeadLightColor(veh)
    elseif getVehicleHeadlightColor then
        return getVehicleHeadlightColor(veh)
    end
    return 255, 255, 255
end

local function safeSetHeadlight(veh, r, g, b)
    if not isElement(veh) then return end
    if setVehicleHeadLightColor then
        setVehicleHeadLightColor(veh, r, g, b)
    elseif setVehicleHeadlightColor then
        setVehicleHeadlightColor(veh, r, g, b)
    end
end

local function playClickSound()
    if fileExists("assets/sounds/wrench.ogg") then
        local s = playSound("assets/sounds/wrench.ogg")
        if s then setSoundVolume(s, 0.6) end
    end
end

local function playApplySound()
    if fileExists("assets/sounds/respray.ogg") then
        local s = playSound("assets/sounds/respray.ogg")
        if s then setSoundVolume(s, 0.7) end
    elseif fileExists("assets/sounds/wrench.ogg") then
        local s = playSound("assets/sounds/wrench.ogg")
        if s then setSoundVolume(s, 0.8) end
    end
end

local function isMouseIn(x, y, w, h)
    if not isCursorShowing() then return false end
    local cx, cy = getCursorPosition()
    cx, cy = cx * screenW, cy * screenH
    return (cx >= x and cx <= x + w and cy >= y and cy <= y + h)
end

function isMechanicMenuOpen()
    return isMenuOpen
end

local function setTemporaryStatus(text, duration)
    statusMessage = text
    if isTimer(statusTimer) then killTimer(statusTimer) end
    statusTimer = setTimer(function()
        statusMessage = nil
    end, duration or 3000, 1)
end

local function getVehicleAvailableBodyParts(veh)
    local partsBySlot = {}
    if not isElement(veh) then return partsBySlot end

    local compatible = getVehicleCompatibleUpgrades(veh)
    if compatible then
        for _, upgId in ipairs(compatible) do
            local slot = getVehicleUpgradeSlotName(upgId)
            if slot and slot ~= "Wheels" and slot ~= "Stereo" and slot ~= "Hydraulics" and slot ~= "Nitro" then
                if not partsBySlot[slot] then
                    partsBySlot[slot] = {}
                end
                table.insert(partsBySlot[slot], upgId)
            end
        end
    end
    return partsBySlot
end

local function getSlotTurkishName(slot)
    if slot == "Spoiler" then return "Spoiler"
    elseif slot == "Front Bumper" then return "Front Bumpers"
    elseif slot == "Rear Bumper" then return "Rear Bumpers"
    elseif slot == "Sideskirt" then return "Skirts"
    elseif slot == "Exhaust" then return "Exhausts"
    elseif slot == "Hood" then return "Hood"
    elseif slot == "Roof" then return "Roof"
    elseif slot == "Vent" then return "Grille / Vents"
    end
    return slot
end

local function buildCurrentMenuItems()
    local items = {}
    local subheading = "CATEGORIES"

    if currentMenu == "mainMenu" then
        subheading = "CATEGORIES"

        local partsBySlot = getVehicleAvailableBodyParts(currentVehicle)
        local slotOrder = { "Spoiler", "Sideskirt", "Exhaust", "Vent", "Hood", "Roof", "Front Bumper", "Rear Bumper" }
        for _, slot in ipairs(slotOrder) do
            if partsBySlot[slot] and #partsBySlot[slot] > 0 then
                local trName = getSlotTurkishName(slot)
                local desc = "Aracın " .. string.lower(trName) .. " parçalarını özelleştirin."
                if slot == "Spoiler" then desc = "Increase downforce."
                elseif slot == "Sideskirt" then desc = "Change side skirts for aerodynamic style."
                elseif slot == "Exhaust" then desc = "Custom high performance exhaust pipes."
                elseif slot == "Vent" then desc = "Custom front air intakes and grilles."
                elseif slot == "Hood" then desc = "Lightweight custom vented hoods."
                elseif slot == "Roof" then desc = "Roof scoops and air induction vents."
                elseif slot == "Front Bumper" then desc = "Aggressive front bumper splitters."
                elseif slot == "Rear Bumper" then desc = "Rear racing diffusers and bumpers."
                end

                table.insert(items, {
                    id = "slot_" .. slot,
                    name = trName,
                    rightText = ">",
                    desc = desc,
                    action = function() openSubMenu("slot_" .. slot) end
                })
            end
        end

        table.insert(items, {
            id = "repair",
            name = "Tamir & Bakım (Repair)",
            rightText = ">",
            desc = "Motor, kaporta, lastikler ve sıvı bakım hizmetleri.",
            action = function() openSubMenu("repair") end
        })
        table.insert(items, {
            id = "paint",
            name = "Boya & Kaplama (Respray)",
            rightText = ">",
            desc = "Gövde ve detay renklerini fırınlı boyayla değiştirin.",
            action = function() openSubMenu("paint") end
        })
        table.insert(items, {
            id = "headlights",
            name = "Xenon Farlar (Headlights)",
            rightText = ">",
            desc = "Yüksek lümenli renkli Xenon far aydınlatması.",
            action = function() openSubMenu("headlights") end
        })
        table.insert(items, {
            id = "wheels",
            name = "Jant Kataloğu (Wheels)",
            rightText = ">",
            desc = "Özel alaşımlı lüks ve spor jant kataloğu.",
            action = function() openSubMenu("wheels") end
        })
        table.insert(items, {
            id = "performance",
            name = "Performans & Ekstralar",
            rightText = ">",
            desc = "10x Nitro (NOS) ve Lowrider Hidrolik süspansiyon.",
            action = function() openSubMenu("performance") end
        })
        table.insert(items, {
            id = "suspension",
            name = "Süspansiyon (Stance)",
            rightText = ">",
            desc = "Süspansiyon basıklık ayarı ve pist stance geometrisi.",
            action = function() openSubMenu("suspension") end
        })
        table.insert(items, {
            id = "neon",
            name = "Neon Aydınlatması",
            rightText = ">",
            desc = "Araç altı renkli neon ışıkları montajı.",
            action = function() openSubMenu("neon") end
        })
        table.insert(items, {
            id = "lift",
            name = "Hydraulic Car Lift",
            rightText = (isLiftRaised and isLiftRaised()) and "[Aşağı]" or "[Yukarı]",
            desc = "Atölyedeki hidrolik araç kaldırma liftini kontrol eder.",
            action = function()
                local cur = (isLiftRaised and isLiftRaised())
                triggerServerEvent("mechanic:toggleLift", resourceRoot, not cur)
                playApplySound()
            end
        })

    elseif currentMenu == "repair" then
        subheading = "TAMIR & BAKIM"

        table.insert(items, {
            id = "fullOverhaul",
            name = "Benny's Komple Revizyon",
            rightText = "$" .. Config.Prices.fullOverhaul,
            desc = "Motor, kaporta, lastikler ve sıvıları tek seferde sıfırlar.",
            action = function()
                triggerServerEvent("mechanic:requestService", resourceRoot, currentVehicle, "fullOverhaul")
                playApplySound()
                setTemporaryStatus("Revizyon tamamlandı, araç sıfırlandı!", 3500)
            end
        })
        table.insert(items, {
            id = "repairEngine",
            name = "Motor & Mekanik Onarımı",
            rightText = "$" .. Config.Prices.repairEngine,
            desc = "Motor bloğunu, radyatörü ve mekanik aksamı %100 duruma getirir.",
            action = function()
                triggerServerEvent("mechanic:requestService", resourceRoot, currentVehicle, "repairEngine")
                playApplySound()
                setTemporaryStatus("Motor ve mekanik aksam onarıldı!", 3000)
            end
        })
        table.insert(items, {
            id = "repairBody",
            name = "Kaporta & Gövde Düzeltme",
            rightText = "$" .. Config.Prices.repairBody,
            desc = "Hasarlı kapı, çamurluk, tampon ve kırık camları onarır.",
            action = function()
                triggerServerEvent("mechanic:requestService", resourceRoot, currentVehicle, "repairBody")
                playApplySound()
                setTemporaryStatus("Kaporta düzeltildi!", 3000)
            end
        })
        table.insert(items, {
            id = "repairTires",
            name = "Lastik Değişimi & Balans",
            rightText = "$" .. Config.Prices.repairTires,
            desc = "Patlak veya aşınmış 4 lastiği sıfırlar, balans ayarını yapar.",
            action = function()
                triggerServerEvent("mechanic:requestService", resourceRoot, currentVehicle, "repairTires")
                playApplySound()
                setTemporaryStatus("Lastikler yenilendi!", 2500)
            end
        })
        table.insert(items, {
            id = "serviceOil",
            name = "Motor Yağı & Sıvı Bakımı",
            rightText = "$" .. Config.Prices.serviceOil,
            desc = "Sentetik motor yağı ve soğutma sıvısını yeniler.",
            action = function()
                triggerServerEvent("mechanic:requestService", resourceRoot, currentVehicle, "serviceOil")
                playApplySound()
                setTemporaryStatus("Motor sıvıları yenilendi!", 2500)
            end
        })

    elseif currentMenu == "paint" then
        subheading = "BOYA & KAPLAMA"

        table.insert(items, {
            id = "paintPrimary",
            name = "Ana Gövde Rengi (Primary)",
            rightText = ">",
            desc = "Aracın ana gövde boyasını seçin ve anında test edin.",
            action = function() openSubMenu("paintPrimary") end
        })
        table.insert(items, {
            id = "paintSecondary",
            name = "İkinci Gövde Rengi (Secondary)",
            rightText = ">",
            desc = "Tavan, ayna ve detay parçalarının boyasını seçin.",
            action = function() openSubMenu("paintSecondary") end
        })

    elseif currentMenu == "paintPrimary" then
        subheading = "ANA GOVDE RENGI"

        for _, col in ipairs(Config.ColorPresets) do
            table.insert(items, {
                id = "col1_" .. col.name,
                name = col.name,
                rightText = "$" .. Config.Prices.paintPrimary,
                desc = col.name .. " fırınlı gövde boyasını araca uygular.",
                onHover = function()
                    if isElement(currentVehicle) then
                        local _, _, _, r2, g2, b2 = getVehicleColor(currentVehicle, true)
                        setVehicleColor(currentVehicle, col.r, col.g, col.b, r2, g2, b2)
                    end
                end,
                action = function()
                    local _, _, _, r2, g2, b2 = getVehicleColor(currentVehicle, true)
                    triggerServerEvent("mechanic:requestService", resourceRoot, currentVehicle, "paint", {
                        r1 = col.r, g1 = col.g, b1 = col.b,
                        r2 = r2, g2 = g2, b2 = b2,
                        paintType = "primary"
                    })
                    originalState.color1 = { r = col.r, g = col.g, b = col.b }
                    playApplySound()
                    setTemporaryStatus("Boya uygulandı!", 3000)
                end
            })
        end

    elseif currentMenu == "paintSecondary" then
        subheading = "IKINCI GOVDE RENGI"

        for _, col in ipairs(Config.ColorPresets) do
            table.insert(items, {
                id = "col2_" .. col.name,
                name = col.name,
                rightText = "$" .. Config.Prices.paintSecondary,
                desc = col.name .. " detay boyasını araca uygular.",
                onHover = function()
                    if isElement(currentVehicle) then
                        local r1, g1, b1 = getVehicleColor(currentVehicle, true)
                        setVehicleColor(currentVehicle, r1, g1, b1, col.r, col.g, col.b)
                    end
                end,
                action = function()
                    local r1, g1, b1 = getVehicleColor(currentVehicle, true)
                    triggerServerEvent("mechanic:requestService", resourceRoot, currentVehicle, "paint", {
                        r1 = r1, g1 = g1, b1 = b1,
                        r2 = col.r, g2 = col.g, b2 = col.b,
                        paintType = "secondary"
                    })
                    originalState.color2 = { r = col.r, g = col.g, b = col.b }
                    playApplySound()
                    setTemporaryStatus("Detay boyası uygulandı!", 3000)
                end
            })
        end

    elseif currentMenu == "headlights" then
        subheading = "XENON FARLAR"

        for _, xen in ipairs(Config.HeadlightColors) do
            table.insert(items, {
                id = "xen_" .. xen.name,
                name = xen.name,
                rightText = "$" .. Config.Prices.headlights,
                desc = xen.name .. " yüksek lümenli Xenon ampul takar.",
                onHover = function()
                    if isElement(currentVehicle) then
                        safeSetHeadlight(currentVehicle, xen.r, xen.g, xen.b)
                    end
                end,
                action = function()
                    triggerServerEvent("mechanic:requestService", resourceRoot, currentVehicle, "headlights", {
                        r = xen.r, g = xen.g, b = xen.b
                    })
                    originalState.headlights = { r = xen.r, g = xen.g, b = xen.b }
                    playApplySound()
                    setTemporaryStatus("Xenon farlar takıldı!", 3000)
                end
            })
        end

    elseif currentMenu == "wheels" then
        subheading = "JANT KATALOGU"

        for _, wh in ipairs(Config.Wheels) do
            table.insert(items, {
                id = "wheel_" .. wh.id,
                name = wh.name,
                rightText = "$" .. wh.price,
                desc = wh.name .. " spor alaşımlı jant takımı.",
                onHover = function()
                    if isElement(currentVehicle) then
                        addVehicleUpgrade(currentVehicle, wh.id)
                    end
                end,
                action = function()
                    triggerServerEvent("mechanic:requestService", resourceRoot, currentVehicle, "wheels", {
                        wheelId = wh.id,
                        price = wh.price
                    })
                    originalState.upgrades["Wheels"] = wh.id
                    playApplySound()
                    setTemporaryStatus(wh.name .. " jantları takıldı!", 3000)
                end
            })
        end

    elseif string.sub(currentMenu, 1, 5) == "slot_" then
        local slotName = string.sub(currentMenu, 6)
        subheading = string.upper(getSlotTurkishName(slotName))

        table.insert(items, {
            id = "stock_" .. slotName,
            name = "Stock " .. getSlotTurkishName(slotName),
            rightText = "$0",
            desc = "Bu yuvadaki özel modifiye parçasını söküp orijinal haline getirir.",
            onHover = function()
                if isElement(currentVehicle) then
                    local u = getVehicleUpgradeOnSlot(currentVehicle, getVehicleUpgradeSlotId and getVehicleUpgradeSlotId(slotName) or 0)
                    if u and u > 0 then removeVehicleUpgrade(currentVehicle, u) end
                end
            end,
            action = function()
                local u = getVehicleUpgradeOnSlot(currentVehicle, getVehicleUpgradeSlotId and getVehicleUpgradeSlotId(slotName) or 0)
                triggerServerEvent("mechanic:requestService", resourceRoot, currentVehicle, "removeUpgrade", {
                    slot = slotName,
                    upgradeId = u
                })
                originalState.upgrades[slotName] = nil
                playApplySound()
                setTemporaryStatus("Orijinal parçaya dönüldü.", 3000)
            end
        })

        local partsBySlot = getVehicleAvailableBodyParts(currentVehicle)
        local upgList = partsBySlot[slotName] or {}
        for idx, upgId in ipairs(upgList) do
            local partName = getSlotTurkishName(slotName) .. " #" .. idx
            table.insert(items, {
                id = "part_" .. upgId,
                name = partName,
                rightText = "$850",
                desc = partName .. " aerodinamik gövde kitini araca monte eder.",
                onHover = function()
                    if isElement(currentVehicle) then
                        addVehicleUpgrade(currentVehicle, upgId)
                    end
                end,
                action = function()
                    triggerServerEvent("mechanic:requestService", resourceRoot, currentVehicle, "upgrade", {
                        upgradeId = upgId,
                        name = partName,
                        price = 850
                    })
                    originalState.upgrades[slotName] = upgId
                    playApplySound()
                    setTemporaryStatus(partName .. " başarıyla takıldı!", 3000)
                end
            })
        end

    elseif currentMenu == "performance" then
        subheading = "PERFORMANS & EKSTRALAR"

        table.insert(items, {
            id = "hydraulics",
            name = "Lowrider Hidrolik Sistemi",
            rightText = "$" .. Config.Prices.hydraulics,
            desc = "4 yönlü hidrolik dans ve zıplama pompası monte eder.",
            action = function()
                triggerServerEvent("mechanic:requestService", resourceRoot, currentVehicle, "hydraulics")
                originalState.upgrades["Hydraulics"] = 1087
                playApplySound()
                setTemporaryStatus("Hidrolik pompası takıldı!", 3000)
            end
        })
        table.insert(items, {
            id = "nitro",
            name = "10x Nitro (NOS) Enjeksiyonu",
            rightText = "$" .. Config.Prices.nitro10x,
            desc = "Motor bloğuna 10 kullanımlık basınçlı azot protoksit tüpü takar.",
            action = function()
                triggerServerEvent("mechanic:requestService", resourceRoot, currentVehicle, "nitro")
                originalState.upgrades["Nitro"] = 1010
                playApplySound()
                setTemporaryStatus("10x Nitro tüpü takıldı!", 3000)
            end
        })

    elseif currentMenu == "suspension" then
        subheading = "SUSPANSIYON (STANCE)"

        for _, susp in ipairs(Config.SuspensionLevels) do
            table.insert(items, {
                id = "susp_" .. susp.name,
                name = susp.name,
                rightText = "$" .. Config.Prices.suspension,
                desc = susp.name .. " basıklık geometrisini handlinge işler.",
                action = function()
                    triggerServerEvent("mechanic:requestService", resourceRoot, currentVehicle, "suspension", susp)
                    playApplySound()
                    setTemporaryStatus("Süspansiyon ayarlandı!", 3000)
                end
            })
        end

    elseif currentMenu == "neon" then
        subheading = "NEON AYDINLATMASI"

        for _, nCol in ipairs(Config.NeonColors) do
            table.insert(items, {
                id = "neon_" .. nCol.name,
                name = nCol.name,
                rightText = nCol.enabled and ("$" .. Config.Prices.neon) or "$0",
                desc = nCol.enabled and (nCol.name .. " neon kitini araç altına döşer.") or "Araç altı neon sistemini kapatır.",
                action = function()
                    triggerServerEvent("mechanic:requestService", resourceRoot, currentVehicle, "neon", nCol)
                    playApplySound()
                    setTemporaryStatus(nCol.enabled and "Neon takıldı!" or "Neon kapatıldı.", 3000)
                end
            })
        end
    end

    return items, subheading
end

function openSubMenu(menuName)
    table.insert(menuStack, { menu = currentMenu, index = selectedIndex, scroll = scrollOffset })
    currentMenu = menuName
    selectedIndex = 1
    scrollOffset = 1
    playClickSound()

    local items = buildCurrentMenuItems()
    if items[1] and items[1].onHover then
        items[1].onHover()
    end
end

function goBackMenu()
    if #menuStack > 0 then
        local prev = table.remove(menuStack)
        currentMenu = prev.menu
        selectedIndex = prev.index
        scrollOffset = prev.scroll
        playClickSound()

        local items = buildCurrentMenuItems()
        if items[selectedIndex] and items[selectedIndex].onHover then
            items[selectedIndex].onHover()
        end
    else
        closeMechanicMenu(true)
    end
end

function openMechanicMenu(veh, stationKey)
    if not isElement(veh) then return end
    currentVehicle = veh
    isMenuOpen = true
    currentMenu = "mainMenu"
    selectedIndex = 1
    scrollOffset = 1
    menuStack = {}
    statusMessage = nil

    showCursor(false)
    setElementFrozen(veh, true)
    toggleAllControls(false, true, false)

    if exports.gzl_hud and exports.gzl_hud.setHUDVisible then
        exports.gzl_hud:setHUDVisible(false)
    end

    if not logoTexture and fileExists("assets/images/logo.png") then
        logoTexture = dxCreateTexture("assets/images/logo.png")
    end

    local r1, g1, b1, r2, g2, b2 = getVehicleColor(veh, true)
    originalState.color1 = { r = r1, g = g1, b = b1 }
    originalState.color2 = { r = r2, g = g2, b = b2 }
    local hr, hg, hb = safeGetHeadlight(veh)
    originalState.headlights = { r = hr, g = hg, b = hb }

    originalState.upgrades = {}
    for slot = 0, 16 do
        local upg = getVehicleUpgradeOnSlot(veh, slot)
        if upg and upg > 0 then
            local sName = getVehicleUpgradeSlotName(upg) or tostring(slot)
            originalState.upgrades[sName] = upg
        end
    end

    if renderNativeBennyMenu then
        removeEventHandler("onClientRender", root, renderNativeBennyMenu)
        addEventHandler("onClientRender", root, renderNativeBennyMenu, true, "low-9999")
    end

    playClickSound()
end

function closeMechanicMenu(restoreOriginals)
    if not isMenuOpen then return end
    isMenuOpen = false
    showCursor(false)
    toggleAllControls(true, true, true)

    if renderNativeBennyMenu then
        removeEventHandler("onClientRender", root, renderNativeBennyMenu)
    end

    if exports.gzl_hud and exports.gzl_hud.setHUDVisible then
        exports.gzl_hud:setHUDVisible(true)
    end

    if isElement(currentVehicle) then
        setElementFrozen(currentVehicle, false)

        if restoreOriginals then
            setVehicleColor(currentVehicle, originalState.color1.r, originalState.color1.g, originalState.color1.b, originalState.color2.r, originalState.color2.g, originalState.color2.b)
            safeSetHeadlight(currentVehicle, originalState.headlights.r, originalState.headlights.g, originalState.headlights.b)

            for slot = 0, 16 do
                local curUpg = getVehicleUpgradeOnSlot(currentVehicle, slot)
                if curUpg and curUpg > 0 then
                    removeVehicleUpgrade(currentVehicle, curUpg)
                end
            end
            for _, upgId in pairs(originalState.upgrades) do
                if upgId and upgId > 0 then
                    addVehicleUpgrade(currentVehicle, upgId)
                end
            end
        end
    end

    currentVehicle = nil
    menuStack = {}
    if isTimer(statusTimer) then killTimer(statusTimer) end
    playClickSound()
end

renderNativeBennyMenu = function()
    if not isMenuOpen or not currentVehicle or not isElement(currentVehicle) then
        return
    end

    local items, subheading = buildCurrentMenuItems()
    local totalItems = #items
    if totalItems == 0 then return end

    if selectedIndex > totalItems then selectedIndex = totalItems end
    if selectedIndex < 1 then selectedIndex = 1 end

    if selectedIndex < scrollOffset then
        scrollOffset = selectedIndex
    elseif selectedIndex >= scrollOffset + maxVisibleItems then
        scrollOffset = selectedIndex - maxVisibleItems + 1
    end

    local visibleCount = math.min(maxVisibleItems, totalItems)
    local curY = menuY

    local fontLogo = getMechanicFont("heavy", 15)
    local fontSubheading = getMechanicFont("heavy", 11)
    local fontCounter = getMechanicFont("medium", 11)
    local fontItem = getMechanicFont("bold", 12)
    local fontRight = getMechanicFont("bold", 12)
    local fontNav = getMechanicFont("semibold", 10)
    local fontDesc = getMechanicFont("medium", 10.5)

    if logoTexture and isElement(logoTexture) then
        dxDrawImage(menuX, curY, menuW, logoH, logoTexture, 0, 0, 0, tocolor(255, 255, 255, 255), true)
    else
        exports.aura_ui:uiDrawRectangle(menuX, curY, menuW, logoH, tocolor(18, 20, 26, 255), true)
        exports.aura_ui:uiDrawText("BENNY'S ORIGINAL MOTOR WORKS", menuX, curY, menuX + menuW, curY + logoH, tocolor(245, 166, 35, 255), 1.0, fontLogo, "center", "center", false, false, true)
    end
    curY = curY + logoH

    exports.aura_ui:uiDrawRectangle(menuX, curY, menuW, subheadH, tocolor(0, 0, 0, 245), true)
    exports.aura_ui:uiDrawText(subheading, menuX + 15, curY, menuX + menuW - 15, curY + subheadH, tocolor(236, 240, 241, 255), 1.0, fontSubheading, "left", "center", false, false, true)
    exports.aura_ui:uiDrawText(selectedIndex .. "/" .. totalItems, menuX + 15, curY, menuX + menuW - 15, curY + subheadH, tocolor(180, 180, 190, 255), 1.0, fontCounter, "right", "center", false, false, true)
    curY = curY + subheadH

    exports.aura_ui:uiDrawRectangle(menuX, curY, menuW, 1, tocolor(236, 240, 241, 140), true)
    curY = curY + 1

    for i = 1, visibleCount do
        local itemIndex = scrollOffset + i - 1
        local item = items[itemIndex]
        if item then
            local isSelected = (itemIndex == selectedIndex)
            local itemY = curY + (i - 1) * itemH

            if isMouseIn(menuX, itemY, menuW, itemH) and not isSelected then
                selectedIndex = itemIndex
                isSelected = true
                playClickSound()
                if item.onHover then item.onHover() end
            end

            local bgCol = isSelected and tocolor(236, 240, 241, 255) or ((i % 2 == 1) and tocolor(0, 0, 0, 165) or tocolor(0, 0, 0, 210))
            local textCol = isSelected and tocolor(0, 0, 0, 255) or tocolor(236, 240, 241, 255)

            exports.aura_ui:uiDrawRectangle(menuX, itemY, menuW, itemH, bgCol, true)

            exports.aura_ui:uiDrawText(item.name, menuX + 15, itemY, menuX + menuW - 80, itemY + itemH, textCol, 1.0, fontItem, "left", "center", true, false, true)

            if item.rightText then
                exports.aura_ui:uiDrawText(item.rightText, menuX + 80, itemY, menuX + menuW - 15, itemY + itemH, textCol, 1.0, fontRight, "right", "center", false, false, true)
            end
        end
    end
    curY = curY + visibleCount * itemH

    exports.aura_ui:uiDrawRectangle(menuX, curY, menuW, 1, tocolor(236, 240, 241, 140), true)
    curY = curY + 1

    exports.aura_ui:uiDrawRectangle(menuX, curY, menuW, directionH, tocolor(0, 0, 0, 230), true)
    exports.aura_ui:uiDrawText("▲▼ Gezin  |  ENTER / ► Seç  |  ◄ / BACKSPACE Geri", menuX, curY, menuX + menuW, curY + directionH, tocolor(200, 210, 220, 220), 1.0, fontNav, "center", "center", false, false, true)
    curY = curY + directionH

    local curItem = items[selectedIndex]
    local descText = statusMessage or (curItem and curItem.desc) or "Benny's Original Motor Works"
    exports.aura_ui:uiDrawRectangle(menuX, curY, menuW, statusH, tocolor(0, 0, 0, 235), true)
    exports.aura_ui:uiDrawText(descText, menuX + 15, curY, menuX + menuW - 15, curY + statusH, tocolor(236, 240, 241, 240), 1.0, fontDesc, "left", "center", true, true, true)
end

addEventHandler("onClientKey", root, function(button, press)
    if not isMenuOpen or not press then return end

    local items = buildCurrentMenuItems()
    local total = #items

    if button == "arrow_u" or button == "arrow_up" or button == "mouse_wheel_up" or button == "num_8" then
        cancelEvent()
        if total > 0 then
            selectedIndex = selectedIndex - 1
            if selectedIndex < 1 then selectedIndex = total end
            playClickSound()
            if items[selectedIndex] and items[selectedIndex].onHover then
                items[selectedIndex].onHover()
            end
        end

    elseif button == "arrow_d" or button == "arrow_down" or button == "mouse_wheel_down" or button == "num_2" then
        cancelEvent()
        if total > 0 then
            selectedIndex = selectedIndex + 1
            if selectedIndex > total then selectedIndex = 1 end
            playClickSound()
            if items[selectedIndex] and items[selectedIndex].onHover then
                items[selectedIndex].onHover()
            end
        end

    elseif button == "arrow_r" or button == "arrow_right" or button == "enter" or button == "num_enter" or button == "space" or button == "num_6" then
        cancelEvent()
        if items[selectedIndex] and items[selectedIndex].action then
            items[selectedIndex].action()
        end

    elseif button == "arrow_l" or button == "arrow_left" or button == "backspace" or button == "num_4" then
        cancelEvent()
        goBackMenu()

    elseif button == "escape" then
        cancelEvent()
        closeMechanicMenu(true)
    end
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    toggleAllControls(true, true, true)
    if exports.gzl_hud and exports.gzl_hud.setHUDVisible then
        exports.gzl_hud:setHUDVisible(true)
    end
    if isElement(currentVehicle) then
        setElementFrozen(currentVehicle, false)
    end
    if isElement(logoTexture) then
        destroyElement(logoTexture)
    end
end)

addEventHandler("onClientClick", root, function(button, state)
    if not isMenuOpen or button ~= "left" or state ~= "down" then return end

    local items, _ = buildCurrentMenuItems()
    local totalItems = #items
    if totalItems == 0 then return end

    local visibleCount = math.min(maxVisibleItems, totalItems)
    local listStartY = menuY + logoH + subheadH + 1

    for i = 1, visibleCount do
        local itemIndex = scrollOffset + i - 1
        local itemY = listStartY + (i - 1) * itemH
        if isMouseIn(menuX, itemY, menuW, itemH) then
            selectedIndex = itemIndex
            if items[itemIndex] and items[itemIndex].action then
                items[itemIndex].action()
            end
            return
        end
    end
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    if renderNativeBennyMenu then
        removeEventHandler("onClientRender", root, renderNativeBennyMenu)
    end
    if isElement(logoTexture) then
        destroyElement(logoTexture)
        logoTexture = nil
    end
end)