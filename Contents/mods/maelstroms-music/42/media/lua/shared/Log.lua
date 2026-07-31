require "Namespace"

MaelstromMusic.Log = {}

local PREFIX = "Maelstrom's Music: "

function MaelstromMusic.Log.write(message)
    print(PREFIX .. message)
end
