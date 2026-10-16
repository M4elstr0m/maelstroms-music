require "Namespace"
require "VanillaMusic"
require "VoicePreview"

MaelstromMusic.MainMenu.Mix = {}

local CLAIM_KEY = "mainmenu"
local PREVIEW_DUCK_LEVEL = 0.3

-- Music option volume, ducked while the character voice preview plays.
function MaelstromMusic.MainMenu.Mix.volume()
    local volume = MaelstromMusic.VanillaMusic.optionVolume()
    if MaelstromMusic.VoicePreview.isPlaying() then
        return volume * PREVIEW_DUCK_LEVEL
    end
    return volume
end

-- Mutes the vanilla soundtrack while the theme should play, and gives it back otherwise.
function MaelstromMusic.MainMenu.Mix.silenceVanilla(wanted)
    MaelstromMusic.VanillaMusic.claim(CLAIM_KEY, wanted)
    MaelstromMusic.VanillaMusic.refresh()
end
