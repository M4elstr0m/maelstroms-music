-- Run from the repository root: lua5.1 tools/lua-tests/json_test.lua
local Support = dofile("tools/lua-tests/support.lua")
require "Namespace"
require "Json"
local decode = MaelstromMusic.Json.decode

local value = decode('{"title": "Night Radio", "shuffle": true, "fade": false, "frequency": 91.5, "drama": -2, "none": null}')
Support.equal("a string field", value.title, "Night Radio")
Support.equal("a true field", value.shuffle, true)
Support.equal("a false field", value.fade, false)
Support.equal("a decimal field", value.frequency, 91.5)
Support.equal("a negative field", value.drama, -2)
Support.equal("null decodes to nothing", value.none, nil)

local nested = decode('{"sequences": [{"before": "a.mp3", "after": "b.mp3"}, {"before": "b.mp3", "after": "c.mp3"}], "empty": [], "map": {}}')
Support.equal("an array of objects", #nested.sequences, 2)
Support.equal("a field of the second element", nested.sequences[2].after, "c.mp3")
Support.equal("an empty array", #nested.empty, 0)
Support.equal("an empty object", next(nested.map), nil)

Support.equal("escaped quote and backslash", decode('"a\\"b\\\\c"'), 'a"b\\c')
Support.equal("escaped control characters", decode('"1\\n2\\t3\\r4\\b5\\f6\\/7"'), "1\n2\t3\r4\b5\f6/7")
Support.equal("an unknown escape keeps the character", decode('"\\q"'), "q")
Support.equal("a two byte unicode escape", decode('"caf\\u00e9"'), "caf\195\169")
Support.equal("a three byte unicode escape", decode('"\\u20ac"'), "\226\130\172")
Support.equal("an ascii unicode escape", decode('"\\u0041"'), "A")
Support.equal("an exponent number", decode("1e3"), 1000)
Support.equal("whitespace around a value", decode(' \n\t 7 \r\n'), 7)
Support.equal("text after the first value is ignored", decode('{"a": 1} trailing').a, 1)
Support.equal("a long plain string", decode('"' .. string.rep("ab", 500) .. '"'), string.rep("ab", 500))
Support.equal("a string with an escape in the middle", decode('"left\\nright and more"'), "left\nright and more")

local missing, reason = decode("")
Support.check("empty input is refused with a reason", missing == nil and reason == "empty input")
Support.check("nil input is refused", decode(nil) == nil)
local _, unterminated = decode('{"a": "open')
Support.check("an unterminated string is reported", unterminated:find("unterminated string", 1, true) ~= nil)
local _, noColon = decode('{"a" 1}')
Support.check("a missing colon is reported", noColon:find("expected ':'", 1, true) ~= nil)
local _, noComma = decode('{"a": 1 "b": 2}')
Support.check("a missing comma is reported", noComma:find("expected ',' or '}'", 1, true) ~= nil)
local _, badArray = decode("[1 2]")
Support.check("a missing array comma is reported", badArray:find("expected ',' or ']'", 1, true) ~= nil)
local _, badKey = decode("{1: 2}")
Support.check("a non string key is reported", badKey:find("expected string key", 1, true) ~= nil)
local _, badToken = decode("@")
Support.check("an unexpected character is reported", badToken:find("unexpected character", 1, true) ~= nil)

Support.finish()
