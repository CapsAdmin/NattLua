local types = require("nattlua.types.types")

return function(META)
    function META:AnalyzeFunctionExpression(node, env)
        local explicit_arguments = false
        local explicit_return = false

        local args = {}

        if node.kind == "function" or node.kind == "local_function" then
            for i, key in ipairs(node.identifiers) do
                if key.value.value == "..." then
                    if key.explicit_type then
                        args[i] = self:NewType(key, "...")
                        args[i]:Set(1, self:AnalyzeExpression(key.explicit_type, "typesystem"))
                    else
                        args[i] = self:NewType(key, "...")
                    end
                elseif key.explicit_type then
                    args[i] = self:AnalyzeExpression(key.explicit_type, "typesystem")
                    explicit_arguments = true
                else    
                    args[i] = self:GuessTypeFromIdentifier(key)
                end
            end
        else
            for i, key in ipairs(node.identifiers) do
                if key.identifier then
                    args[i] = self:AnalyzeExpression(key, "typesystem")
                    explicit_arguments = true
                elseif key.explicit_type then
                    args[i] = self:AnalyzeExpression(key.explicit_type, "typesystem")
                    explicit_arguments = true
                elseif key.value.value == "self" then
                    args[i] = self.current_table
                elseif key.value.value == "..." then
                    args[i] = self:NewType(key, "...")
                else
                    args[i] = self:NewType(key, "any")
                end
            end    
        end
    
        if node.self_call and node.expression then
            local upvalue = self:FindLocalValue(node.expression.left, "runtime")
            if upvalue then
                if upvalue.data.contract then
                    table.insert(args, 1, upvalue.data)
                else
                    table.insert(args, 1, types.Union({types.Any(), upvalue.data}))
                end
            end
        end

        local ret = {}

        if node.return_types then
            explicit_return = true
            self:CreateAndPushScope(node)
                for i, key in ipairs(node.identifiers) do
                    if key.kind == "value" then
                        self:CreateLocalValue(key, args[i], "typesystem", true)
                    end
                end

                for i, type_exp in ipairs(node.return_types) do
                    if type_exp.kind == "value" and type_exp.value.value == "..." then
                        local tup
                        if type_exp.explicit_type then
                            tup = types.Tuple({self:AnalyzeExpression(type_exp.explicit_type, "typesystem")}):SetRepeat(math.huge)
                        else
                            tup = self:NewType(type_exp, "...")
                        end
                        ret[i] = tup
                    else
                        ret[i] = self:AnalyzeExpression(type_exp, "typesystem")
                    end
                end
            self:PopScope()
        end
        
        args = types.Tuple(args)
        ret = types.Tuple(ret)

        local func
        if env == "typesystem" then
            if node.statements and (node.kind == "type_function" or node.kind == "local_type_function") then
                func = self:CompileLuaTypeCode("return " .. node:Render({}), node)()
            end
        end

        local obj = self:NewType(node, "function", {
            arg = args,
            ret = ret,
            lua_function = func
        })

        obj.explicit_arguments = explicit_arguments
        obj.explicit_return = explicit_return

        if env == "runtime" then
            self:CallMeLater(obj, args, node, true)
        end

        return obj
    end
end