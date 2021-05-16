
local prefix_operator = require("nattlua.analyzer.operators.prefix")

return function(analyzer, node, env)
    return analyzer:Assert(node, prefix_operator(analyzer, node, analyzer:AnalyzeExpression(node.right, env), env))
end