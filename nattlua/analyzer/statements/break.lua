return
	{
		AnalyzeBreak = function(self, statement)
			self.break_out_scope = self:GetScope()
			self.break_loop = true
		end,
	}
