

local screenW, screenH = guiGetScreenSize()
local baseW, baseH = 1920, 1080
local scale = math.max(0.75, math.min(1.2, screenH / 1080))

local isPanelOpen = false
local animAlpha = 0
local activeTab = 1
local lastDataRequestTick = 0

local factionData = nil
local playerData = nil
local memberList = {}
local vaultLogs = {}
local nearbyPlayers = {}
local onlineCount = 0
local totalCount = 0

local rosterSearchText = ""
local rosterFilter = "all" -- "all", "online", "duty"
local rosterScroll = 0
local maxVisibleRosterRows = 7
local rankScroll = 0

local vaultDepositAmount = ""
local vaultDepositReason = ""
local vaultWithdrawAmount = ""
local vaultWithdrawReason = ""
local vaultScroll = 0

local isInviteModalOpen = false
local inviteTargetInput = ""
local inviteSelectedRank = 1
local inviteSelectedNearby = nil

local kickConfirmTarget = nil -- { charId = X, name = "..." }

local activeInvitePrompt = nil -- { faction_id, faction_name, faction_short, sender_name, rank_id, rank_name, expires, duration }
local invitePromptAlpha = 0

local activeEditBox = nil
local editBoxBlinkTick = 0

local function uLen(s)
    if not s then return 0 end
    if utf8 and utf8.len then
        local l = utf8.len(s)
        if l then return l end
    end
    return string.len(s)
end

local function uSub(s, i, j)
    if not s then return "" end
    if utf8 and utf8.sub then
        return utf8.sub(s, i, j)
    end
    if utf8 and utf8.offset and utf8.len then
        local len = utf8.len(s)
        if not len then return string.sub(s, i, j) end
        if i < 0 then i = len + i + 1 end
        if j and j < 0 then j = len + j + 1 end
        j = j or len
        if i > len or j < i or j < 1 then return "" end
        i = math.max(1, i)
        j = math.min(len, j)
        local byteStart = utf8.offset(s, i)
        local byteEnd = utf8.offset(s, j + 1)
        if byteEnd then
            byteEnd = byteEnd - 1
        else
            byteEnd = #s
        end
        return string.sub(s, byteStart, byteEnd)
    end
    return string.sub(s, i, j)
end

local function setActiveField(fieldId)
    activeEditBox = fieldId
    if activeEditBox then
        pcall(guiSetInputMode, "no_binds")
        pcall(guiSetInputEnabled, true)
    else
        pcall(guiSetInputMode, "allow_binds")
        pcall(guiSetInputEnabled, false)
    end
end

local fonts = {}
local function getUIFont(weight, size)
    local actualSize = math.max(8, math.floor(size * scale))
    local key = weight .. "_" .. actualSize
    if not fonts[key] then
        if exports.gzl_ui and exports.gzl_ui.getFont then
            fonts[key] = exports.gzl_ui:getFont(weight, actualSize)
        end
        if not fonts[key] or not isElement(fonts[key]) then
            if weight == "bold" or weight == "heavy" or weight == "semibold" then
                fonts[key] = "default-bold"
            else
                fonts[key] = "default"
            end
        end
    end
    return fonts[key]
end

local function isMouseInPosition(x, y, w, h)
    if not isCursorShowing() then return false end
    local cx, cy = getCursorPosition()
    if not cx or not cy then return false end
    cx, cy = cx * screenW, cy * screenH
    return (cx >= x and cx <= x + w and cy >= y and cy <= y + h)
end

local function formatCurrency(amount)
    amount = math.floor(tonumber(amount) or 0)
    local sign = (amount < 0) and "-" or ""
    local s = tostring(math.abs(amount))
    local pos = string.len(s) % 3
    if pos == 0 then pos = 3 end
    return sign .. "$" .. string.sub(s, 1, pos) .. string.gsub(string.sub(s, pos + 1), "(%d%d%d)", ".%1")
end

local function notifyUser(msgType, text)
    if exports.gzl_ui and exports.gzl_ui.showNotification then
        exports.gzl_ui:showNotification(msgType, text)
    elseif exports.gzl_ui and exports.gzl_ui.showToast then
        exports.gzl_ui:showToast(text, msgType)
    else
        local prefix = (msgType == "success") and "#34d399[BAŞARILI] " or ((msgType == "error") and "#ef4444[HATA] " or "#38bdf8[BİLGİ] ")
        outputChatBox(prefix .. "#ffffff" .. tostring(text), 255, 255, 255, true)
    end
end

local lastToggleTick = 0
function openFactionPanel()
    if isPanelOpen then return end
    local now = getTickCount()
    if (now - lastToggleTick) < 300 then return end
    lastToggleTick = now

    local isLogged = getElementData(localPlayer, "loggedin_character") or getElementData(localPlayer, "character:id") or getElementData(localPlayer, "char:id")
    if not isLogged then return end

    local pFaction = getElementData(localPlayer, "character:faction") or getElementData(localPlayer, "faction") or getElementData(localPlayer, "faction:id")
    local fId = tonumber(pFaction)
    if not fId or fId <= 0 then
        notifyUser("error", "Herhangi bir birliğe üye değilsiniz!")
        return
    end

    isPanelOpen = true
    showCursor(true)
    setActiveField(nil)
    rosterScroll = 0
    vaultScroll = 0
    rankScroll = 0
    isInviteModalOpen = false
    kickConfirmTarget = nil

    triggerServerEvent("faction:requestPanelData", resourceRoot)
    lastDataRequestTick = getTickCount()
end

function closeFactionPanel()
    if not isPanelOpen then return end
    isPanelOpen = false
    setActiveField(nil)
    isInviteModalOpen = false
    kickConfirmTarget = nil
    showCursor(false)
end

function toggleFactionPanel()
    if isPanelOpen then
        closeFactionPanel()
    else
        openFactionPanel()
    end
end

local cmdAliases = FactionConfig and FactionConfig.CommandAliases or { "fpanel", "faction", "birlik" }
for _, alias in ipairs(cmdAliases) do
    addCommandHandler(alias, toggleFactionPanel)
end

local panelKey = FactionConfig and FactionConfig.PanelKey or "F6"
bindKey(panelKey, "down", function()
    if isChatBoxInputActive and isChatBoxInputActive() then return end
    if isConsoleActive and isConsoleActive() then return end
    if isPanelOpen then
        closeFactionPanel()
    else
        if exports.gzl_ui and exports.gzl_ui.isPlayerTyping and exports.gzl_ui:isPlayerTyping() then
            return
        end
        openFactionPanel()
    end
end)

addEvent("faction:receivePanelData", true)
addEventHandler("faction:receivePanelData", root, function(payload, errorMsg)
    if errorMsg then
        notifyUser("error", errorMsg)
        if isPanelOpen then
            closeFactionPanel()
        end
        return
    end

    if type(payload) == "table" then
        factionData = payload.faction
        playerData = payload.player
        memberList = payload.members or {}
        vaultLogs = payload.vaultLogs or {}
        nearbyPlayers = payload.nearbyPlayers or {}
        onlineCount = payload.onlineCount or 0
        totalCount = payload.totalCount or #memberList

        if playerData and playerData.cash then
        end
    end
end)

addEvent("faction:actionResponse", true)
addEventHandler("faction:actionResponse", root, function(success, message)
    if success then
        notifyUser("success", message)
        triggerServerEvent("faction:requestPanelData", resourceRoot)
    else
        notifyUser("error", message)
    end
end)

addEvent("faction:dutyUpdated", true)
addEventHandler("faction:dutyUpdated", root, function(newDuty)
    if playerData then
        playerData.duty = newDuty
    end
    notifyUser("info", newDuty and "Mesaiye başladınız (Aktif Görevde)." or "Mesaiden ayrıldınız (İzinli).")
    triggerServerEvent("faction:requestPanelData", resourceRoot)
end)

addEvent("faction:vaultUpdated", true)
addEventHandler("faction:vaultUpdated", root, function(newBalance, newLogs, pCash)
    if factionData then
        factionData.vault_balance = newBalance
    end
    if type(newLogs) == "table" then
        vaultLogs = newLogs
    end
    if playerData and pCash then
        playerData.cash = pCash
    end
    vaultDepositAmount = ""
    vaultDepositReason = ""
    vaultWithdrawAmount = ""
    vaultWithdrawReason = ""
    setActiveField(nil)
end)

addEvent("faction:showInvitePrompt", true)
addEventHandler("faction:showInvitePrompt", root, function(inviteInfo)
    if type(inviteInfo) == "table" then
        activeInvitePrompt = inviteInfo
        activeInvitePrompt.expires = getTickCount() + ((inviteInfo.duration or 60) * 1000)
        invitePromptAlpha = 0
    end
end)

addEventHandler("onClientCharacter", root, function(char)
    if not isPanelOpen or not activeEditBox then return end

    if activeEditBox == "roster_search" then
        if #rosterSearchText < 24 then
            rosterSearchText = rosterSearchText .. char
            rosterScroll = 0
        end
    elseif activeEditBox == "vault_dep_amount" then
        if char:match("%d") and #vaultDepositAmount < 9 then
            vaultDepositAmount = vaultDepositAmount .. char
        end
    elseif activeEditBox == "vault_dep_reason" then
        if #vaultDepositReason < 40 then
            vaultDepositReason = vaultDepositReason .. char
        end
    elseif activeEditBox == "vault_with_amount" then
        if char:match("%d") and #vaultWithdrawAmount < 9 then
            vaultWithdrawAmount = vaultWithdrawAmount .. char
        end
    elseif activeEditBox == "vault_with_reason" then
        if #vaultWithdrawReason < 40 then
            vaultWithdrawReason = vaultWithdrawReason .. char
        end
    elseif activeEditBox == "invite_target" then
        if #inviteTargetInput < 24 then
            inviteTargetInput = inviteTargetInput .. char
            inviteSelectedNearby = nil
        end
    end
end)

addEventHandler("onClientKey", root, function(button, press)
    if not press then return end

    if activeInvitePrompt and not isPanelOpen then
        local isTypingAnywhere = (isChatBoxInputActive and isChatBoxInputActive())
            or (isConsoleActive and isConsoleActive())
            or (guiGetInputEnabled and guiGetInputEnabled())
            or (exports.gzl_ui and exports.gzl_ui.isPlayerTyping and exports.gzl_ui:isPlayerTyping())

        if not isTypingAnywhere then
            if button == "y" then
                cancelEvent()
                triggerServerEvent("faction:respondInvite", resourceRoot, true)
                activeInvitePrompt = nil
                return
            elseif button == "n" then
                cancelEvent()
                triggerServerEvent("faction:respondInvite", resourceRoot, false)
                activeInvitePrompt = nil
                return
            end
        end
    end

    if not isPanelOpen then return end

    if button == "escape" then
        cancelEvent()
        if kickConfirmTarget then
            kickConfirmTarget = nil
            return
        end
        if isInviteModalOpen then
            isInviteModalOpen = false
            setActiveField(nil)
            return
        end
        if activeEditBox then
            setActiveField(nil)
            return
        end
        closeFactionPanel()
        return
    end

    if activeEditBox then
        local isCtrl = (getKeyState and (getKeyState("lctrl") or getKeyState("rctrl")))
        if isCtrl and button == "v" then
            local clip = (getClipboard and getClipboard()) or ""
            if type(clip) == "string" and #clip > 0 then
                clip = clip:gsub("[\r\n\t]", "")
                if activeEditBox == "roster_search" then
                    local rem = 24 - uLen(rosterSearchText)
                    if rem > 0 then
                        rosterSearchText = rosterSearchText .. uSub(clip, 1, rem)
                        rosterScroll = 0
                    end
                elseif activeEditBox == "vault_dep_amount" then
                    local digitsOnly = clip:gsub("%D", "")
                    local rem = 9 - #vaultDepositAmount
                    if rem > 0 and #digitsOnly > 0 then
                        vaultDepositAmount = vaultDepositAmount .. digitsOnly:sub(1, rem)
                    end
                elseif activeEditBox == "vault_dep_reason" then
                    local rem = 40 - uLen(vaultDepositReason)
                    if rem > 0 then
                        vaultDepositReason = vaultDepositReason .. uSub(clip, 1, rem)
                    end
                elseif activeEditBox == "vault_with_amount" then
                    local digitsOnly = clip:gsub("%D", "")
                    local rem = 9 - #vaultWithdrawAmount
                    if rem > 0 and #digitsOnly > 0 then
                        vaultWithdrawAmount = vaultWithdrawAmount .. digitsOnly:sub(1, rem)
                    end
                elseif activeEditBox == "vault_with_reason" then
                    local rem = 40 - uLen(vaultWithdrawReason)
                    if rem > 0 then
                        vaultWithdrawReason = vaultWithdrawReason .. uSub(clip, 1, rem)
                    end
                elseif activeEditBox == "invite_target" then
                    local rem = 24 - uLen(inviteTargetInput)
                    if rem > 0 then
                        inviteTargetInput = inviteTargetInput .. uSub(clip, 1, rem)
                        inviteSelectedNearby = nil
                    end
                end
            end
            cancelEvent()
            return
        end

        if button == "backspace" then
            cancelEvent()
            if activeEditBox == "roster_search" then
                if uLen(rosterSearchText) > 0 then
                    rosterSearchText = uSub(rosterSearchText, 1, -2)
                    rosterScroll = 0
                end
            elseif activeEditBox == "vault_dep_amount" then
                if #vaultDepositAmount > 0 then
                    vaultDepositAmount = string.sub(vaultDepositAmount, 1, -2)
                end
            elseif activeEditBox == "vault_dep_reason" then
                if uLen(vaultDepositReason) > 0 then
                    vaultDepositReason = uSub(vaultDepositReason, 1, -2)
                end
            elseif activeEditBox == "vault_with_amount" then
                if #vaultWithdrawAmount > 0 then
                    vaultWithdrawAmount = string.sub(vaultWithdrawAmount, 1, -2)
                end
            elseif activeEditBox == "vault_with_reason" then
                if uLen(vaultWithdrawReason) > 0 then
                    vaultWithdrawReason = uSub(vaultWithdrawReason, 1, -2)
                end
            elseif activeEditBox == "invite_target" then
                if uLen(inviteTargetInput) > 0 then
                    inviteTargetInput = uSub(inviteTargetInput, 1, -2)
                    inviteSelectedNearby = nil
                end
            end
            return
        elseif button == "tab" then
            cancelEvent()
            if activeEditBox == "vault_dep_amount" then
                setActiveField("vault_dep_reason")
            elseif activeEditBox == "vault_dep_reason" then
                setActiveField("vault_dep_amount")
            elseif activeEditBox == "vault_with_amount" then
                setActiveField("vault_with_reason")
            elseif activeEditBox == "vault_with_reason" then
                setActiveField("vault_with_amount")
            end
            return
        elseif button == "enter" or button == "num_enter" then
            setActiveField(nil)
            cancelEvent()
            return
        end
    end

    if button == "mouse_wheel_up" then
        if activeTab == 2 and not isInviteModalOpen then
            if rosterScroll > 0 then
                rosterScroll = rosterScroll - 1
            end
        elseif activeTab == 3 then
            if vaultScroll > 0 then
                vaultScroll = vaultScroll - 1
            end
        elseif activeTab == 4 then
            if rankScroll > 0 then
                rankScroll = rankScroll - 1
            end
        end
    elseif button == "mouse_wheel_down" then
        if activeTab == 2 and not isInviteModalOpen then
            rosterScroll = rosterScroll + 1
        elseif activeTab == 3 then
            vaultScroll = vaultScroll + 1
        elseif activeTab == 4 then
            rankScroll = rankScroll + 1
        end
    end
end)

