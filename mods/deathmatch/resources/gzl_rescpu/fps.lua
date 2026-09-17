local enabled = false
local frames, elapsed = 0, 0
local caption = "FPS: ..."
local white = tocolor(255, 255, 255, 255)

local function measure(delta)
    frames = frames + 1
    elapsed = elapsed + delta
    if elapsed >= 1000 then
        caption = "FPS: " .. math.floor(frames * 1000 / elapsed + 0.5)
        frames, elapsed = 0, 0
    end
end

local function draw()
    local sw = guiGetScreenSize()
    exports.aura_ui:uiDrawText(caption, sw / 2 - 80, 12, sw / 2 + 80, 38, white, 1.3, "default-bold", "center", "top", false, false, true)
end

addCommandHandler("simplefps", function()
    enabled = not enabled
    frames, elapsed, caption = 0, 0, "FPS: ..."
    if enabled then
        addEventHandler("onClientPreRender", root, measure)
        addEventHandler("onClientRender", root, draw, true, "low-1000")
    else
        removeEventHandler("onClientPreRender", root, measure)
        removeEventHandler("onClientRender", root, draw)
    end
    outputChatBox(enabled and "[FPS] Acildi: ekranin ust ortasi." or "[FPS] Kapatildi.", 255, 255, 255)
end)

addEventHandler("onClientRestore", root, function()
    frames, elapsed, caption = 0, 0, "FPS: ..."
end)