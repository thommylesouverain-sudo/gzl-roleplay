local screenW, screenH = guiGetScreenSize()
local isVisible = false
local currentTab = "login"
local isProcessing = false
local fonts = nil
local fontTimer = nil
local rememberMe = false
local savedCredentialsApplied = false
local pendingLoginCredentials = nil

local SAVED_LOGIN_FILE = "@saved_login.xml"

local function loadSavedCredentials()
    if not fileExists(SAVED_LOGIN_FILE) then
        return nil
    end
    local xml = xmlLoadFile(SAVED_LOGIN_FILE)
    if not xml then
        return nil
    end
    local rem = xmlNodeGetAttribute(xml, "remember") == "true"
    local u = xmlNodeGetAttribute(xml, "user") or ""
    local p = xmlNodeGetAttribute(xml, "pass") or ""
    if p and p ~= "" then
        p = decodeString("base64", p) or ""
    end
    xmlUnloadFile(xml)
    return {
        remember = rem,
        username = u,
        password = p
    }
end

local function saveSavedCredentials(remember, username, password)
    if not remember then
        if fileExists(SAVED_LOGIN_FILE) then
            fileDelete(SAVED_LOGIN_FILE)
        end
        return
    end
    local xml = xmlLoadFile(SAVED_LOGIN_FILE)
    if not xml then
        xml = xmlCreateFile(SAVED_LOGIN_FILE, "login")
    end
    if xml then
        xmlNodeSetAttribute(xml, "remember", "true")
        xmlNodeSetAttribute(xml, "user", tostring(username or ""))
        xmlNodeSetAttribute(xml, "pass", encodeString("base64", tostring(password or "")))
        xmlSaveFile(xml)
        xmlUnloadFile(xml)
    end
end

local layout = {
    scale = 1,
    panelX = 0,
    panelY = 0,
    panelW = 0,
    panelH = 0,
    drawX = 0,
    tabY = 0,
    tabH = 0,
    formW = 0,
    inputH = 0,
    userLabelY = 0,
    userBoxY = 0,
    passLabelY = 0,
    passBoxY = 0,
    rememberY = 0,
    rememberH = 0,
    rememberHitW = 0,
    pass2LabelY = 0,
    pass2BoxY = 0,
    buttonY = 0,
    hintY = 0
}

local maxUsernameLength = type(AuthConfig) == "table" and tonumber(AuthConfig.MaxUsernameLength) or 24
local loginUserOptions = {placeholder = "Kullanıcı adın", icon = "user", radius = 9, maxChars = maxUsernameLength}
local loginPassOptions = {placeholder = "Şifren", masked = true, icon = "lock", radius = 9, maxChars = 72}
local registerUserOptions = {placeholder = "Kullanıcı adı belirle", icon = "user", radius = 9, maxChars = maxUsernameLength}
local registerPassOptions = {placeholder = "En az 4 karakter", masked = true, icon = "lock", radius = 9, maxChars = 72}
local registerPassConfirmOptions = {placeholder = "Şifreni yeniden yaz", masked = true, icon = "shield", radius = 9, maxChars = 72}
local loginButtonOptions = {radius = 9, theme = "blue", icon = "key", disabled = false}
local registerButtonOptions = {radius = 9, theme = "blue", icon = "check", disabled = false}

local requiredUIExports = {
    "getFont",
    "getAnimProgress",
    "resetAnimProgress",
    "drawRoundedRectangle",
    "drawGlassPanel",
    "drawDiagonalTabBarSVG",
    "drawIconSVG",
    "drawGlassButton",
    "drawGlassEditBox",
    "isMouseInPosition",
    "setActiveEditBox",
    "getActiveEditBox",
    "getEditBoxText",
    "setEditBoxText",
    "showToast"
}

local function isUIReady()
    local resource = getResourceFromName("gzl_ui")
    if not resource or getResourceState(resource) ~= "running" or not exports.gzl_ui then
        return false
    end
    for i = 1, #requiredUIExports do
        if not exports.gzl_ui[requiredUIExports[i]] then
            return false
        end
    end
    return true
end

local function showAuthToast(message, toastType)
    if isUIReady() then
        exports.gzl_ui:showToast(message, toastType)
    end
end

