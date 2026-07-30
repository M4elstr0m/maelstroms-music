require "Namespace"
require "Log"

MaelstromMusic.Safe = {}

function MaelstromMusic.Safe.call(context, fn)
    local ok, err = pcall(fn)
    if not ok then
        MaelstromMusic.Log.write(context .. " - " .. tostring(err))
    end
    return ok
end
