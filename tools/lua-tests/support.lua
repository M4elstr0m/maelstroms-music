-- Shared harness of the stubbed engine tests, load it with dofile("tools/lua-tests/support.lua") from the repository root.
local root = "Contents/mods/maelstroms-music/42/media/lua/"
package.path = root .. "shared/?.lua;" .. root .. "client/?.lua;" .. root .. "server/?.lua;" .. package.path

local Support = { failures = 0, handlers = {} }

-- Prints the result of one assertion and counts failures.
function Support.check(description, condition)
    print((condition and "pass  " or "FAIL  ") .. description)
    if not condition then Support.failures = Support.failures + 1 end
end

-- Asserts that two values are equal, showing both when they are not.
function Support.equal(description, actual, expected)
    local same = actual == expected
    Support.check(same and description or (description .. " (got " .. tostring(actual) .. ", expected " .. tostring(expected) .. ")"), same)
end

-- Prints a line of state only when TRACE is set, to compare two runs of the same scenario.
function Support.trace(...)
    if os.getenv("TRACE") then print("trace", ...) end
end

-- Installs a global Events table that records every handler, so a test can fire an event by name.
function Support.installEvents()
    Support.handlers = {}
    Events = setmetatable({}, { __index = function(_, name)
        return { Add = function(handler)
            Support.handlers[name] = Support.handlers[name] or {}
            table.insert(Support.handlers[name], handler)
        end }
    end })
end

-- Calls every handler registered for an event.
function Support.fire(name, ...)
    for _, handler in ipairs(Support.handlers[name] or {}) do handler(...) end
end

-- Exits with the number of failed assertions.
function Support.finish()
    print(Support.failures == 0 and "all checks passed" or (Support.failures .. " check(s) failed"))
    os.exit(Support.failures == 0 and 0 or 1)
end

return Support