local function applySavedCredentials()
    if savedCredentialsApplied then
        return true
    end
    if not isUIReady() then
        return false
    end

    local saved = loadSavedCredentials()
    if saved and saved.remember then
        rememberMe = true
        if saved.username and saved.username ~= "" then
            exports.gzl_ui:setEditBoxText("login_user", saved.username)
        end
        if saved.password and saved.password ~= "" then
            exports.gzl_ui:setEditBoxText("login_pass", saved.password)
        end
    end

    savedCredentialsApplied = true
    return true
end

local function updateLayout()
    local scale = math.min(screenW / 1920, screenH / 1080)
    scale = math.max(0.78, math.min(1.18, scale))
    local panelW = 430 * scale
    local panelH = (currentTab == "login" and 620 or 670) * scale
    local panelX = math.max(34, 58 * scale)
    local panelY = math.max(22, (screenH - panelH) / 2)
    local formInset = 30 * scale

    layout.scale = scale
    layout.panelX = panelX
    layout.panelY = panelY
    layout.panelW = panelW
    layout.panelH = panelH
    layout.drawX = panelX
    layout.tabY = panelY + 234 * scale
    layout.tabH = 42 * scale
    layout.formW = panelW - formInset * 2
    layout.inputH = 44 * scale
    layout.userLabelY = panelY + 298 * scale
    layout.userBoxY = panelY + 318 * scale
    layout.passLabelY = panelY + 386 * scale
    layout.passBoxY = panelY + 406 * scale
    layout.rememberY = panelY + 462 * scale
    layout.rememberH = 22 * scale
    layout.rememberHitW = 160 * scale
    layout.pass2LabelY = panelY + 474 * scale
    layout.pass2BoxY = panelY + 494 * scale
    layout.buttonY = panelY + (currentTab == "login" and 500 or 570) * scale
    layout.hintY = panelY + (currentTab == "login" and 558 or 626) * scale
end

local function prepareFonts()
    if fonts then
        return true
    end
    if not isUIReady() then
        return false
    end

    local scale = layout.scale
    fonts = {
        brand = exports.gzl_ui:getFont("heavy", math.max(17, math.floor(23 * scale))),
        brandSub = exports.gzl_ui:getFont("medium", math.max(8, math.floor(9 * scale))),
        eyebrow = exports.gzl_ui:getFont("bold", math.max(8, math.floor(9 * scale))),
        title = exports.gzl_ui:getFont("heavy", math.max(20, math.floor(27 * scale))),
        body = exports.gzl_ui:getFont("medium", math.max(9, math.floor(10 * scale))),
        tab = exports.gzl_ui:getFont("bold", math.max(9, math.floor(10 * scale))),
        label = exports.gzl_ui:getFont("semibold", math.max(8, math.floor(9 * scale))),
        input = exports.gzl_ui:getFont("regular", math.max(9, math.floor(10 * scale))),
        button = exports.gzl_ui:getFont("bold", math.max(10, math.floor(11 * scale))),
        hint = exports.gzl_ui:getFont("medium", math.max(8, math.floor(9 * scale)))
    }

    loginUserOptions.font = fonts.input
    loginPassOptions.font = fonts.input
    registerUserOptions.font = fonts.input
    registerPassOptions.font = fonts.input
    registerPassConfirmOptions.font = fonts.input
    loginButtonOptions.font = fonts.button
    registerButtonOptions.font = fonts.button
    return true
end

local function setTab(tab)
    if tab ~= "login" and tab ~= "register" then
        return
    end
    currentTab = tab
    updateLayout()
end

local function drawBackdrop(alpha)
    local scale = layout.scale
    exports.gzl_ui:drawRoundedRectangle(0, 0, screenW, screenH, 8, tocolor(5, 9, 16, math.floor(92 * alpha)))
    exports.gzl_ui:drawRoundedRectangle(0, 0, math.min(screenW, 660 * scale), screenH, 8, tocolor(7, 12, 21, math.floor(132 * alpha)))
    exports.gzl_ui:drawRoundedRectangle(0, 0, math.min(screenW, 980 * scale), screenH, 8, tocolor(8, 13, 22, math.floor(46 * alpha)))
end

