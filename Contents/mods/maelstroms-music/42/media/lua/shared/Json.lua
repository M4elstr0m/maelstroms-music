require "Namespace"
require "Json/Scalars"

-- Returns the position of the first non whitespace character from pos.
local function skipWhitespace(str, pos)
    local _, stop = string.find(str, "^[ \t\r\n]*", pos)
    return stop + 1
end

local parseValue

-- Parses a JSON object at pos into a table, returns it and the next position.
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
        key, i = MaelstromMusic.Json.Scalars.text(str, i)
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

-- Parses a JSON array at pos into a table, returns it and the next position.
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

-- Parses any JSON value at pos, returns it and the next position.
parseValue = function(str, pos)
    local c = string.sub(str, pos, pos)
    if c == "\"" then
        return MaelstromMusic.Json.Scalars.text(str, pos)
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
        return MaelstromMusic.Json.Scalars.number(str, pos)
    else
        error("MaelstromMusic.Json: unexpected character '" .. tostring(c) .. "' at position " .. pos)
    end
end

-- Decodes JSON text, returning nil and an error message when the text is empty or invalid.
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
