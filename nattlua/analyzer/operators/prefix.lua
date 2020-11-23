local types = require("nattlua.types.types")

local operators = {
    ["-"] = function(l) return -l end,
    ["~"] = function(l) return bit.bnot(l) end,
    ["#"] = function(l) return #l end,
}

local function metatable_function(self, meta_method, l)
    if l.meta then
        local func = l.meta:Get(meta_method)

        if func then
            return self:Call(func, types.Tuple({l})):Get(1)
        end
    end
end

local function arithmetic(l, type, operator)
    assert(operators[operator], "cannot map operator " .. tostring(operator))
    if l.Type == type then
        if l:IsLiteral() then
            local obj = types.Number(operators[operator](l.data)):MakeLiteral(true)

            if l.max then
                obj.max = arithmetic(l.max, type, operator)
            end

            return obj
        end

        return types.Number()
    end

    return types.errors.other("no operator for " .. operator .. tostring(l) .. " in runtime")
end

return function(META)
    function META:PrefixOperator(node, l, env)
        local op = node.value.value

        if l.Type == "tuple" then l = l:Get(1) end

        if l.Type == "union" then
            local new_union = types.Union()
            local truthy_union = types.Union()
            local falsy_union = types.Union()

            for _, l in ipairs(l:GetTypes()) do
                local res = self:Assert(node, self:PrefixOperator(node, l, env))
                new_union:AddType(res)


                if res:IsTruthy() then
                    truthy_union:AddType(l)
                end

                if res:IsFalsy() then
                    falsy_union:AddType(l)
                end
            end

            new_union.truthy_union = truthy_union
            new_union.falsy_union = falsy_union

            return new_union:SetSource(node, l)
        end

        if l.Type == "any" then
            return types.Any()
        end

        if env == "typesystem" then
            if op == "typeof" then
                local obj = self:AnalyzeExpression(node.right, "runtime")

                if not obj then
                    return types.errors.other("cannot find '" .. node.right:Render() .. "' in the current typesystem scope")
                end
                return obj.contract or obj
            elseif op == "unique" then
                local obj = self:AnalyzeExpression(node.right, "typesystem")
                obj:MakeUnique(true)
                return obj
            elseif op == "out" then
                local obj = self:AnalyzeExpression(node.right, "typesystem")
                obj.out = true
                return obj
            elseif op == "$" then
                local obj = self:AnalyzeExpression(node.right, "typesystem")

                if obj.Type ~= "string" then
                    return types.errors.other("must evaluate to a string")
                end
                if not obj:IsLiteral() then
                    return types.errors.other("must be a literal")
                end

                obj.pattern_contract = obj:GetData()
            
                return obj
            end
        end

        if op == "-" then local res = metatable_function(self, "__unm", l) if res then return res end
        elseif op == "~" then local res = metatable_function(self, "__bxor", l) if res then return res end
        elseif op == "#" then local res = metatable_function(self, "__len", l) if res then return res end end

        if op == "not" or op == "!" then
            if l:IsTruthy() and l:IsFalsy() then
                return self:NewType(node, "boolean", nil, false, l):SetSource(node, l)
            end

            if l:IsTruthy() then
                return self:NewType(node, "boolean", false, true, l):SetSource(node, l)
            end

            if l:IsFalsy() then
                return self:NewType(node, "boolean", true, true, l):SetSource(node, l)
            end
        end


        if op == "-" then return arithmetic(l, "number", op)
        elseif op == "~" then return arithmetic(l, "number", op)
        elseif op == "#" then
            if l.Type == "table" then
                return types.Number(l:GetLength()):MakeLiteral(l:IsLiteral())
            elseif l.Type == "string" then
                return types.Number(l:GetData() and #l:GetData() or nil):MakeLiteral(l:IsLiteral())
            end
        end

        error("unhandled prefix operator in " .. env .. ": " .. op .. tostring(l))
    end

    function META:AnalyzePrefixOperatorExpression(node, env)
        return self:Assert(node, self:PrefixOperator(node, self:AnalyzeExpression(node.right, env), env))
    end
end
