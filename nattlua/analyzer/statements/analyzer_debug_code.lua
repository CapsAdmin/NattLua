return
	{
		AnalyzeAnalyzerDebugCode = function(analyzer, statement)
			local code = statement.lua_code.value.value:sub(3)
			analyzer:CallLuaTypeFunction(statement.lua_code, analyzer:CompileLuaAnalyzerDebugCode(code, statement.lua_code), analyzer:GetScope())
		end,
	}
