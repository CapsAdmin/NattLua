local tprint = require("libraries.tprint")

local B = string.byte
local C = string.char

--[[

        self:ReadSpace() then               return "space", true elseif
        self:ReadCommentEscape() then       return "comment_escape", true elseif

        self:ReadCMultilineComment() then   return "multiline_comment", true elseif
        self:ReadCLineComment() then        return "line_comment", true elseif

        self:ReadMultilineComment() then    return "multiline_comment", true elseif
        self:ReadLineComment() then         return "line_comment", true elseif

        self:ReadNumber() then              return "number", false elseif

        self:ReadMultilineString() then     return "string", false elseif
        self:ReadSingleString() then        return "string", false elseif
        self:ReadDoubleString() then        return "string", false elseif

        self:ReadLetter() then              return "letter", false elseif
        self:ReadSymbol() then              return "symbol", false elseif
        self:ReadEndOfFile() then           return "end_of_file", false elseif

]]

local syntax = {}

function syntax.IsLetter(c)
    return
        (c >= B'a' and c <= B'z') or
        (c >= B'A' and c <= B'Z') or
        (c == B'_' or c >= 127)
end

function syntax.IsDuringLetter(c)
    return syntax.IsLetter(c) or syntax.IsNumber(c)
end

function syntax.IsNumber(c)
    return (c >= B'0' and c <= B'9')
end

function syntax.IsSpace(c)
    return c > 0 and c <= 32
end

function syntax.IsSymbol(c)
    return c ~= B'_' and (
        (c >= B'!' and c <= B'/') or
        (c >= B':' and c <= B'@') or
        (c >= B'[' and c <= B'`') or
        (c >= B'{' and c <= B'~')
    )
end

local function Map(check, tbl)
    tbl = tbl or {}
    for i = 0, 255 do
        if not tbl[C(i)] then
            local val = check(i, tbl)
            if val then
                tbl[C(i)] = val
            end
        end
    end
    return tbl
end

local state = {}

local function Merge(state, tbl, to, fallback)
    for i = 1, 255 do
        local c = C(i)
        local v = tbl[c]

        if v == true then
            state[c] = to
        elseif fallback then
            state[c] = fallback[c]
        end
    end
end

local tagged = {}

local function Tag(tbl, what)
    tagged[tbl] = what
end

local number = Map(function(byte, tbl) return syntax.IsNumber(byte) end)
local space = Map(function(byte, tbl) return syntax.IsSpace(byte) end)
local letter = Map(function(byte, tbl) return syntax.IsLetter(byte) end)
local during_letter = Map(function(byte, tbl) return syntax.IsDuringLetter(byte) end)
local line_comment = {["-"] = {["-"] = Map(function(byte, tbl) return byte ~= B"\n" end)}}

Merge(line_comment["-"]["-"], line_comment["-"]["-"], line_comment["-"]["-"])
Merge(line_comment["-"]["-"], line_comment["-"]["-"], line_comment["-"]["-"], state)

Tag(state, "state")
Tag(space, "space")
Tag(number, "number")
Tag(letter, "letter")
Tag(during_letter, "letter")
Tag(line_comment, "line_comment")
Tag(line_comment["-"], "line_comment")
Tag(line_comment["-"]["-"], "line_comment")

Merge(state, space, space, state)
Merge(state, space, space)
Merge(state, line_comment, line_comment)

Merge(state, number, number)
Merge(number, number, number, state)

Merge(state, letter, during_letter)
Merge(during_letter, during_letter, during_letter, state)

print(state["1"]["1"][" "])
local code = [=====[


        -- adwadawd awdawd

        --[[
ww
        ]]

        --[==[
ww
        ]==]
]=====]
