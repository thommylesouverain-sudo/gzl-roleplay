local depotPedElement = nil

local function initDepot()
    local d = Config.DepotLocation.ped
    depotPedElement = createPed(d.skin, d.x, d.y, d.z, d.rot)
    if isElement(depotPedElement) then
        setElementFrozen(depotPedElement, true)
        setElementData(depotPedElement, "name", "Temizlik Şefi")
    end
end

addEventHandler("onResourceStart", resourceRoot, function()
    initDepot()
end)

addEventHandler("onResourceStop", resourceRoot, function()
    if isElement(depotPedElement) then
        destroyElement(depotPedElement)
        depotPedElement = nil
    end
    for _, ply in ipairs(getElementsByType("player")) do
        JobServer.handlePlayerDisconnect(ply)
    end
end)

addEventHandler("onPlayerQuit", root, function()
    local ply = source
    LobbyServer.handlePlayerDisconnect(ply)
    JobServer.handlePlayerDisconnect(ply)
end)