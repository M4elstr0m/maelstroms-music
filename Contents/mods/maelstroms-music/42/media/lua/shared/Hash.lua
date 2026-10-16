require "Namespace"

MaelstromMusic.Hash = {}

local MODULUS = 2147483647

-- Stable string hash (djb2), the same on every machine so a name keeps its place across sessions.
function MaelstromMusic.Hash.of(str)
    local hash = 5381
    for i = 1, #str do
        hash = (hash * 33 + string.byte(str, i)) % MODULUS
    end
    return hash
end