local function drawBrand(x, y, alpha)
    local scale = layout.scale
    local iconBox = 48 * scale
    local iconSize = 27 * scale
    exports.gzl_ui:drawRoundedRectangle(x, y, iconBox, iconBox, 11 * scale, tocolor(16, 30, 51, math.floor(224 * alpha)))
    exports.gzl_ui:drawIconSVG("badge", x + (iconBox - iconSize) / 2, y + (iconBox - iconSize) / 2, iconSize, tocolor(95, 168, 255, math.floor(255 * alpha)))
    exports.aura_ui:uiDrawText("#5FA8FFGZL #F4F7FCROLEPLAY", x + 61 * scale, y - 2 * scale, x + layout.panelW, y + 30 * scale, tocolor(244, 247, 252, math.floor(255 * alpha)), 1, fonts.brand, "left", "center", false, false, false, true)
    exports.aura_ui:uiDrawText("Hikâyenin başladığı yer", x + 61 * scale, y + 25 * scale, x + layout.panelW, y + 48 * scale, tocolor(151, 166, 188, math.floor(225 * alpha)), 1, fonts.brandSub, "left", "center")
end

local function drawForm(alpha)
    local scale = layout.scale
    local x = layout.drawX
    local y = layout.panelY
    local panelW = layout.panelW
    local formX = x + 30 * scale
    local formW = layout.formW
    local title = currentTab == "login" and "Şehre giriş yap" or "Hesabını oluştur"
    local body = currentTab == "login" and "Karakterlerine ulaş, hikâyene kaldığın yerden devam et." or "GZL dünyasına katılmak için güvenli hesabını oluştur."
    local railW = 3 * scale
    local hookW = 34 * scale

    exports.gzl_ui:drawGlassPanel(x, y, panelW, layout.panelH, 16 * scale)
    exports.gzl_ui:drawRoundedRectangle(x, y, railW, layout.panelH, 2 * scale, tocolor(95, 168, 255, math.floor(235 * alpha)))
    exports.gzl_ui:drawRoundedRectangle(x, y, hookW, railW, 2 * scale, tocolor(95, 168, 255, math.floor(235 * alpha)))
    exports.gzl_ui:drawRoundedRectangle(x, y + layout.panelH - railW, hookW, railW, 2 * scale, tocolor(95, 168, 255, math.floor(235 * alpha)))
    drawBrand(x + 30 * scale, y + 28 * scale, alpha)

    exports.aura_ui:uiDrawText("HESAP MERKEZİ", formX, y + 108 * scale, x + panelW - 30 * scale, y + 126 * scale, tocolor(95, 168, 255, math.floor(245 * alpha)), 1, fonts.eyebrow, "left", "top")
    exports.aura_ui:uiDrawText(title, formX, y + 132 * scale, x + panelW - 30 * scale, y + 174 * scale, tocolor(244, 247, 252, math.floor(255 * alpha)), 1, fonts.title, "left", "top")
    exports.aura_ui:uiDrawText(body, formX, y + 188 * scale, x + panelW - 30 * scale, y + 218 * scale, tocolor(161, 176, 198, math.floor(225 * alpha)), 1, fonts.body, "left", "top", false, true)

    local tabX = formX
    local tabW = formW
    local tabHalfW = tabW * 0.5
    exports.gzl_ui:drawDiagonalTabBarSVG(tabX, layout.tabY, tabW, layout.tabH, 9 * scale, currentTab)
    local loginHover = exports.gzl_ui:isMouseInPosition(tabX, layout.tabY, tabHalfW, layout.tabH)
    local registerHover = exports.gzl_ui:isMouseInPosition(tabX + tabHalfW, layout.tabY, tabHalfW, layout.tabH)
    local loginColor = currentTab == "login" and tocolor(247, 250, 255, math.floor(255 * alpha)) or tocolor(154, 169, 190, math.floor((loginHover and 235 or 180) * alpha))
    local registerColor = currentTab == "register" and tocolor(247, 250, 255, math.floor(255 * alpha)) or tocolor(154, 169, 190, math.floor((registerHover and 235 or 180) * alpha))
    exports.aura_ui:uiDrawText("GİRİŞ", tabX, layout.tabY, tabX + tabHalfW - 5 * scale, layout.tabY + layout.tabH, loginColor, 1, fonts.tab, "center", "center")
    exports.aura_ui:uiDrawText("KAYIT", tabX + tabHalfW + 5 * scale, layout.tabY, tabX + tabW, layout.tabY + layout.tabH, registerColor, 1, fonts.tab, "center", "center")

    exports.aura_ui:uiDrawText("KULLANICI ADI", formX, layout.userLabelY, formX + formW, layout.userLabelY + 16 * scale, tocolor(178, 193, 214, math.floor(230 * alpha)), 1, fonts.label, "left", "top")
    if currentTab == "login" then
        exports.gzl_ui:drawGlassEditBox("login_user", formX, layout.userBoxY, formW, layout.inputH, loginUserOptions)
    else
        exports.gzl_ui:drawGlassEditBox("reg_user", formX, layout.userBoxY, formW, layout.inputH, registerUserOptions)
    end

    exports.aura_ui:uiDrawText("ŞİFRE", formX, layout.passLabelY, formX + formW, layout.passLabelY + 16 * scale, tocolor(178, 193, 214, math.floor(230 * alpha)), 1, fonts.label, "left", "top")
    if currentTab == "login" then
        exports.gzl_ui:drawGlassEditBox("login_pass", formX, layout.passBoxY, formW, layout.inputH, loginPassOptions)

        local remY = layout.rememberY
        local remH = layout.rememberH
        local checkSize = 18 * scale
        local checkY = remY + (remH - checkSize) * 0.5
        local checkX = formX

        local textX = checkX + checkSize + 10 * scale
        local textW = fonts and exports.aura_ui:uiTextWidth("Beni Hatırla", 1, fonts.label) or (80 * scale)
        layout.rememberHitW = (18 + 10) * scale + textW + 15 * scale
        local isRemHover = exports.gzl_ui:isMouseInPosition(checkX, remY, layout.rememberHitW, remH)

        local checkBorder = rememberMe and tocolor(95, 168, 255, math.floor(255 * alpha)) or (isRemHover and tocolor(140, 175, 215, math.floor(190 * alpha)) or tocolor(255, 255, 255, math.floor(45 * alpha)))
        local checkFill = rememberMe and tocolor(24, 78, 148, math.floor(240 * alpha)) or (isRemHover and tocolor(18, 28, 44, math.floor(210 * alpha)) or tocolor(12, 18, 28, math.floor(190 * alpha)))

        exports.gzl_ui:drawRoundedRectangle(checkX, checkY, checkSize, checkSize, 5 * scale, checkBorder)
        exports.gzl_ui:drawRoundedRectangle(checkX + 1, checkY + 1, checkSize - 2, checkSize - 2, 4 * scale, checkFill)

        if rememberMe then
            local iconPad = 2 * scale
            exports.gzl_ui:drawIconSVG("check", checkX + iconPad, checkY + iconPad, checkSize - iconPad * 2, tocolor(255, 255, 255, math.floor(255 * alpha)))
        end

        local labelColor = isRemHover and tocolor(244, 247, 252, math.floor(255 * alpha)) or tocolor(161, 176, 198, math.floor(225 * alpha))
        exports.aura_ui:uiDrawText("Beni Hatırla", textX, remY, formX + formW, remY + remH, labelColor, 1, fonts.label, "left", "center")
    else
        exports.gzl_ui:drawGlassEditBox("reg_pass", formX, layout.passBoxY, formW, layout.inputH, registerPassOptions)
        exports.aura_ui:uiDrawText("ŞİFRE TEKRARI", formX, layout.pass2LabelY, formX + formW, layout.pass2LabelY + 16 * scale, tocolor(178, 193, 214, math.floor(230 * alpha)), 1, fonts.label, "left", "top")
        exports.gzl_ui:drawGlassEditBox("reg_pass2", formX, layout.pass2BoxY, formW, layout.inputH, registerPassConfirmOptions)
    end

    loginButtonOptions.disabled = isProcessing
    registerButtonOptions.disabled = isProcessing
    if currentTab == "login" then
        exports.gzl_ui:drawGlassButton("login_submit", isProcessing and "GİRİŞ YAPILIYOR" or "GİRİŞ YAP", formX, layout.buttonY, formW, 46 * scale, loginButtonOptions)
    else
        exports.gzl_ui:drawGlassButton("register_submit", isProcessing and "HESAP OLUŞTURULUYOR" or "HESAP OLUŞTUR", formX, layout.buttonY, formW, 46 * scale, registerButtonOptions)
    end

    local hintText = currentTab == "login" and "Hesabın yok mu?  #5FA8FFKayıt ol" or "Zaten hesabın var mı?  #5FA8FFGiriş yap"
    local hintHover = exports.gzl_ui:isMouseInPosition(formX, layout.hintY, formW, 24 * scale)
    local hintColor = hintHover and tocolor(230, 238, 249, math.floor(255 * alpha)) or tocolor(154, 169, 190, math.floor(205 * alpha))
    exports.aura_ui:uiDrawText(hintText, formX, layout.hintY, formX + formW, layout.hintY + 24 * scale, hintColor, 1, fonts.hint, "left", "center", false, false, false, true)
