local table_pool = require("nattlua.other.table_pool")

--[[#
local type TokenWhitespaceType = "line_comment" | "multiline_comment" | "comment_escape" | "space"
local type TokenType = "analyzer_debug_code" | "parser_debug_code" | "letter" | "string" | "number" | "symbol" | "end_of_file" | "shebang" | "discard" | "unknown" | TokenWhitespaceType
local type TokenReturnType = TokenType | false
local type WhitespaceToken = {
    type = TokenWhitespaceType,
    value = string,
    start = number,
    stop = number,
}
]]

local META = {}
META.__index = META

--[[# 
local analyzer function parent_type(what: literal string, offset: literal number)
    return analyzer:GetCurrentType(what:GetData(), offset:GetData())
end
type META.@Name = "Token"
type META.@Self = {
	type = TokenType,
	value = string,
	start = number,
	stop = number,
	is_whitespace = boolean | nil,
    string_value = nil | string,
    inferred_type = nil | any,
    inferred_types = nil | List<|any|>,
	whitespace = false | nil | {
		[1 .. inf] = parent_type<|"table", 2|>,
	},
}
]]

function META:__tostring()
    return self.type .. ": " .. self.value
end

function META:AddType(obj)
    self.inferred_types = self.inferred_types or {}
    table.insert(self.inferred_types, obj)
    self.inferred_type = obj
end

function META:GetTypes()
    return self.inferred_types or {}
end

function META:GetLastType()
    do return self.inferred_type end
    return self.inferred_types and self.inferred_types[#self.inferred_types]
end

local new_token = table_pool(
    function()
        local x = {
            type = "unknown",
            value = "",
            whitespace = false,
            start = 0,
            stop = 0,
        }
        return x
    end,
    3105585
)

function META.New(
    type--[[#: TokenType]],
    is_whitespace--[[#: boolean]],
    start--[[#: number]],
    stop--[[#: number]]
)--[[#: META.@Self]]
    local tk = new_token()
    tk.type = type
    tk.is_whitespace = is_whitespace
    tk.start = start
    tk.stop = stop
    setmetatable(tk, META)
    return tk
end

META.TokenWhitespaceType = TokenWhitespaceType
META.TokenType = TokenType
META.TokenReturnType = TokenReturnType
META.WhitespaceToken = TokenReturnType

return META