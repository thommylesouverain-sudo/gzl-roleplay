Audio = {}

local lastWipeTick = 0

function Audio.playWipeEffect()
    local now = getTickCount()
    if now - lastWipeTick > 220 then
        lastWipeTick = now
        -- Cam silme ve çekçek sürtünme hissi
        playSoundFrontEnd(41)
    end
end

function Audio.playSuccess()
    -- Vitrin temizlendiğinde hoş bildirim sesi
    playSoundFrontEnd(13)
end

function Audio.playContractComplete()
    -- Sözleşme başarıyla tamamlandığında çalacak zafer sesi
    playSoundFrontEnd(12)
end

function Audio.playButtonClick()
    playSoundFrontEnd(41)
end