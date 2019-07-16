local LuaEmitter = require("oh.lua_emitter")
local table_insert = table.insert
local table_concat = table.concat

local META = {}
META.__index = META
META.type = "expression"

function META:__tostring()
    return "[" .. self.type .. " - " .. self.kind .. "] " .. ("%p"):format(self)
end

function META:Render()
    local em = LuaEmitter({preserve_whitespace = false, no_newlines = true})

    em:EmitExpression(self)

    return em:Concat()
end

setmetatable(META, {
    __call = function(_, kind)
        local node = {}
        node.tokens = {}
        node.kind = kind

        setmetatable(node, META)

        return node
    end
})

return META