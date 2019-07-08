local syntax = require("oh.syntax")

local types = {}

function types.Type(val, node, parent, t)
    local meta = types.types[t or type(val)]
    assert(meta, "unknown meta type " .. (t or type(val)))
    return setmetatable({val = val, node = node, parent = parent}, meta)
end

do
    local META = {}
    META.__index = META
    META.IsTable = true

    function META:__tostring()
        return "{#" .. self.id .. "}"
    end

    function META:SetValue(key, val)
        self.tbl[types.Hash(key)] = val
    end

    function META:GetValue(key, val)
        return self.tbl[key]
    end

    local id = 0

    function types.Table(node)
        id = id + 1
        return setmetatable({node = node, tbl = {}, id = id}, META)
    end
end

do
    local meta = {}

    meta.IsType = true

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
        return types.Type(self.val, node, self, what)
    end

    function meta:Copy(t)
        return types.Type(self.val, self.node, self.parent, t or self.type)
    end

    function meta:Max(t)
        local copy = self:Copy()
        copy.max = t.val
        return copy
    end

    function meta:Combine(t)
        local combined = self.combined or {}
        local copy = self:Copy()
        copy.combined = {}
        for i,v in ipairs(combined) do
            copy.combined[i] = v:Copy()
        end
        table.insert(copy.combined, t:Copy())
        return copy
    end

    function meta:__tostring()
        local str

        if self.type == "function" then
            local lol = {}

            for k,v in pairs(self.val) do
                lol[k] = tostring(v)
            end

            str = self.type .. ": " .. table.concat(lol, ", ")
        elseif self.max then
            str = self.type .. "(" .. tostring(self.val) .. ".." .. tostring(self.max) .. ")"
        elseif self.type == "any" or self.type == "nil" then
            str =  self.type .. "(" .. self.node:Render() .. ")"
        else
            str = self.type .. "(" .. tostring(self.val) .. ")"
        end

        if self.combined then
            local lol = {}

            for k,v in pairs(self.combined) do
                lol[k] = tostring(v)
            end

            table.insert(lol, 1, str)

            str = "{ " .. table.concat(lol, " | ") .. " }"
        end

        return str
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

    function meta:Truthy()
        if self.type == "any" then
            return true
        end

        if self.val == nil or self.val == false then
            return false
        end

        return true
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
            local t = self:Type(self.BinaryOperatorMap[what], node)

            if syntax.CompiledBinaryOperatorFunctions[what] then

                if what == "==" and val.max then
                    if self.val >= val.val and self.val <= val.max then
                        t.val = true
                    else
                        t.val = false
                    end
                else
                    local ok, val2 = pcall(syntax.CompiledBinaryOperatorFunctions[what], self.val, val.val)
                    if ok then
                        t.val = val2
                    else
                        return self:ErrorBinary(what, val, node)
                        --print(val, self, val.val)
                    end
                end
            end

            return t
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

    types.types = {}

    function types.RegisterType(meta)

        for k,v in pairs(types.base_type) do
            meta[k] = meta[k] or v
        end

        for k,v in pairs(types.base_type.BinaryOperatorMap) do
            meta.BinaryOperatorMap[k] = meta.BinaryOperatorMap[k] or v
        end

        for k,v in pairs(types.base_type.PrefixOperatorMap) do
            meta.PrefixOperatorMap[k] = meta.PrefixOperatorMap[k] or v
        end

        meta.__index = meta

        types.types[meta.type] = meta
    end

    types.base_type = meta
end

do
    local meta = {}
    meta.type = "any"

    function meta:BinaryOperator(what, val, node) return self:Type("any", node) end
    function meta:PrefixOperator(what, node) return self:Type("any", node) end
    function meta:PostfixOperator(what, node) return self:Type("any", node) end
    function meta:Call(node, ...) return self:Type("any", node) end

    types.RegisterType(meta)
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

    types.RegisterType(meta)
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

    types.RegisterType(meta)
end


do
    local meta = {}
    meta.type = "table"

    meta.PrefixOperatorMap = {
        ["#"] = "number",
    }

    function meta:Max(t)
        self.max = t
    end

    types.RegisterType(meta)
end

do
    local meta = {}
    meta.type = "boolean"

    types.RegisterType(meta)
end

do
    local meta = {}
    meta.type = "nil"

    types.RegisterType(meta)
end


do
    local meta = {}
    meta.type = "..."

    types.RegisterType(meta)
end

do
    local meta = {}
    meta.type = "function"

    types.RegisterType(meta)
end

function types.Hash(t)
    assert(type(t) == "table" and (t.IsType or t.type == "letter" or t.value == "..."), "expected a type or identifier got " .. tostring(t))

    if t.type == "letter" or t.value == "..." then
        return t.value
    end

    if type(t.val) == "table" then
        return t.val.value.value
    end

    return t.val
end

return types