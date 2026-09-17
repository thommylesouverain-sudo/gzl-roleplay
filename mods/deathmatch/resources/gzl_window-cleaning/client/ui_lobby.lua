LobbyUI = {}

local ui = exports.aura_ui
local rootPanel = nil
local activeLobbyData = nil
local nearbyPlayersList = {}
local selectedBuildingIndex = 1
local currentTabIndex = 1

local contractsContainer = nil
local groupContainer = nil
local detailsCard = nil

local function isLeader()
    if not activeLobbyData or not activeLobbyData.isGroup then return true end
    return activeLobbyData.leader == localPlayer
end

function LobbyUI.isOpen()
    return rootPanel and isElement(rootPanel)
end

function LobbyUI.close()
    if rootPanel and isElement(rootPanel) then
        ui:uiDestroy(rootPanel)
        rootPanel = nil
        showCursor(false)
    end
end

function LobbyUI.updateData(lobbyData, nearbyPlayers)
    activeLobbyData = lobbyData
    if nearbyPlayers then
        nearbyPlayersList = nearbyPlayers
    end
    if LobbyUI.isOpen() then
        local savedBuild = selectedBuildingIndex
        LobbyUI.close()
        LobbyUI.open(activeLobbyData, nearbyPlayersList)
        selectedBuildingIndex = savedBuild
    end
end

