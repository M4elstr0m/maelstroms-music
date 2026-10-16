require "Namespace"

MaelstromMusic.Log = {}

local PREFIX = "Maelstrom's Music: "

-- Prints a message to the game console, prefixed with the mod name.
function MaelstromMusic.Log.write(message)
    print(PREFIX .. message)
end
