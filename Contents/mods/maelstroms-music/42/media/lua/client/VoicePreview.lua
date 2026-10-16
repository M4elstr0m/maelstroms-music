require "Namespace"

MaelstromMusic.VoicePreview = {}

local previewPanel = nil

-- Whether the character creation voice preview is currently playing.
function MaelstromMusic.VoicePreview.isPlaying()
    if not previewPanel or not previewPanel.soundPlayer or not previewPanel.soundRef or previewPanel.soundRef == 0 then
        return false
    end
    return previewPanel.soundPlayer:isPlaying(previewPanel.soundRef)
end

if CharacterCreationMain and CharacterCreationMain.onOptionMouseDown then
    local originalOnOptionMouseDown = CharacterCreationMain.onOptionMouseDown

    -- Remembers the creation screen when the voice preview button is pressed.
    function CharacterCreationMain:onOptionMouseDown(button, x, y)
        originalOnOptionMouseDown(self, button, x, y)
        if button.internal == "PLAYDEMOVOICE" then
            previewPanel = self
        end
    end
end
