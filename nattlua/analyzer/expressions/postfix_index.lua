return function(analyzer, node, env)
	return analyzer:Assert(node, analyzer:IndexOperator(node, analyzer:AnalyzeExpression(node.left, env), analyzer:AnalyzeExpression(node.expression, env), env))
end