local function drawGlassCard(x, y, w, h, radius, alphaMult, strokeColor)
    radius = radius or 12
    local bgAlpha = math.floor(240 * alphaMult)
    if exports.gzl_ui and exports.gzl_ui.drawGlassPanel then
        exports.gzl_ui:drawGlassPanel(x, y, w, h, radius, tocolor(255, 255, 255, math.floor(255 * alphaMult)))
    else
        exports.aura_ui:uiDrawRectangle(x, y, w, h, tocolor(15, 23, 42, bgAlpha))
    end
    if strokeColor then
        if exports.gzl_ui and exports.gzl_ui.drawRoundedBorder then
            exports.gzl_ui:drawRoundedBorder(x, y, w, h, radius, 1.0, strokeColor)
        else
            exports.aura_ui:uiDrawRectangle(x, y, w, 1, strokeColor)
            exports.aura_ui:uiDrawRectangle(x, y + h - 1, w, 1, strokeColor)
            exports.aura_ui:uiDrawRectangle(x, y, 1, h, strokeColor)
            exports.aura_ui:uiDrawRectangle(x + w - 1, y, 1, h, strokeColor)
        end
    end
end

local function drawSubPanel(x, y, w, h, radius, alphaMult, fillAlpha)
    radius = radius or 10
    fillAlpha = fillAlpha or 160
    local c = tocolor(20, 29, 47, math.floor(fillAlpha * alphaMult))
    local borderC = tocolor(255, 255, 255, math.floor(18 * alphaMult))
    if exports.gzl_ui and exports.gzl_ui.drawRoundedRectangle then
        exports.gzl_ui:drawRoundedRectangle(x, y, w, h, radius, c)
        exports.gzl_ui:drawRoundedBorder(x, y, w, h, radius, 1.0, borderC)
    else
        exports.aura_ui:uiDrawRectangle(x, y, w, h, c)
    end
end

local function drawCustomInput(fieldId, x, y, w, h, placeholder, textVal, font, alphaMult)
    local isActive = (activeEditBox == fieldId)
    local isHov = isMouseInPosition(x, y, w, h)
    local bgAlpha = isActive and 220 or (isHov and 170 or 120)
    local borderC = isActive and tocolor(56, 189, 248, math.floor(230 * alphaMult)) or (isHov and tocolor(148, 163, 184, math.floor(120 * alphaMult)) or tocolor(51, 65, 85, math.floor(90 * alphaMult)))

    if exports.gzl_ui and exports.gzl_ui.drawRoundedRectangle then
        exports.gzl_ui:drawRoundedRectangle(x, y, w, h, 8, tocolor(15, 23, 42, math.floor(bgAlpha * alphaMult)))
        exports.gzl_ui:drawRoundedBorder(x, y, w, h, 8, 1.0, borderC)
    else
        exports.aura_ui:uiDrawRectangle(x, y, w, h, tocolor(15, 23, 42, math.floor(bgAlpha * alphaMult)))
    end

    local textToRender = textVal or ""
    if #textToRender == 0 and not isActive then
        exports.aura_ui:uiDrawText(placeholder, x + 10 * scale, y, x + w - 10 * scale, y + h, tocolor(148, 163, 184, math.floor(150 * alphaMult)), 1, font, "left", "center", true)
    else
        local cursor = ""
        if isActive and (getTickCount() % 1000 < 500) then
            cursor = "|"
        end
        exports.aura_ui:uiDrawText(textToRender .. cursor, x + 10 * scale, y, x + w - 10 * scale, y + h, tocolor(255, 255, 255, math.floor(240 * alphaMult)), 1, font, "left", "center", true)
    end

    return isHov
end

local function drawScrollBar(x, y, w, h, totalItems, visibleItems, currentScroll, alphaMult, themeColor)
    if totalItems <= visibleItems or visibleItems <= 0 then return end
    local trackBg = tocolor(15, 23, 42, math.floor(110 * alphaMult))
    local thumbColor = themeColor or tocolor(56, 189, 248, math.floor(180 * alphaMult))

    if exports.gzl_ui and exports.gzl_ui.drawRoundedRectangle then
        exports.gzl_ui:drawRoundedRectangle(x, y, w, h, math.floor(w / 2), trackBg)
    else
        exports.aura_ui:uiDrawRectangle(x, y, w, h, trackBg)
    end

    local thumbH = math.max(16 * scale, math.floor(h * (visibleItems / totalItems)))
    local maxScroll = math.max(1, totalItems - visibleItems)
    local thumbY = y + math.floor((h - thumbH) * (currentScroll / maxScroll))

    if exports.gzl_ui and exports.gzl_ui.drawRoundedRectangle then
        exports.gzl_ui:drawRoundedRectangle(x, thumbY, w, thumbH, math.floor(w / 2), thumbColor)
    else
        exports.aura_ui:uiDrawRectangle(x, thumbY, w, thumbH, thumbColor)
    end
end

local function drawActionButton(id, text, x, y, w, h, theme, alphaMult, font)
    local isHov = isMouseInPosition(x, y, w, h)
    local btnAlpha = isHov and 240 or 190

    local drawn = false
    if exports.gzl_ui and exports.gzl_ui.drawLiquidButtonSVG then
        local svgTheme = theme
        if svgTheme == "amber" then svgTheme = "blue" end
        exports.gzl_ui:drawLiquidButtonSVG(x, y, w, h, 8, svgTheme, isHov and "hover" or "normal")
        drawn = true
    end

    if not drawn then
        local bgC, borderC
        if theme == "green" then
            bgC = isHov and tocolor(16, 185, 129, math.floor(btnAlpha * alphaMult)) or tocolor(5, 150, 105, math.floor(btnAlpha * alphaMult))
            borderC = tocolor(52, 211, 153, math.floor(200 * alphaMult))
        elseif theme == "red" or theme == "danger" then
            bgC = isHov and tocolor(239, 68, 68, math.floor(btnAlpha * alphaMult)) or tocolor(220, 38, 38, math.floor(btnAlpha * alphaMult))
            borderC = tocolor(248, 113, 113, math.floor(200 * alphaMult))
        elseif theme == "amber" then
            bgC = isHov and tocolor(245, 158, 11, math.floor(btnAlpha * alphaMult)) or tocolor(217, 119, 6, math.floor(btnAlpha * alphaMult))
            borderC = tocolor(251, 191, 36, math.floor(200 * alphaMult))
        else
            bgC = isHov and tocolor(56, 189, 248, math.floor(btnAlpha * alphaMult)) or tocolor(2, 132, 199, math.floor(btnAlpha * alphaMult))
            borderC = tocolor(125, 211, 252, math.floor(200 * alphaMult))
        end

        if exports.gzl_ui and exports.gzl_ui.drawRoundedRectangle then
            exports.gzl_ui:drawRoundedRectangle(x, y, w, h, 8, bgC)
            exports.gzl_ui:drawRoundedBorder(x, y, w, h, 8, 1.0, borderC)
        else
            exports.aura_ui:uiDrawRectangle(x, y, w, h, bgC)
        end
    end

    exports.aura_ui:uiDrawText(text, x, y, x + w, y + h, tocolor(255, 255, 255, math.floor(255 * alphaMult)), 1, font, "center", "center", true)
    return isHov
end

