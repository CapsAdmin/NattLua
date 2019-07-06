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

    function meta:Type(what)
        return oh.Type(what, self)
    end

    function meta:__tostring()
        return self.type
    end

    function meta:ErrorBinary(what, val, node)
        print(tostring(self) .. " " .. what .. " " .. tostring(val) .. " is an illegal operation")
        return self:Type("any")
    end

    function meta:ErrorPrefix(what, node)
        print(tostring(self) .. " " .. what .. " is an illegal operation")
        return self:Type("any")
    end

    function meta:ErrorPostfix(what, node)
        print(what .. " " .. tostring(self) .. " is an illegal operation")
        return self:Type("any")
    end

    function meta:BinaryOperator(what, val, node)
        if self.BinaryOperatorMap[what] then
            return self:Type(self.BinaryOperatorMap[what])
        end

        return self:ErrorBinary(what, val, node)
    end

    function meta:PrefixOperator(what, node)
        if self.PrefixOperatorMap[what] then
            return self:Type(self.PrefixOperatorMap[what])
        end

        return self:ErrorPrefix(what, val, node)
    end

    function meta:PostfixOperator(what, node)
        if self.PostfixOperatorMap[what] then
            return self:Type(self.PostfixOperatorMap[what])
        end

        return self:ErrorPostfix(what, val, node)
    end

    function meta:Call(node, ...)
        print(self, "(", ...)

        return self:Type("any")
    end

    oh.base_type = meta
end

do
    local meta = {}
    meta.type = "any"

    function meta:BinaryOperator(what, val, node) return self:Type("any") end
    function meta:PrefixOperator(what, node) return self:Type("any") end
    function meta:PostfixOperator(what, node) return self:Type("any") end
    function meta:Call(node, ...) return self:Type("any") end

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

function oh.Type(str, parent)
    return setmetatable({parent = parent}, oh.types[str])
end