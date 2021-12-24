return
	{
		AnalyzePostfixIndex = function(analyzer, node)
			return analyzer:Assert(node, analyzer:IndexOperator(node, analyzer:AnalyzeExpression(node.left), analyzer:AnalyzeExpression(node.expression):GetFirstValue()))
		end,
	}