addEventHandler("onClientRender", root, function()
    local now = getTickCount()

    if activeInvitePrompt then
        local remTime = math.max(0, math.floor((activeInvitePrompt.expires - now) / 1000))
        if remTime <= 0 then
            activeInvitePrompt = nil
        else
            invitePromptAlpha = invitePromptAlpha + (1 - invitePromptAlpha) * 0.15
            local pAlpha = math.min(1, math.max(0, invitePromptAlpha))
            local cardW = math.floor(480 * scale)
            local cardH = math.floor(130 * scale)
            local cardX = math.floor((screenW - cardW) / 2)
            local cardY = math.floor(40 * scale)

            drawGlassCard(cardX, cardY, cardW, cardH, 14, pAlpha, tocolor(56, 189, 248, math.floor(180 * pAlpha)))

            local fontTitle = getUIFont("bold", 12)
            local fontSub = getUIFont("regular", 10)
            local fontBold = getUIFont("bold", 10)

            exports.aura_ui:uiDrawText("BİRLİK DAVETİ ALINDI (" .. remTime .. "s)", cardX + 16 * scale, cardY + 12 * scale, cardX + cardW - 16 * scale, cardY + 28 * scale, tocolor(56, 189, 248, math.floor(255 * pAlpha)), 1, fontTitle, "left", "center")
            local desc = string.format("%s adlı yetkili sizi %s birliğine davet etti.\nTeklif Edilen Rütbe: %s", activeInvitePrompt.sender_name or "Yetkili", activeInvitePrompt.faction_name or "Birlik", activeInvitePrompt.rank_name or "Üye")
            exports.aura_ui:uiDrawText(desc, cardX + 16 * scale, cardY + 34 * scale, cardX + cardW - 16 * scale, cardY + 76 * scale, tocolor(241, 245, 249, math.floor(230 * pAlpha)), 1, fontSub, "left", "top")

            local btnW = math.floor((cardW - 40 * scale) / 2)
            local btnH = math.floor(34 * scale)
            local btnY = cardY + cardH - btnH - 12 * scale

            drawActionButton("prompt_accept", "[Y] KABUL ET", cardX + 16 * scale, btnY, btnW, btnH, "green", pAlpha, fontBold)
            drawActionButton("prompt_reject", "[N] REDDET", cardX + 24 * scale + btnW, btnY, btnW, btnH, "red", pAlpha, fontBold)
        end
    end

    if not isPanelOpen and animAlpha <= 0 then return end

    local targetAlpha = isPanelOpen and 1 or 0
    animAlpha = animAlpha + (targetAlpha - animAlpha) * 0.18
    if animAlpha < 0.01 and not isPanelOpen then return end

    local alphaMult = math.min(1, math.max(0, animAlpha))
    local globalAlpha = math.floor(255 * alphaMult)

    local fontHeaderTitle = getUIFont("bold", 14)
    local fontHeaderSub = getUIFont("medium", 9.5)
    local fontTab = getUIFont("bold", 10.5)
    local fontBody = getUIFont("regular", 10)
    local fontBodyBold = getUIFont("bold", 10)
    local fontLarge = getUIFont("heavy", 20)
    local fontSmall = getUIFont("regular", 8.5)

    local panelW = math.floor(960 * scale)
    local panelH = math.floor(620 * scale)
    local panelX = math.floor((screenW - panelW) / 2)
    local panelY = math.floor((screenH - panelH) / 2)

    exports.aura_ui:uiDrawRectangle(0, 0, screenW, screenH, tocolor(5, 8, 14, math.floor(140 * alphaMult)))

    local fType = factionData and factionData.type or "default"
    local theme = FactionConfig and FactionConfig.getTypeTheme(fType) or { color = { 56, 189, 248 } }
    local accentColor = tocolor(theme.color[1], theme.color[2], theme.color[3], math.floor(160 * alphaMult))

    drawGlassCard(panelX, panelY, panelW, panelH, 16, alphaMult, tocolor(255, 255, 255, math.floor(35 * alphaMult)))

    local headerH = math.floor(70 * scale)
    if exports.gzl_ui and exports.gzl_ui.drawRoundedRectangle then
        exports.gzl_ui:drawRoundedRectangle(panelX + 2, panelY + 2, panelW - 4, headerH, 14, tocolor(24, 34, 53, math.floor(180 * alphaMult)))
    else
        exports.aura_ui:uiDrawRectangle(panelX + 2, panelY + 2, panelW - 4, headerH, tocolor(24, 34, 53, math.floor(180 * alphaMult)))
    end

    exports.aura_ui:uiDrawRectangle(panelX + 30 * scale, panelY + 2, panelW - 60 * scale, 2, accentColor)

    local logoSize = math.floor(46 * scale)
    local logoX = panelX + math.floor(20 * scale)
    local logoY = panelY + math.floor((headerH - logoSize) / 2)

    if exports.gzl_ui and exports.gzl_ui.drawRoundedRectangle then
        exports.gzl_ui:drawRoundedRectangle(logoX, logoY, logoSize, logoSize, 10, tocolor(theme.color[1], theme.color[2], theme.color[3], math.floor(220 * alphaMult)))
    else
        exports.aura_ui:uiDrawRectangle(logoX, logoY, logoSize, logoSize, tocolor(theme.color[1], theme.color[2], theme.color[3], math.floor(220 * alphaMult)))
    end

    local iconDrawn = false
    local iconName = theme.icon or "shield"
    if exports.gzl_ui and exports.gzl_ui.drawIconSVG then
        local iconPad = math.floor(10 * scale)
        local iconSz = logoSize - iconPad * 2
        exports.gzl_ui:drawIconSVG(iconName, logoX + iconPad, logoY + iconPad, iconSz, tocolor(15, 23, 42, globalAlpha))
        iconDrawn = true
    end
    if not iconDrawn then
        local emblemText = factionData and (factionData.short_name or "GZL") or "GZL"
        exports.aura_ui:uiDrawText(string.sub(emblemText, 1, 4), logoX, logoY, logoX + logoSize, logoY + logoSize, tocolor(15, 23, 42, globalAlpha), 1, fontTab, "center", "center")
    end

    local fTitle = factionData and factionData.name or "Birlik Sistemi"
    local fSub = string.format("[%s] • %s • ÜYELER: %d/%d", factionData and factionData.short_name or "TAG", theme.title or "Teşkilat", onlineCount, totalCount)
    exports.aura_ui:uiDrawText(fTitle, logoX + logoSize + 14 * scale, panelY + 14 * scale, panelX + panelW - 240 * scale, panelY + 36 * scale, tocolor(255, 255, 255, globalAlpha), 1, fontHeaderTitle, "left", "center", true)
    exports.aura_ui:uiDrawText(fSub, logoX + logoSize + 14 * scale, panelY + 38 * scale, panelX + panelW - 240 * scale, panelY + 56 * scale, tocolor(148, 163, 184, math.floor(210 * alphaMult)), 1, fontHeaderSub, "left", "center", true)

    local closeSize = math.floor(34 * scale)
    local closeX = panelX + panelW - closeSize - 18 * scale
    local closeY = panelY + math.floor((headerH - closeSize) / 2)
    local isCloseHov = isMouseInPosition(closeX, closeY, closeSize, closeSize)
    local closeBg = isCloseHov and tocolor(239, 68, 68, math.floor(230 * alphaMult)) or tocolor(51, 65, 85, math.floor(130 * alphaMult))

    if exports.gzl_ui and exports.gzl_ui.drawRoundedRectangle then
        exports.gzl_ui:drawRoundedRectangle(closeX, closeY, closeSize, closeSize, 8, closeBg)
    else
        exports.aura_ui:uiDrawRectangle(closeX, closeY, closeSize, closeSize, closeBg)
    end
    exports.aura_ui:uiDrawText("✕", closeX, closeY, closeX + closeSize, closeY + closeSize, tocolor(255, 255, 255, globalAlpha), 1, fontBodyBold, "center", "center")

    local isOnDuty = playerData and (playerData.duty == true)
    local dutyBtnW = math.floor(140 * scale)
    local dutyBtnH = math.floor(36 * scale)
    local dutyBtnX = closeX - dutyBtnW - 14 * scale
    local dutyBtnY = panelY + math.floor((headerH - dutyBtnH) / 2)
    local isDutyHov = isMouseInPosition(dutyBtnX, dutyBtnY, dutyBtnW, dutyBtnH)

    local pulse = math.abs(math.sin(now / 350))
    local dutyDotColor = isOnDuty and tocolor(34, 197, 94, math.floor((180 + 75 * pulse) * alphaMult)) or tocolor(148, 163, 184, math.floor(160 * alphaMult))
    local dutyBgColor = isOnDuty and (isDutyHov and tocolor(20, 83, 45, math.floor(240 * alphaMult)) or tocolor(10, 58, 30, math.floor(220 * alphaMult))) or (isDutyHov and tocolor(40, 50, 70, math.floor(220 * alphaMult)) or tocolor(24, 32, 47, math.floor(180 * alphaMult)))
    local dutyBorderColor = isOnDuty and tocolor(34, 197, 94, math.floor(190 * alphaMult)) or tocolor(71, 85, 105, math.floor(120 * alphaMult))

    if exports.gzl_ui and exports.gzl_ui.drawRoundedRectangle then
        exports.gzl_ui:drawRoundedRectangle(dutyBtnX, dutyBtnY, dutyBtnW, dutyBtnH, 8, dutyBgColor)
        exports.gzl_ui:drawRoundedBorder(dutyBtnX, dutyBtnY, dutyBtnW, dutyBtnH, 8, 1.0, dutyBorderColor)
    else
        exports.aura_ui:uiDrawRectangle(dutyBtnX, dutyBtnY, dutyBtnW, dutyBtnH, dutyBgColor)
    end

    local dDotSize = math.floor(8 * scale)
    local dDotX = dutyBtnX + 12 * scale
    local dDotY = dutyBtnY + math.floor((dutyBtnH - dDotSize) / 2)
    if exports.gzl_ui and exports.gzl_ui.drawCircle then
        exports.gzl_ui:drawCircle(dDotX + dDotSize * 0.5, dDotY + dDotSize * 0.5, dDotSize * 0.5, dutyDotColor)
    elseif exports.gzl_ui and exports.gzl_ui.drawRoundedRectangle then
        exports.gzl_ui:drawRoundedRectangle(dDotX, dDotY, dDotSize, dDotSize, math.floor(dDotSize / 2), dutyDotColor)
    else
        exports.aura_ui:uiDrawRectangle(dDotX, dDotY, dDotSize, dDotSize, dutyDotColor)
    end
    local dutyStr = isOnDuty and "MESAİDE [ON]" or "İZİNLİ [OFF]"
    exports.aura_ui:uiDrawText(dutyStr, dutyBtnX + 26 * scale, dutyBtnY, dutyBtnX + dutyBtnW - 6 * scale, dutyBtnY + dutyBtnH, tocolor(255, 255, 255, globalAlpha), 1, fontBodyBold, "center", "center")

    local tabBarY = panelY + headerH + math.floor(10 * scale)
    local tabH = math.floor(40 * scale)
    local tabs = {
        { id = 1, title = "Genel Bakış" },
        { id = 2, title = string.format("Üye Kadrosu (%d/%d)", onlineCount, totalCount) },
        { id = 3, title = string.format("Birlik Kasası (%s)", formatCurrency(factionData and factionData.vault_balance or 0)) },
        { id = 4, title = "Rütbeler & Yetki" }
    }

    local tabGap = math.floor(10 * scale)
    local tabW = math.floor((panelW - 40 * scale - (#tabs - 1) * tabGap) / #tabs)

    for i, tab in ipairs(tabs) do
        local tabX = panelX + 20 * scale + (i - 1) * (tabW + tabGap)
        local isCurrent = (activeTab == tab.id)
        local isHov = isMouseInPosition(tabX, tabBarY, tabW, tabH)

        local tabBg = isCurrent and tocolor(theme.color[1], theme.color[2], theme.color[3], math.floor(210 * alphaMult)) or (isHov and tocolor(30, 41, 59, math.floor(180 * alphaMult)) or tocolor(15, 23, 42, math.floor(120 * alphaMult)))
        local tabTextColor = isCurrent and tocolor(15, 23, 42, globalAlpha) or (isHov and tocolor(255, 255, 255, globalAlpha) or tocolor(148, 163, 184, math.floor(210 * alphaMult)))

        if exports.gzl_ui and exports.gzl_ui.drawRoundedRectangle then
            exports.gzl_ui:drawRoundedRectangle(tabX, tabBarY, tabW, tabH, 8, tabBg)
            if not isCurrent and isHov then
                exports.gzl_ui:drawRoundedBorder(tabX, tabBarY, tabW, tabH, 8, 1.0, tocolor(theme.color[1], theme.color[2], theme.color[3], math.floor(80 * alphaMult)))
            end
        else
            exports.aura_ui:uiDrawRectangle(tabX, tabBarY, tabW, tabH, tabBg)
        end

        exports.aura_ui:uiDrawText(tab.title, tabX, tabBarY, tabX + tabW, tabBarY + tabH, tabTextColor, 1, fontTab, "center", "center", true)
    end

    local contentX = panelX + math.floor(20 * scale)
    local contentY = tabBarY + tabH + math.floor(12 * scale)
    local contentW = panelW - math.floor(40 * scale)
    local contentH = panelH - (contentY - panelY) - math.floor(16 * scale)

    if activeTab == 1 then
        local leftW = math.floor(contentW * 0.58)
        local rightW = contentW - leftW - math.floor(14 * scale)
        local rightX = contentX + leftW + math.floor(14 * scale)

        local cardH1 = math.floor(130 * scale)
        drawSubPanel(contentX, contentY, leftW, cardH1, 12, alphaMult, 140)

        exports.aura_ui:uiDrawText("PERSONEL GÖREV KARTI & DURUM", contentX + 16 * scale, contentY + 12 * scale, contentX + leftW, contentY + 28 * scale, tocolor(148, 163, 184, math.floor(180 * alphaMult)), 1, fontSmall, "left", "center")

        local cName = playerData and playerData.character_name or "Giriş Yapılmadı"
        local rName = playerData and playerData.rank_name or "Rütbe Belirsiz"
        local rId = playerData and playerData.rank_id or 1
        local pSalary = 0
        if factionData and factionData.ranks and factionData.ranks[rId] then
            pSalary = factionData.ranks[rId].salary or 0
        end

        exports.aura_ui:uiDrawText(cName, contentX + 16 * scale, contentY + 32 * scale, contentX + leftW - 170 * scale, contentY + 56 * scale, tocolor(255, 255, 255, globalAlpha), 1, fontBodyBold, "left", "center", true)
        local rankAndPay = string.format("%s (Derece %d) • %s / saat", rName, rId, formatCurrency(pSalary))
        exports.aura_ui:uiDrawText(rankAndPay, contentX + 16 * scale, contentY + 56 * scale, contentX + leftW - 170 * scale, contentY + 74 * scale, tocolor(theme.color[1], theme.color[2], theme.color[3], math.floor(240 * alphaMult)), 1, fontBody, "left", "center", true)

        local dutyStatusStr = isOnDuty and "AKTİF MESAİDE (GÖREVDE)" or "İZİNLİ / PASİF DURUMDA"
        local dutyStatusCol = isOnDuty and tocolor(34, 197, 94, math.floor(240 * alphaMult)) or tocolor(148, 163, 184, math.floor(200 * alphaMult))
        exports.aura_ui:uiDrawText("VARDİYA: " .. dutyStatusStr, contentX + 16 * scale, contentY + 84 * scale, contentX + leftW - 170 * scale, contentY + 104 * scale, dutyStatusCol, 1, fontSmall, "left", "center")

        local dutyToggleW = math.floor(140 * scale)
        local dutyToggleH = math.floor(38 * scale)
        local dutyToggleX = contentX + leftW - dutyToggleW - 16 * scale
        local dutyToggleY = contentY + math.floor((cardH1 - dutyToggleH) / 2)
        local toggleText = isOnDuty and "Mesaiyi Bitir" or "Mesaiye Başla"
        drawActionButton("dash_duty_btn", toggleText, dutyToggleX, dutyToggleY, dutyToggleW, dutyToggleH, isOnDuty and "red" or "green", alphaMult, fontBodyBold)

        local botCardY = contentY + cardH1 + math.floor(12 * scale)
        local botCardH = contentH - cardH1 - math.floor(12 * scale)
        drawSubPanel(contentX, botCardY, leftW, botCardH, 12, alphaMult, 140)

        exports.aura_ui:uiDrawText("TAKTIK HABERLEŞME & TELSİZ SİSTEMİ", contentX + 16 * scale, botCardY + 14 * scale, contentX + leftW, botCardY + 32 * scale, tocolor(255, 255, 255, globalAlpha), 1, fontBodyBold, "left", "center")

        local freqBoxW = leftW - 32 * scale
        local freqBoxH = math.floor(76 * scale)
        local freqBoxX = contentX + 16 * scale
        local freqBoxY = botCardY + 38 * scale

        if exports.gzl_ui and exports.gzl_ui.drawRoundedRectangle then
            exports.gzl_ui:drawRoundedRectangle(freqBoxX, freqBoxY, freqBoxW, freqBoxH, 8, tocolor(12, 17, 29, math.floor(200 * alphaMult)))
            exports.gzl_ui:drawRoundedBorder(freqBoxX, freqBoxY, freqBoxW, freqBoxH, 8, 1.0, tocolor(theme.color[1], theme.color[2], theme.color[3], math.floor(80 * alphaMult)))
        else
            exports.aura_ui:uiDrawRectangle(freqBoxX, freqBoxY, freqBoxW, freqBoxH, tocolor(12, 17, 29, math.floor(200 * alphaMult)))
        end

        local assignedFreq = theme.channel or "155.0"
        local channelTitle = theme.channelName or (assignedFreq .. " MHz Taktik Frekansı")
        local encryptionTxt = theme.encryption or "MIL-SPEC Şifreli Telsiz Ağı"

        exports.aura_ui:uiDrawText(assignedFreq, freqBoxX + 16 * scale, freqBoxY + 10 * scale, freqBoxX + 140 * scale, freqBoxY + 44 * scale, tocolor(theme.color[1], theme.color[2], theme.color[3], globalAlpha), 1, fontLarge, "left", "center")
        exports.aura_ui:uiDrawText("MHz", freqBoxX + 88 * scale, freqBoxY + 18 * scale, freqBoxX + 160 * scale, freqBoxY + 40 * scale, tocolor(148, 163, 184, math.floor(200 * alphaMult)), 1, fontSmall, "left", "center")

        exports.aura_ui:uiDrawText(channelTitle, freqBoxX + 140 * scale, freqBoxY + 12 * scale, freqBoxX + freqBoxW - 165 * scale, freqBoxY + 30 * scale, tocolor(255, 255, 255, globalAlpha), 1, fontBodyBold, "left", "center", true)
        exports.aura_ui:uiDrawText("🔒 " .. encryptionTxt .. " • [Sivillere Kapalı]", freqBoxX + 140 * scale, freqBoxY + 32 * scale, freqBoxX + freqBoxW - 165 * scale, freqBoxY + 50 * scale, tocolor(52, 211, 153, math.floor(220 * alphaMult)), 1, fontSmall, "left", "center", true)

        local rConnW = math.floor(150 * scale)
        local rConnH = math.floor(36 * scale)
        local rConnX = freqBoxX + freqBoxW - rConnW - 12 * scale
        local rConnY = freqBoxY + math.floor((freqBoxH - rConnH) / 2)
        local connBtnText = string.format("Telsize Bağlan (%s)", assignedFreq)
        drawActionButton("dash_radio_connect", connBtnText, rConnX, rConnY, rConnW, rConnH, "blue", alphaMult, fontSmall)

        local guideY = freqBoxY + freqBoxH + math.floor(14 * scale)
        exports.aura_ui:uiDrawText("OPERASYONEL TELSİZ PROTOKOLÜ & TALİMATLAR", contentX + 16 * scale, guideY, contentX + leftW, guideY + 18 * scale, tocolor(148, 163, 184, math.floor(180 * alphaMult)), 1, fontSmall, "left", "center")

        local radioGuideTexts = {
            "• Teşkilat frekansına sivil telsizler erişemez; yetkisiz telsizler frekansa giremez.",
            "• Envanterinizdeki telsiz cihazından da " .. assignedFreq .. " MHz girerek telsize katılabilirsiniz.",
            "• Müşterek Acil Durum / Ortak Operasyon kanalı: 911.0 MHz (LSPD & EMS Ortak)",
            "• Taktik Telsiz Kodları: 10-4 (Anlaşıldı) | 10-20 (Konum) | 10-0 (Memur Vuruldu / Destek)"
        }
        local rgY = guideY + math.floor(22 * scale)
        for _, rgt in ipairs(radioGuideTexts) do
            exports.aura_ui:uiDrawText(rgt, contentX + 16 * scale, rgY, contentX + leftW - 16 * scale, rgY + 18 * scale, tocolor(203, 213, 225, math.floor(210 * alphaMult)), 1, fontSmall, "left", "center", true)
            rgY = rgY + 22 * scale
        end

        local rCardH1 = math.floor(175 * scale)
        drawSubPanel(rightX, contentY, rightW, rCardH1, 12, alphaMult, 140)
        exports.aura_ui:uiDrawText("BİRLİK KASASI & MALİ DURUM", rightX + 16 * scale, contentY + 14 * scale, rightX + rightW, contentY + 30 * scale, tocolor(148, 163, 184, math.floor(180 * alphaMult)), 1, fontSmall, "left", "center")
        exports.aura_ui:uiDrawText(formatCurrency(factionData and factionData.vault_balance or 0), rightX + 16 * scale, contentY + 34 * scale, rightX + rightW - 16 * scale, contentY + 70 * scale, tocolor(52, 211, 153, globalAlpha), 1, fontLarge, "left", "center")

        local pCashStr = string.format("Cüzdanınızdaki Nakit: %s", formatCurrency(playerData and playerData.cash or 0))
        exports.aura_ui:uiDrawText(pCashStr, rightX + 16 * scale, contentY + 74 * scale, rightX + rightW - 16 * scale, contentY + 92 * scale, tocolor(148, 163, 184, math.floor(200 * alphaMult)), 1, fontBody, "left", "center")

        local canWithStr = (playerData and playerData.canWithdraw) and "✓ Kasa Çekim Yetkiniz Var" or "✕ Para Çekme Yetkiniz Yok"
        local canWithCol = (playerData and playerData.canWithdraw) and tocolor(52, 211, 153, math.floor(200 * alphaMult)) or tocolor(239, 68, 68, math.floor(200 * alphaMult))
        exports.aura_ui:uiDrawText(canWithStr, rightX + 16 * scale, contentY + 96 * scale, rightX + rightW - 16 * scale, contentY + 114 * scale, canWithCol, 1, fontSmall, "left", "center")

        drawActionButton("dash_vault_jump", "Kasa İşlemlerini Aç →", rightX + 16 * scale, contentY + 124 * scale, rightW - 32 * scale, 34 * scale, "blue", alphaMult, fontBodyBold)

        local rCardH2 = contentH - rCardH1 - math.floor(12 * scale)
        local rCardY2 = contentY + rCardH1 + math.floor(12 * scale)
        drawSubPanel(rightX, rCardY2, rightW, rCardH2, 12, alphaMult, 140)

        exports.aura_ui:uiDrawText("DEPARTMAN KADROSU & KAPASİTE", rightX + 16 * scale, rCardY2 + 14 * scale, rightX + rightW, rCardY2 + 30 * scale, tocolor(255, 255, 255, globalAlpha), 1, fontBodyBold, "left", "center")
        exports.aura_ui:uiDrawText(string.format("%d Aktif Memur Çevrimiçi", onlineCount), rightX + 16 * scale, rCardY2 + 34 * scale, rightX + rightW, rCardY2 + 56 * scale, tocolor(255, 255, 255, globalAlpha), 1, fontLarge, "left", "center")
        exports.aura_ui:uiDrawText(string.format("Toplam Kayıtlı Personel: %d / %d", totalCount, factionData and factionData.max_members or 50), rightX + 16 * scale, rCardY2 + 58 * scale, rightX + rightW, rCardY2 + 76 * scale, tocolor(148, 163, 184, math.floor(200 * alphaMult)), 1, fontBody, "left", "center")

        local maxM = factionData and factionData.max_members or 50
        local barProg = math.min(1, totalCount / maxM)
        local pBarW = rightW - 32 * scale
        local pBarH = 6 * scale
        exports.aura_ui:uiDrawRectangle(rightX + 16 * scale, rCardY2 + 84 * scale, pBarW, pBarH, tocolor(15, 23, 42, math.floor(220 * alphaMult)))
        exports.aura_ui:uiDrawRectangle(rightX + 16 * scale, rCardY2 + 84 * scale, math.floor(pBarW * barProg), pBarH, tocolor(theme.color[1], theme.color[2], theme.color[3], math.floor(240 * alphaMult)))
        exports.aura_ui:uiDrawText(string.format("Kadro Doluluk Oranı: %%%d", math.floor(barProg * 100)), rightX + 16 * scale, rCardY2 + 94 * scale, rightX + rightW, rCardY2 + 110 * scale, tocolor(148, 163, 184, math.floor(180 * alphaMult)), 1, fontSmall, "left", "center")

        local fRoleDesc = string.format("Teşkilat Türü: %s\nYönetici Yetkisi: %s\nPanel Kısayolu: F6 Tuşu",
            theme.title or "Resmi Teşkilat",
            (playerData and playerData.canManage) and "Yetkili Komuta Kademesi" or "Standart Personel",
            "F6"
        )
        exports.aura_ui:uiDrawText(fRoleDesc, rightX + 16 * scale, rCardY2 + 120 * scale, rightX + rightW - 16 * scale, rCardY2 + rCardH2 - 12 * scale, tocolor(148, 163, 184, math.floor(190 * alphaMult)), 1, fontSmall, "left", "top")

    elseif activeTab == 2 then
        local topH = math.floor(40 * scale)
        local searchW = math.floor(260 * scale)
        drawCustomInput("roster_search", contentX, contentY, searchW, topH, "Üye adı veya ID ara...", rosterSearchText, fontBody, alphaMult)

        local filterPills = {
            { id = "all", title = "Tümü" },
            { id = "online", title = string.format("Çevrimiçi (%d)", onlineCount) },
            { id = "duty", title = "Mesaide" }
        }
        local fPillX = contentX + searchW + math.floor(14 * scale)
        local pillW = math.floor(100 * scale)
        for _, p in ipairs(filterPills) do
            local isSel = (rosterFilter == p.id)
            local isHov = isMouseInPosition(fPillX, contentY, pillW, topH)
            local pBg = isSel and tocolor(theme.color[1], theme.color[2], theme.color[3], math.floor(220 * alphaMult)) or (isHov and tocolor(30, 41, 59, math.floor(180 * alphaMult)) or tocolor(15, 23, 42, math.floor(120 * alphaMult)))
            local pTextColor = isSel and tocolor(15, 23, 42, globalAlpha) or tocolor(241, 245, 249, math.floor(220 * alphaMult))

            if exports.gzl_ui and exports.gzl_ui.drawRoundedRectangle then
                exports.gzl_ui:drawRoundedRectangle(fPillX, contentY, pillW, topH, 8, pBg)
            else
                exports.aura_ui:uiDrawRectangle(fPillX, contentY, pillW, topH, pBg)
            end
            exports.aura_ui:uiDrawText(p.title, fPillX, contentY, fPillX + pillW, contentY + topH, pTextColor, 1, fontSmall, "center", "center")
            fPillX = fPillX + pillW + math.floor(8 * scale)
        end

        if playerData and playerData.canInvite then
            local invBtnW = math.floor(180 * scale)
            local invBtnX = contentX + contentW - invBtnW
            drawActionButton("open_invite_modal", "+ Yeni Üye Davet Et", invBtnX, contentY, invBtnW, topH, "green", alphaMult, fontBodyBold)
        end

        local tableY = contentY + topH + math.floor(12 * scale)
        local tableH = contentH - topH - math.floor(12 * scale)
        drawSubPanel(contentX, tableY, contentW, tableH, 12, alphaMult, 140)

        local thH = math.floor(32 * scale)
        exports.aura_ui:uiDrawRectangle(contentX, tableY, contentW, thH, tocolor(15, 23, 42, math.floor(160 * alphaMult)))

        local col1X = contentX + math.floor(16 * scale)
        local col2X = col1X + math.floor(90 * scale)
        local col3X = col2X + math.floor(240 * scale)
        local col4X = col3X + math.floor(180 * scale)
        local col5X = col4X + math.floor(120 * scale)

        exports.aura_ui:uiDrawText("DURUM", col1X, tableY, col2X, tableY + thH, tocolor(148, 163, 184, math.floor(180 * alphaMult)), 1, fontSmall, "left", "center")
        exports.aura_ui:uiDrawText("ÜYE ADI & ID", col2X, tableY, col3X, tableY + thH, tocolor(148, 163, 184, math.floor(180 * alphaMult)), 1, fontSmall, "left", "center")
        exports.aura_ui:uiDrawText("RÜTBE & DERECE", col3X, tableY, col4X, tableY + thH, tocolor(148, 163, 184, math.floor(180 * alphaMult)), 1, fontSmall, "left", "center")
        exports.aura_ui:uiDrawText("GÖREV DURUMU", col4X, tableY, col5X, tableY + thH, tocolor(148, 163, 184, math.floor(180 * alphaMult)), 1, fontSmall, "left", "center")
        exports.aura_ui:uiDrawText("İŞLEMLER", col5X, tableY, contentX + contentW - 16 * scale, tableY + thH, tocolor(148, 163, 184, math.floor(180 * alphaMult)), 1, fontSmall, "left", "center")

        local filteredMembers = {}
        local q = string.lower(rosterSearchText)
        for _, m in ipairs(memberList) do
            local pass = true
            if rosterFilter == "online" and not m.is_online then pass = false end
            if rosterFilter == "duty" and not m.duty_status then pass = false end

            if pass and q ~= "" then
                local mName = string.lower(m.character_name or "")
                local mId = tostring(m.character_id or "")
                if not string.find(mName, q, 1, true) and not string.find(mId, q, 1, true) then
                    pass = false
                end
            end
            if pass then table.insert(filteredMembers, m) end
        end

        local rowH = math.floor(48 * scale)
        local listH = tableH - thH
        local maxRows = math.floor(listH / rowH)

        if rosterScroll > math.max(0, #filteredMembers - maxRows) then
            rosterScroll = math.max(0, #filteredMembers - maxRows)
        end

        if #filteredMembers == 0 then
            exports.aura_ui:uiDrawText("Herhangi bir üye bulunamadı.", contentX, tableY + thH, contentX + contentW, tableY + tableH, tocolor(148, 163, 184, math.floor(160 * alphaMult)), 1, fontBody, "center", "center")
        else
            for idx = 1, maxRows do
                local itemIndex = rosterScroll + idx
                local m = filteredMembers[itemIndex]
                if m then
                    local rowY = tableY + thH + (idx - 1) * rowH
                    local isRowHov = isMouseInPosition(contentX, rowY, contentW, rowH)

                    local rowBg = (itemIndex % 2 == 0) and tocolor(20, 29, 47, math.floor(80 * alphaMult)) or tocolor(15, 23, 42, math.floor(80 * alphaMult))
                    if isRowHov then
                        rowBg = tocolor(30, 41, 59, math.floor(140 * alphaMult))
                    end
                    exports.aura_ui:uiDrawRectangle(contentX, rowY, contentW, rowH, rowBg)

                    local dotCol = m.is_online and tocolor(34, 197, 94, math.floor(240 * alphaMult)) or tocolor(100, 116, 139, math.floor(180 * alphaMult))
                    local dotTxt = m.is_online and "Çevrimiçi" or "Çevrimdışı"
                    local sDotSize = math.floor(8 * scale)
                    local sDotY = rowY + math.floor((rowH - sDotSize) / 2)
                    if exports.gzl_ui and exports.gzl_ui.drawCircle then
                        exports.gzl_ui:drawCircle(col1X + sDotSize * 0.5, sDotY + sDotSize * 0.5, sDotSize * 0.5, dotCol)
                    elseif exports.gzl_ui and exports.gzl_ui.drawRoundedRectangle then
                        exports.gzl_ui:drawRoundedRectangle(col1X, sDotY, sDotSize, sDotSize, math.floor(sDotSize / 2), dotCol)
                    else
                        exports.aura_ui:uiDrawRectangle(col1X, sDotY, sDotSize, sDotSize, dotCol)
                    end
                    exports.aura_ui:uiDrawText(dotTxt, col1X + 14 * scale, rowY, col2X, rowY + rowH, dotCol, 1, fontSmall, "left", "center")

                    exports.aura_ui:uiDrawText(m.character_name or "N/A", col2X, rowY + 8 * scale, col3X, rowY + 26 * scale, tocolor(255, 255, 255, globalAlpha), 1, fontBodyBold, "left", "center", true)
                    local idInfo = string.format("Karakter ID: #%d%s", m.character_id or 0, (m.server_id and (" • ID: " .. m.server_id) or ""))
                    exports.aura_ui:uiDrawText(idInfo, col2X, rowY + 26 * scale, col3X, rowY + 42 * scale, tocolor(148, 163, 184, math.floor(180 * alphaMult)), 1, fontSmall, "left", "center", true)

                    local rBadgeStr = string.format("%s (D-%d)", m.rank_name or "Üye", m.rank_id or 1)
                    exports.aura_ui:uiDrawText(rBadgeStr, col3X, rowY, col4X, rowY + rowH, tocolor(theme.color[1], theme.color[2], theme.color[3], math.floor(230 * alphaMult)), 1, fontBody, "left", "center", true)

                    local dutyTag = m.duty_status and "MESAİDE" or "İZİNLİ"
                    local dutyCol = m.duty_status and tocolor(34, 197, 94, math.floor(220 * alphaMult)) or tocolor(148, 163, 184, math.floor(160 * alphaMult))
                    exports.aura_ui:uiDrawText(dutyTag, col4X, rowY, col5X, rowY + rowH, dutyCol, 1, fontSmall, "left", "center")

                    if m.character_id == (playerData and playerData.character_id) then
                        local meW = math.floor(52 * scale)
                        local meH = math.floor(22 * scale)
                        local meY = rowY + math.floor((rowH - meH) / 2)
                        if exports.gzl_ui and exports.gzl_ui.drawRoundedRectangle then
                            exports.gzl_ui:drawRoundedRectangle(col5X, meY, meW, meH, 4, tocolor(theme.color[1], theme.color[2], theme.color[3], math.floor(35 * alphaMult)))
                            exports.gzl_ui:drawRoundedBorder(col5X, meY, meW, meH, 4, 1.0, tocolor(theme.color[1], theme.color[2], theme.color[3], math.floor(140 * alphaMult)))
                        else
                            exports.aura_ui:uiDrawRectangle(col5X, meY, meW, meH, tocolor(theme.color[1], theme.color[2], theme.color[3], math.floor(35 * alphaMult)))
                        end
                        exports.aura_ui:uiDrawText("(Siz)", col5X, meY, col5X + meW, meY + meH, tocolor(theme.color[1], theme.color[2], theme.color[3], globalAlpha), 1, fontSmall, "center", "center")
                    elseif playerData and playerData.canManage then
                        local myRank = playerData.rank_id or 1
                        local maxR = playerData.maxRank or 5
                        local isTargetLower = (m.rank_id < myRank) and (m.character_id ~= playerData.character_id)

                        if isTargetLower then
                            local actBtnSize = math.floor(28 * scale)
                            local actY = rowY + math.floor((rowH - actBtnSize) / 2)

                            local canPromote = (m.rank_id + 1 < myRank) and (m.rank_id + 1 <= maxR)
                            local promX = col5X
                            if canPromote then
                                drawActionButton("prom_" .. m.character_id, "▲", promX, actY, actBtnSize, actBtnSize, "green", alphaMult, fontBodyBold)
                            else
                                exports.aura_ui:uiDrawRectangle(promX, actY, actBtnSize, actBtnSize, tocolor(30, 41, 59, math.floor(100 * alphaMult)))
                                exports.aura_ui:uiDrawText("▲", promX, actY, promX + actBtnSize, actY + actBtnSize, tocolor(100, 116, 139, math.floor(100 * alphaMult)), 1, fontBodyBold, "center", "center")
                            end

                            local canDemote = (m.rank_id > 1)
                            local demX = promX + actBtnSize + 6 * scale
                            if canDemote then
                                drawActionButton("dem_" .. m.character_id, "▼", demX, actY, actBtnSize, actBtnSize, "amber", alphaMult, fontBodyBold)
                            else
                                exports.aura_ui:uiDrawRectangle(demX, actY, actBtnSize, actBtnSize, tocolor(30, 41, 59, math.floor(100 * alphaMult)))
                                exports.aura_ui:uiDrawText("▼", demX, actY, demX + actBtnSize, actY + actBtnSize, tocolor(100, 116, 139, math.floor(100 * alphaMult)), 1, fontBodyBold, "center", "center")
                            end

                            local kickX = demX + actBtnSize + 6 * scale
                            drawActionButton("kick_" .. m.character_id, "✕", kickX, actY, actBtnSize, actBtnSize, "red", alphaMult, fontBodyBold)
                        else
                            exports.aura_ui:uiDrawText("Yetkisiz", col5X, rowY, contentX + contentW - 16 * scale, rowY + rowH, tocolor(100, 116, 139, math.floor(140 * alphaMult)), 1, fontSmall, "left", "center")
                        end
                    else
                        exports.aura_ui:uiDrawText("—", col5X, rowY, contentX + contentW - 16 * scale, rowY + rowH, tocolor(100, 116, 139, math.floor(140 * alphaMult)), 1, fontSmall, "left", "center")
                    end
                end
            end

            local sbW = math.floor(4 * scale)
            local sbX = contentX + contentW - sbW - 4 * scale
            local sbY = tableY + thH + 4 * scale
            local sbH = tableH - thH - 8 * scale
            drawScrollBar(sbX, sbY, sbW, sbH, #filteredMembers, maxRows, rosterScroll, alphaMult, tocolor(theme.color[1], theme.color[2], theme.color[3], math.floor(200 * alphaMult)))
        end

    elseif activeTab == 3 then
        local topH = math.floor(175 * scale)
        local halfW = math.floor((contentW - 14 * scale) / 2)

        drawSubPanel(contentX, contentY, halfW, topH, 12, alphaMult, 140)
        exports.aura_ui:uiDrawText("KASAYA PARA YATIR", contentX + 16 * scale, contentY + 12 * scale, contentX + halfW, contentY + 28 * scale, tocolor(52, 211, 153, globalAlpha), 1, fontBodyBold, "left", "center")

        local inpW = halfW - 32 * scale
        local inpH = math.floor(34 * scale)
        drawCustomInput("vault_dep_amount", contentX + 16 * scale, contentY + 34 * scale, inpW, inpH, "Yatırılacak miktar ($)...", vaultDepositAmount, fontBody, alphaMult)

        local quickPills = { 1000, 5000, 25000, 100000 }
        local pillW = math.floor((inpW - 3 * 6 * scale) / 5)
        local qX = contentX + 16 * scale
        local qY = contentY + 34 * scale + inpH + 6 * scale
        for _, amt in ipairs(quickPills) do
            local isHov = isMouseInPosition(qX, qY, pillW, 24 * scale)
            local bgC = isHov and tocolor(30, 41, 59, math.floor(220 * alphaMult)) or tocolor(15, 23, 42, math.floor(160 * alphaMult))
            if exports.gzl_ui and exports.gzl_ui.drawRoundedRectangle then
                exports.gzl_ui:drawRoundedRectangle(qX, qY, pillW, 24 * scale, 6, bgC)
            else
                exports.aura_ui:uiDrawRectangle(qX, qY, pillW, 24 * scale, bgC)
            end
            exports.aura_ui:uiDrawText("+" .. formatCurrency(amt), qX, qY, qX + pillW, qY + 24 * scale, tocolor(148, 163, 184, math.floor(220 * alphaMult)), 1, fontSmall, "center", "center")
            qX = qX + pillW + 6 * scale
        end
        local isAllHov = isMouseInPosition(qX, qY, pillW, 24 * scale)
        local allBg = isAllHov and tocolor(16, 185, 129, math.floor(220 * alphaMult)) or tocolor(5, 150, 105, math.floor(160 * alphaMult))
        if exports.gzl_ui and exports.gzl_ui.drawRoundedRectangle then
            exports.gzl_ui:drawRoundedRectangle(qX, qY, pillW, 24 * scale, 6, allBg)
        else
            exports.aura_ui:uiDrawRectangle(qX, qY, pillW, 24 * scale, allBg)
        end
        exports.aura_ui:uiDrawText("Tümü", qX, qY, qX + pillW, qY + 24 * scale, tocolor(255, 255, 255, globalAlpha), 1, fontSmall, "center", "center")

        drawCustomInput("vault_dep_reason", contentX + 16 * scale, qY + 30 * scale, math.floor(inpW * 0.62), inpH, "Açıklama (opsiyonel)...", vaultDepositReason, fontBody, alphaMult)
        local depBtnW = inpW - math.floor(inpW * 0.62) - 8 * scale
        drawActionButton("btn_vault_deposit", "Kasaya Yatır", contentX + 16 * scale + math.floor(inpW * 0.62) + 8 * scale, qY + 30 * scale, depBtnW, inpH, "green", alphaMult, fontBodyBold)

        local withX = contentX + halfW + math.floor(14 * scale)
        drawSubPanel(withX, contentY, halfW, topH, 12, alphaMult, 140)

        if playerData and playerData.canWithdraw then
            exports.aura_ui:uiDrawText("KASADAN PARA ÇEK", withX + 16 * scale, contentY + 12 * scale, withX + halfW, contentY + 28 * scale, tocolor(248, 113, 113, globalAlpha), 1, fontBodyBold, "left", "center")
            drawCustomInput("vault_with_amount", withX + 16 * scale, contentY + 34 * scale, inpW, inpH, "Çekilecek miktar ($)...", vaultWithdrawAmount, fontBody, alphaMult)

            local wqX = withX + 16 * scale
            for _, amt in ipairs(quickPills) do
                local isHov = isMouseInPosition(wqX, qY, pillW, 24 * scale)
                local bgC = isHov and tocolor(30, 41, 59, math.floor(220 * alphaMult)) or tocolor(15, 23, 42, math.floor(160 * alphaMult))
                if exports.gzl_ui and exports.gzl_ui.drawRoundedRectangle then
                    exports.gzl_ui:drawRoundedRectangle(wqX, qY, pillW, 24 * scale, 6, bgC)
                else
                    exports.aura_ui:uiDrawRectangle(wqX, qY, pillW, 24 * scale, bgC)
                end
                exports.aura_ui:uiDrawText("-" .. formatCurrency(amt), wqX, qY, wqX + pillW, qY + 24 * scale, tocolor(248, 113, 113, math.floor(220 * alphaMult)), 1, fontSmall, "center", "center")
                wqX = wqX + pillW + 6 * scale
            end
            local isAllVaultHov = isMouseInPosition(wqX, qY, pillW, 24 * scale)
            local allVaultBg = isAllVaultHov and tocolor(239, 68, 68, math.floor(220 * alphaMult)) or tocolor(185, 28, 28, math.floor(160 * alphaMult))
            if exports.gzl_ui and exports.gzl_ui.drawRoundedRectangle then
                exports.gzl_ui:drawRoundedRectangle(wqX, qY, pillW, 24 * scale, 6, allVaultBg)
            else
                exports.aura_ui:uiDrawRectangle(wqX, qY, pillW, 24 * scale, allVaultBg)
            end
            exports.aura_ui:uiDrawText("Tüm Kasa", wqX, qY, wqX + pillW, qY + 24 * scale, tocolor(255, 255, 255, globalAlpha), 1, fontSmall, "center", "center")

            drawCustomInput("vault_with_reason", withX + 16 * scale, qY + 30 * scale, math.floor(inpW * 0.62), inpH, "Çekim gerekçesi...", vaultWithdrawReason, fontBody, alphaMult)
            local withBtnW = inpW - math.floor(inpW * 0.62) - 8 * scale
            drawActionButton("btn_vault_withdraw", "Kasadan Çek", withX + 16 * scale + math.floor(inpW * 0.62) + 8 * scale, qY + 30 * scale, withBtnW, inpH, "red", alphaMult, fontBodyBold)
        else
            exports.aura_ui:uiDrawText("KASADAN PARA ÇEK (YETKİ GEREKLİ)", withX + 16 * scale, contentY + 12 * scale, withX + halfW, contentY + 28 * scale, tocolor(148, 163, 184, math.floor(180 * alphaMult)), 1, fontBodyBold, "left", "center")
            local lockNotice = "Bu işlem yetkili rütbelere sınırlandırılmıştır.\n\nKasadan para çekebilmek için birliğinizde yetkili lider veya kıdemli komuta kademesinde olmanız gerekmektedir."
            exports.aura_ui:uiDrawText(lockNotice, withX + 16 * scale, contentY + 44 * scale, withX + halfW - 16 * scale, contentY + topH - 16 * scale, tocolor(148, 163, 184, math.floor(180 * alphaMult)), 1, fontBody, "left", "top")
        end

        local botY = contentY + topH + math.floor(12 * scale)
        local botH = contentH - topH - math.floor(12 * scale)
        drawSubPanel(contentX, botY, contentW, botH, 12, alphaMult, 140)

        local logThH = math.floor(30 * scale)
        exports.aura_ui:uiDrawRectangle(contentX, botY, contentW, logThH, tocolor(15, 23, 42, math.floor(160 * alphaMult)))

        local lCol1 = contentX + 16 * scale
        local lCol2 = lCol1 + 160 * scale
        local lCol3 = lCol2 + 200 * scale
        local lCol4 = lCol3 + 120 * scale
        local lCol5 = lCol4 + 140 * scale

        exports.aura_ui:uiDrawText("TARİH & SAAT", lCol1, botY, lCol2, botY + logThH, tocolor(148, 163, 184, math.floor(180 * alphaMult)), 1, fontSmall, "left", "center")
        exports.aura_ui:uiDrawText("İŞLEMİ YAPAN", lCol2, botY, lCol3, botY + logThH, tocolor(148, 163, 184, math.floor(180 * alphaMult)), 1, fontSmall, "left", "center")
        exports.aura_ui:uiDrawText("İŞLEM TÜRÜ", lCol3, botY, lCol4, botY + logThH, tocolor(148, 163, 184, math.floor(180 * alphaMult)), 1, fontSmall, "left", "center")
        exports.aura_ui:uiDrawText("MİKTAR", lCol4, botY, lCol5, botY + logThH, tocolor(148, 163, 184, math.floor(180 * alphaMult)), 1, fontSmall, "left", "center")
        exports.aura_ui:uiDrawText("AÇIKLAMA", lCol5, botY, contentX + contentW - 16 * scale, botY + logThH, tocolor(148, 163, 184, math.floor(180 * alphaMult)), 1, fontSmall, "left", "center")

        local logRowH = math.floor(36 * scale)
        local maxLogRows = math.floor((botH - logThH) / logRowH)

        if vaultScroll > math.max(0, #vaultLogs - maxLogRows) then
            vaultScroll = math.max(0, #vaultLogs - maxLogRows)
        end

        if #vaultLogs == 0 then
            exports.aura_ui:uiDrawText("Henüz kaydedilmiş bir kasa hareketi bulunmuyor.", contentX, botY + logThH, contentX + contentW, botY + botH, tocolor(148, 163, 184, math.floor(150 * alphaMult)), 1, fontBody, "center", "center")
        else
            for idx = 1, maxLogRows do
                local lIdx = vaultScroll + idx
                local log = vaultLogs[lIdx]
                if log then
                    local lRowY = botY + logThH + (idx - 1) * logRowH
                    local rBg = (lIdx % 2 == 0) and tocolor(20, 29, 47, math.floor(70 * alphaMult)) or tocolor(15, 23, 42, math.floor(70 * alphaMult))
                    exports.aura_ui:uiDrawRectangle(contentX, lRowY, contentW, logRowH, rBg)

                    local isDep = (log.action_type == "deposit")
                    local amtCol = isDep and tocolor(52, 211, 153, globalAlpha) or tocolor(248, 113, 113, globalAlpha)
                    local amtPrefix = isDep and "+" or "-"
                    local typeStr = isDep and "Yatırma" or "Çekme"

                    exports.aura_ui:uiDrawText(log.created_at or "N/A", lCol1, lRowY, lCol2, lRowY + logRowH, tocolor(148, 163, 184, math.floor(180 * alphaMult)), 1, fontSmall, "left", "center", true)
                    exports.aura_ui:uiDrawText(log.character_name or "Sistem", lCol2, lRowY, lCol3, lRowY + logRowH, tocolor(255, 255, 255, globalAlpha), 1, fontBodyBold, "left", "center", true)
                    exports.aura_ui:uiDrawText(typeStr, lCol3, lRowY, lCol4, lRowY + logRowH, tocolor(203, 213, 225, math.floor(200 * alphaMult)), 1, fontSmall, "left", "center")
                    exports.aura_ui:uiDrawText(amtPrefix .. formatCurrency(log.amount or 0), lCol4, lRowY, lCol5, lRowY + logRowH, amtCol, 1, fontBodyBold, "left", "center")
                    exports.aura_ui:uiDrawText(log.reason or "—", lCol5, lRowY, contentX + contentW - 16 * scale, lRowY + logRowH, tocolor(148, 163, 184, math.floor(200 * alphaMult)), 1, fontSmall, "left", "center", true)
                end
            end

            local sbW = math.floor(4 * scale)
            local sbX = contentX + contentW - sbW - 4 * scale
            local sbY = botY + logThH + 4 * scale
            local sbH = botH - logThH - 8 * scale
            drawScrollBar(sbX, sbY, sbW, sbH, #vaultLogs, maxLogRows, vaultScroll, alphaMult, tocolor(52, 211, 153, math.floor(180 * alphaMult)))
        end

    elseif activeTab == 4 then
        drawSubPanel(contentX, contentY, contentW, contentH, 12, alphaMult, 140)

        local rThH = math.floor(34 * scale)
        exports.aura_ui:uiDrawRectangle(contentX, contentY, contentW, rThH, tocolor(15, 23, 42, math.floor(160 * alphaMult)))

        local rCol1 = contentX + 16 * scale
        local rCol2 = rCol1 + 75 * scale
        local rCol3 = rCol2 + 270 * scale
        local rCol4 = rCol3 + 140 * scale
        local rCol5 = rCol4 + 150 * scale

        exports.aura_ui:uiDrawText("DERECE", rCol1, contentY, rCol2, contentY + rThH, tocolor(148, 163, 184, math.floor(180 * alphaMult)), 1, fontSmall, "left", "center")
        exports.aura_ui:uiDrawText("RÜTBE ÜNVANI", rCol2, contentY, rCol3, contentY + rThH, tocolor(148, 163, 184, math.floor(180 * alphaMult)), 1, fontSmall, "left", "center")
        exports.aura_ui:uiDrawText("SAATLİK MAAŞ", rCol3, contentY, rCol4, contentY + rThH, tocolor(148, 163, 184, math.floor(180 * alphaMult)), 1, fontSmall, "left", "center")
        exports.aura_ui:uiDrawText("ÜYE YÖNETİM YETKİSİ", rCol4, contentY, rCol5, contentY + rThH, tocolor(148, 163, 184, math.floor(180 * alphaMult)), 1, fontSmall, "left", "center")
        exports.aura_ui:uiDrawText("KASA ÇEKİM YETKİSİ", rCol5, contentY, contentX + contentW - 16 * scale, contentY + rThH, tocolor(148, 163, 184, math.floor(180 * alphaMult)), 1, fontSmall, "left", "center")

        local ranksList = {}
        if factionData and factionData.ranks then
            for rId, rInfo in pairs(factionData.ranks) do
                table.insert(ranksList, { id = tonumber(rId), name = rInfo.name, salary = rInfo.salary })
            end
            table.sort(ranksList, function(a, b) return a.id < b.id end)
        end

        local rRowH = math.floor(46 * scale)
        local maxRankRows = math.floor((contentH - rThH) / rRowH)
        if rankScroll > math.max(0, #ranksList - maxRankRows) then
            rankScroll = math.max(0, #ranksList - maxRankRows)
        end

        for idx = 1, maxRankRows do
            local rIdx = rankScroll + idx
            local r = ranksList[rIdx]
            if r then
                local rY = contentY + rThH + (idx - 1) * rRowH
                local isMyRank = (playerData and playerData.rank_id == r.id)

                local rBg = isMyRank and tocolor(30, 58, 100, math.floor(160 * alphaMult)) or ((rIdx % 2 == 0) and tocolor(20, 29, 47, math.floor(70 * alphaMult)) or tocolor(15, 23, 42, math.floor(70 * alphaMult)))
                exports.aura_ui:uiDrawRectangle(contentX, rY, contentW, rRowH, rBg)

                if isMyRank then
                    exports.aura_ui:uiDrawRectangle(contentX, rY, 3 * scale, rRowH, tocolor(theme.color[1], theme.color[2], theme.color[3], globalAlpha))
                end

                local canManageRank = FactionConfig and FactionConfig.canManageMembers(factionData and factionData.id, r.id)
                local canWithRank = FactionConfig and FactionConfig.canWithdrawVault(factionData and factionData.id, r.id)

                exports.aura_ui:uiDrawText(string.format("D-%d", r.id), rCol1, rY, rCol2, rY + rRowH, tocolor(255, 255, 255, globalAlpha), 1, fontBodyBold, "left", "center")

                local rTitleCol = isMyRank and tocolor(theme.color[1], theme.color[2], theme.color[3], globalAlpha) or tocolor(241, 245, 249, globalAlpha)
                local rankNameMaxW = 180 * scale
                exports.aura_ui:uiDrawText(r.name, rCol2, rY, rCol2 + rankNameMaxW, rY + rRowH, rTitleCol, 1, fontBodyBold, "left", "center", true)

                if isMyRank then
                    local myPillW = math.floor(75 * scale)
                    local myPillH = math.floor(22 * scale)
                    local myPillX = rCol2 + rankNameMaxW + 8 * scale
                    local myPillY = rY + math.floor((rRowH - myPillH) / 2)
                    if exports.gzl_ui and exports.gzl_ui.drawRoundedRectangle then
                        exports.gzl_ui:drawRoundedRectangle(myPillX, myPillY, myPillW, myPillH, 4, tocolor(theme.color[1], theme.color[2], theme.color[3], math.floor(35 * alphaMult)))
                        exports.gzl_ui:drawRoundedBorder(myPillX, myPillY, myPillW, myPillH, 4, 1.0, tocolor(theme.color[1], theme.color[2], theme.color[3], math.floor(180 * alphaMult)))
                    else
                        exports.aura_ui:uiDrawRectangle(myPillX, myPillY, myPillW, myPillH, tocolor(theme.color[1], theme.color[2], theme.color[3], math.floor(35 * alphaMult)))
                    end
                    exports.aura_ui:uiDrawText("MEVCUT", myPillX, myPillY, myPillX + myPillW, myPillY + myPillH, tocolor(theme.color[1], theme.color[2], theme.color[3], globalAlpha), 1, fontSmall, "center", "center")
                end

                exports.aura_ui:uiDrawText(formatCurrency(r.salary or 0) .. " / saat", rCol3, rY, rCol4, rY + rRowH, tocolor(52, 211, 153, globalAlpha), 1, fontBody, "left", "center")

                local manStr = canManageRank and "✓ Yetkili" or "✕ Yetkisiz"
                local manCol = canManageRank and tocolor(52, 211, 153, globalAlpha) or tocolor(148, 163, 184, math.floor(160 * alphaMult))
                exports.aura_ui:uiDrawText(manStr, rCol4, rY, rCol5, rY + rRowH, manCol, 1, fontSmall, "left", "center")

                local withStr = canWithRank and "✓ Yetkili" or "✕ Yetkisiz"
                local withCol = canWithRank and tocolor(52, 211, 153, globalAlpha) or tocolor(148, 163, 184, math.floor(160 * alphaMult))
                exports.aura_ui:uiDrawText(withStr, rCol5, rY, contentX + contentW - 16 * scale, rY + rRowH, withCol, 1, fontSmall, "left", "center")
            end
        end

        local sbW = math.floor(4 * scale)
        local sbX = contentX + contentW - sbW - 4 * scale
        local sbY = contentY + rThH + 4 * scale
        local sbH = contentH - rThH - 8 * scale
        drawScrollBar(sbX, sbY, sbW, sbH, #ranksList, maxRankRows, rankScroll, alphaMult, tocolor(theme.color[1], theme.color[2], theme.color[3], math.floor(180 * alphaMult)))
    end

    if isInviteModalOpen then
        exports.aura_ui:uiDrawRectangle(0, 0, screenW, screenH, tocolor(0, 0, 0, math.floor(160 * alphaMult)))

        local modalW = math.floor(460 * scale)
        local modalH = math.floor(400 * scale)
        local modalX = math.floor((screenW - modalW) / 2)
        local modalY = math.floor((screenH - modalH) / 2)

        drawGlassCard(modalX, modalY, modalW, modalH, 16, alphaMult, tocolor(theme.color[1], theme.color[2], theme.color[3], math.floor(200 * alphaMult)))

        exports.aura_ui:uiDrawText("BİRLİĞE ÜYE DAVET ET", modalX + 20 * scale, modalY + 16 * scale, modalX + modalW - 20 * scale, modalY + 36 * scale, tocolor(255, 255, 255, globalAlpha), 1, fontHeaderTitle, "left", "center")
        exports.aura_ui:uiDrawText("Yakındaki vatandaşlardan birini seçin veya Karakter / Oyuncu ID girin.", modalX + 20 * scale, modalY + 38 * scale, modalX + modalW - 20 * scale, modalY + 56 * scale, tocolor(148, 163, 184, math.floor(200 * alphaMult)), 1, fontSmall, "left", "center")

        exports.aura_ui:uiDrawText("YAKINDAKİ VATANDAŞLAR (15M)", modalX + 20 * scale, modalY + 68 * scale, modalX + modalW, modalY + 84 * scale, tocolor(148, 163, 184, math.floor(180 * alphaMult)), 1, fontSmall, "left", "center")
        local nearBoxH = math.floor(75 * scale)
        drawSubPanel(modalX + 20 * scale, modalY + 86 * scale, modalW - 40 * scale, nearBoxH, 8, alphaMult, 120)

        if #nearbyPlayers == 0 then
            exports.aura_ui:uiDrawText("Yakında birliksiz vatandaş bulunamadı.", modalX + 20 * scale, modalY + 86 * scale, modalX + modalW - 20 * scale, modalY + 86 * scale + nearBoxH, tocolor(100, 116, 139, math.floor(160 * alphaMult)), 1, fontSmall, "center", "center")
        else
            local pItemW = math.floor((modalW - 56 * scale) / 2)
            local pItemH = math.floor(28 * scale)
            for nIdx, nPlayer in ipairs(nearbyPlayers) do
                if nIdx <= 4 then
                    local pRow = math.floor((nIdx - 1) / 2)
                    local pCol = (nIdx - 1) % 2
                    local pX = modalX + 26 * scale + pCol * (pItemW + 8 * scale)
                    local pY = modalY + 92 * scale + pRow * (pItemH + 6 * scale)

                    local isSel = (inviteSelectedNearby == nPlayer.element)
                    local isHov = isMouseInPosition(pX, pY, pItemW, pItemH)
                    local pBg = isSel and tocolor(theme.color[1], theme.color[2], theme.color[3], math.floor(220 * alphaMult)) or (isHov and tocolor(30, 41, 59, math.floor(220 * alphaMult)) or tocolor(15, 23, 42, math.floor(180 * alphaMult)))
                    local pTxtCol = isSel and tocolor(15, 23, 42, globalAlpha) or tocolor(255, 255, 255, globalAlpha)

                    if exports.gzl_ui and exports.gzl_ui.drawRoundedRectangle then
                        exports.gzl_ui:drawRoundedRectangle(pX, pY, pItemW, pItemH, 6, pBg)
                    else
                        exports.aura_ui:uiDrawRectangle(pX, pY, pItemW, pItemH, pBg)
                    end
                    local dispStr = string.format("%s (#%d)", nPlayer.name or "Vatandaş", nPlayer.server_id or 0)
                    exports.aura_ui:uiDrawText(dispStr, pX + 6 * scale, pY, pX + pItemW - 6 * scale, pY + pItemH, pTxtCol, 1, fontSmall, "left", "center", true)
                end
            end
        end

        exports.aura_ui:uiDrawText("HEDEF OYUNCU (ID VEYA İSİM)", modalX + 20 * scale, modalY + 172 * scale, modalX + modalW, modalY + 188 * scale, tocolor(148, 163, 184, math.floor(180 * alphaMult)), 1, fontSmall, "left", "center")
        drawCustomInput("invite_target", modalX + 20 * scale, modalY + 192 * scale, modalW - 40 * scale, 36 * scale, "Oyuncu ID veya isim...", inviteTargetInput, fontBody, alphaMult)

        exports.aura_ui:uiDrawText("BAŞLANGIÇ RÜTBESİ", modalX + 20 * scale, modalY + 238 * scale, modalX + modalW, modalY + 254 * scale, tocolor(148, 163, 184, math.floor(180 * alphaMult)), 1, fontSmall, "left", "center")
        local maxInvRank = math.max(1, (playerData and playerData.rank_id or 2) - 1)
        local rankSelectorW = modalW - 40 * scale
        local rankSelectorH = math.floor(36 * scale)
        drawSubPanel(modalX + 20 * scale, modalY + 258 * scale, rankSelectorW, rankSelectorH, 8, alphaMult, 160)

        local prevBtnW = math.floor(36 * scale)
        local isPrevHov = isMouseInPosition(modalX + 20 * scale, modalY + 258 * scale, prevBtnW, rankSelectorH)
        local isNextHov = isMouseInPosition(modalX + 20 * scale + rankSelectorW - prevBtnW, modalY + 258 * scale, prevBtnW, rankSelectorH)

        exports.aura_ui:uiDrawText("◀", modalX + 20 * scale, modalY + 258 * scale, modalX + 20 * scale + prevBtnW, modalY + 258 * scale + rankSelectorH, isPrevHov and tocolor(255, 255, 255, globalAlpha) or tocolor(148, 163, 184, math.floor(180 * alphaMult)), 1, fontBodyBold, "center", "center")
        exports.aura_ui:uiDrawText("▶", modalX + 20 * scale + rankSelectorW - prevBtnW, modalY + 258 * scale, modalX + 20 * scale + rankSelectorW, modalY + 258 * scale + rankSelectorH, isNextHov and tocolor(255, 255, 255, globalAlpha) or tocolor(148, 163, 184, math.floor(180 * alphaMult)), 1, fontBodyBold, "center", "center")

        local rInfo = factionData and factionData.ranks and factionData.ranks[inviteSelectedRank]
        local rNameStr = string.format("%s (Derece %d)", (rInfo and rInfo.name or "Rütbe"), inviteSelectedRank)
        exports.aura_ui:uiDrawText(rNameStr, modalX + 20 * scale + prevBtnW, modalY + 258 * scale, modalX + 20 * scale + rankSelectorW - prevBtnW, modalY + 258 * scale + rankSelectorH, tocolor(theme.color[1], theme.color[2], theme.color[3], globalAlpha), 1, fontBodyBold, "center", "center")

        local mBtnW = math.floor((modalW - 50 * scale) / 2)
        local mBtnH = math.floor(38 * scale)
        local mBtnY = modalY + modalH - mBtnH - 18 * scale

        drawActionButton("btn_send_invite", "Davet Gönder", modalX + 20 * scale, mBtnY, mBtnW, mBtnH, "green", alphaMult, fontBodyBold)
        drawActionButton("btn_cancel_invite", "Vazgeç", modalX + 30 * scale + mBtnW, mBtnY, mBtnW, mBtnH, "red", alphaMult, fontBodyBold)
    end

    if kickConfirmTarget then
        exports.aura_ui:uiDrawRectangle(0, 0, screenW, screenH, tocolor(0, 0, 0, math.floor(170 * alphaMult)))

        local kW = math.floor(400 * scale)
        local kH = math.floor(180 * scale)
        local kX = math.floor((screenW - kW) / 2)
        local kY = math.floor((screenH - kH) / 2)

        drawGlassCard(kX, kY, kW, kH, 14, alphaMult, tocolor(239, 68, 68, math.floor(200 * alphaMult)))

        exports.aura_ui:uiDrawText("ÜYEYİ İHRAÇ ET", kX + 20 * scale, kY + 16 * scale, kX + kW - 20 * scale, kY + 34 * scale, tocolor(239, 68, 68, globalAlpha), 1, fontHeaderTitle, "left", "center")
        local kickDesc = string.format("%s adlı üyeyi birliğinizden ihraç etmek istediğinize emin misiniz?", kickConfirmTarget.name or "Üye")
        exports.aura_ui:uiDrawText(kickDesc, kX + 20 * scale, kY + 44 * scale, kX + kW - 20 * scale, kY + 100 * scale, tocolor(241, 245, 249, math.floor(220 * alphaMult)), 1, fontBody, "left", "top")

        local kBtnW = math.floor((kW - 50 * scale) / 2)
        local kBtnH = math.floor(36 * scale)
        local kBtnY = kY + kH - kBtnH - 16 * scale

        drawActionButton("btn_confirm_kick", "Evet, İhraç Et", kX + 20 * scale, kBtnY, kBtnW, kBtnH, "red", alphaMult, fontBodyBold)
        drawActionButton("btn_cancel_kick", "Vazgeç", kX + 30 * scale + kBtnW, kBtnY, kBtnW, kBtnH, "blue", alphaMult, fontBodyBold)
    end
end)

addEventHandler("onClientClick", root, function(button, state, absX, absY)
    if button ~= "left" or state ~= "up" then return end

    if activeInvitePrompt and not isPanelOpen then
        local cardW = math.floor(480 * scale)
        local cardH = math.floor(130 * scale)
        local cardX = math.floor((screenW - cardW) / 2)
        local cardY = math.floor(40 * scale)
        local btnW = math.floor((cardW - 40 * scale) / 2)
        local btnH = math.floor(34 * scale)
        local btnY = cardY + cardH - btnH - 12 * scale

        if isMouseInPosition(cardX + 16 * scale, btnY, btnW, btnH) then
            triggerServerEvent("faction:respondInvite", resourceRoot, true)
            activeInvitePrompt = nil
            return
        elseif isMouseInPosition(cardX + 24 * scale + btnW, btnY, btnW, btnH) then
            triggerServerEvent("faction:respondInvite", resourceRoot, false)
            activeInvitePrompt = nil
            return
        end
    end

    if not isPanelOpen then return end

    local panelW = math.floor(960 * scale)
    local panelH = math.floor(620 * scale)
    local panelX = math.floor((screenW - panelW) / 2)
    local panelY = math.floor((screenH - panelH) / 2)

    local headerH = math.floor(70 * scale)
    local closeSize = math.floor(34 * scale)
    local closeX = panelX + panelW - closeSize - 18 * scale
    local closeY = panelY + math.floor((headerH - closeSize) / 2)
    if isMouseInPosition(closeX, closeY, closeSize, closeSize) then
        closeFactionPanel()
        return
    end

    local dutyBtnW = math.floor(140 * scale)
    local dutyBtnH = math.floor(36 * scale)
    local dutyBtnX = closeX - dutyBtnW - 14 * scale
    local dutyBtnY = panelY + math.floor((headerH - dutyBtnH) / 2)
    if isMouseInPosition(dutyBtnX, dutyBtnY, dutyBtnW, dutyBtnH) then
        triggerServerEvent("faction:toggleDuty", resourceRoot)
        return
    end

    if kickConfirmTarget then
        local kW = math.floor(400 * scale)
        local kH = math.floor(180 * scale)
        local kX = math.floor((screenW - kW) / 2)
        local kY = math.floor((screenH - kH) / 2)
        local kBtnW = math.floor((kW - 50 * scale) / 2)
        local kBtnH = math.floor(36 * scale)
        local kBtnY = kY + kH - kBtnH - 16 * scale

        if isMouseInPosition(kX + 20 * scale, kBtnY, kBtnW, kBtnH) then
            triggerServerEvent("faction:manageMember", resourceRoot, "kick", kickConfirmTarget.charId)
            kickConfirmTarget = nil
            return
        elseif isMouseInPosition(kX + 30 * scale + kBtnW, kBtnY, kBtnW, kBtnH) then
            kickConfirmTarget = nil
            return
        end
        return
    end

    if isInviteModalOpen then
        local modalW = math.floor(460 * scale)
        local modalH = math.floor(400 * scale)
        local modalX = math.floor((screenW - modalW) / 2)
        local modalY = math.floor((screenH - modalH) / 2)

        if #nearbyPlayers > 0 then
            local pItemW = math.floor((modalW - 56 * scale) / 2)
            local pItemH = math.floor(28 * scale)
            for nIdx, nPlayer in ipairs(nearbyPlayers) do
                if nIdx <= 4 then
                    local pRow = math.floor((nIdx - 1) / 2)
                    local pCol = (nIdx - 1) % 2
                    local pX = modalX + 26 * scale + pCol * (pItemW + 8 * scale)
                    local pY = modalY + 92 * scale + pRow * (pItemH + 6 * scale)
                    if isMouseInPosition(pX, pY, pItemW, pItemH) then
                        inviteSelectedNearby = nPlayer.element
                        inviteTargetInput = tostring(nPlayer.server_id or nPlayer.name)
                        return
                    end
                end
            end
        end

        if isMouseInPosition(modalX + 20 * scale, modalY + 192 * scale, modalW - 40 * scale, 36 * scale) then
            setActiveField("invite_target")
            return
        end

        local maxInvRank = math.max(1, (playerData and playerData.rank_id or 2) - 1)
        local rankSelectorW = modalW - 40 * scale
        local rankSelectorH = math.floor(36 * scale)
        local prevBtnW = math.floor(36 * scale)
        if isMouseInPosition(modalX + 20 * scale, modalY + 258 * scale, prevBtnW, rankSelectorH) then
            inviteSelectedRank = math.max(1, inviteSelectedRank - 1)
            return
        elseif isMouseInPosition(modalX + 20 * scale + rankSelectorW - prevBtnW, modalY + 258 * scale, prevBtnW, rankSelectorH) then
            inviteSelectedRank = math.min(maxInvRank, inviteSelectedRank + 1)
            return
        end

        local mBtnW = math.floor((modalW - 50 * scale) / 2)
        local mBtnH = math.floor(38 * scale)
        local mBtnY = modalY + modalH - mBtnH - 18 * scale
        if isMouseInPosition(modalX + 20 * scale, mBtnY, mBtnW, mBtnH) then
            local targetVal = inviteSelectedNearby or inviteTargetInput
            if not targetVal or targetVal == "" then
                notifyUser("error", "Lütfen geçerli bir oyuncu seçin veya ID girin!")
                return
            end
            triggerServerEvent("faction:invitePlayer", resourceRoot, targetVal, inviteSelectedRank)
            isInviteModalOpen = false
            setActiveField(nil)
            return
        elseif isMouseInPosition(modalX + 30 * scale + mBtnW, mBtnY, mBtnW, mBtnH) then
            isInviteModalOpen = false
            setActiveField(nil)
            return
        end

        return
    end

    local tabBarY = panelY + headerH + math.floor(10 * scale)
    local tabH = math.floor(40 * scale)
    local tabGap = math.floor(10 * scale)
    local tabW = math.floor((panelW - 40 * scale - 3 * tabGap) / 4)

    for i = 1, 4 do
        local tabX = panelX + 20 * scale + (i - 1) * (tabW + tabGap)
        if isMouseInPosition(tabX, tabBarY, tabW, tabH) then
            activeTab = i
            setActiveField(nil)
            return
        end
    end

    local contentX = panelX + math.floor(20 * scale)
    local contentY = tabBarY + tabH + math.floor(12 * scale)
    local contentW = panelW - math.floor(40 * scale)
    local contentH = panelH - (contentY - panelY) - math.floor(16 * scale)

    if activeTab == 1 then
        local leftW = math.floor(contentW * 0.58)
        local cardH1 = math.floor(130 * scale)

        local dutyToggleW = math.floor(140 * scale)
        local dutyToggleH = math.floor(38 * scale)
        local dutyToggleX = contentX + leftW - dutyToggleW - 16 * scale
        local dutyToggleY = contentY + math.floor((cardH1 - dutyToggleH) / 2)
        if isMouseInPosition(dutyToggleX, dutyToggleY, dutyToggleW, dutyToggleH) then
            triggerServerEvent("faction:toggleDuty", resourceRoot)
            return
        end

        local botCardY = contentY + cardH1 + math.floor(12 * scale)
        local freqBoxW = leftW - 32 * scale
        local freqBoxH = math.floor(76 * scale)
        local freqBoxX = contentX + 16 * scale
        local freqBoxY = botCardY + 38 * scale
        local rConnW = math.floor(150 * scale)
        local rConnH = math.floor(36 * scale)
        local rConnX = freqBoxX + freqBoxW - rConnW - 12 * scale
        local rConnY = freqBoxY + math.floor((freqBoxH - rConnH) / 2)

        if isMouseInPosition(rConnX, rConnY, rConnW, rConnH) then
            local fType = factionData and factionData.type or "default"
            local theme = FactionConfig and FactionConfig.getTypeTheme(fType)
            local assignedFreq = theme and theme.channel or "155.0"
            triggerServerEvent("faction:connectRadio", resourceRoot, assignedFreq)
            return
        end

        local rightW = contentW - leftW - math.floor(14 * scale)
        local rightX = contentX + leftW + math.floor(14 * scale)
        local rCardH1 = math.floor(175 * scale)
        if isMouseInPosition(rightX + 16 * scale, contentY + 124 * scale, rightW - 32 * scale, 34 * scale) then
            activeTab = 3
            return
        end

    elseif activeTab == 2 then
        local topH = math.floor(40 * scale)
        local searchW = math.floor(260 * scale)

        if isMouseInPosition(contentX, contentY, searchW, topH) then
            setActiveField("roster_search")
            return
        end

        local filterPills = { "all", "online", "duty" }
        local fPillX = contentX + searchW + math.floor(14 * scale)
        local pillW = math.floor(100 * scale)
        for _, pId in ipairs(filterPills) do
            if isMouseInPosition(fPillX, contentY, pillW, topH) then
                rosterFilter = pId
                rosterScroll = 0
                return
            end
            fPillX = fPillX + pillW + math.floor(8 * scale)
        end

        if playerData and playerData.canInvite then
            local invBtnW = math.floor(180 * scale)
            local invBtnX = contentX + contentW - invBtnW
            if isMouseInPosition(invBtnX, contentY, invBtnW, topH) then
                isInviteModalOpen = true
                inviteTargetInput = ""
                inviteSelectedNearby = nil
                inviteSelectedRank = 1
                setActiveField("invite_target")
                return
            end
        end

        local tableY = contentY + topH + math.floor(12 * scale)
        local thH = math.floor(32 * scale)
        local rowH = math.floor(48 * scale)

        local col1X = contentX + math.floor(16 * scale)
        local col2X = col1X + math.floor(90 * scale)
        local col3X = col2X + math.floor(240 * scale)
        local col4X = col3X + math.floor(180 * scale)
        local col5X = col4X + math.floor(120 * scale)

        local filteredMembers = {}
        local q = string.lower(rosterSearchText)
        for _, m in ipairs(memberList) do
            local pass = true
            if rosterFilter == "online" and not m.is_online then pass = false end
            if rosterFilter == "duty" and not m.duty_status then pass = false end
            if pass and q ~= "" then
                local mName = string.lower(m.character_name or "")
                local mId = tostring(m.character_id or "")
                if not string.find(mName, q, 1, true) and not string.find(mId, q, 1, true) then pass = false end
            end
            if pass then table.insert(filteredMembers, m) end
        end

        local maxRows = math.floor((contentH - topH - 12 * scale - thH) / rowH)
        for idx = 1, maxRows do
            local itemIndex = rosterScroll + idx
            local m = filteredMembers[itemIndex]
            if m and playerData and playerData.canManage then
                local myRank = playerData.rank_id or 1
                local maxR = playerData.maxRank or 5
                local isTargetLower = (m.rank_id < myRank) and (m.character_id ~= playerData.character_id)

                if isTargetLower then
                    local rowY = tableY + thH + (idx - 1) * rowH
                    local actBtnSize = math.floor(28 * scale)
                    local actY = rowY + math.floor((rowH - actBtnSize) / 2)

                    local promX = col5X
                    local demX = promX + actBtnSize + 6 * scale
                    local kickX = demX + actBtnSize + 6 * scale

                    if isMouseInPosition(promX, actY, actBtnSize, actBtnSize) then
                        if (m.rank_id + 1 < myRank) and (m.rank_id + 1 <= maxR) then
                            triggerServerEvent("faction:manageMember", resourceRoot, "promote", m.character_id)
                        else
                            notifyUser("error", "Üyeyi kendi rütbenize veya daha yükseğe terfi ettiremezsiniz!")
                        end
                        return
                    elseif isMouseInPosition(demX, actY, actBtnSize, actBtnSize) then
                        if m.rank_id > 1 then
                            triggerServerEvent("faction:manageMember", resourceRoot, "demote", m.character_id)
                        else
                            notifyUser("error", "Üye zaten en alt rütbede!")
                        end
                        return
                    elseif isMouseInPosition(kickX, actY, actBtnSize, actBtnSize) then
                        kickConfirmTarget = { charId = m.character_id, name = m.character_name }
                        return
                    end
                end
            end
        end

    elseif activeTab == 3 then
        local topH = math.floor(175 * scale)
        local halfW = math.floor((contentW - 14 * scale) / 2)
        local inpW = halfW - 32 * scale
        local inpH = math.floor(34 * scale)
        local qY = contentY + 34 * scale + inpH + 6 * scale
        local pillW = math.floor((inpW - 3 * 6 * scale) / 5)

        if isMouseInPosition(contentX + 16 * scale, contentY + 34 * scale, inpW, inpH) then
            setActiveField("vault_dep_amount")
            return
        end

        local quickPills = { 1000, 5000, 25000, 100000 }
        local qX = contentX + 16 * scale
        for _, amt in ipairs(quickPills) do
            if isMouseInPosition(qX, qY, pillW, 24 * scale) then
                local current = tonumber(vaultDepositAmount) or 0
                vaultDepositAmount = tostring(current + amt)
                return
            end
            qX = qX + pillW + 6 * scale
        end
        if isMouseInPosition(qX, qY, pillW, 24 * scale) then
            vaultDepositAmount = tostring(playerData and playerData.cash or 0)
            return
        end

        if isMouseInPosition(contentX + 16 * scale, qY + 30 * scale, math.floor(inpW * 0.62), inpH) then
            setActiveField("vault_dep_reason")
            return
        end

        local depBtnW = inpW - math.floor(inpW * 0.62) - 8 * scale
        if isMouseInPosition(contentX + 16 * scale + math.floor(inpW * 0.62) + 8 * scale, qY + 30 * scale, depBtnW, inpH) then
            local amt = tonumber(vaultDepositAmount)
            if not amt or amt <= 0 then
                notifyUser("error", "Lütfen geçerli bir yatırma miktarı girin!")
                return
            end
            if amt > (playerData and playerData.cash or 0) then
                notifyUser("error", "Üzerinizde bu kadar nakit bulunmuyor!")
                return
            end
            triggerServerEvent("faction:vaultAction", resourceRoot, "deposit", amt, vaultDepositReason)
            return
        end

        if playerData and playerData.canWithdraw then
            local withX = contentX + halfW + math.floor(14 * scale)
            if isMouseInPosition(withX + 16 * scale, contentY + 34 * scale, inpW, inpH) then
                setActiveField("vault_with_amount")
                return
            end

            local wqX = withX + 16 * scale
            for _, amt in ipairs(quickPills) do
                if isMouseInPosition(wqX, qY, pillW, 24 * scale) then
                    local current = tonumber(vaultWithdrawAmount) or 0
                    vaultWithdrawAmount = tostring(current + amt)
                    return
                end
                wqX = wqX + pillW + 6 * scale
            end
            if isMouseInPosition(wqX, qY, pillW, 24 * scale) then
                vaultWithdrawAmount = tostring(factionData and factionData.vault_balance or 0)
                return
            end

            if isMouseInPosition(withX + 16 * scale, qY + 30 * scale, math.floor(inpW * 0.62), inpH) then
                setActiveField("vault_with_reason")
                return
            end

            local withBtnW = inpW - math.floor(inpW * 0.62) - 8 * scale
            if isMouseInPosition(withX + 16 * scale + math.floor(inpW * 0.62) + 8 * scale, qY + 30 * scale, withBtnW, inpH) then
                local amt = tonumber(vaultWithdrawAmount)
                if not amt or amt <= 0 then
                    notifyUser("error", "Lütfen geçerli bir çekim miktarı girin!")
                    return
                end
                if amt > (factionData and factionData.vault_balance or 0) then
                    notifyUser("error", "Kasa bakiyesi bu miktar için yetersiz!")
                    return
                end
                triggerServerEvent("faction:vaultAction", resourceRoot, "withdraw", amt, vaultWithdrawReason)
                return
            end
        end
    end

    setActiveField(nil)
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    if isPanelOpen then
        showCursor(false)
        isPanelOpen = false
    end
    activeInvitePrompt = nil
    pcall(guiSetInputMode, "allow_binds")
    pcall(guiSetInputEnabled, false)
end)
