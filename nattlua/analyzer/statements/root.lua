local types = require("nattlua.types.types")
return function(META)
	function META:AnalyzeRootStatement(statement, ...)
		local argument_tuple = ... and types.Tuple({...}) or types.Tuple({...}):AddRemainder(types.Tuple({types.Any()}):SetRepeat(math.huge))
		self:CreateAndPushFunctionScope(statement, nil, {type = "root"})
		self:PushEnvironment(statement, nil, "runtime")
		self:PushEnvironment(statement, nil, "typesystem")
		self:CreateLocalValue("...", argument_tuple, "runtime")
		local analyzed_return = self:AnalyzeStatementsAndCollectReturnTypes(statement)
		self:PopEnvironment("runtime")
		self:PopEnvironment("typesystem")
		self:PopScope()
		return analyzed_return
	end
end