end

local function renderAuthGUI()
    if not isVisible or not fonts or not isUIReady() then
        return
    end

    if not savedCredentialsApplied then
        applySavedCredentials()
    end

    local openProgress = exports.gzl_ui:getAnimProgress("auth_panel_open", 1, 0.12, 0)
    layout.drawX = layout.panelX - (1 - openProgress) * 26 * layout.scale
    drawBackdrop(openProgress)
    drawForm(openProgress)
end

function submitAuthForm()
    if isProcessing or not isUIReady() then
        return
    end

    if currentTab == "login" then
        local username = exports.gzl_ui:getEditBoxText("login_user")
        local password = exports.gzl_ui:getEditBoxText("login_pass")
        if string.len(username) == 0 or string.len(password) == 0 then
            showAuthToast("Lütfen kullanıcı adı ve şifre alanlarını doldurun.", "warning")
            return
        end
        isProcessing = true
        pendingLoginCredentials = { username = username, password = password }
        triggerServerEvent("auth:requestLogin", localPlayer, username, password)
    else
        local username = exports.gzl_ui:getEditBoxText("reg_user")
        local password = exports.gzl_ui:getEditBoxText("reg_pass")
        local passwordConfirm = exports.gzl_ui:getEditBoxText("reg_pass2")
        if string.len(username) == 0 or string.len(password) == 0 or string.len(passwordConfirm) == 0 then
            showAuthToast("Lütfen tüm alanları eksiksiz doldurun.", "warning")
            return
        end
        if password ~= passwordConfirm then
            showAuthToast("Şifreler birbiriyle uyuşmuyor.", "error")
            return
        end
        isProcessing = true
        triggerServerEvent("auth:requestRegister", localPlayer, username, password, passwordConfirm)
    end
