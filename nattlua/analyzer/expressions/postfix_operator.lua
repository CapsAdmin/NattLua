local postfix_operator = require("nattlua.analyzer.operators.postfix")

return function(analyzer, node, env)
    return analyzer:Assert(node, postfix_operator(analyzer, node, analyzer:AnalyzeExpression(node.left, env), env))
end