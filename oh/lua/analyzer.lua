
local syntax = require("oh.lua.syntax")
local types = require("oh.typesystem.types")
types.Initialize()

local META = {}

do -- type operators
    function META:PostfixOperator(node, r, env)
        local op = node.value.value

        if op == "++" then
            return self:BinaryOperator({value = {value = "+"}}, r, r, env)
        end
    end

    local operators = {
        ["-"] = function(l) return -l end,
        ["~"] = function(l) return bit.bnot(l) end,
        ["#"] = function(l) return #l end,
    }

    local function metatable_function(self, meta_method, l)
        if l.meta then
            local func = l.meta:Get(meta_method)

            if func then
                return self:Call(func, types.Tuple:new({l})):Get(1)
            end
        end
    end

    local function arithmetic(l, type, operator)
        assert(operators[operator], "cannot map operator " .. tostring(operator))
        if l.type == type then
            if l:IsConst() then
                local obj = types.Object:new(type, operators[operator](l.data), true)

                if l.max then
                    obj.max = arithmetic(l.max, type, operator)
                end

                return obj
            end

            return types.Object:new(type)
        end

        return false, "no operator for " .. operator .. tostring(l) .. " in runtime"
    end

    function META:PrefixOperator(node, l, env)
        local op = node.value.value

        if l.Type == "tuple" then l = l:Get(1) end

        if l.Type == "set" then
            local new_set = types.Set:new()

            for _, l in ipairs(l:GetElements()) do
                new_set:AddElement(assert(self:PrefixOperator(node, l, env)))
            end

            return new_set
        end

        if l.type == "any" then
            return types.Object:new("any")
        end

        if env == "typesystem" then
            if op == "typeof" then
                local obj = self:GetValue(node.right, "runtime")
                if not obj then
                    return false, "cannot find " .. self:Hash(node.right) .. " in the current typesystem scope"
                end
                return obj.contract or obj
            end
        end

        if op == "-" then local res = metatable_function(self, "__unm", l) if res then return res end
        elseif op == "~" then local res = metatable_function(self, "__bxor", l) if res then return res end
        elseif op == "#" then local res = metatable_function(self, "__len", l) if res then return res end end

        if op == "not" then
            if l:IsTruthy() and l:IsFalsy() then
                return types.Object:new("boolean")
            end

            if l:IsTruthy() then
                return types.Object:new("boolean", false, true)
            end

            if l:IsFalsy() then
                return types.Object:new("boolean", true, true)
            end
        end


        if op == "-" then return arithmetic(l, "number", op)
        elseif op == "~" then return arithmetic(l, "number", op)
        elseif op == "#" then
            if l.Type == "dictionary" then
                return types.Object:new("number", l:GetLength(), l:IsConst())
            elseif l.Type == "object" and l.type == "string" then
                return types.Object:new("number", l:GetData() and #l:GetData() or nil, l:IsConst())
            end
        end

        error("unhandled prefix operator in " .. env .. ": " .. op .. tostring(l))
    end

    local operators = {
        ["+"] = function(l,r) return l+r end,
        ["-"] = function(l,r) return l-r end,
        ["*"] = function(l,r) return l*r end,
        ["/"] = function(l,r) return l/r end,
        ["//"] = function(l,r) return math.floor(l/r) end,
        ["%"] = function(l,r) return l%r end,
        ["^"] = function(l,r) return l^r end,
        [".."] = function(l,r) return l..r end,

        ["&"] = function(l, r) return bit.band(l,r) end, -- bitwise AND (&) operation.
        ["|"] = function(l, r) return bit.bor(l,r) end, -- bitwise OR (|) operation.
        ["~"] = function(l,r) return bit.bxor(l,r) end, -- bitwise exclusive OR (binary ~) operation.
        ["<<"] = function(l, r) return bit.lshift(l,r) end, -- bitwise left shift (<<) operation.
        [">>"] = function(l, r) return bit.rshift(l,r) end, -- bitwise right shift (>>) operation.

        ["=="] = function(l,r) return l==r end,
        ["<"] = function(l,r) return l<r end,
        ["<="] = function(l,r) return l<=r end,
    }

    local function metatable_function(self, meta_method, l,r, swap)
        if swap then
            l,r = r,l
        end

        if r.meta or l.meta then
            local func = (l.meta and l.meta:Get(meta_method)) or (r.meta and r.meta:Get(meta_method))

            if func then
                return self:Call(func, types.Tuple:new({l, r})):Get(1)
            end
        end
    end

    local function arithmetic(l,r, type, operator)
        assert(operators[operator], "cannot map operator " .. tostring(operator))
        if type and l.type == type and r.type == type then
            if l:IsConst() and r:IsConst() then
                local obj = types.Object:new(type, operators[operator](l.data, r.data), true)

                if r.max then
                    obj.max = arithmetic(l, r.max, type, operator)
                end

                if l.max then
                    obj.max = arithmetic(l.max, r, type, operator)
                end

                return obj
            end

            return types.Object:new(type)
        end

        return false, "no operator for " .. tostring(l) .. " " .. operator .. " " .. tostring(r) .. " in runtime"
    end

    function META:BinaryOperator(node, l, r, env)
        local op = node.value.value

        -- adding two tuples at runtime in lua will practically do this
        if l.Type == "tuple" then l = l:Get(1) end
        if r.Type == "tuple" then r = r:Get(1) end

        -- normalize l and r to be both sets to reduce complexity
        if l.Type == "set" and r.Type == "set" then l = types.Set:new({l}) end
        if l.Type == "set" and r.Type ~= "set" then r = types.Set:new({r}) end

        if l.Type == "set" and r.Type == "set" then
            local new_set = types.Set:new()

             for _, l in ipairs(l:GetElements()) do
                 for _, r in ipairs(r:GetElements()) do
                     new_set:AddElement(assert(self:BinaryOperator(node, l, r, env)))
                 end
             end

             return new_set
         end

        if env == "typesystem" then
            if op == "|" then
                return types.Set:new({l, r})
            elseif op == "&" then
                if l.Type == "dictionary" and r.Type == "dictionary" then
                    return l:Extend(r)
                end
            end

            if op == "extends" then
                return l:Extend(r)
            end

            -- number range
            if op == ".." then
                local new = l:Copy()
                new.max = r
                return new
            end
        end

        if op == "." or op == ":" then
            return self:GetOperator(l, r)
        end

        if l.type == "any" or r.type == "any" then
            return types.Object:new("any")
        end

        if op == "+" then local res = metatable_function(self, "__add", l, r) if res then return res end
        elseif op == "-" then local res = metatable_function(self, "__sub", l, r) if res then return res end
        elseif op == "*" then local res = metatable_function(self, "__mul", l, r) if res then return res end
        elseif op == "/" then local res = metatable_function(self, "__div", l, r) if res then return res end
        elseif op == "//" then local res = metatable_function(self, "__idiv", l, r) if res then return res end
        elseif op == "%" then local res = metatable_function(self, "__mod", l, r) if res then return res end
        elseif op == "^" then local res = metatable_function(self, "__pow", l, r) if res then return res end
        elseif op == "&" then local res = metatable_function(self, "__band", l, r) if res then return res end
        elseif op == "|" then local res = metatable_function(self, "__bor", l, r) if res then return res end
        elseif op == "~" then local res = metatable_function(self, "__bxor", l, r) if res then return res end
        elseif op == "<<" then local res = metatable_function(self, "__lshift", l, r) if res then return res end
        elseif op == ">>" then local res = metatable_function(self, "__rshift", l, r) if res then return res end end

        if l.Type == "object" then
            if l.type == "number" and r.type == "number" then
                if op == "~=" then
                    if l.max and l.max.data then
                        return types.Object:new("boolean", not (r.data >= l.data and r.data <= l.max.data), true)
                    end

                    if r.max and r.max.data then
                        return types.Object:new("boolean", not (l.data >= r.data and l.data <= r.max.data), true)
                    end
                elseif op == "==" then
                    if l.max and l.max.data then
                        return types.Object:new("boolean", r.data >= l.data and r.data <= l.max.data, true)
                    end

                    if r.max and r.max.data then
                        return types.Object:new("boolean", l.data >= r.data and l.data <= r.max.data, true)
                    end
                end
            end
        end

        if op == "==" then
            local res = metatable_function(self, "__eq", l, r)
            if res then
                return res
			end

            if l:IsConst() and r:IsConst() then
                return types.Object:new("boolean", l.data == r.data, true)
            end

            if l.type == "nil" and r.type == "nil" then
                return types.Object:new("boolean", nil == nil, true)
            end

            if l.type ~= r.type then
                return types.Object:new("boolean", false, true)
            end

            if l == r then
                return types.Object:new("boolean", true, true)
            end

            return types.Object:new("boolean")
        elseif op == "~=" then
            local res = metatable_function(self, "__eq", l, r)
            if res then
                if res:IsConst() then
                    res.data = not res.data
                end
                return res
            end
            if l:IsConst() and r:IsConst() then
                return types.Object:new("boolean", l.data ~= r.data, true)
            end

            if l.type == "nil" and r.type == "nil" then
                return types.Object:new("boolean", nil ~= nil, true)
            end

            if l.type ~= r.type then
                return types.Object:new("boolean", true, true)
            end

            if l == r then
                return types.Object:new("boolean", false, true)
            end

            return types.Object:new("boolean")
        elseif op == "<" then
            local res = metatable_function(self, "__lt", l, r)
            if res then
                return res
            end
            if l:IsConst() and r:IsConst() then
                return types.Object:new("boolean", l.data < r.data, true)
            end

            return types.Object:new("boolean")
        elseif op == "<=" then
            local res = metatable_function(self, "__le", l, r)
            if res then
                return res
            end
            if l:IsConst() and r:IsConst() then
                return types.Object:new("boolean", l.data <= r.data, true)
            end

            return types.Object:new("boolean")
        elseif op == ">" then
            local res = metatable_function(self, "__lt", l, r, true)
            if res then
                return res
            end
            if l:IsConst() and r:IsConst() then
                return types.Object:new("boolean", l.data > r.data, true)
            end

            return types.Object:new("boolean")
        elseif op == ">=" then
            local res = metatable_function(self, "__le", l, r, true)
            if res then
                return res
            end
            if l:IsConst() and r:IsConst() then
                return types.Object:new("boolean", l.data >= r.data, true)
            end

            return types.Object:new("boolean")
        elseif op == "or" then
            if l:IsTruthy() and l:IsFalsy() then
                return types.Set:new({l,r})
            end

            if r:IsTruthy() and r:IsFalsy() then
                return types.Set:new({l,r})
            end

            -- when true, or returns its first argument
            if l:IsTruthy() then
                return l
            end

            if r:IsTruthy() then
                return r
            end

            return r
        elseif op == "and" then
            if l:IsTruthy() and r:IsFalsy() then
                if l:IsFalsy() or r:IsTruthy() then
                    return types.Set:new({l,r})
                end

                return r
            end

            if l:IsFalsy() and r:IsTruthy() then
                if l:IsTruthy() or r:IsFalsy() then
                    return types.Set:new({l,r})
                end

                return l
            end

            if l:IsTruthy() and r:IsTruthy() then
                if l:IsFalsy() and r:IsFalsy() then
                    return types.Set:new({l,r})
                end

                return r
            else
                if l:IsTruthy() and r:IsTruthy() then
                    return types.Set:new({l,r})
                end

                return l
            end
        end

        if op == ".." then
            if
                (l.type == "string" or r.type == "string") and
                (l.type == "number" or r.type == "number" or l.type == "string" or l.type == "string")
            then
                if l:IsConst() and r:IsConst() then
                    return types.Object:new("string", l.data ..  r.data, true)
                end

                return types.Object:new("string")
            end

            return false, "no operator for " .. tostring(l) .. " " .. ".." .. " " .. tostring(r)
        end

        if op == "+" then return arithmetic(l,r, "number", op)
        elseif op == "-" then return arithmetic(l,r, "number", op)
        elseif op == "*" then return arithmetic(l,r, "number", op)
        elseif op == "/" then return arithmetic(l,r, "number", op)
        elseif op == "//" then return arithmetic(l,r, "number", op)
        elseif op == "%" then return arithmetic(l,r, "number", op)
        elseif op == "^" then return arithmetic(l,r, "number", op)

        elseif op == "&" then return arithmetic(l,r, "number", op)
        elseif op == "|" then return arithmetic(l,r, "number", op)
        elseif op == "~" then return arithmetic(l,r, "number", op)
        elseif op == "<<" then return arithmetic(l,r, "number", op)
        elseif op == ">>" then return arithmetic(l,r, "number", op) end

        error("no operator for "..tostring(l).." "..op.. " "..tostring(r) .. " in " .. env)
    end

    function META:SetOperator(obj, key, val, env)

        if obj.Type == "set" then
            local copy = types.Set:new()
            for _,v in ipairs(obj:GetElements()) do
                local ok, err = self:SetOperator(v, key, val, env)
                if not ok then
                    return ok, err
                end
                copy:AddElement(val)
            end
            return copy
        end

        if obj.meta then
            local func = obj.meta:Get("__newindex")

            if func then
                if func.Type == "dictionary" then
                    return func:Set(key, val)
                end

                if func.Type == "object" then
                    return self:Call(func, types.Tuple:new({obj, key, val}), key.node):Get(1)
                end
            end
        end


        if not obj.Set then
            return false, "undefined set: " .. tostring(obj) .. "[" .. tostring(key) .. "] = " .. tostring(val) .. " on type " .. obj.Type
        end

        return obj:Set(key, val)
    end

    function META:GetOperator(obj, key, env)
        if obj.Type == "set" then
            local copy = types.Set:new()
            for _,v in ipairs(obj:GetElements()) do
                local val, err = self:GetOperator(v, key)
                if not val then
                    return val, err
                end
                copy:AddElement(val)
            end
            return copy
        end

        if obj.Type ~= "dictionary" and obj.Type ~= "tuple" and (obj.Type ~= "object" or obj.type ~= "string") then
            return false, "undefined get: " .. tostring(obj) .. "[" .. tostring(key) .. "]"
        end

        if obj.Type == "dictionary" and obj.meta and not obj:Contains(key) then
            local index = obj.meta:Get("__index")

            if index then
                if index.Type == "dictionary" then
                    if index.contract then
                        return index.contract:Get(key)
                    else
                        return index:Get(key)
                    end
                end

                if index.Type == "object" then
                    return self:Call(index, types.Tuple:new({obj, key}), key.node):Get(1)
                end
            end
        end

        if obj.contract then
            return obj:Get(key)
        end

        local val = obj:Get(key)

        if not val then
            return self:TypeFromImplicitNode(obj.node, "nil")
        end

        return val
    end
end

do -- types
    function META:CreateLuaType(type, data, const)
        if type == "self" then
            local t = types.Dictionary:new(data, const)
            t.self = true
            return t
        elseif type == "table" then
            return types.Dictionary:new(data, const)
        elseif type == "..." then
            return types.Tuple:new(data)
        elseif type == "string" then
            local obj = types.Object:new(type, data, const)

            if not self.string_meta then
                local meta = self:CreateLuaType("table", {})
                meta:Set("__index", self.IndexNotFound and self:IndexNotFound("string") or self:GetValue("string", "typesystem"))
                self.string_meta = meta
            end

            obj.meta = self.string_meta

            return obj
        elseif type == "number" or type == "function" or type == "boolean" then
            return types.Object:new(type, data, const)
        elseif type == "nil" then
            return types.Object:new(type, const)
        elseif type == "any" then
            return types.Object:new(type, const)
        elseif type == "list" then
            data = data or {}
            local tup = types.Tuple:new(data.values)
            tup.ElementType = data.type
            tup.max = data.length
            return tup
        end

        error("NYI " .. type)
    end

    function META:TypeFromImplicitNode(node, name, data, const)
        node.scope = self.scope -- move this out of here

        local obj = self:CreateLuaType(name, data, const)

        if not obj then error("NYI: " .. name) end

        obj.node = node
        node.inferred_type = obj

        return obj
    end

    do
        local guesses = {
            {pattern = "count", type = "number"},
            {pattern = "tbl", type = "table", ctor = function(obj) obj:Set(types.Object:new("any"), types.Object:new("any")) end},
            {pattern = "str", type = "string"},
        }

        table.sort(guesses, function(a, b) return #a.pattern > #b.pattern end)

        function META:GetInferredType(node, env)
            local str = node.value.value:lower()

            for _, v in ipairs(guesses) do
                if str:find(v.pattern, nil, true) then
                    local obj = self:TypeFromImplicitNode(node, v.type)
                    if v.ctor then
                        v.ctor(obj)
                    end
                    return obj
                end
            end

            if env == "typesystem" then
                return self:TypeFromImplicitNode(node, "nil")
            end

            return self:TypeFromImplicitNode(node, "any")
        end
    end

    function META:Call(obj, arguments, call_node)
        call_node = call_node or obj.node
        local function_node = obj.node

        obj.called = true

        local env = self.PreferTypesystem and "typesystem" or "runtime"

        if obj.Type == "tuple" then
            obj = obj:Get(1)
        end

        if obj.Type == "set" then
            if obj:IsEmpty() then
                return false, "cannot call empty set"
            end

            for _, obj in ipairs(obj:GetData()) do
                if (obj.Type == "object" and not obj:IsType("function")) then
                    return false, "set contains uncallable object " .. tostring(obj)
                end
            end

            local errors = {}

            for _, obj in ipairs(obj:GetData()) do
                if arguments:GetLength() ~= obj:GetArguments():GetLength() then
                    table.insert(errors, "invalid amount of arguments")
                else
                    local res, reason = self:Call(obj, arguments, call_node)

                    if res then
                        return res
                    end

                    table.insert(errors, reason)
                end
            end

            return false, table.concat(errros, "\n")
        end

        if obj.Type == "object" and obj.type == "any" then
            return self:TypeFromImplicitNode(function_node, "any")
        end

        do
            local A = arguments -- incoming
            local B = obj:GetArguments() -- the contract
            -- A should be a subset of B

            for i, a in ipairs(A:GetData()) do
                local b = B:Get(i)
                if not b then
                    break
                end

                if b.Type == "tuple" then
                    b = b:Get(1)
                end

                local ok, reason = a:SubsetOf(b)

                if not ok then
                    return false, reason
                end
            end
        end

        local return_tuple

        if obj.data.lua_function then
            _G.self = self
            local res = {obj.data.lua_function(table.unpack(arguments.data))}
            _G.self = nil

            for i,v in ipairs(res) do
                if not types.IsTypeObject(v) then
                    res[i] = self:TypeFromImplicitNode(obj.node, type(v), v, true)
                end
            end
            return_tuple = types.Tuple:new(res)
        else
            return_tuple = obj:GetReturnTypes()
        end

        if not function_node or function_node.kind == "type_function" then
            self:FireEvent("external_call", call_node, obj)
        else
            if not function_node.statements then
                print(obj, function_node)
                error("cannot call " .. tostring(function_node) .. " because it has no statements")
            end

            do -- recursive guard
                if self.calling_function == obj then
                    return (obj:GetReturnTypes() and obj:GetReturnTypes().data and obj:GetReturnTypes():Get(1)) or types.Tuple:new({self:TypeFromImplicitNode(call_node, "any")})
                end
                self.calling_function = obj
            end

            self:PushScope(function_node)

                -- TODO: function_node can be a root statement because of loadstring
                if function_node.identifiers then
                    if function_node.self_call then
                        self:SetUpvalue("self", arguments:Get(1) or self:TypeFromImplicitNode(function_node, "nil"), env)
                    end

                    for i, identifier in ipairs(function_node.identifiers) do
                        local argi = function_node.self_call and (i+1) or i

                        if identifier.value.value == "..." then
                            local values = {}
                            for i = argi, arguments:GetLength() do
                                table.insert(values, arguments:Get(i))
                            end
                            self:SetUpvalue(identifier, self:TypeFromImplicitNode(identifier, "...", values), env)
                        else
                            self:SetUpvalue(identifier, arguments:Get(argi) or self:TypeFromImplicitNode(identifier, "nil"), env)
                        end
                    end
                end

                -- crawl and collect return values from function statements
                self:ReturnFromThisScope()
                self:AnalyzeStatements(function_node.statements)
                local analyzed_return = types.Tuple:new(self:GetReturnExpressions())
                self:ClearReturnExpressions()

            self:PopScope()

            self.calling_function = nil

            do
                -- if this function has an explicit return type
                if function_node.return_types then
                    local ok, reason = analyzed_return:SubsetOf(return_tuple)
                    if not ok then
                        return ok, reason
                    end
                else
                    -- copy the entire tuple so we don't modify the return value of this call
                    local ret_tuple = analyzed_return:Copy()

                    for _,v in ipairs(ret_tuple:GetData()) do
                        v.volatile = true
                    end

                    obj:GetReturnTypes():Merge(ret_tuple)
                end
            end

            obj:GetArguments():Merge(arguments, true)

            -- TODO
            if call_node and call_node.self_call then
                local first_arg = obj:GetArguments():Get(1)
                if first_arg and not first_arg.contract then
                    first_arg.volatile = true
                end
            end

            do -- this is for the emitter
                if function_node.identifiers then
                    for i, node in ipairs(function_node.identifiers) do
                        node.inferred_type = obj:GetArguments():Get(i)
                    end
                end

                function_node.inferred_type = obj
            end

            self:FireEvent("function_spec", obj)

            -- this is so that the return type of a function can access its arguments, to generics
            -- local function foo(a: number, b: number): Foo(a, b) return a + b end
            if function_node.return_types then
                self:PushScope(function_node)
                    for i, key in ipairs(function_node.identifiers) do
                        self:SetUpvalue(key, arguments:Get(i), "typesystem")
                    end

                    for i, type_exp in ipairs(function_node.return_types) do
                        analyzed_return:Set(i, self:AnalyzeExpression(type_exp, "typesystem"))
                    end
                self:PopScope()
            end

            return_tuple = analyzed_return
        end

        -- TODO: hacky workaround for trimming the returned tuple
        -- local a,b,c = (foo())
        -- b and c should be nil, a should be something
        if not return_tuple:IsEmpty() and call_node and call_node.tokens["("] and call_node.tokens[")"] then
            if return_tuple:Get(1).Type == "tuple" then
                return_tuple:Set(1, return_tuple:Get(1):Get(1))
            end

            return_tuple.data = {return_tuple:Get(1)}
        end

        if return_tuple:IsEmpty() then
            return_tuple:Set(1, self:TypeFromImplicitNode(call_node, "nil"))
        end

        return return_tuple
    end
end

function META:AnalyzeStatement(statement)
    self.current_statement = statement

    if statement.kind == "root" then
        self:PushScope(statement)
        self:AnalyzeStatements(statement.statements)
        self:PopScope()
        if self.deferred_calls then
            for _,v in ipairs(self.deferred_calls) do
                if not v[1].called then
                    local obj, arguments, node = table.unpack(v)

                    -- diregard arguments and use function's arguments in case they have been maniupulated (ie string.gsub)
                    arguments = obj:GetArguments()

                    self:Assert(node, self:Call(obj, arguments, node))
                end
            end
        end
    elseif statement.kind == "assignment" or statement.kind == "local_assignment" then
        local env = self.PreferTypesystem and "typesystem" or statement.environment or "runtime"
        local assignments = {}

        for i, exp_key in ipairs(statement.left) do
            if statement.kind == "local_assignment" then
                assignments[i] = {
                    key = exp_key,
                    env = env,
                }
            elseif statement.kind == "assignment" then
                if type(exp_key) == "string" or exp_key.kind == "value" then
                    assignments[i] = {
                        key = exp_key,
                        env = env,
                    }
                else
                    local obj = self:AnalyzeExpression(exp_key.left, env)
                    local key = exp_key.kind == "postfix_expression_index" and self:AnalyzeExpression(exp_key.expression, env) or self:AnalyzeExpression(exp_key.right, env)

                    assignments[i] = {
                        obj = obj,
                        key = key,
                    }
                end
            end
        end

        local values = {}

        if statement.right then
            for i, exp in ipairs(statement.right) do
                for i2, obj in ipairs({self:AnalyzeExpression(exp, env)}) do
                    if obj.Type == "tuple" then
                        for i3,v in ipairs(obj:GetData()) do
                            values[i + i2 - 1 + i3 - 1 ] = v
                        end
                    else
                        values[i + i2 - 1] = obj
                    end
                end
            end

            -- TODO: just to pass tests
            local cut = #values - #statement.right
            if cut > 0 and (statement.right[#statement.right] and statement.right[#statement.right].value and statement.right[#statement.right].value.value ~= "...") then
                for i = 1, cut do
                    table.remove(values, #values)
                end
            end
        end

        for i, exp_key in ipairs(statement.left) do
            local val = values[i] or self:TypeFromImplicitNode(exp_key, "nil")

            local key = assignments[i].key
            local obj = assignments[i].obj

            -- if there's a type expression override the right value
            if exp_key.type_expression then
                local contract = self:AnalyzeExpression(exp_key.type_expression, "typesystem")

                if contract.type == "nil" then
                    -- TODO: better error
                    self:Error(exp_key.type_expression, "cannot be nil")
                end

                if statement.right and statement.right[i] then

                    if contract.Type == "dictionary" then
                        val:CopyConstness(contract)
                    else
                        -- local a: 1 = 1
                        -- should turn the right side into a constant number rather than number(1)
                        val.const = contract:IsConst()
                    end

                    local ok, reason = val:SubsetOf(contract)

                    if not ok then
                        self:Error(val.node or exp_key.type_expression, tostring(val) .. " is not a subset of " .. tostring(contract) .. " because " .. reason)
                    end
                end

                if val.type == "dictionary" and contract.type == "list" then
                    assert("NYI")
                else
                    val.contract = contract
                end

                if not values[i] then
                    val = contract
                end

                --val = contract
            else
                -- by default assignments are not constant, even though TypeFromImplicitNode is const by default
              --  val.const = false
            end

            exp_key.inferred_type = val

            if statement.kind == "local_assignment" then
                self:SetUpvalue(key, val, env)
            elseif statement.kind == "assignment" then
                if type(exp_key) == "string" or exp_key.kind == "value" then
                    self:SetValue(key, val, env)
                else
                    self:Assert(exp_key, self:SetOperator(obj, key, val, env))
                    self:FireEvent("newindex", obj, key, val, env)
                end
            end
        end

    elseif statement.kind == "destructure_assignment" or statement.kind == "local_destructure_assignment" then
        local env = statement.environment or "runtime"
        local obj = self:AnalyzeExpression(statement.right, env)

        if obj.Type ~= "dictionary" then
            self:Error(statement.right, "expected a table on the right hand side, got " .. tostring(obj))
        end

        if statement.default then
            if statement.kind == "local_destructure_assignment" then
                self:SetUpvalue(statement.default, obj, env)
            elseif statement.kind == "destructure_assignment" then
                self:SetValue(statement.default, obj, env)
            end
        end

        for _, node in ipairs(statement.left) do
            local obj = node.value and obj:Get(node.value.value, env) or self:TypeFromImplicitNode(node, "nil")

            if statement.kind == "local_destructure_assignment" then
                self:SetUpvalue(node, obj, env)
            elseif statement.kind == "destructure_assignment" then
                self:SetValue(node, obj, env)
            end
        end
    elseif statement.kind == "function" then
        self:SetValue(statement.expression, self:GetValue(statement.expression, "typesystem") or self:AnalyzeFunction(statement, "runtime"), "runtime")
    elseif statement.kind == "local_function" then
        self:SetUpvalue(statement.tokens["identifier"], self:AnalyzeFunction(statement, "runtime"), "runtime")
    elseif statement.kind == "local_type_function" or statement.kind == "local_type_function2" then
        self:SetUpvalue(statement.identifier, self:AnalyzeFunction(statement, "typesystem"), "typesystem")
    elseif statement.kind == "if" then
        for i, statements in ipairs(statement.statements) do
            if statement.expressions[i] then
                local obj = self:AnalyzeExpression(statement.expressions[i], "runtime")

                if obj:IsTruthy() then
                    self:PushScope(statement, statement.tokens["if/else/elseif"][i])
                        obj:PushTruthy()
                            self:AnalyzeStatements(statements)
                        obj:PopTruthy()
                    self:PopScope()
                    break
                end
            else
                -- else part
                self:PushScope(statement, statement.tokens["if/else/elseif"][i])
                    self:AnalyzeStatements(statements)
                self:PopScope()
            end
        end
    elseif statement.kind == "while" then
        if self:AnalyzeExpression(statement.expression):IsTruthy() then
            self:PushScope(statement)
            self:AnalyzeStatements(statement.statements)
            self:PopScope()
        end
    elseif statement.kind == "do" then
        self:PushScope(statement)
        self:AnalyzeStatements(statement.statements)
        self:PopScope()
    elseif statement.kind == "repeat" then
        self:PushScope(statement)
        self:AnalyzeStatements(statement.statements)
        if self:AnalyzeExpression(statement.expression):IsTruthy() then
            self:FireEvent("break")
        end
        self:PopScope()
    elseif statement.kind == "return" then
        local ret = self:AnalyzeExpressions(statement.expressions)
        self:CollectReturnExpressions(ret)
        self.Returned = true
        self:FireEvent("return", ret)
    elseif statement.kind == "break" then
        self:FireEvent("break")
    elseif statement.kind == "call_expression" then
        self:FireEvent("call", statement.value, {self:AnalyzeExpression(statement.value)})
    elseif statement.kind == "generic_for" then
        self:PushScope(statement)

        local args = self:AnalyzeExpressions(statement.expressions)
        local obj = args[1]


        if obj then
            table.remove(args, 1)
            local values = self:Assert(statement.expressions[1], self:Call(obj, types.Tuple:new(args), statement.expressions[1]))

            for i,v in ipairs(statement.identifiers) do
                self:SetUpvalue(v, values:Get(i), "runtime")
            end
        end

        self:AnalyzeStatements(statement.statements)

        self:PopScope()
    elseif statement.kind == "numeric_for" then
        self:PushScope(statement)
        local range = self:AnalyzeExpression(statement.expressions[1]):Max(self:AnalyzeExpression(statement.expressions[2]))
        self:SetUpvalue(statement.identifiers[1], range, "runtime")

        if statement.expressions[3] then
            self:AnalyzeExpression(statement.expressions[3])
        end

        self:AnalyzeStatements(statement.statements)
        self:PopScope()
    elseif statement.kind == "type_interface" then
        local tbl = self:GetValue(statement.key, "typesystem") or self:TypeFromImplicitNode(statement, "table", {})

        for _, exp in ipairs(statement.expressions) do
            local left = tbl:Get(exp.left.value)
            local right = self:AnalyzeExpression(exp.right, "typesystem")

            -- function overload shortcut
            if left and left.Type == "object" and left.type == "function" then
                tbl:Set(exp.left.value, types.Set:new({left, right}))
            elseif left and left.Type == "set" then
                left:AddElement(right)
            else
                tbl:Set(exp.left.value, right)
            end
        end

        self:SetUpvalue(statement.key, tbl, "typesystem")
    elseif
        statement.kind ~= "end_of_file" and
        statement.kind ~= "semicolon" and
        statement.kind ~= "shebang" and
        statement.kind ~= "goto_label" and
        statement.kind ~= "goto"
    then
        error("unhandled statement " .. tostring(statement))
    end
end

do
    function META:AnalyzeExpression(exp, env)
        assert(exp and exp.type == "expression")
        env = env or "runtime"

        if self.PreferTypesystem then
            env = "typesystem"
        end

        local stack = self:CreateStack()

        for _, node in ipairs(self:ExpandExpression(exp)) do
            self.current_expression = node

            if node.type_expression then
                local val = self:AnalyzeExpression(node.type_expression, "typesystem")
                stack:Push(val)
                if node.tokens["is"] then
                    node.result_is = self:GetValue(node, env):IsType(val)
                end
            elseif node.kind == "value" then
                if (node.value.type == "letter" and node.upvalue_or_global) or node.value.value == "..." then
                    local obj

                    if env == "typesystem" then
                        if node.value.value == "any" then
                            obj = self:TypeFromImplicitNode(node, "any")
                        elseif node.value.value == "self" then
                            obj = self:TypeFromImplicitNode(node, "self")--self.current_table
                        elseif node.value.value == "inf" then
                            obj = self:TypeFromImplicitNode(node, "number", math.huge, true)
                        elseif node.value.value == "nan" then
                            obj = self:TypeFromImplicitNode(node, "number", 0/0, true)
                        end
                    end

                    if not obj then
                        -- if it's ^string, number, etc, but not string
                        if env == "typesystem" and types.IsPrimitiveType(self:Hash(node)) and not node.force_upvalue then
                            obj = self:TypeFromImplicitNode(node, node.value.value)
                        else
                            obj = self:GetValue(node, env)

                            if not obj and env == "runtime" then
                                obj = self:GetValue(node, "typesystem")
                            end
                        end
                    end


                    if not obj and self.IndexNotFound then
                        obj = self:IndexNotFound(node)
                    end

                    -- last resort, itemCount > number
                    if not obj then
                        obj = self:GetInferredType(node, env)
                    end

                    stack:Push(obj)
                elseif node.value.type == "number" then
                    stack:Push(self:TypeFromImplicitNode(node, "number", self:StringToNumber(node.value.value), true))
                elseif node.value.type == "string" then
                    stack:Push(self:TypeFromImplicitNode(node, "string", node.value.value:sub(2, -2), true))
                elseif node.value.type == "letter" then
                    stack:Push(self:TypeFromImplicitNode(node, "string", node.value.value, true))
                elseif node.value.value == "nil" then
                    stack:Push(self:TypeFromImplicitNode(node, "nil", env == "typesystem"))
                elseif node.value.value == "true" then
                    stack:Push(self:TypeFromImplicitNode(node, "boolean", true, true))
                elseif node.value.value == "false" then
                    stack:Push(self:TypeFromImplicitNode(node, "boolean", false, true))
                else
                    error("unhandled value type " .. node.value.type .. " " .. node:Render())
                end
            elseif node.kind == "function" then
                stack:Push(self:AnalyzeFunction(node, env))
            elseif node.kind == "table" then
                stack:Push(self:TypeFromImplicitNode(node, "table", self:AnalyzeTable(node, env), env == "typesystem"))
            elseif node.kind == "binary_operator" then
                local right, left = stack:Pop(), stack:Pop()

                if node.value.value == ":" then
                    stack:Push(left)
                end

                 stack:Push(self:Assert(node, self:BinaryOperator(node, left, right, env)))
            elseif node.kind == "prefix_operator" then
                local left = stack:Pop()
                stack:Push(self:Assert(node, self:PrefixOperator(node, left, env)))
            elseif node.kind == "postfix_operator" then
                local right = stack:Pop()
                stack:Push(self:Assert(node, self:PostfixOperator(node, right, env)))
            elseif node.kind == "postfix_expression_index" then
                local obj = stack:Pop()
                stack:Push(self:Assert(node, self:GetOperator(obj, self:AnalyzeExpression(node.expression))))
            elseif node.kind == "type_function" then
                stack:Push(self:AnalyzeFunction(node, env))
            elseif node.kind == "postfix_call" then
                local obj = stack:Pop()

                local arguments = self:AnalyzeExpressions(node.expressions, node.type_call and "typesystem" or env)

                if node.self_call then
                    local val = stack:Pop()
                    table.insert(arguments, 1, val)
                end

                --lua function
                local callable = obj.Type == "dictionary" and obj.meta and obj.meta:Get("__call")

                if callable then
                    local arg = obj
                    arg.volatile = true
                    table.insert(arguments, 1, arg)
                    obj = callable
                end

                if obj.type and obj.type ~= "function" and obj.type ~= "table" and obj.type ~= "any" then
                    self:Error(node, tostring(obj) .. " cannot be called")
                else
                    self.PreferTypesystem = node.type_call
                    stack:Push(self:Assert(node, self:Call(obj, types.Tuple:new(arguments), node)))
                    self.PreferTypesystem = nil
                end
            elseif node.kind == "type_list" then
                local tbl = {}

                if node.types then
                    for i, exp in ipairs(node.types)do
                        tbl[i] = self:AnalyzeExpression(exp, env)
                    end
                end

                -- number[3] << tbl only contains {3}.. hmm
                stack:Push(self:TypeFromImplicitNode(node, "list", {length = nil, values = tbl}))
            elseif node.kind == "type_table" then
                local obj = self:TypeFromImplicitNode(node, "table")

                self.current_table = obj
                for _, v in ipairs(self:AnalyzeTable(node, env)) do
                    obj:Set(v.key, v.val, true)
                end
                self.current_table = nil

                stack:Push(obj)
            elseif node.kind == "import" or node.kind == "lsx" then
                --stack:Push(self:AnalyzeStatement(node.root))
            else
                error("unhandled expression " .. node.kind)
            end
        end

        return stack:Unpack()
    end

    function META:AnalyzeFunction(node, env)
        local args = {}

        for i, key in ipairs(node.identifiers) do
            -- if this node is already explicitly annotated with foo: mytype or foo as mytype use that
            if key.type_expression then
                args[i] = self:AnalyzeExpression(key.type_expression, "typesystem") or self:GetInferredType(key)
            else
                if env == "typesystem" then
                    if key.kind == "value" and key.value.value == "..." then
                        args[i] = self:TypeFromImplicitNode(key, "...", {self:TypeFromImplicitNode(key, "any")})
                        args[i].max = math.huge
                    elseif key.kind == "type_table" then
                        args[i] = self:AnalyzeExpression(key)
                    else
                        args[i] = self:GetValue(key.left or key, env) or (types.IsPrimitiveType(key.value.value) and self:TypeFromImplicitNode(node, key.value.value)) or self:GetInferredType(key)
                    end
                else
                    if key.value.value == "..." then
                        args[i] = self:TypeFromImplicitNode(key, "...", {self:TypeFromImplicitNode(key, "any")})
                        args[i].max = math.huge
                    else
                        args[i] = self:GetInferredType(key)
                    end
                    args[i].volatile = true
                end
            end
        end

        if node.self_call and node.expression then
            local upvalue = self:GetUpvalue(node.expression.left, "runtime")
            if upvalue then
                -- TODO: this will cause local META = {} .. to be volatile,
                -- all the volatile things should be separated from types i think
                upvalue.data.volatile = true
                table.insert(args, 1, upvalue.data)
            end
        end


        local ret = {}

		if node.return_types then
			self:PushScope(node)
				for i, key in ipairs(node.identifiers) do
					self:SetUpvalue(key, args[i], "typesystem")
				end

				for i, type_exp in ipairs(node.return_types) do
					ret[i] = self:AnalyzeExpression(type_exp, "typesystem")
				end
			self:PopScope()
        end


        if node.return_expressions then
            for i,v in ipairs(node.return_expressions) do
                ret[i] = self:AnalyzeExpression(v, env)
            end
        end

        args = types.Tuple:new(args)
        ret = types.Tuple:new(ret)

        local func
        if env == "typesystem" then
            if node.statements and node.kind == "type_function" then
                local str = "local oh, analyzer, types, node = ...; return " .. node:Render({})
                local load_func, err = load(str, "")
                if not load_func then
                    -- this should never happen unless node:Render() produces bad code or the parser didn't catch any errors
                    io.write(str, "\n")
                    error(err)
                end
                func = load_func(require("oh"), self, types, node)
            end
        end

        local obj = self:TypeFromImplicitNode(node, "function", {
            arg = args,
            ret = ret,
            lua_function = func
        })


        if env == "runtime" then
            self:CallMeLater(obj, args, node, true)
        end

        return obj
    end

    function META:AnalyzeTable(node, env)
        local out = {}
        for i, node in ipairs(node.children) do
            if node.kind == "table_key_value" then
                local val = self:AnalyzeExpression(node.expression, env)
                out[i] = {
                    key = node.tokens["identifier"].value,
                    val = val
                }
            elseif node.kind == "table_expression_value" then

                local key = self:AnalyzeExpression(node.expressions[1], env)
                local obj = self:AnalyzeExpression(node.expressions[2], env)


                if key:IsType("string") and key.value then
                    out[i] = {key = key.value, val = obj}
                else
                    out[i] = {key = key, val = obj}
                end
            elseif node.kind == "table_index_value" then
                local val = {self:AnalyzeExpression(node.expression, env)}
                if node.i then
                    out[i] = {
                        key = node.i,
                        val = val[1]
                    }
                elseif val then
                    for i, val in ipairs(val) do
                        table.insert(out, {
                            key = #out + 1,
                            val = val
                        })
                    end
                end
            end
        end
        return out
    end
end



return require("oh.analyzer")(META)