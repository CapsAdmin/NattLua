local types = require("nattlua.types.types")
local type_errors = require("nattlua.types.error_messages")

local operators = {
    ["+"] = function(l,r) return l+r end,
    ["-"] = function(l,r) return l-r end,
    ["*"] = function(l,r) return l*r end,
    ["/"] = function(l,r) return l/r end,
    ["/idiv/"] = function(l,r) return (math.modf(l/r)) end,
    ["%"] = function(l,r) return l%r end,
    ["^"] = function(l,r) return l^r end,
    [".."] = function(l,r) return l..r end,

    ["&"] = function(l, r) return bit.band(l,r) end,
    ["|"] = function(l, r) return bit.bor(l,r) end,
    ["~"] = function(l,r) return bit.bxor(l,r) end,
    ["<<"] = function(l, r) return bit.lshift(l,r) end,
    [">>"] = function(l, r) return bit.rshift(l,r) end,

    ["=="] = function(l,r) return l==r end,
    ["<"] = function(l,r) return l<r end,
    ["<="] = function(l,r) return l<=r end,
}

local function metatable_function(self, meta_method, l,r, swap)
    if swap then
        l,r = r,l
    end

    if r:GetMetaTable() or l:GetMetaTable() then
        local func = (l:GetMetaTable() and l:GetMetaTable():Get(meta_method)) or (r:GetMetaTable() and r:GetMetaTable():Get(meta_method))

        if func then
            if func.Type == "function" then
                return self:Assert(self.current_expression, self:Call(func, types.Tuple({l, r}))):Get(1)
            else
                return func
            end
        end
    end
end

local function arithmetic(node, l,r, type, operator)
    assert(operators[operator], "cannot map operator " .. tostring(operator))

    if type and l.Type == type and r.Type == type then
        if l:IsLiteral() and r:IsLiteral() then
            local obj = types.Number(operators[operator](l:GetData(), r:GetData())):SetLiteral(true)

            if r:GetMax() then
                obj:SetMax(arithmetic(node, l, r:GetMax(), type, operator))
            end

            if l:GetMax() then
                obj:SetMax(arithmetic(node, l:GetMax(), r, type, operator))
            end

            return obj:SetNode(node):SetBinarySource(l,r)
        end

        return types.Number():SetNode(node):SetBinarySource(l,r)
    end
    
    return type_errors.binary(operator, l,r)
end

