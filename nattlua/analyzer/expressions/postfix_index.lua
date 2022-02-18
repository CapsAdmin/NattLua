return {
	AnalyzePostfixIndex = function(self, node)
		return self:Assert(
			node,
			self:IndexOperator(
				node,
				self:AnalyzeExpression(node.left),
				self:AnalyzeExpression(node.expression):GetFirstValue()
			)
		)
	end,
}
