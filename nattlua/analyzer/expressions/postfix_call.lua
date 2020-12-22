local types = require("nattlua.types.types")
local Tuple = types.Tuple

return function(META)
    function META:AnalyzePostfixCallExpression(node, env)
        local env =  node.type_call and "typesystem" or env
        local callable = self:AnalyzeExpression(node.left, env)

        local self_arg

        if self.self_arg_stack and node.left.kind == "binary_operator" and node.left.value.value == ":" then
            self_arg = table.remove(self.self_arg_stack)
        end

        if callable.Type == "tuple" then
            callable = self:Assert(node, callable:Get(1))
        end

        if callable.Type == "symbol" then
            self:Error(node, tostring(node.left:Render()) .. " is nil")
            return types.Tuple({types.Any()})
        end

        local types = self:AnalyzeExpressions(node.expressions, env)

        if self_arg then
            table.insert(types, 1, self_arg)
        end
        
        self.PreferTypesystem = node.type_call

        local arguments

        if #types == 1 and types[1].Type == "tuple" then
            arguments = types[1]
        else
            local temp = {}
            for i,v in ipairs(types) do
                if v.Type == "tuple" then
                    if i == #types then
                        table.insert(temp, v)
                    else
                        local obj = v:Get(1)
                        if obj then
                            table.insert(temp, obj)
                        end
                    end
                else
                    table.insert(temp, v)
                end
            end
            arguments = Tuple(temp)
        end
        
        local returned_tuple = self:Assert(node, self:Call(callable, arguments, node))
        
        self.PreferTypesystem = nil

        if node:IsWrappedInParenthesis() then
            returned_tuple = returned_tuple:Get(1)
        end

        if env == "runtime" and returned_tuple.Type == "tuple" and returned_tuple:GetLength() == 1 then
            returned_tuple = returned_tuple:Get(1)
        end

        return returned_tuple
    end
end