
--[[#local type { Token } = import_type<|"nattlua/lexer/token.nlua"|>]]
--[[#local type { ExpressionKind, StatementKind } = import_type<|"nattlua/parser/nodes.nlua"|>]]
--[[#import_type<|"nattlua/code/code.lua"|>]]

--[[#local type NodeType = "expression" | "statement"]]
--[[#local type Node = any]]
local ipairs = _G.ipairs
local pairs = _G.pairs
local setmetatable = _G.setmetatable
local type = _G.type
local table = require("table")
local helpers = require("nattlua.other.helpers")
local quote_helper = require("nattlua.other.quote")

local META = {}
META.__index = META
META.Type = "node"

--[[#	
type META.@Name = "Node"

type META.@Self = {
    type = "expression" | "statement",
    kind = ExpressionKind | StatementKind,
    id = number,
    Code = Code,
    tokens = Map<|string, Token|>,
    environment = "typesystem" | "runtime",
    parent = nil | self,
    code_start = number,
    code_stop = number,
    
    statements = nil | List<|any|>,
    value = nil | Token,
}

local type Node = META.@Self

]]


local id = 0
function META.New(init--[[#: Omit<|META.@Self, "id" | "tokens" |> ]])--[[#: Node]]
    id = id + 1
    init.tokens = {}
    init.id = id
    return setmetatable(init --[[# as META.@Self ]], META)
end

function META:__tostring()
    if self.type == "statement" then
        local str = "[" .. self.type .. " - " .. self.kind .. "]"
        local lua_code = self.Code:GetString()
        local name = self.Code:GetName()

        if name:sub(1, 1) == "@" then
            local data = helpers.SubPositionToLinePosition(lua_code, self:GetStartStop())

            if data and data.line_start then
                str = str .. " @ " .. name:sub(2) .. ":" .. data.line_start
            else
                str = str .. " @ " .. name:sub(2) .. ":" .. "?"
            end
        else
            str = str .. " " .. ("%s"):format(self.id)
        end

        return str
    elseif self.type == "expression" then
        local str = "[" .. self.type .. " - " .. self.kind .. " - " .. ("%s"):format(self.id) .. "]"

        if self.value and type(self.value.value) == "string" then
            str = str .. ": " .. quote_helper.QuoteToken(self.value.value)
        end

        return str
    end
end

function META:Render(config)
    local em = require("nattlua.transpiler.emitter"--[[#as string]])(config or {preserve_whitespace = false, no_newlines = true})

    if self.type == "expression" then
        em:EmitExpression(self)
    else
        em:EmitStatement(self)
    end

    return em:Concat()
end

function META:GetStartStop()
    return self.code_start, self.code_stop
end

function META:GetStatement()
    if self.type == "statement" then
        return self
    end
    if self.parent then
        return self.parent:GetStatement()
    end
    return self
end

function META:GetRootExpression()
    if self.parent and self.parent.type == "expression" then
        return self.parent:GetRootExpression()
    end
    return self
end

function META:GetLength()
    local start, stop = self:GetStartStop()
    return stop - start
end

function META:GetNodes()--[[#: List<|any|>]]
    if self.kind == "if" then
        local flat--[[#: List<|any|>]] = {}

        for _, statements in ipairs(assert(self.statements)) do
            for _, v in ipairs(statements) do
                table.insert(flat, v)
            end
        end

        return flat
    end

    return self.statements or {}
end

function META:HasNodes()
    return self.statements ~= nil
end

local function find_by_type(node--[[#: META.@Self]], what--[[#: StatementKind | ExpressionKind]], out--[[#: List<|META.@Name|>]])
    out = out or {}

    for _, child in ipairs(node:GetNodes()) do
        if child.kind == what then
            table.insert(out, child)
        elseif child:GetNodes() then
            find_by_type(child, what, out)
        end
    end

    return out
end

function META:FindNodesByType(what--[[#: StatementKind | ExpressionKind]])
    return find_by_type(self, what, {})
end


return META