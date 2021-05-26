local tostring = tostring
local ipairs = ipairs
local NodeToString = require("nattlua.types.string").NodeToString
local Nil = require("nattlua.types.symbol").Nil
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
		local key = NodeToString(statement.default)

		if statement.kind == "local_destructure_assignment" then
			analyzer:CreateLocalValue(key, obj, env)
		elseif statement.kind == "destructure_assignment" then
			analyzer:SetLocalOrEnvironmentValue(key, obj, env)
		end
	end

	for _, node in ipairs(statement.left) do
		local obj = node.value and obj:Get(NodeToString(node), env)

		if not obj then
			if env == "runtime" then
				obj = Nil():SetNode(node)
			else
				analyzer:Error(node, "field " .. tostring(node.value.value) .. " does not exist")
			end
		end

		if statement.kind == "local_destructure_assignment" then
			analyzer:CreateLocalValue(NodeToString(node), obj, env)
		elseif statement.kind == "destructure_assignment" then
			analyzer:SetLocalOrEnvironmentValue(NodeToString(node), obj, env)
		end
	end
end
