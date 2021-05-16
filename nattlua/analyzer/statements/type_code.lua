return function(analyzer, statement)
	local code = statement.lua_code.value.value:sub(3)
	analyzer:CallLuaTypeFunction(statement.lua_code, analyzer:CompileLuaTypeCode(code, statement.lua_code), analyzer:GetScope())
end