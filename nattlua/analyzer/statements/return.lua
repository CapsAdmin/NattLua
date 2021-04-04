return function(META)
	function META:AnalyzeReturnStatement(statement)
		local ret = self:AnalyzeExpressions(statement.expressions)
        
        -- do return end > do return nil end
        if not ret[1] then
			ret[1] = self:NewType(statement, "nil")
		end

		self:Return(statement, ret)
		self:FireEvent("return", ret)
	end
end
