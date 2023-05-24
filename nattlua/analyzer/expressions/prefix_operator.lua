local Prefix = require("nattlua.analyzer.operators.prefix").Prefix
return {
	AnalyzePrefixOperator = function(self, node)
		local op = node.value.value

		if op == "not" then
			self.inverted_index_tracking = not self.inverted_index_tracking
		end

		local r = self:AnalyzeExpression(node.right)

		if op == "not" then self.inverted_index_tracking = nil end

		self.current_expression = node
		return self:Assert(Prefix(self, node, r))
	end,
}