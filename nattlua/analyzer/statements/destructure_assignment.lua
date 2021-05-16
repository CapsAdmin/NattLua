return function(analyzer, statement)
	local env = statement.environment or "runtime"
	local obj = analyzer:AnalyzeExpression(statement.right, env)

	if obj.Type == "union" then
		obj = obj:GetData()[1]
	end

	if obj.Type == "tuple" then
		obj = obj:Get(1)
	end

	if obj.Type ~= "table" then
		analyzer:Error(statement.right, "expected a table on the right hand side, got " .. tostring(obj.Type))
	end

	if statement.default then
		if statement.kind == "local_destructure_assignment" then
			analyzer:CreateLocalValue(statement.default, obj, env)
		elseif statement.kind == "destructure_assignment" then
			analyzer:SetLocalOrEnvironmentValue(statement.default, obj, env)
		end
	end

	for _, node in ipairs(statement.left) do
		local obj = node.value and obj:Get(node.value.value, env)

		if not obj then
			if env == "runtime" then
				obj = analyzer:NewType(node, "nil")
			else
				analyzer:Error(node, "field " .. tostring(node.value.value) .. " does not exist")
			end
		end

		if statement.kind == "local_destructure_assignment" then
			analyzer:CreateLocalValue(node, obj, env)
		elseif statement.kind == "destructure_assignment" then
			analyzer:SetLocalOrEnvironmentValue(node, obj, env)
		end
	end
end
