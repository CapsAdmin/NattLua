local tostring = tostring
local ipairs = ipairs
local NodeToString = require("nattlua.types.string").NodeToString
local Nil = require("nattlua.types.symbol").Nil
return
	{
		AnalyzeDestructureAssignment = function(analyzer, statement)
			local obj = analyzer:AnalyzeExpression(statement.right)

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
					analyzer:CreateLocalValue(key, obj)
				elseif statement.kind == "destructure_assignment" then
					analyzer:SetLocalOrGlobalValue(key, obj)
				end
			end

			for _, node in ipairs(statement.left) do
				local obj = node.value and obj:Get(NodeToString(node))

				if not obj then
					if analyzer:IsRuntime() then
						obj = Nil():SetNode(node)
					else
						analyzer:Error(node, "field " .. tostring(node.value.value) .. " does not exist")
					end
				end

				if statement.kind == "local_destructure_assignment" then
					analyzer:CreateLocalValue(NodeToString(node), obj)
				elseif statement.kind == "destructure_assignment" then
					analyzer:SetLocalOrGlobalValue(NodeToString(node), obj)
				end
			end
		end,
	}
