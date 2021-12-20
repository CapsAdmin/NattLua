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
				local env = statement.kind == "local_function" and "runtime" or "typesystem"
				analyzer:CreateLocalValue(statement.tokens["identifier"], AnalyzeFunction(analyzer, statement, env), env)
			elseif
				statement.kind == "function" or
				statement.kind == "analyzer_function" or
				statement.kind == "type_function"
			then
				local env = statement.kind == "function" and "runtime" or "typesystem"
				local key = statement.expression

				if key.kind == "binary_operator" then
					local obj = analyzer:AnalyzeExpression(key.left, env)
					local key = analyzer:AnalyzeExpression(key.right, env)
					local val = AnalyzeFunction(analyzer, statement, env)
					analyzer:NewIndexOperator(statement, obj, key, val, env)
				else
					local key = NodeToString(key)
					local existing_type = env == "runtime" and analyzer:GetLocalOrEnvironmentValue(key, "typesystem")
					local val = existing_type or AnalyzeFunction(analyzer, statement, env)
					analyzer:SetLocalOrEnvironmentValue(key, val, env)
				end
			else
				analyzer:FatalError("unhandled statement: " .. statement.kind)
			end
		end,
	}
