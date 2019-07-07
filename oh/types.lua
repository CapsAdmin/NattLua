local oh = ...

oh.types = {}

function oh.RegisterType(meta)

    for k,v in pairs(oh.base_type) do
        meta[k] = meta[k] or v
    end

    for k,v in pairs(oh.base_type.BinaryOperatorMap) do
        meta.BinaryOperatorMap[k] = meta.BinaryOperatorMap[k] or v
    end

    for k,v in pairs(oh.base_type.PrefixOperatorMap) do
        meta.PrefixOperatorMap[k] = meta.PrefixOperatorMap[k] or v
    end

    meta.__index = meta

    oh.types[meta.type] = meta
end

function oh.Type(str, parent, node)
    assert(node and node.kind)
    return setmetatable({parent = parent, node = node}, oh.types[str])
end

local self_arg
function oh.TypeWalk(node, stack, handle_upvalue, ...)
    if node.kind == "value" then
        if node.value.type == "letter" then
            if node.upvalue_or_global then
                if handle_upvalue then
                    stack:Push(handle_upvalue(node, ...))
                else
                    stack:Push(oh.Type("any", nil, node))
                end
            else
                stack:Push(oh.Type("string", nil, node))
            end
        elseif node.value.type == "number" then
            stack:Push(oh.Type("number", nil, node))
        elseif node.value.type == "string" then
            stack:Push(oh.Type("string", nil, node))
        elseif node.value.value == "true" or node.value.value == "false" then
            stack:Push(oh.Type("boolean", nil, node))
        elseif node.value.value == "..." then
            stack:Push(oh.Type("any", nil, node))
        else
            error("unhandled value type " .. node.value.type)
        end
    elseif handle_upvalue and (node.kind == "function" or node.kind == "table") then
        stack:Push(handle_upvalue(node, ...))
    elseif node.kind == "function" then
        stack:Push(oh.Type("function", nil, node))
    elseif node.kind == "table" then
        stack:Push(oh.Type("table", nil, node))
    elseif node.kind == "binary_operator" then
        local r, l = stack:Pop(), stack:Pop()
        local op = node.value.value

        stack:Push(r:BinaryOperator(op, l, node))
    elseif node.kind == "prefix_operator" then
        local r = stack:Pop()
        local op = node.value.value

        stack:Push(r:PrefixOperator(op, node))
    elseif node.kind == "postfix_operator" then
        local r = stack:Pop()
        local op = node.value.value

        stack:Push(r:PostfixOperator(op, node))
    elseif node.kind == "postfix_expression_index" then
        local r = stack:Pop()
        local index = node.expression:Evaluate(oh.TypeWalk, handle_upvalue)

        stack:Push(r:BinaryOperator(".", index, node))
    elseif node.kind == "postfix_call" then
        local r = stack:Pop()
        local args = {}
        for i,v in ipairs(node.expressions) do
            args[i] = v:Evaluate(oh.TypeWalk, handle_upvalue)
        end

        if self_arg then
            stack:Push(r:Call(node, self_arg, unpack(args)))
            self_arg = nil
        else
            stack:Push(r:Call(node, unpack(args)))
        end
    else
        error("unhandled expression " .. node.kind)
    end
end

do
    local meta = {}

    meta.BinaryOperatorMap = {
        ["=="] = "boolean",
        ["~="] = "boolean",
        ["or"] = "any",
    }
    meta.PrefixOperatorMap = {
        ["not"] = "boolean",
    }
    meta.PostfixOperatorMap = {}

    function meta:Type(what, node)
        return oh.Type(what, self, node)
    end

    function meta:__tostring()
        return self.type
    end

    function meta:TraceBack()
        local list = {}
        local p = self
        for i = 1, math.huge do
            if not p then break end
            list[i] = p
            p = p.parent
        end
        return list
    end

    function meta:ErrorBinary(what, val, node)
        print(tostring(self) .. " " .. what .. " " .. tostring(val) .. " is an illegal operation")
        return self:Type("any", node)
    end

    function meta:ErrorPrefix(what, node)
        print(tostring(self) .. " " .. what .. " is an illegal operation")
        return self:Type("any", node)
    end

    function meta:ErrorPostfix(what, node)
        print(what .. " " .. tostring(self) .. " is an illegal operation")
        return self:Type("any", node)
    end

    function meta:BinaryOperator(what, val, node)
        if self.BinaryOperatorMap[what] then
            return self:Type(self.BinaryOperatorMap[what], node)
        end

        return self:ErrorBinary(what, val, node)
    end

    function meta:PrefixOperator(what, node)
        if self.PrefixOperatorMap[what] then
            return self:Type(self.PrefixOperatorMap[what], node)
        end

        return self:ErrorPrefix(what, val, node)
    end

    function meta:PostfixOperator(what, node)
        if self.PostfixOperatorMap[what] then
            return self:Type(self.PostfixOperatorMap[what], node)
        end

        return self:ErrorPostfix(what, val, node)
    end

    function meta:Call(node, ...)
        print(self, "(", ...)

        return self:Type("any", node)
    end

    oh.base_type = meta
end

do
    local meta = {}
    meta.type = "any"

    function meta:BinaryOperator(what, val, node) return self:Type("any", node) end
    function meta:PrefixOperator(what, node) return self:Type("any", node) end
    function meta:PostfixOperator(what, node) return self:Type("any", node) end
    function meta:Call(node, ...) return self:Type("any", node) end

    oh.RegisterType(meta)
end

do
    local meta = {}
    meta.type = "number"

    meta.PrefixOperator = {
        ["-"] = "number",
        ["~"] = "number",
    }

    meta.BinaryOperatorMap = {
        ["+"] = "number",
        ["-"] = "number",
        ["*"] = "number",
        ["/"] = "number",
        ["^"] = "number",
        ["%"] = "number",
        ["//"] = "number",

        ["&"] = "number",
        ["|"] = "number",
        ["~"] = "number",
        [">>"] = "number",
        ["<<"] = "number",

        ["<"] = "boolean",
        [">"] = "boolean",
        ["<="] = "boolean",
        [">="] = "boolean",
    }

    oh.RegisterType(meta)
end

do
    local meta = {}
    meta.type = "string"

    meta.BinaryOperatorMap = {
        [".."] = "string",

        ["<"] = "boolean",
        [">"] = "boolean",
        ["<="] = "boolean",
        [">="] = "boolean",
    }

    meta.PrefixOperatorMap = {
        ["#"] = "number",
    }

    oh.RegisterType(meta)
end


do
    local meta = {}
    meta.type = "table"

    meta.PrefixOperatorMap = {
        ["#"] = "number",
    }

    oh.RegisterType(meta)
end

do
    local meta = {}
    meta.type = "boolean"

    meta.BinaryOperatorMap = {
        ["=="] = "boolean",
        ["~="] = "boolean",
    }



    oh.RegisterType(meta)
end

do
    local meta = {}
    meta.type = "function"

    oh.RegisterType(meta)
end