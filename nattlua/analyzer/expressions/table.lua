local tostring = tostring
local ipairs = ipairs
local LNumber = require("nattlua.types.number").LNumber
local LString = require("nattlua.types.string").LString
local Table = require("nattlua.types.table").Table
local table = require("table")
return function(analyzer, node, env)
	local tbl = Table():SetNode(node):SetLiteral(env == "typesystem")

	if env == "runtime" then
		tbl:SetReferenceId(tostring(tbl:GetData()))
	end

	analyzer.current_tables = analyzer.current_tables or {}
	table.insert(analyzer.current_tables, tbl)
	local tree = node

	for i, node in ipairs(node.children) do
		if node.kind == "table_key_value" then
			local key = LString(node.tokens["identifier"].value):SetNode(node.tokens["identifier"])
			local val = analyzer:AnalyzeExpression(node.expression, env)
			analyzer:NewIndexOperator(node, tbl, key, val, env)
		elseif node.kind == "table_expression_value" then
			local key = analyzer:AnalyzeExpression(node.expressions[1], env)
			local val = analyzer:AnalyzeExpression(node.expressions[2], env)
			analyzer:NewIndexOperator(node, tbl, key, val, env)
		elseif node.kind == "table_index_value" then
			local val = {analyzer:AnalyzeExpression(node.expression, env)}

			if val[1].Type == "tuple" then
				local tup = val[1]

				if tree.children[i + 1] then
					tbl:Insert(tup:Get(1))
				else
					for i = 1, tup:GetMinimumLength() do
						tbl:Set(LNumber(tbl:GetLength() + 1), tup:Get(i))
					end

					if tup.Remainder then
						local current_index = LNumber(tbl:GetLength() + 1)
						local max = LNumber(tup.Remainder:GetLength())
						tbl:Set(current_index:SetMax(max), tup.Remainder:Get(1))
					end
				end
			else
				if node.i then
					tbl:Insert(LNumber(val[1]))
				elseif val then
					for _, val in ipairs(val) do
						tbl:Insert(val)
					end
				end
			end
		end
	end

	table.remove(analyzer.current_tables)
	return tbl
end
