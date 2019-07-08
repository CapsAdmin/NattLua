local LuaEmitter = require("oh.lua_emitter")
local table_insert = table.insert
local table_concat = table.concat

local META = {}
META.__index = META
META.type = "expression"

function META:GetStartStop()
    local tbl = self:Flatten()
    local start, stop = tbl[1], tbl[#tbl]
    start = start.value.start

    if stop.kind ~= "value" then
        if stop.kind == "postfix_call" then
            stop = stop.tokens["call)"].stop
        elseif stop.kind == "postfix_expression_index" then
            stop = stop.tokens["]"].stop
        else
            error("not sure how to handle stop for " .. stop.kind)
        end
    else
        stop = stop.value.stop
    end

    return start, stop
end

function META:__tostring()
    return "[" .. self.type .. " - " .. self.kind .. "] " .. ("%p"):format(self)
end

function META:GetExpressions()
    if self.expression then
        return {self.expression}
    end

    return self.expressions or self.left or self.right
end

function META:GetExpression()
    return self.expression or self.expressions[1]
end

function META:GetUpvaluesAndGlobals(tbl)
    tbl = tbl or {}
    for _, v in ipairs(self:Flatten()) do
        if v.kind == "postfix_call" then
            for _, v in ipairs(v.expressions) do
                v:GetUpvaluesAndGlobals(tbl)
            end
        elseif v.kind == "postfix_expression_index" then
            v.expression:GetUpvaluesAndGlobals(tbl)
        end

        if v.upvalue_or_global then
            table_insert(tbl, v)
        end
    end
    return tbl
end

function META:GetKind(kind)
    local tbl = {}
    for _, v in ipairs(self:Flatten()) do
        if v.kind == kind then
            table_insert(tbl, v)
        end
    end
    return tbl
end

function META:Render()
    local em = LuaEmitter({preserve_whitespace = false, no_newlines = true})

    em:EmitExpression(self)

    return em:Concat()
end

do
    local function expand(node, tbl)

        if node.kind == "prefix_operator" or node.kind == "postfix_operator" then
            table_insert(tbl, node.value.value)
            table_insert(tbl, "(")
            expand(node.right or node.left, tbl)
            table_insert(tbl, ")")
            return tbl
        elseif node.kind:sub(1, #"postfix") == "postfix" then
            table_insert(tbl, node.kind:sub(#"postfix"+2))
        elseif node.kind ~= "binary_operator" then
            table_insert(tbl, node:Render())
        else
            table_insert(tbl, node.value.value)
        end

        if node.left then
            table_insert(tbl, "(")
            expand(node.left, tbl)
        end


        if node.right then
            table_insert(tbl, ", ")
            expand(node.right, tbl)
            table_insert(tbl, ")")
        end

        if node.kind:sub(1, #"postfix") == "postfix" then
            local str = {""}
            for _, exp in ipairs(node:GetExpressions()) do
                table_insert(str, exp:Render())
            end
            table_insert(tbl, table_concat(str, ", "))
            table_insert(tbl, ")")
        end

        return tbl
    end

    function META:DumpPresedence()
        local list = expand(self, {})
        local a = table_concat(list)
        return a
    end
end

do
    local meta = {}
    meta.__index = meta

    function meta:Push(val)
        self.values[self.i] = val
        self.i = self.i + 1
    end

    function meta:Pop()
        self.i = self.i - 1
        return self.values[self.i]
    end

    local function expand(node, cb, stack, ...)
        if node.left then
            expand(node.left, cb, stack, ...)
        end

        if node.right then
            expand(node.right, cb, stack, ...)
        end

        cb(node, stack, ...)
    end

    function META:Evaluate(cb, ...)
        local stack = setmetatable({values = {}, i = 1}, meta)
        expand(self, cb, stack, ...)
        return unpack(stack.values)
    end
end

do
    local function expand(node, tbl)
        if node.left then
            expand(node.left, tbl)
        end

        table_insert(tbl, node)

        if node.right then
            expand(node.right, tbl)
        end
    end

    function META:Flatten()
        local flat = {}

        expand(self, flat)

        return flat
    end

    local function expand(node, cb, arg)
        if node.left and not node.left.primary then
            expand(node.left, cb, arg)
        end

        if node.left and node.right then
            local res

            if node.left.kind ~= "binary_operator" then
                res = cb(node.left, node)
            end

            if res then
                expand(res, cb, arg)
            end

            res = cb(node.right, node, arg)

            if res then
                expand(res, cb, arg)
            end
        end

        if node.right and not node.right.primary then
            expand(node.right, cb, arg)
        end
    end

    function META:WalkValues(cb, arg)
        if self.kind ~= "binary_operator" or self.primary then
            cb(self)
        else
            expand(self, cb, arg)
        end
    end

    local function expand(node, cb, arg)
        if node.left then
            expand(node.left, cb, arg)
        end

        if node.left and node.right then
            cb(node.left, node, node.right, arg)
        end

        if node.right then
            expand(node.right, cb, arg)
        end
    end

    function META:WalkBinary(cb, arg)
        if self.kind ~= "binary_operator" then
            cb(self)
        else
            expand(self, cb, arg)
        end
    end
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