function LobbyUI.open(lobbyData, nearbyPlayers)
    if LobbyUI.isOpen() then return end

    activeLobbyData = lobbyData
    nearbyPlayersList = nearbyPlayers or {}
    local sw,sh=guiGetScreenSize()

    -- Ana AURA Penceresi (Geniş & Ferah)
    rootPanel = ui:uiCreate("panel", {
        w = 880, h = 560, centered = true, scale=math.min(1.15,(sw-64)/880,(sh-64)/560), radius = 14, color={15,17,20}, modal=true
    })
    if not rootPanel then return end

    -- Başlık ve Şirket Tanıtımı
    ui:uiCreate("label", {
        x = 24, y = 12, w = 100, h = 44, text = "aura", size = 26, textColor = {239,242,244}
    }, rootPanel)

    ui:uiCreate("label", {
        x = 112, y = 24, w = 600, h = 20, text = "TEMİZLİK / SÖZLEŞMELER VE EKİP", textColor={143,153,164}, size = 9
    }, rootPanel)

    -- Kapat Butonu (X)
    local closeBtn = ui:uiCreate("button", {
        x = 880 - 24 - 40, y = 14, w = 40, h = 34, text = "✕", variant = "ghost", size = 11
    }, rootPanel)
    addEventHandler("onAuraClick", closeBtn, function()
        LobbyUI.close()
    end, false)

    -- Sekme Değiştirici (Tabs)
    local tabSwitcher = ui:uiCreate("tabs", {
        x = 24, y = 68, w = 832, h = 40,
        items = { "Temizlik Sözleşmeleri", "Takım ve Lobi" },
        value = currentTabIndex, size = 11
    }, rootPanel)

    -- 1. SEKME: SÖZLEŞMELER
    contractsContainer = ui:uiCreate("panel", {
        x = 24, y = 118, w = 832, h = 422, color = {0, 0, 0, 0}, border = false, visible=currentTabIndex==1
    }, rootPanel)

    -- Sol Panel: Sözleşme Butonları
    local listPanel = ui:uiCreate("panel", {
        x = 0, y = 0, w = 370, h = 422, color = {22,25,29}, radius = 10
    }, contractsContainer)

    ui:uiCreate("label", {
        x = 16, y = 12, w = 330, h = 22, text = "MEVCUT SÖZLEŞMELER", bold = true, size = 11, textColor = {143,153,164}
    }, listPanel)

    local buttonRefs = {}
    for idx, building in ipairs(Config.Buildings) do
        local btnY = 38 + (idx - 1) * 72
        local isSel = (idx == selectedBuildingIndex)

        local bBtn = ui:uiCreate("button", {
            x = 12, y = btnY, w = 346, h = 64,
            text = building.name,
            variant = "secondary", color=isSel and {38,46,34} or {30,34,39}, borderColor=isSel and {201,244,111} or {48,54,61}, textColor=isSel and {201,244,111} or {239,242,244},
            size = 11
        }, listPanel)
        buttonRefs[idx] = bBtn

        addEventHandler("onAuraClick", bBtn, function()
            selectedBuildingIndex = idx
            for bIdx, btn in ipairs(buttonRefs) do
                ui:uiSet(btn,"color",bIdx==selectedBuildingIndex and {38,46,34} or {30,34,39})
                ui:uiSet(btn,"borderColor",bIdx==selectedBuildingIndex and {201,244,111} or {48,54,61})
                ui:uiSet(btn,"textColor",bIdx==selectedBuildingIndex and {201,244,111} or {239,242,244})
            end
            LobbyUI.renderDetailsContent()
        end, false)
    end

    -- Lüks Butik'in Altına Kıyafeti Bırak Butonu
    local leaveOutfitBtn = ui:uiCreate("button", {
        x = 12, y = 330, w = 346, h = 56,
        text = "Sivil kıyafete dön",
        variant = "secondary",
        color = {35, 42, 54, 240},
        borderColor = {239, 68, 68, 160},
        size = 11
    }, listPanel)

    addEventHandler("onAuraClick", leaveOutfitBtn, function()
        Audio.playButtonClick()
        triggerServerEvent("windowCleaning:leaveOutfit", localPlayer)
        exports.aura_ui:uiToast("Kıyafet Bırakıldı", "Temizlikçi üniforması çıkarıldı, sivil kıyafetlerinize döndünüz.", "success", 4000)
    end, false)

    -- Sağ Panel: Detay Kartı
    detailsCard = ui:uiCreate("panel", {
        x = 384, y = 0, w = 448, h = 422, color = {22,25,29}, radius = 10
    }, contractsContainer)

    LobbyUI.renderDetailsContent()

    -- 2. SEKME: TAKIM & LOBİ
    groupContainer = ui:uiCreate("panel", {
        x = 24, y = 118, w = 832, h = 422, color = {0, 0, 0, 0}, border = false,
        visible = currentTabIndex==2
    }, rootPanel)

    LobbyUI.renderGroupContent()

    -- Tab Değişim Olayı
    addEventHandler("onAuraChange", tabSwitcher, function(val)
        currentTabIndex = tonumber(val) or 1
        if currentTabIndex == 1 then
            ui:uiSet(contractsContainer, "visible", true)
            ui:uiSet(groupContainer, "visible", false)
        else
            ui:uiSet(contractsContainer, "visible", false)
            ui:uiSet(groupContainer, "visible", true)
        end
    end, false)

    showCursor(true)
end