end

addEventHandler("onClientClick", root, function(button, state)
    if not isVisible or isProcessing or button ~= "left" or state ~= "down" or not fonts or not isUIReady() then
        return
    end

    local scale = layout.scale
    local formX = layout.drawX + 30 * scale
    local formW = layout.formW
    local tabHalfW = formW * 0.5

    if exports.gzl_ui:isMouseInPosition(formX, layout.tabY, tabHalfW, layout.tabH) then
        setTab("login")
        return
    end
    if exports.gzl_ui:isMouseInPosition(formX + tabHalfW, layout.tabY, tabHalfW, layout.tabH) then
        setTab("register")
        return
    end

    if currentTab == "login" then
        if exports.gzl_ui:isMouseInPosition(formX, layout.userBoxY, formW, layout.inputH) then
            exports.gzl_ui:setActiveEditBox("login_user")
        elseif exports.gzl_ui:isMouseInPosition(formX, layout.passBoxY, formW, layout.inputH) then
            exports.gzl_ui:setActiveEditBox("login_pass")
        elseif exports.gzl_ui:isMouseInPosition(formX, layout.rememberY, layout.rememberHitW or (160 * scale), layout.rememberH) then
            rememberMe = not rememberMe
            if not rememberMe then
                saveSavedCredentials(false)
            end
            playSoundFrontEnd(41)
        elseif exports.gzl_ui:isMouseInPosition(formX, layout.buttonY, formW, 46 * scale) then
            submitAuthForm()
        elseif exports.gzl_ui:isMouseInPosition(formX, layout.hintY, formW, 24 * scale) then
            setTab("register")
        end
    else
        if exports.gzl_ui:isMouseInPosition(formX, layout.userBoxY, formW, layout.inputH) then
            exports.gzl_ui:setActiveEditBox("reg_user")
        elseif exports.gzl_ui:isMouseInPosition(formX, layout.passBoxY, formW, layout.inputH) then
            exports.gzl_ui:setActiveEditBox("reg_pass")
        elseif exports.gzl_ui:isMouseInPosition(formX, layout.pass2BoxY, formW, layout.inputH) then
            exports.gzl_ui:setActiveEditBox("reg_pass2")
        elseif exports.gzl_ui:isMouseInPosition(formX, layout.buttonY, formW, 46 * scale) then
            submitAuthForm()
        elseif exports.gzl_ui:isMouseInPosition(formX, layout.hintY, formW, 24 * scale) then
            setTab("login")
        end
    end
end)

