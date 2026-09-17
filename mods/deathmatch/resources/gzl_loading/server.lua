local startedAt = getTickCount()

local function getBootStatus()
    local launcher = getResourceFromName("gzl_launcher")
    if launcher and getResourceState(launcher) == "running" then
        local launcherExports = exports["gzl_launcher"]
        if launcherExports and launcherExports.getLauncherStatus then
            local status = launcherExports:getLauncherStatus()
            if type(status) == "table" then
                local progress = tonumber(status.progress) or 0
                local total = tonumber(status.total) or 0
                local ready = status.currentAction == "idle" and (tonumber(status.lastStartTime) or 0) > 0
                return progress, total, status.isBusy == true, ready
            end
        end
    end

    local elapsed = getTickCount() - startedAt
    return 0, 0, elapsed < 12000, elapsed >= 12000
end

local bootTimer = nil
local lastProgress, lastTotal, lastBusy, lastReady = -1, -1, nil, nil

local function checkAndBroadcastBootStatus()
    local progress, total, busy, ready = getBootStatus()
    if progress ~= lastProgress or total ~= lastTotal or busy ~= lastBusy or ready ~= lastReady then
        lastProgress, lastTotal, lastBusy, lastReady = progress, total, busy, ready
        triggerClientEvent(root, "gzl_loading:status", resourceRoot, progress, total, busy, ready)
    end

    if ready and not busy then
        if isTimer(bootTimer) then
            killTimer(bootTimer)
            bootTimer = nil
        end
    end
end

addEventHandler("onResourceStart", resourceRoot, function()
    setTransferBoxVisible(false)
    bootTimer = setTimer(checkAndBroadcastBootStatus, 2000, 0)
end)

addEventHandler("onPlayerJoin", root, function()
    local player = source
    setTimer(function(target)
        if not isElement(target) then return end
        local progress, total, busy, ready = getBootStatus()
        triggerClientEvent(target, "gzl_loading:status", resourceRoot, progress, total, busy, ready)
    end, 1000, 1, player)
end)

addEvent("gzl_loading:requestStatus", true)
addEventHandler("gzl_loading:requestStatus", resourceRoot, function()
    local player = client
    if not isElement(player) then return end
    local progress, total, busy, ready = getBootStatus()
    triggerClientEvent(player, "gzl_loading:status", resourceRoot, progress, total, busy, ready)
end)
