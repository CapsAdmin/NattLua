return function(META)
	function META:AnalyzeCallExpressionStatement(statement)
		local foo = self:AnalyzeExpression(statement.value)
		self:FireEvent("call", statement.value, {foo})
	end
end