return function(META)
    function META:BinaryOperator(node, l, r, env, op)
        op = op or node.value.value

        -- adding two tuples at runtime in lua will practically do this
        if env == "runtime" then
            if l.Type == "tuple" then l = self:Assert(node, l:Get(1)) end
            if r.Type == "tuple" then r = self:Assert(node, r:Get(1)) end
        end

        -- normalize l and r to be both sets to reduce complexity
        if l.Type ~= "union" and r.Type == "union" then l = types.Union({l}) end
        if l.Type == "union" and r.Type ~= "union" then r = types.Union({r}) end

        if l.Type == "union" and r.Type == "union" then
            if op == "|" and env == "typesystem" then
                return types.Union({l, r}):SetNode(node):SetBinarySource(l, r)
            elseif op == "~" and env == "typesystem" then
                return l:RemoveType(r):Copy()
            else
                local new_union = types.Union()
                local truthy_union = types.Union()
                local falsy_union = types.Union()
                local condition = l
                
                for _, l in ipairs(l:GetData()) do
                    for _, r in ipairs(r:GetData()) do
                        local res, err = self:BinaryOperator(node, l, r, env, op)

                        if not res then
                            self:ErrorAndCloneCurrentScope(node, err, condition)
                        else
                            if res:IsTruthy() then
                                if self.type_checked then                                
                                    for _, t in ipairs(self.type_checked:GetData()) do
                                        if t:GetLuaType() == l:GetData() then
                                            truthy_union:AddType(t)
                                        end
                                    end                                
                                    
                                else
                                    truthy_union:AddType(l)
                                end
                            end
        
                            if res:IsFalsy() then
                                if self.type_checked then                                
                                    for _, t in ipairs(self.type_checked:GetData()) do
                                        if t:GetLuaType() == l:GetData() then
                                            falsy_union:AddType(t)
                                        end
                                    end                                
                                    
                                else
                                    falsy_union:AddType(l)
                                end
                            end

                            new_union:AddType(res)
                        end
                    end
                end

                if self.type_checked then
                    new_union.type_checked = self.type_checked
                    self.type_checked = nil
                end

                local upvalue = condition.upvalue or new_union.type_checked and new_union.type_checked.upvalue

                if upvalue then
                    self.current_statement.checks = self.current_statement.checks or {}
                    self.current_statement.checks[upvalue] = self.current_statement.checks[upvalue] or {}
                    table.insert(self.current_statement.checks[upvalue], new_union)
                end

                if op == "~=" then
                    new_union.inverted = true
                end
                
                truthy_union.upvalue = condition.upvalue
                falsy_union.upvalue = condition.upvalue
                new_union.truthy_union = truthy_union
                new_union.falsy_union = falsy_union

                return new_union:SetNode(node):SetSource(new_union):SetBinarySource(l,r)
            end
        end

        if env == "typesystem" then
            if op == "|" then
                return types.Union({l, r})
            elseif op == "~" then
                return l:RemoveType(r)
            elseif op == "&" or op == "extends" then
                if l.Type ~= "table" then
                    return false, "type ".. tostring(l) .. " cannot be extended"
                end
                return l:Extend(r)
            elseif op == ".." then
                return l:Copy():SetMax(r)
            elseif op == ">" then
                return types.Symbol((r:IsSubsetOf(l)))
            elseif op == "<" then
                return types.Symbol((l:IsSubsetOf(r)))
            elseif op == "+" then
                if l.Type == "table" and r.Type == "table" then
                    return l:Union(r)
                end
            end
        end

        if op == "." or op == ":" then
            return self:IndexOperator(node, l, r, env)
        end

        if l.Type == "any" or r.Type == "any" then
            return types.Any()
        end

        if op == "+" then local res = metatable_function(self, "__add", l, r) if res then return res end
        elseif op == "-" then local res = metatable_function(self, "__sub", l, r) if res then return res end
        elseif op == "*" then local res = metatable_function(self, "__mul", l, r) if res then return res end
        elseif op == "/" then local res = metatable_function(self, "__div", l, r) if res then return res end
        elseif op == "/idiv/" then local res = metatable_function(self, "__idiv", l, r) if res then return res end
        elseif op == "%" then local res = metatable_function(self, "__mod", l, r) if res then return res end
        elseif op == "^" then local res = metatable_function(self, "__pow", l, r) if res then return res end
        elseif op == "&" then local res = metatable_function(self, "__band", l, r) if res then return res end
        elseif op == "|" then local res = metatable_function(self, "__bor", l, r) if res then return res end
        elseif op == "~" then local res = metatable_function(self, "__bxor", l, r) if res then return res end
        elseif op == "<<" then local res = metatable_function(self, "__lshift", l, r) if res then return res end
        elseif op == ">>" then local res = metatable_function(self, "__rshift", l, r) if res then return res end end

        if l.Type == "number" and r.Type == "number" then
            if op == "~=" or op == "!=" then
                if l:GetMax() and l:GetMax():GetData() then
                    return (not (r:GetData() >= l:GetData() and r:GetData() <= l:GetMax():GetData())) and types.True() or types.Boolean()
                end

                if r:GetMax() and r:GetMax():GetData() then
                    return (not (l:GetData() >= r:GetData() and l:GetData() <= r:GetMax():GetData())) and types.True() or types.Boolean()
                end
            elseif op == "==" then
                if l:GetMax() and l:GetMax():GetData() then
                    return r:GetData() >= l:GetData() and r:GetData() <= l:GetMax():GetData() and types.Boolean() or types.False()
                end

                if r:GetMax() and r:GetMax():GetData() then
                    return l:GetData() >= r:GetData() and l:GetData() <= r:GetMax():GetData() and types.Boolean() or types.False()
                end
            end
        end

        if op == "==" then
            local res = metatable_function(self, "__eq", l, r)
            if res then
                return res
            end

            if l:IsLiteral() and r:IsLiteral() and l.Type == r.Type then

                if l.Type == "table" then
                    if env == "runtime" then
                        if l.reference_id and r.reference_id then
                            return l.reference_id == r.reference_id and types.True() or types.False()
                        end
                    end

                    if env == "typesystem" then
                        return l:IsSubsetOf(r) and r:IsSubsetOf(l) and types.True() or types.False()
                    end 

                    return types.Boolean()
                end


                return l:GetData() == r:GetData() and types.True() or types.False()
            end

            if l.Type == "table" and r.Type == "table" then
                if env == "typesystem" then
                    return l:IsSubsetOf(r) and r:IsSubsetOf(l) and types.True() or types.False()
                end
            end

            if l.Type == "symbol" and r.Type == "symbol" and l:GetData() == nil and r:GetData() == nil then
                return types.True()
            end

            if l.Type ~= r.Type then
                return types.False()
            end

            if l == r then
                return types.True()
            end

            return types.Boolean()
        elseif op == "~=" then
            local res = metatable_function(self, "__eq", l, r)
            if res then
                if res:IsLiteral() then
                    res:SetData(not res:GetData())
                end
                return res
            end
            if l:IsLiteral() and r:IsLiteral() then
                return l:GetData() ~= r:GetData() and types.True() or types.False()
            end

            if l == types.Nil() and r == types.Nil() then
                return types.True()
            end

            if l.Type ~= r.Type then
                return types.True()
            end

            if l == r then
                return types.False()
            end

            return types.Boolean()
        elseif op == "<" then
            local res = metatable_function(self, "__lt", l, r)
            if res then
                return res
            end

            if (l.Type == "string" and r.Type == "string") or (l.Type == "number" and r.Type == "number") then
                if l:IsLiteral() and r:IsLiteral() then
                    return types.Symbol(l:GetData() < r:GetData())
                end
                return types.Boolean()
            end

            return type_errors.binary(op, l,r)
        elseif op == "<=" then
            local res = metatable_function(self, "__le", l, r)
            if res then
                return res
            end

            if (l.Type == "string" and r.Type == "string") or (l.Type == "number" and r.Type == "number") then
                if l:IsLiteral() and r:IsLiteral() then
                    return types.Symbol(l:GetData() <= r:GetData())
                end
                return types.Boolean()
            end

            return type_errors.binary(op, l,r)
        elseif op == ">" then
            local res = metatable_function(self, "__lt", l, r)
            if res then
                return res
            end


            if (l.Type == "string" and r.Type == "string") or (l.Type == "number" and r.Type == "number") then
                if l:IsLiteral() and r:IsLiteral() then
                    return types.Symbol(l:GetData() > r:GetData())
                end
                return types.Boolean()
            end

            return type_errors.binary(op, l,r)
        elseif op == ">=" then
            local res = metatable_function(self, "__le", l, r)

            if res then
                return res
            end


            if (l.Type == "string" and r.Type == "string") or (l.Type == "number" and r.Type == "number") then
                if l:IsLiteral() and r:IsLiteral() then
                    return types.Symbol(l:GetData() >= r:GetData())
                end
                return types.Boolean()
            end

            return type_errors.binary(op, l,r)
        elseif op == "or" or op == "||" then
            if l:IsUncertain() or r:IsUncertain() then
                return types.Union({l,r}):SetNode(node):SetBinarySource(l,r)
            end

            -- when true, or returns its first argument
            if l:IsTruthy() then
                return l:Copy():SetNode(node):SetSource(l):SetBinarySource(l,r)
            end

            if r:IsTruthy() then
                return r:Copy():SetNode(node):SetSource(r):SetBinarySource(l,r)
            end

            return r:Copy():SetNode(node):SetSource(r)
        elseif op == "and" or op == "&&" then
            if l:IsTruthy() and r:IsFalsy() then
                if l:IsFalsy() or r:IsTruthy() then
                    return types.Union({l,r}):SetNode(node):SetBinarySource(l,r)
                end

                return r:Copy():SetNode(node):SetSource(r):SetBinarySource(l,r)
            end

            if l:IsFalsy() and r:IsTruthy() then
                if l:IsTruthy() or r:IsFalsy() then
                    return types.Union({l,r}):SetNode(node):SetBinarySource(l,r)
                end

                return l:Copy():SetNode(node):SetSource(l):SetBinarySource(l,r)
            end

            if l:IsTruthy() and r:IsTruthy() then
                if l:IsFalsy() and r:IsFalsy() then
                    return types.Union({l,r}):SetNode(node):SetBinarySource(l,r)
                end

                return r:Copy():SetNode(node):SetSource(r):SetBinarySource(l,r)
            else
                if l:IsTruthy() and r:IsTruthy() then
                    return types.Union({l,r}):SetNode(node):SetBinarySource(l,r)
                end

                return l:Copy():SetNode(node):SetSource(l):SetBinarySource(l,r)
            end
        end

        if op == ".." then
            if
                (l.Type == "string" and r.Type == "string") or
                (l.Type == "number" and r.Type == "string") or
                (l.Type == "number" and r.Type == "number") or
                (l.Type == "string" and r.Type == "number")
            then
                if l:IsLiteral() and r:IsLiteral() then
                    return self:NewType(node, "string", l:GetData() .. r:GetData(), true)
                end

                return self:NewType(node, "string")
            end

            return type_errors.binary(op, l,r)
        end

        if op == "+" then return arithmetic(node, l,r, "number", op)
        elseif op == "-" then return arithmetic(node, l,r, "number", op)
        elseif op == "*" then return arithmetic(node, l,r, "number", op)
        elseif op == "/" then return arithmetic(node, l,r, "number", op)
        elseif op == "/idiv/" then return arithmetic(node, l,r, "number", op)
        elseif op == "%" then return arithmetic(node, l,r, "number", op)
        elseif op == "^" then return arithmetic(node, l,r, "number", op)

        elseif op == "&" then return arithmetic(node, l,r, "number", op)
        elseif op == "|" then return arithmetic(node, l,r, "number", op)
        elseif op == "~" then return arithmetic(node, l,r, "number", op)
        elseif op == "<<" then return arithmetic(node, l,r, "number", op)
        elseif op == ">>" then return arithmetic(node, l,r, "number", op) end

        return type_errors.binary(op, l,r)
    end

    function META:AnalyzeBinaryOperatorExpression(node, env)
        local left
        local right

        if node.value.value == "and" then
            left = self:AnalyzeExpression(node.left, env)
            if left:IsFalsy() and left:IsTruthy() then
                -- if it's uncertain, remove uncertainty while analysing
                if left.Type == "union" then
                    left:DisableFalsy()
                end

                right = self:AnalyzeExpression(node.right, env)

                if self.current_statement.checks and right.upvalue then
                    local checks = self.current_statement.checks[right.upvalue]
                    if checks then
                        right = checks[#checks].truthy_union
                    end
                end

                if left.Type == "union" then
                    left:EnableFalsy()
                end
            elseif left:IsFalsy() and not left:IsTruthy() then
                -- if it's really false do nothing
                right = self:NewType(node.right, "nil")
            else
                right = self:AnalyzeExpression(node.right, env)    
            end
        elseif node.value.value == "or" then
            left = self:AnalyzeExpression(node.left, env)
            
            if left:IsTruthy() and not left:IsFalsy() then
                right = self:NewType(node.right, "nil")
            elseif left:IsFalsy() and not left:IsTruthy() then
                right = self:AnalyzeExpression(node.right, env)
            else
                right = self:AnalyzeExpression(node.right, env)
            end
        else
            left = self:AnalyzeExpression(node.left, env)
            right = self:AnalyzeExpression(node.right, env)
        end

        if node.and_expr then
            if node.and_expr.and_res == left then
                if left.Type == "union" then
                    left = left:Copy()
                    left:DisableFalsy()
                end
            end
        end

        if left.Type == "tuple" and not left:Get(1) then
            left = types.Nil()
        end

        if right.Type == "tuple" and not right:Get(1) then
            right = types.Nil()
        end

        assert(left)
        assert(right)

        -- TODO: more elegant way of dealing with self?
        if node.value.value == ":" then
            self.self_arg_stack = self.self_arg_stack or {}
            table.insert(self.self_arg_stack, left)
        end

        return self:Assert(node, self:BinaryOperator(node, left, right, env))
    end
end