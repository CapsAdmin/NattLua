return function(META)
	function META:AnalyzeWhileStatement(statement)
		local obj = self:AnalyzeExpression(statement.expression)

		if obj:IsTruthy() then
			self:CreateAndPushScope()
				self:FireEvent("while", obj)
				self:OnEnterConditionalScope({type = "while", condition = obj,})
				self:AnalyzeStatements(statement.statements)
			self:PopScope()
			self:OnExitConditionalScope({condition = obj})
			self.break_out_scope = nil
		end
	end
end
