local LuaEmitter = require("oh.lua_emitter")
local Expression = require("oh.expression")

local table_insert = table.insert

local META = {}
META.__index = META
META.type = "statement"

function META:__tostring()
    return "[" .. self.type .. " - " .. self.kind .. "] " .. ("%p"):format(self)
end

function META:Render()
    local em = LuaEmitter({preserve_whitespace = false, no_newlines = true})

    em:EmitStatement(self)

    return em:Concat()
end

function META:GetStatements()
    if self.kind == "if" then
        local flat = {}
        for _, statements in ipairs(self.statements) do
            for _, v in ipairs(statements) do
                table_insert(flat, v)
            end
        end
        return flat
    end
    return self.statements
end

function META:HasStatements()
    return self.statements ~= nil
end

function META:FindStatementsByType(what, out)
    out = out or {}
    for _, child in ipairs(self:GetStatements()) do
        if child.kind == what then
            table_insert(out, child)
        elseif child:GetStatements() then
            child:FindStatementsByType(what, out)
        end
    end
    return out
end

function META:ToExpression(kind)
    setmetatable(self, Expression)
    self.kind = kind
    return self
end

return function(kind)
    local node = {}
    node.tokens = {}
    node.kind = kind

    setmetatable(node, META)

    return node
end