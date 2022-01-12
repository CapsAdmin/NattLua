return
	{
		AnalyzeAnalyzerDebugCode = function(self, statement)
			local code = statement.lua_code.value.value:sub(3)
			self:CallLuaTypeFunction(statement.lua_code, self:CompileLuaAnalyzerDebugCode(code, statement.lua_code), self:GetScope())
		end,
	}
