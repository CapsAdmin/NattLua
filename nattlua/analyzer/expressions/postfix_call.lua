local types = require("nattlua.types.types")
local Tuple = types.Tuple

return function(META)
    function META:AnalyzePostfixCallExpression(node, env)
        local env =  node.type_call and "typesystem" or env

        local callable = self:AnalyzeExpression(node.left, env)
        if callable.Type == "tuple" then
            callable = callable:Get(1)
        end

        local types = self:AnalyzeExpressions(node.expressions, env)

        if self.self_arg_stack and node.left.kind == "binary_operator" and node.left.value.value == ":" then
            table.insert(types, 1, table.remove(self.self_arg_stack))
        end
        
        self.PreferTypesystem = node.type_call

        local arguments

        if #types == 1 and types[1].Type == "tuple" then
            arguments = types[1]
        else
            local temp = {}
            for i,v in ipairs(types) do
                if v.Type == "tuple" then
                    temp[i] = v:Get(1)
                else
                    temp[i] = v
                end
            end
            arguments = Tuple(temp)
        end
        
        local returned_tuple = self:Assert(node, self:Call(callable, arguments, node))
        
        self.PreferTypesystem = nil

        if node:IsWrappedInParenthesis() then
            returned_tuple = returned_tuple:Get(1)
        end

        if returned_tuple.Type == "tuple" and returned_tuple:GetLength() == 1 then
            returned_tuple = returned_tuple:Get(1)
        end

        return returned_tuple
    end
end