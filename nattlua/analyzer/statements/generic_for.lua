local types = require("nattlua.types.types")
return function(analyzer, statement)
	local args = analyzer:AnalyzeExpressions(statement.expressions)
	local obj = table.remove(args, 1)
	if not obj then return end

	if obj.Type == "tuple" then
		obj = obj:Get(1)
	end

	local returned_key = nil
	local one_loop = obj and obj.Type == "any"
	local uncertain_break = nil

	for i = 1, 1000 do
		local values = analyzer:Assert(statement.expressions[1], analyzer:Call(obj, types.Tuple(args), statement.expressions[1]))

		if
			not values:Get(1) or
			values:Get(1).Type == "symbol" and
			values:Get(1):GetData() == nil
		then
			break
		end

		if i == 1 then
			returned_key = values:Get(1)

			if not returned_key:IsLiteral() then
				returned_key = types.Union({types.Symbol(nil), returned_key})
			end

			analyzer:CreateAndPushScope()
				analyzer:OnEnterConditionalScope({
					type = "generic_for",
					condition = returned_key,
				})
				analyzer:FireEvent("generic_for", statement.identifiers, values)
			end

			local brk = false

			for i, identifier in ipairs(statement.identifiers) do
				local obj = values:Get(i)

				if uncertain_break then
					obj:SetLiteral(false)
					brk = true
				end

				analyzer:CreateLocalValue(identifier, obj, "runtime")
			end

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

			if i == 1000 then
				analyzer:Error(statement, "too many iterations")
			end

			table.insert(values:GetData(), 1, args[1])
			args = values:GetData()
			if one_loop then break end
			if brk then break end
		end

		if returned_key then
			analyzer:PopScope()
			analyzer:OnExitConditionalScope({condition = returned_key})
		end
	end
