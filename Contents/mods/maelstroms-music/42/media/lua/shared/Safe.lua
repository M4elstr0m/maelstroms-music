require "Namespace"
require "Log"

MaelstromMusic.Safe = {}

-- Runs fn in protected mode, logs a failure under the given context and returns whether it succeeded.
function MaelstromMusic.Safe.call(context, fn)
    local ok, err = pcall(fn)
    if not ok then
        MaelstromMusic.Log.write(context .. " - " .. tostring(err))
    end
    return ok
end
