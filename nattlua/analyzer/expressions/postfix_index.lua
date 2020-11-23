local types = require("nattlua.types.types")

return function(META)
    function META:AnalyzePostfixExpressionIndexExpression(node, env)
        return self:Assert(
            node, 
            self:IndexOperator(
                self:AnalyzeExpression(node.left, env), 
                self:AnalyzeExpression(node.expression, env), 
                node
            )
        )
    end
end