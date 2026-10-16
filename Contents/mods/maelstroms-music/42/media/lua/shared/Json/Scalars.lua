require "Namespace"

MaelstromMusic.Json.Scalars = {}

local escapeMap = {
    ["\""] = "\"",
    ["\\"] = "\\",
    ["/"] = "/",
    ["b"] = "\b",
    ["f"] = "\f",
    ["n"] = "\n",
    ["r"] = "\r",
    ["t"] = "\t",
}

-- Encodes a code point from a \u escape as UTF-8.
local function utf8Char(code)
    if code < 0x80 then
        return string.char(code)
    elseif code < 0x800 then
        return string.char(0xC0 + math.floor(code / 0x40), 0x80 + (code % 0x40))
    end
    return string.char(0xE0 + math.floor(code / 0x1000), 0x80 + (math.floor(code / 0x40) % 0x40), 0x80 + (code % 0x40))
end

-- Reads the escape sequence that starts with the backslash at i, returns its text and the next position.
local function readEscape(str, i)
    local escaped = string.sub(str, i + 1, i + 1)
    if escaped == "u" then
        return utf8Char(tonumber(string.sub(str, i + 2, i + 5), 16) or 63), i + 6
    end
    return escapeMap[escaped] or escaped, i + 2
end

-- Parses a JSON string at pos (escapes and \u sequences become UTF-8), returns it and the next position.
function MaelstromMusic.Json.Scalars.text(str, pos)
    local out = {}
    local i = pos + 1
    while true do
        local stop = string.find(str, '["\\]', i)
        if not stop then
            error("MaelstromMusic.Json: unterminated string at position " .. pos)
        end
        table.insert(out, string.sub(str, i, stop - 1))
        if string.sub(str, stop, stop) == "\"" then
            return table.concat(out), stop + 1
        end
        local text
        text, i = readEscape(str, stop)
        table.insert(out, text)
    end
end

-- Parses a JSON number at pos, returns it and the next position.
function MaelstromMusic.Json.Scalars.number(str, pos)
    local _, stop, numStr = string.find(str, "^(-?%d+%.?%d*[eE]?[-+]?%d*)", pos)
    if not numStr then
        error("MaelstromMusic.Json: invalid number at position " .. pos)
    end
    return tonumber(numStr), stop + 1
end

