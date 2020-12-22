local types = require("nattlua.types.types")

return function(META)
    require("nattlua.analyzer.operators.binary")(META)
    require("nattlua.analyzer.operators.prefix")(META)
    require("nattlua.analyzer.operators.postfix")(META)

    require("nattlua.analyzer.expressions.postfix_call")(META)
    require("nattlua.analyzer.expressions.postfix_index")(META)
    require("nattlua.analyzer.expressions.function")(META)
    require("nattlua.analyzer.expressions.table")(META)
    require("nattlua.analyzer.expressions.atomic_value")(META)
    require("nattlua.analyzer.expressions.list")(META)

    function META:AnalyzeExpression(node, env)
        self.current_expression = node

        if not node then error("node is nil", 2) end
        if node.type ~= "expression" then error("node is not an expression", 2) end
        env = env or "runtime"
    
        if self.PreferTypesystem then
            env = "typesystem"
        end

        if node.explicit_type then
            if node.kind == "table" then
                local obj = self:AnalyzeTableExpression(node, env)
                obj:SetContract(self:AnalyzeExpression(node.explicit_type, "typesystem"))
                return obj
            end

            return self:AnalyzeExpression(node.explicit_type, "typesystem")
        elseif node.kind == "value" then
            return self:AnalyzeAtomicValueExpression(node, env)
        elseif node.kind == "function" or node.kind == "type_function" then
            return self:AnalyzeFunctionExpression(node, env)
        elseif node.kind == "table" or node.kind == "type_table" then
            return self:AnalyzeTableExpression(node, env)
        elseif node.kind == "type_list" then
            return self:AnalyzeListExpression(node, env)
        elseif node.kind == "binary_operator" then
            return self:AnalyzeBinaryOperatorExpression(node, env)
        elseif node.kind == "prefix_operator" then
            return self:AnalyzePrefixOperatorExpression(node, env)
        elseif node.kind == "postfix_operator" then
            return self:AnalyzePostfixOperatorExpression(node, env)
        elseif node.kind == "postfix_expression_index" then
            return self:AnalyzePostfixExpressionIndexExpression(node, env)
        elseif node.kind == "postfix_call" then
            return self:AnalyzePostfixCallExpression(node, env)
        else
            self:FatalError("unhandled expression " .. node.kind)
        end
    end
end
