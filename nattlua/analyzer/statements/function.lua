local AnalyzeFunction = require("nattlua.analyzer.expressions.function").AnalyzeFunction
local NodeToString = require("nattlua.types.string").NodeToString
return
	{
		AnalyzeFunction = function(analyzer, statement)
			if
				statement.kind == "local_function" or
				statement.kind == "local_analyzer_function" or
				statement.kind == "local_type_function"
			then
				analyzer:PushAnalyzerEnvironment(statement.kind == "local_function" and "runtime" or "typesystem")
				analyzer:CreateLocalValue(statement.tokens["identifier"], AnalyzeFunction(analyzer, statement))
				analyzer:PopAnalyzerEnvironment()
			elseif
				statement.kind == "function" or
				statement.kind == "analyzer_function" or
				statement.kind == "type_function"
			then
				local key = statement.expression

				analyzer:PushAnalyzerEnvironment(statement.kind == "function" and "runtime" or "typesystem")

				if key.kind == "binary_operator" then
					local obj = analyzer:AnalyzeExpression(key.left)
					local key = analyzer:AnalyzeExpression(key.right)
					local val = AnalyzeFunction(analyzer, statement)
					analyzer:NewIndexOperator(statement, obj, key, val)
				else
					local key = NodeToString(key)
					local val = AnalyzeFunction(analyzer, statement)
					analyzer:SetLocalOrGlobalValue(key, val)
				end

				analyzer:PopAnalyzerEnvironment()
			else
				analyzer:FatalError("unhandled statement: " .. statement.kind)
			end
		end,
	}
