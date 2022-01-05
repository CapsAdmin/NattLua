local tostring = tostring
local ipairs = ipairs
local LNumber = require("nattlua.types.number").LNumber
local LString = require("nattlua.types.string").LString
local Table = require("nattlua.types.table").Table
local table = require("table")
return
	{
		AnalyzeTable = function(analyzer, node)
			local tbl = Table():SetNode(node):SetLiteral(analyzer:IsTypesystem())

			if analyzer:IsRuntime() then
				tbl:SetReferenceId(tostring(tbl:GetData()))
			end

			analyzer.current_tables = analyzer.current_tables or {}
			table.insert(analyzer.current_tables, tbl)
			local tree = node

			tbl.scope = analyzer:GetScope()

			for i, node in ipairs(node.children) do
				if node.kind == "table_key_value" then
					local key = LString(node.tokens["identifier"].value):SetNode(node.tokens["identifier"])
					local val = analyzer:AnalyzeExpression(node.value_expression):GetFirstValue()
					analyzer:NewIndexOperator(node, tbl, key, val)
				elseif node.kind == "table_expression_value" then
					local key = analyzer:AnalyzeExpression(node.key_expression):GetFirstValue()
					local val = analyzer:AnalyzeExpression(node.value_expression):GetFirstValue()
					analyzer:NewIndexOperator(node, tbl, key, val)
				elseif node.kind == "table_index_value" then
					local obj = analyzer:AnalyzeExpression(node.value_expression)
					
					if node.value_expression.kind ~= "value" or node.value_expression.value.value ~= "..." then
						obj = obj:GetFirstValue()
					end

					if obj.Type == "tuple" then

						if tree.children[i + 1] then
							tbl:Insert(obj:Get(1))
						else
							for i = 1, obj:GetMinimumLength() do
								tbl:Set(LNumber(tbl:GetLength() + 1), obj:Get(i))
							end

							if obj.Remainder then
								local current_index = LNumber(tbl:GetLength() + 1)
								local max = LNumber(obj.Remainder:GetLength())
								tbl:Set(current_index:SetMax(max), obj.Remainder:Get(1))
							end
						end
					else
						if node.i then
							tbl:Insert(LNumber(obj))
						elseif obj then
							tbl:Insert(obj)
						end
					end
				end
				analyzer:ClearAffectedUpvalues()
			end

			table.remove(analyzer.current_tables)

			return tbl
		end,
	}