function LobbyUI.renderDetailsContent()
    if not detailsCard or not isElement(detailsCard) then return end

    local children = getElementChildren(detailsCard)
    for _, child in ipairs(children) do
        ui:uiDestroy(child)
    end

    local b = Config.Buildings[selectedBuildingIndex]
    if not b then return end

    -- Bina Başlığı (Geniş w değeri verildi)
    ui:uiCreate("label", {
        x = 20, y = 14, w = 408, h = 26, text = b.name, bold = true, size = 11, textColor = {239,242,244}
    }, detailsCard)

    -- Konum & Bölge (Geniş w değeri verildi)
    ui:uiCreate("label", {
        x = 20, y = 40, w = 310, h = 20, text = "Bölge: " .. (b.zone or "Los Santos"), size = 11, textColor = {143,153,164}
    }, detailsCard)

    -- Zorluk Rozeti
    local toneMap = {
        ["Kolay"] = "success",
        ["Orta"] = "warning",
        ["Zor"] = "danger",
        ["Uzman"] = "accent"
    }
    ui:uiCreate("badge", {
        x = 448 - 20 - 85, y = 40, w = 85, h = 24,
        text = b.difficulty, tone = toneMap[b.difficulty] or "accent", size = 11
    }, detailsCard)

    -- Açıklama (İki satırlık net yerleşim - Kesilmeyi önler)
    if b.description1 then
        ui:uiCreate("label", {
            x = 20, y = 66, w = 408, h = 20, text = b.description1, textColor = {143,153,164}, size = 11
        }, detailsCard)
        ui:uiCreate("label", {
            x = 20, y = 88, w = 408, h = 20, text = b.description2 or "", textColor = {143,153,164}, size = 11
        }, detailsCard)
    else
        ui:uiCreate("label", {
            x = 20, y = 70, w = 408, h = 22, text = b.description or "", textColor = {143,153,164}, size = 11
        }, detailsCard)
    end

    -- İstatistikler
    local statY = 126
    local stats = {
        { label = "Temizlenecek Vitrin Sayısı:", val = tostring(#b.windows) .. " Adet" },
        { label = "Cam Başına Ücret:", val = "$" .. tostring(Config.Economy.basePayPerWindow) },
        { label = "Sözleşme Tamamlama Primi:", val = "$" .. tostring(Config.Economy.completionBonus) },
        { label = "Tahmini Toplam Kazanç:", val = "$" .. tostring((#b.windows * Config.Economy.basePayPerWindow) + Config.Economy.completionBonus), color = {201,244,111} },
        { label = "Tahsis Edilen Şirket Aracı:", val = "Utility Van (552)" }
    }

    for idx, stat in ipairs(stats) do
        local rowY = statY + (idx - 1) * 40
        local rowBox = ui:uiCreate("panel", {
            x = 20, y = rowY, w = 408, h = 34, color = {30,34,39}, radius = 6
        }, detailsCard)

        ui:uiCreate("label", {
            x = 12, y = 0, w = 240, h = 34, text = stat.label, textColor = {143,153,164}, size = 11
        }, rowBox)

        local valColor = stat.color or {255, 255, 255}
        ui:uiCreate("label", {
            x = 408 - 12 - 150, y = 0, w = 150, h = 34, text = stat.val,
            bold = true, size = 11, textColor = valColor, align = "right"
        }, rowBox)
    end

    -- İşe Başla Butonu
    local canStart = isLeader()
    local btnText = canStart and "Sözleşmeyi imzala ve başla" or "Liderin İşi Başlatması Bekleniyor..."
    local startBtn = ui:uiCreate("button", {
        x = 20, y = 358, w = 408, h = 48,
        text = btnText, variant = canStart and "primary" or "secondary",
        disabled = not canStart, size = 11
    }, detailsCard)

    if canStart then
        addEventHandler("onAuraClick", startBtn, function()
            triggerServerEvent("windowCleaning:startJob", localPlayer, b.id)
            LobbyUI.close()
        end, false)
    end
end

function LobbyUI.renderGroupContent()
    if not groupContainer or not isElement(groupContainer) then return end

    local children = getElementChildren(groupContainer)
    for _, child in ipairs(children) do
        ui:uiDestroy(child)
    end

    -- Sol Taraf: Takım Listesi
    local teamPanel = ui:uiCreate("panel", {
        x = 0, y = 0, w = 406, h = 422, color = {22,25,29}, radius = 10
    }, groupContainer)

    ui:uiCreate("label", {
        x = 16, y = 14, w = 370, h = 24, text = "TAKIM ÜYELERİ", bold = true, size = 11, textColor = {201,244,111}
    }, teamPanel)

    if activeLobbyData and activeLobbyData.isGroup then
        for idx, member in ipairs(activeLobbyData.members) do
            local itemY = 48 + (idx - 1) * 54
            local mBox = ui:uiCreate("panel", {
                x = 14, y = itemY, w = 378, h = 46, color = {30,34,39}, radius = 6
            }, teamPanel)

            local isMLeader = (member.element == activeLobbyData.leader)
            local pName = member.name or getPlayerName(member.element) or "Bilinmeyen"

            ui:uiCreate("label", {
                x = 14, y = 0, w = 260, h = 46, text = pName, bold = true, size = 11
            }, mBox)

            ui:uiCreate("badge", {
                x = 378 - 14 - 84, y = 10, w = 84, h = 26,
                text = isMLeader and "Lider" or "Üye",
                tone = isMLeader and "warning" or "accent", size = 10
            }, mBox)
        end

        local leaveBtn = ui:uiCreate("button", {
            x = 14, y = 358, w = 378, h = 48,
            text = isLeader() and "TAKIMI DAĞIT" or "TAKIMDAN AYRIL",
            variant = "primary", tone = "danger", size = 11
        }, teamPanel)

        addEventHandler("onAuraClick", leaveBtn, function()
            triggerServerEvent("windowCleaning:leaveTeam", localPlayer)
        end, false)
    else
        ui:uiCreate("label", {
            x = 16, y = 50, w = 374, h = 22,
            text = "Henüz bir takım oluşturmadınız.",
            bold = true, size = 11, textColor = {240, 245, 250}
        }, teamPanel)

        ui:uiCreate("label", {
            x = 16, y = 78, w = 374, h = 22,
            text = "Tek başınıza çalışabilir veya arkadaşlarınızla",
            textColor = {143,153,164}, size = 11
        }, teamPanel)

        ui:uiCreate("label", {
            x = 16, y = 102, w = 374, h = 22,
            text = "takım kurup kişi başı +%20 prim kazanabilirsiniz!",
            textColor = {143,153,164}, size = 11
        }, teamPanel)

        local createBtn = ui:uiCreate("button", {
            x = 16, y = 160, w = 374, h = 46,
            text = "Takım oluştur", variant = "primary", size = 11
        }, teamPanel)

        addEventHandler("onAuraClick", createBtn, function()
            triggerServerEvent("windowCleaning:createTeam", localPlayer)
        end, false)
    end

    -- Sağ Taraf: Yakındaki Oyuncular (Davet Et)
    local invitePanel = ui:uiCreate("panel", {
        x = 422, y = 0, w = 410, h = 422, color = {22,25,29}, radius = 10
    }, groupContainer)

    ui:uiCreate("label", {
        x = 16, y = 14, w = 378, h = 24, text = "YAKINDAKİ OYUNCULAR", bold = true, size = 11, textColor = {201,244,111}
    }, invitePanel)

    if #nearbyPlayersList == 0 then
        ui:uiCreate("label", {
            x = 16, y = 50, w = 378, h = 22, text = "30 metre yakınınızda oyuncu bulunamadı.", textColor = {143,153,164}, size = 11
        }, invitePanel)
        ui:uiCreate("label", {
            x = 16, y = 74, w = 378, h = 22, text = "Arkadaşınız yanınıza geldiğinde burada listelenir.", textColor = {143,153,164}, size = 10
        }, invitePanel)
    else
        for idx, ply in ipairs(nearbyPlayersList) do
            if idx <= 5 and isElement(ply) then
                local itemY = 48 + (idx - 1) * 54
                local pBox = ui:uiCreate("panel", {
                    x = 14, y = itemY, w = 382, h = 46, color = {30,34,39}, radius = 6
                }, invitePanel)

                ui:uiCreate("label", {
                    x = 14, y = 0, w = 260, h = 46, text = getPlayerName(ply), bold = true, size = 11
                }, pBox)

                if activeLobbyData and activeLobbyData.isGroup and isLeader() then
                    local invBtn = ui:uiCreate("button", {
                        x = 382 - 14 - 90, y = 8, w = 90, h = 30,
                        text = "Davet Et", variant = "primary", tone = "success", size = 11
                    }, pBox)

                    addEventHandler("onAuraClick", invBtn, function()
                        triggerServerEvent("windowCleaning:invitePlayer", localPlayer, ply)
                        exports.aura_ui:uiToast("Davet Gönderildi", getPlayerName(ply) .. " adlı oyuncuya iş daveti iletildi.", "info")
                    end, false)
                end
            end
        end
    end
end

addEventHandler("onClientKey", root, function(button, press)
    if press and button == "escape" and LobbyUI.isOpen() then
        LobbyUI.close()
        cancelEvent()
    end
end)
