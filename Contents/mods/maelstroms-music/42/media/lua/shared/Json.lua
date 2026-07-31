require "Namespace"

MaelstromMusic.Json = {}

local function skipWhitespace(str, pos)
    local _, stop = string.find(str, "^[ \t\r\n]*", pos)
    return stop + 1
end

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

local parseValue

local function parseString(str, pos)
    local out = {}
    local i = pos + 1
    local len = string.len(str)
    while i <= len do
        local c = string.sub(str, i, i)
        if c == "\"" then
            return table.concat(out), i + 1
        elseif c == "\\" then
            local nextC = string.sub(str, i + 1, i + 1)
            if nextC == "u" then
                local hex = string.sub(str, i + 2, i + 5)
                local code = tonumber(hex, 16) or 63
                if code < 0x80 then
                    table.insert(out, string.char(code))
                elseif code < 0x800 then
                    table.insert(out, string.char(
                        0xC0 + math.floor(code / 0x40),
                        0x80 + (code % 0x40)
                    ))
                else
                    table.insert(out, string.char(
                        0xE0 + math.floor(code / 0x1000),
                        0x80 + (math.floor(code / 0x40) % 0x40),
                        0x80 + (code % 0x40)
                    ))
                end
                i = i + 6
            else
                table.insert(out, escapeMap[nextC] or nextC)
                i = i + 2
            end
        else
            table.insert(out, c)
            i = i + 1
        end
    end
    error("MaelstromMusic.Json: unterminated string at position " .. pos)
end

local function parseNumber(str, pos)
    local _, stop, numStr = string.find(str, "^(-?%d+%.?%d*[eE]?[-+]?%d*)", pos)
    if not numStr then
        error("MaelstromMusic.Json: invalid number at position " .. pos)
    end
    return tonumber(numStr), stop + 1
end

local function parseObject(str, pos)
    local obj = {}
    local i = skipWhitespace(str, pos + 1)
    if string.sub(str, i, i) == "}" then
        return obj, i + 1
    end
    while true do
        i = skipWhitespace(str, i)
        if string.sub(str, i, i) ~= "\"" then
            error("MaelstromMusic.Json: expected string key at position " .. i)
        end
        local key
        key, i = parseString(str, i)
        i = skipWhitespace(str, i)
        if string.sub(str, i, i) ~= ":" then
            error("MaelstromMusic.Json: expected ':' at position " .. i)
        end
        i = skipWhitespace(str, i + 1)
        local value
        value, i = parseValue(str, i)
        obj[key] = value
        i = skipWhitespace(str, i)
        local c = string.sub(str, i, i)
        if c == "," then
            i = skipWhitespace(str, i + 1)
        elseif c == "}" then
            return obj, i + 1
        else
            error("MaelstromMusic.Json: expected ',' or '}' at position " .. i)
        end
    end
end

local function parseArray(str, pos)
    local arr = {}
    local i = skipWhitespace(str, pos + 1)
    if string.sub(str, i, i) == "]" then
        return arr, i + 1
    end
    while true do
        i = skipWhitespace(str, i)
        local value
        value, i = parseValue(str, i)
        table.insert(arr, value)
        i = skipWhitespace(str, i)
        local c = string.sub(str, i, i)
        if c == "," then
            i = skipWhitespace(str, i + 1)
        elseif c == "]" then
            return arr, i + 1
        else
            error("MaelstromMusic.Json: expected ',' or ']' at position " .. i)
        end
    end
end

parseValue = function(str, pos)
    local c = string.sub(str, pos, pos)
    if c == "\"" then
        return parseString(str, pos)
    elseif c == "{" then
        return parseObject(str, pos)
    elseif c == "[" then
        return parseArray(str, pos)
    elseif c == "t" and string.sub(str, pos, pos + 3) == "true" then
        return true, pos + 4
    elseif c == "f" and string.sub(str, pos, pos + 4) == "false" then
        return false, pos + 5
    elseif c == "n" and string.sub(str, pos, pos + 3) == "null" then
        return nil, pos + 4
    elseif c == "-" or (c >= "0" and c <= "9") then
        return parseNumber(str, pos)
    else
        error("MaelstromMusic.Json: unexpected character '" .. tostring(c) .. "' at position " .. pos)
    end
end

function MaelstromMusic.Json.decode(str)
    if not str or str == "" then
        return nil, "empty input"
    end
    local ok, result = pcall(function()
        local i = skipWhitespace(str, 1)
        local value = parseValue(str, i)
        return value
    end)
    if not ok then
        return nil, tostring(result)
    end
    return result
end
