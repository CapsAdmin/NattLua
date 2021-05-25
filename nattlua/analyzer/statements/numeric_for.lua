local ipairs = ipairs
local math = math
local assert = assert
local True = require("nattlua.types.symbol").True
local LNumber = require("nattlua.types.number").LNumber
local False = require("nattlua.types.symbol").False
local Union = require("nattlua.types.union").Union
local binary_operator = require("nattlua.analyzer.operators.binary")

local function get_largest_number(obj)
	if obj:IsLiteral() then
		if obj.Type == "union" then
			local max = -math.huge

			for _, v in ipairs(obj:GetData()) do
				max = math.max(max, v:GetData())
			end

			return max
		end

		return obj:GetData()
	end
end

return function(analyzer, statement)
	local init = analyzer:AnalyzeExpression(statement.expressions[1])
	local max = analyzer:AnalyzeExpression(statement.expressions[2])
	local step = statement.expressions[3] and analyzer:AnalyzeExpression(statement.expressions[3]) or nil

	if step then
		assert(step.Type == "number")
	end

	local literal_init = get_largest_number(init)
	local literal_max = get_largest_number(max)
	local literal_step = not step and 1 or get_largest_number(step)
	local condition = Union()

	if literal_init and literal_max then
		-- also check step
		condition:AddType(binary_operator(
			analyzer,
			statement,
			init,
			max,
			"runtime",
			"<="
		))
	else
		condition:AddType(True())
		condition:AddType(False())
	end

	statement.identifiers[1].inferred_type = init
	analyzer:CreateAndPushScope()
		analyzer:OnEnterConditionalScope(
			{
				type = "numeric_for",
				init = init,
				max = max,
				condition = condition,
				step = step,
			}
		)
		analyzer:FireEvent("numeric_for", init, max, step)

		if literal_init and literal_max and literal_step and literal_max < 1000 then
			local uncertain_break = false

			for i = literal_init, literal_max, literal_step do
				analyzer:CreateAndPushScope()
					analyzer:OnEnterConditionalScope(
						{
							type = "numeric_for_iteration",
							condition = condition,
							i = i,
						}
					)
					local i = LNumber(i):SetNode(statement.expressions[1])
					local brk = false

					if uncertain_break then
						i:SetLiteral(false)
						brk = true
					end

					analyzer:CreateLocalValue(statement.identifiers[1], i, "runtime")
					analyzer:AnalyzeStatements(statement.statements)

					if analyzer._continue_ then
						analyzer._continue_ = nil
					end

					if analyzer.break_out_scope then
						if analyzer.break_out_scope:IsUncertain() then
							uncertain_break = true
						else
							brk = true
						end

						analyzer.break_out_scope = nil
					end

				analyzer:PopScope()
				analyzer:OnExitConditionalScope({
					type = "numeric_for_iteration",
					i = i,
				})
				if brk then break end
			end

			local children = analyzer:GetScope():GetChildren()

			if children[1] then
				local merged_scope = children[1]:Copy(true)

				for i = 2, #children do
					merged_scope:Merge(children[i])
				end

				merged_scope:MakeReadOnly(true)
				analyzer:GetScope():AddChild(merged_scope)
				analyzer:FireEvent("merge_iteration_scopes", merged_scope)
				analyzer:PushScope(merged_scope)
					analyzer:AnalyzeStatements(statement.statements)
					statement.identifiers[1].inferred_type = analyzer:GetScope():FindValue(statement.identifiers[1].value.value, "runtime"):GetValue()
				analyzer:PopScope()
			end
		else
			if
				init.Type == "number" and
				(max.Type == "number" or (max.Type == "union" and max:IsType("number")))
			then
				init = analyzer:Assert(statement.expressions[1], init:SetMax(max))
			end

			if max.Type == "any" then
				init:SetLiteral(false)
			end

			local range = analyzer:Assert(statement.expressions[1], init)
			analyzer:CreateLocalValue(statement.identifiers[1], range, "runtime")
			analyzer:AnalyzeStatements(statement.statements)
		end

		analyzer:FireEvent("leave_scope")
		analyzer.break_out_scope = nil
	analyzer:PopScope()
	analyzer:OnExitConditionalScope({init = init, max = max, condition = condition})
end
