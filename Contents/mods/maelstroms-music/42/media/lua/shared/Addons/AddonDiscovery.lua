require "Namespace"
require "Log"
require "Safe"
require "AddonManifest"

MaelstromMusic.Addons.Discovery = {}

local function requiresBaseMod(modId)
    local ok, info = pcall(getModInfoByID, modId)
    if not ok or not info then
        return false
    end
    local ok2, requireList = pcall(function() return info:getRequire() end)
    if not ok2 or not requireList then
        return false
    end
    for i = 0, requireList:size() - 1 do
        if requireList:get(i) == MaelstromMusic.MOD_ID then
            return true
        end
    end
    return false
end

local function displayName(modId)
    local ok, info = pcall(getModInfoByID, modId)
    if ok and info then
        local ok2, name = pcall(function() return info:getName() end)
        if ok2 and name and name ~= "" then
            return name
        end
    end
    return modId
end

function MaelstromMusic.Addons.Discovery.scan()
    local addons = {}

    MaelstromMusic.Safe.call("addon discovery failed", function()
        local ok, activated = pcall(getActivatedMods)
        if not ok or not activated then
            return
        end

        for i = 0, activated:size() - 1 do
            local modId = activated:get(i)
            if modId ~= MaelstromMusic.MOD_ID then
                local manifest = MaelstromMusic.Addons.Manifest.read(modId)
                if manifest then
                    if requiresBaseMod(modId) then
                        table.insert(addons, { modId = modId, name = displayName(modId) })
                    else
                        MaelstromMusic.Log.write("mod '" .. modId .. "' ships a Maelstrom's Music addon marker but its mod.info is missing \"require=" .. MaelstromMusic.MOD_ID .. "\" - ignoring it.")
                    end
                end
            end
        end
    end)

    table.sort(addons, function(a, b) return a.modId < b.modId end)
    return addons
end