addEventHandler("onClientKey", root, function(button, press)
    if not press or not isVisible or not fonts or not isUIReady() then
        return
    end

    if button == "enter" then
        submitAuthForm()
    elseif button == "tab" then
        local active = exports.gzl_ui:getActiveEditBox()
        local isShift = getKeyState("lshift") or getKeyState("rshift")
        if currentTab == "login" then
            exports.gzl_ui:setActiveEditBox(active == "login_user" and "login_pass" or "login_user")
        elseif not isShift then
            if active == "reg_user" then
                exports.gzl_ui:setActiveEditBox("reg_pass")
            elseif active == "reg_pass" then
                exports.gzl_ui:setActiveEditBox("reg_pass2")
            else
                exports.gzl_ui:setActiveEditBox("reg_user")
            end
        else
            if active == "reg_pass2" then
                exports.gzl_ui:setActiveEditBox("reg_pass")
            elseif active == "reg_pass" then
                exports.gzl_ui:setActiveEditBox("reg_user")
            else
                exports.gzl_ui:setActiveEditBox("reg_pass2")
            end
        end
        cancelEvent()
    end
end)

addEvent("auth:response", true)
addEventHandler("auth:response", root, function(success, message, isLogin)
    isProcessing = false
    showAuthToast(message, success and "success" or "error")
    if not success or not isUIReady() then
        pendingLoginCredentials = nil
        return
    end

    if isLogin then
        if rememberMe and pendingLoginCredentials then
            saveSavedCredentials(true, pendingLoginCredentials.username, pendingLoginCredentials.password)
        else
            saveSavedCredentials(false)
        end
        pendingLoginCredentials = nil
        hideLoginScreen()
        triggerServerEvent("char:requestList", localPlayer)
    else
        local registeredUser = exports.gzl_ui:getEditBoxText("reg_user")
        exports.gzl_ui:setEditBoxText("login_user", registeredUser)
        exports.gzl_ui:setEditBoxText("login_pass", "")
        exports.gzl_ui:setEditBoxText("reg_pass", "")
        exports.gzl_ui:setEditBoxText("reg_pass2", "")
        setTab("login")
        exports.gzl_ui:setActiveEditBox("login_pass")
    end
end)

function showLoginScreen()
    if isVisible then
        return
    end
    isVisible = true
    updateLayout()
    prepareFonts()
    if isUIReady() then
        exports.gzl_ui:resetAnimProgress("auth_panel_open", 0)
        applySavedCredentials()
    end
    if not fonts and not isTimer(fontTimer) then
        fontTimer = setTimer(function()
            if isUIReady() then
                applySavedCredentials()
            end
            if prepareFonts() and isTimer(fontTimer) then
                killTimer(fontTimer)
                fontTimer = nil
            end
        end, 250, 20)
    end
    showCursor(true)
    showChat(false)
    local chatRes = getResourceFromName("gzl_chat")
    if chatRes and getResourceState(chatRes) == "running" then
        pcall(function() exports.gzl_chat:setChatVisible(false) end)
    end
    startAuthCamera()
    addEventHandler("onClientRender", root, renderAuthGUI)
end

addEvent("auth:showLoginScreen", true)
addEventHandler("auth:showLoginScreen", root, showLoginScreen)

function hideLoginScreen()
    if not isVisible then
        return
    end
    isVisible = false
    savedCredentialsApplied = false
    if isTimer(fontTimer) then
        killTimer(fontTimer)
        fontTimer = nil
    end
    showCursor(false)
    showChat(false)
    local chatRes = getResourceFromName("gzl_chat")
    if chatRes and getResourceState(chatRes) == "running" then
        pcall(function() exports.gzl_chat:setChatVisible(true) end)
    end
    stopAuthCamera()
    removeEventHandler("onClientRender", root, renderAuthGUI)
end

addEventHandler("onClientResourceStart", resourceRoot, function()
    if not getElementData(localPlayer, "loggedin") and not getElementData(localPlayer, "loggedin_character") then
        showLoginScreen()
        triggerServerEvent("auth:checkLoginState", localPlayer)
    end
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    if isTimer(fontTimer) then
        killTimer(fontTimer)
        fontTimer = nil
    end
    if isVisible then
        hideLoginScreen()
    end
end)