local characters = {}
local B = string.byte

function characters.IsLetter(c--[[#: number]])--[[#: boolean]]
    return
        (c >= B("a") and c <= B("z")) or
        (c >= B("A") and c <= B("Z")) or
        (c == B("_") or c == B("@") or c >= 127)
end

function characters.IsDuringLetter(c--[[#: number]])--[[#: boolean]]
    return
        (c >= B("a") and c <= B("z")) or
        (c >= B("0") and c <= B("9")) or
        (c >= B("A") and c <= B("Z")) or
        (c == B("_") or c == B("@") or c >= 127)
end

function characters.IsNumber(c--[[#: number]])--[[#: boolean]]
    return (c >= B("0") and c <= B("9"))
end

function characters.IsSpace(c--[[#: number]])--[[#: boolean]]
    return c > 0 and c <= 32
end

function characters.IsSymbol(c--[[#: number]])--[[#: boolean]]
    return
        c ~= B("_") and
        (
            (c >= B("!") and c <= B("/")) or
            (c >= B(":") and c <= B("?")) or
            (c >= B("[") and c <= B("`")) or
            (c >= B("{") and c <= B("~"))
        )
end

local function generate_map(str--[[#: string]])
    local out = {}

    for i = 1, #str do
        out[str:byte(i)] = true
    end

    return out
end

local allowed_hex = generate_map("1234567890abcdefABCDEF")

function characters.IsHex(c--[[#: number]])--[[#: boolean]]
    return allowed_hex[c] ~= nil
end


return characters